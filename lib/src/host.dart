import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'ai_providers.dart';
import 'controller.dart';
import 'generator.dart';
import 'spec.dart';
import 'xray.dart';

/// Entry point. Add one line to your app:
///
/// ```dart
/// MaterialApp(
///   theme: lightTheme,
///   darkTheme: darkTheme,
///   builder: Reskin.builder(theme: lightTheme, darkTheme: darkTheme),
///   home: const HomePage(),
/// )
/// ```
///
/// In release and profile builds [builder] returns your app unchanged.
abstract final class Reskin {
  static TransitionBuilder builder({
    ReskinController? controller,
    ThemeData? theme,
    ThemeData? darkTheme,
    bool enabled = kDebugMode,
    ReskinFontResolver? fontResolver,
    ValueChanged<String>? onExport,
    TransitionBuilder? builder,
    XrayScanner scanner = const XrayScanner(),
    bool registerServiceExtensions = true,
    bool initiallyOpen = false,
  }) {
    return (BuildContext context, Widget? child) {
      final inner = builder != null ? builder(context, child) : child!;
      if (!enabled) return inner;
      return ReskinHost(
        controller: controller,
        theme: theme,
        darkTheme: darkTheme,
        fontResolver: fontResolver,
        onExport: onExport,
        scanner: scanner,
        registerServiceExtensions: registerServiceExtensions,
        initiallyOpen: initiallyOpen,
        child: inner,
      );
    };
  }

  /// The controller of the nearest [ReskinHost], if any.
  static ReskinController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ReskinScope>()?.notifier;
}

class _ReskinScope extends InheritedNotifier<ReskinController> {
  const _ReskinScope(
      {required ReskinController controller, required super.child})
      : super(notifier: controller);
}

/// Wraps the app (inside MaterialApp, above the Navigator), applies the live
/// theme, paints the X-ray overlay and hosts the floating panel.
class ReskinHost extends StatefulWidget {
  const ReskinHost({
    super.key,
    required this.child,
    this.controller,
    this.theme,
    this.darkTheme,
    this.fontResolver,
    this.onExport,
    this.scanner = const XrayScanner(),
    this.registerServiceExtensions = true,
    this.initiallyOpen = false,
  });

  final Widget child;
  final ReskinController? controller;

  /// Your original light/dark themes, used when "Original" is selected and
  /// the Light/Dark toggle is forced. Defaults to the ambient theme.
  final ThemeData? theme;
  final ThemeData? darkTheme;
  final ReskinFontResolver? fontResolver;

  /// Called with the generated `app_theme.dart` source on Export.
  final ValueChanged<String>? onExport;
  final XrayScanner scanner;
  final bool registerServiceExtensions;
  final bool initiallyOpen;

  @override
  State<ReskinHost> createState() => ReskinHostState();
}

/// Public so tests and tools can call [scanNow].
class ReskinHostState extends State<ReskinHost> {
  static ReskinHostState? _active;
  static bool _extensionsRegistered = false;

  final GlobalKey _appKey = GlobalKey(debugLabel: 'reskin-app');
  late ReskinController _controller;
  bool _ownsController = false;
  ThemeData? _probe;
  bool _instant = false;
  bool _ready = false;
  int _handledRun = -1;
  Future<List<XrayFinding>>? _scanning;
  late final OverlayEntry _panelEntry;
  late ThemeData _base;

  ReskinController get controller => _controller;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? ReskinController();
    if (widget.initiallyOpen) _controller.setPanelOpen(true);
    _controller.addListener(_onChange);
    _panelEntry = OverlayEntry(
      builder: (_) => _PanelLayer(host: this),
    );
    _active = this;
    if (widget.registerServiceExtensions) _registerExtensions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void didUpdateWidget(ReskinHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller &&
        widget.controller != null) {
      _controller.removeListener(_onChange);
      if (_ownsController) _controller.dispose();
      _ownsController = false;
      _controller = widget.controller!;
      _controller.addListener(_onChange);
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    // Hot reload: source may have changed, so X-ray again.
    if (_controller.xray) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _controller.rescan());
    }
  }

  @override
  void dispose() {
    if (_active == this) _active = null;
    _controller.removeListener(_onChange);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    if (_controller.xray && _controller.xrayRuns != _handledRun) {
      _handledRun = _controller.xrayRuns;
      scheduleMicrotask(() => scanNow());
    }
  }

  Brightness get _brightness {
    final d = _controller.dark;
    if (d == null) return _base.brightness;
    return d ? Brightness.dark : Brightness.light;
  }

  ThemeData _original(Brightness b) {
    if (_controller.dark == null) return _base;
    if (b == Brightness.dark) {
      return widget.darkTheme ??
          (_base.brightness == Brightness.dark ? _base : _derive(_base, b));
    }
    return widget.theme ??
        (_base.brightness == Brightness.light ? _base : _derive(_base, b));
  }

  static ThemeData _derive(ThemeData from, Brightness b) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
            seedColor: from.colorScheme.primary, brightness: b),
      );

  ThemeData _resolved() {
    final b = _brightness;
    final c = _controller.current;
    if (c == null) return _original(b);
    return c.toThemeData(b, fontResolver: widget.fontResolver);
  }

  /// The probe: the live theme with every color role shifted to a different
  /// value (same layout, fonts and radii). A widget color that is identical
  /// before and after cannot come from the theme.
  static ThemeData _probeOf(ThemeData real) {
    Color sh(Color c) => Color.fromARGB(
          (c.a * 255).round(),
          ((c.r * 255).round() + 97) % 256,
          ((c.g * 255).round() + 53) % 256,
          ((c.b * 255).round() + 151) % 256,
        );
    final s = real.colorScheme;
    final cs = s.copyWith(
      primary: sh(s.primary),
      onPrimary: sh(s.onPrimary),
      primaryContainer: sh(s.primaryContainer),
      onPrimaryContainer: sh(s.onPrimaryContainer),
      primaryFixed: sh(s.primaryFixed),
      primaryFixedDim: sh(s.primaryFixedDim),
      onPrimaryFixed: sh(s.onPrimaryFixed),
      onPrimaryFixedVariant: sh(s.onPrimaryFixedVariant),
      secondary: sh(s.secondary),
      onSecondary: sh(s.onSecondary),
      secondaryContainer: sh(s.secondaryContainer),
      onSecondaryContainer: sh(s.onSecondaryContainer),
      secondaryFixed: sh(s.secondaryFixed),
      secondaryFixedDim: sh(s.secondaryFixedDim),
      onSecondaryFixed: sh(s.onSecondaryFixed),
      onSecondaryFixedVariant: sh(s.onSecondaryFixedVariant),
      tertiary: sh(s.tertiary),
      onTertiary: sh(s.onTertiary),
      tertiaryContainer: sh(s.tertiaryContainer),
      onTertiaryContainer: sh(s.onTertiaryContainer),
      tertiaryFixed: sh(s.tertiaryFixed),
      tertiaryFixedDim: sh(s.tertiaryFixedDim),
      onTertiaryFixed: sh(s.onTertiaryFixed),
      onTertiaryFixedVariant: sh(s.onTertiaryFixedVariant),
      error: sh(s.error),
      onError: sh(s.onError),
      errorContainer: sh(s.errorContainer),
      onErrorContainer: sh(s.onErrorContainer),
      surface: sh(s.surface),
      onSurface: sh(s.onSurface),
      surfaceDim: sh(s.surfaceDim),
      surfaceBright: sh(s.surfaceBright),
      surfaceContainerLowest: sh(s.surfaceContainerLowest),
      surfaceContainerLow: sh(s.surfaceContainerLow),
      surfaceContainer: sh(s.surfaceContainer),
      surfaceContainerHigh: sh(s.surfaceContainerHigh),
      surfaceContainerHighest: sh(s.surfaceContainerHighest),
      onSurfaceVariant: sh(s.onSurfaceVariant),
      outline: sh(s.outline),
      outlineVariant: sh(s.outlineVariant),
      shadow: sh(s.shadow),
      scrim: sh(s.scrim),
      inverseSurface: sh(s.inverseSurface),
      onInverseSurface: sh(s.onInverseSurface),
      inversePrimary: sh(s.inversePrimary),
      surfaceTint: sh(s.surfaceTint),
    );
    TextTheme shiftText(TextTheme t) {
      TextStyle? f(TextStyle? x) =>
          x?.color == null ? x : x!.copyWith(color: sh(x.color!));
      return t.copyWith(
        displayLarge: f(t.displayLarge),
        displayMedium: f(t.displayMedium),
        displaySmall: f(t.displaySmall),
        headlineLarge: f(t.headlineLarge),
        headlineMedium: f(t.headlineMedium),
        headlineSmall: f(t.headlineSmall),
        titleLarge: f(t.titleLarge),
        titleMedium: f(t.titleMedium),
        titleSmall: f(t.titleSmall),
        bodyLarge: f(t.bodyLarge),
        bodyMedium: f(t.bodyMedium),
        bodySmall: f(t.bodySmall),
        labelLarge: f(t.labelLarge),
        labelMedium: f(t.labelMedium),
        labelSmall: f(t.labelSmall),
      );
    }

    return real.copyWith(
      colorScheme: cs,
      textTheme: shiftText(real.textTheme),
      primaryTextTheme: shiftText(real.primaryTextTheme),
      scaffoldBackgroundColor: sh(real.scaffoldBackgroundColor),
      canvasColor: sh(real.canvasColor),
      cardColor: sh(real.cardColor),
      dividerColor: sh(real.dividerColor),
      primaryColor: sh(real.primaryColor),
      primaryColorLight: sh(real.primaryColorLight),
      primaryColorDark: sh(real.primaryColorDark),
      hintColor: sh(real.hintColor),
      disabledColor: sh(real.disabledColor),
      unselectedWidgetColor: sh(real.unselectedWidgetColor),
      secondaryHeaderColor: sh(real.secondaryHeaderColor),
      shadowColor: sh(real.shadowColor),
      iconTheme: real.iconTheme.color == null
          ? real.iconTheme
          : real.iconTheme.copyWith(color: sh(real.iconTheme.color!)),
    );
  }

  /// Runs the two-probe X-ray now and reports findings to the controller.
  Future<List<XrayFinding>> scanNow() {
    return _scanning ??= _scan().whenComplete(() => _scanning = null);
  }

  Future<List<XrayFinding>> _scan() async {
    // Let any theme animation settle first so the restore is seamless.
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return const <XrayFinding>[];
    final real = _resolved();
    final root = _appKey.currentContext as Element?;
    if (root == null) return const <XrayFinding>[];

    // The probe must not reach the screen: run it between frames, rebuilding
    // synchronously and restoring before anything is laid out or painted.
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      await SchedulerBinding.instance.endOfFrame;
      if (!mounted) return const <XrayFinding>[];
    }
    final owner = WidgetsBinding.instance.buildOwner!;
    final appRoot = WidgetsBinding.instance.rootElement!;

    // Snapshot A: the live theme as the user sees it.
    final a = widget.scanner.capture(root);

    // Snapshot B: every color role shifted. Built, read, and reverted.
    setState(() => _probe = _probeOf(real));
    owner.buildScope(appRoot);
    final b = widget.scanner.capture(root);
    setState(() {
      _probe = null;
      _instant = true;
    });
    owner.buildScope(appRoot);
    WidgetsBinding.instance.addPostFrameCallback((_) => _instant = false);
    final findings = widget.scanner.diff(a, b);
    if (_controller.xray) _controller.reportFindings(findings);
    return findings;
  }

  /// Exports the applied theme (or the original as a seed theme).
  String exportCode() {
    final current = _controller.current;
    final t = current ??
        ReskinTheme(
          name: 'Original',
          light: (widget.theme ?? _original(Brightness.light)).colorScheme,
          dark: (widget.darkTheme ?? _original(Brightness.dark)).colorScheme,
          source: 'original',
        );
    return _controller.exportDart(fallback: t);
  }

  void export() {
    final code = exportCode();
    widget.onExport?.call(code);
    _controller.setShowExport(true);
  }

  void _registerExtensions() {
    if (!kDebugMode || _extensionsRegistered) return;
    _extensionsRegistered = true;
    developer.ServiceExtensionResponse ok(Object? v) =>
        developer.ServiceExtensionResponse.result(jsonEncode(v));
    developer.ServiceExtensionResponse fail(String m) =>
        developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.extensionError, m);
    ReskinHostState? host() => _active;

    developer.registerExtension('ext.reskin.applyTheme',
        (method, params) async {
      final h = host();
      if (h == null) return fail('No ReskinHost mounted.');
      final seed = parseHexColor(params['seed']);
      final prompt = ReskinPrompt(
          text: params['prompt'],
          seed: seed,
          count: int.tryParse(params['count'] ?? '') ?? 4);
      if (prompt.text == null && prompt.seed == null) {
        return fail('Pass prompt and/or seed.');
      }
      final v = await h._controller.generate(prompt);
      final i = int.tryParse(params['select'] ?? '');
      if (i != null) h._controller.select(i);
      return ok(<String, Object?>{
        'applied': h._controller.index,
        'provider': h._controller.provider.name,
        'variants': v.map((t) => t.toJson()).toList(),
      });
    });
    developer.registerExtension('ext.reskin.setMode', (method, params) async {
      final h = host();
      if (h == null) return fail('No ReskinHost mounted.');
      final m = params['mode'];
      h._controller.setDark(m == 'dark'
          ? true
          : m == 'light'
              ? false
              : null);
      return ok(<String, Object?>{'mode': m ?? 'system'});
    });
    developer.registerExtension('ext.reskin.xray', (method, params) async {
      final h = host();
      if (h == null) return fail('No ReskinHost mounted.');
      h._controller.setXray(true);
      final f = await h.scanNow();
      return ok(<String, Object?>{
        'count': f.length,
        'tracked': isCreationTracked,
        'findings': f.map((e) => e.toJson()).toList(),
      });
    });
    developer.registerExtension('ext.reskin.exportTheme',
        (method, params) async {
      final h = host();
      if (h == null) return fail('No ReskinHost mounted.');
      return ok(<String, Object?>{
        'name': h._controller.current?.name ?? 'Original',
        'code': h.exportCode(),
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    _base = Theme.of(context);
    final raw = _probe ?? _resolved();
    // Theme.of() hands out localized themes; localize ours the same way so
    // AnimatedTheme can lerp between them (TextStyle.inherit must match).
    final category =
        Localizations.of<MaterialLocalizations>(context, MaterialLocalizations)
                ?.scriptCategory ??
            ScriptCategory.englishLike;
    final data =
        ThemeData.localize(raw, raw.typography.geometryThemeFor(category));
    final instant = _probe != null || _instant;
    return _ReskinScope(
      controller: _controller,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          AnimatedTheme(
            data: data,
            duration:
                instant ? Duration.zero : const Duration(milliseconds: 350),
            child: KeyedSubtree(key: _appKey, child: widget.child),
          ),
          if (_controller.xray)
            IgnorePointer(child: _XrayOverlay(findings: _controller.findings)),
          // Built after the first frame: focus traversal may sort focus nodes
          // before the first layout on web, and our nodes must not be there yet.
          if (_ready) Overlay(initialEntries: <OverlayEntry>[_panelEntry]),
        ],
      ),
    );
  }
}

// ───────────────────────────── X-ray overlay ─────────────────────────────

class _XrayOverlay extends StatefulWidget {
  const _XrayOverlay({required this.findings});
  final List<XrayFinding> findings;

  @override
  State<_XrayOverlay> createState() => _XrayOverlayState();
}

class _XrayOverlayState extends State<_XrayOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  List<(Rect, String)> _boxes = const <(Rect, String)>[];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => _update())..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _update() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final next = <(Rect, String)>[];
    final counts = <String, int>{};
    for (final f in widget.findings) {
      counts[f.label] = (counts[f.label] ?? 0) + 1;
    }
    final labelled = <String>{};
    for (final f in widget.findings) {
      final e = f.element;
      final r = e != null ? globalRectOf(e) : f.rect;
      if (r == null) continue;
      final local = Rect.fromPoints(
          box.globalToLocal(r.topLeft), box.globalToLocal(r.bottomRight));
      // One label per source location; repeats (list items) get a box only.
      final n = counts[f.label]!;
      final label =
          labelled.add(f.label) ? (n > 1 ? '${f.label}  ×$n' : f.label) : '';
      next.add((local, label));
    }
    if (!listEquals(next, _boxes)) setState(() => _boxes = next);
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _XrayPainter(_boxes),
      size: Size.infinite,
    );
  }
}

class _XrayPainter extends CustomPainter {
  _XrayPainter(this.boxes);
  final List<(Rect, String)> boxes;

  static const Color red = Color(0xFFFF1744);

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = red.withValues(alpha: 0.07);
    final stroke = Paint()
      ..color = red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final labelBg = Paint()..color = red;
    final placed = <Rect>[];
    for (final (r, _) in boxes) {
      final rr =
          RRect.fromRectAndRadius(r.deflate(1), const Radius.circular(3));
      canvas.drawRRect(rr, fill);
      canvas.drawRRect(rr, stroke);
    }
    for (final (r, label) in boxes) {
      if (label.isEmpty) continue;
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
            fontFamilyFallback: _mono,
            height: 1.1,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: size.width - 8);
      final maxDx = size.width - tp.width - 8;
      final dx = maxDx <= 2 ? 2.0 : r.left.clamp(2.0, maxDx);
      // Inside the box's top edge when it is tall enough, else just above it.
      var dy = r.height > tp.height * 2.6 ? r.top + 3 : r.top - tp.height - 5;
      if (dy < 2) dy = r.top + 2;
      var lr = Rect.fromLTWH(dx, dy, tp.width + 6, tp.height + 3);
      // Nudge labels down until they do not overlap earlier ones.
      var guard = 0;
      while (placed.any((p) => p.overlaps(lr)) && guard++ < 12) {
        lr = lr.shift(Offset(0, lr.height + 1));
      }
      placed.add(lr);
      canvas.drawRRect(
          RRect.fromRectAndRadius(lr, const Radius.circular(3)), labelBg);
      tp.paint(canvas, lr.topLeft + const Offset(3, 1.5));
    }
  }

  @override
  bool shouldRepaint(_XrayPainter old) => !listEquals(old.boxes, boxes);
}

// ──────────────────────────────── Panel ────────────────────────────────

const List<String> _mono = <String>[
  'JetBrains Mono',
  'Roboto Mono',
  'Menlo',
  'Consolas',
  'Courier New',
];

final ThemeData _panelTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF7C4DFF),
    brightness: Brightness.dark,
  ).copyWith(surface: const Color(0xFF15131C)),
);

class _PanelLayer extends StatelessWidget {
  const _PanelLayer({required this.host});
  final ReskinHostState host;

  @override
  Widget build(BuildContext context) {
    final c = host.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final pad = MediaQuery.paddingOf(context);
        return Theme(
          data: _panelTheme,
          child: Stack(
            children: <Widget>[
              if (c.showExport) Positioned.fill(child: _ExportView(host: host)),
              if (!c.showExport)
                Positioned(
                  left: c.panelOpen ? 10 : null,
                  right: 10,
                  bottom: 10 + pad.bottom,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: c.panelOpen
                        ? _Panel(
                            key: const ValueKey<String>('panel'), host: host)
                        : _Pill(
                            key: const ValueKey<String>('pill'), controller: c),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.controller});
  final ReskinController controller;

  @override
  Widget build(BuildContext context) {
    final n = controller.findingSites;
    return Material(
      color: const Color(0xFF15131C),
      shape: const StadiumBorder(side: BorderSide(color: Color(0x33FFFFFF))),
      elevation: 8,
      child: InkWell(
        key: const Key('reskin-pill'),
        customBorder: const StadiumBorder(),
        onTap: () => controller.setPanelOpen(true),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.auto_awesome,
                  size: 18, color: Color(0xFFB39DFF)),
              const SizedBox(width: 6),
              const Text('reskin',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
              if (controller.xray) ...<Widget>[
                const SizedBox(width: 8),
                _CountBadge(n),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.n);
  final int n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: n == 0 ? const Color(0xFF00C853) : _XrayPainter.red,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(n == 0 ? '✓ 0' : '$n',
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

class _Panel extends StatefulWidget {
  const _Panel({super.key, required this.host});
  final ReskinHostState host;

  @override
  State<_Panel> createState() => _PanelState();
}

class _PanelState extends State<_Panel> {
  final TextEditingController _text = TextEditingController();
  late final PageController _pages;
  bool _dragging = false;

  ReskinController get c => widget.host.controller;

  @override
  void initState() {
    super.initState();
    _text.text = c.lastPrompt;
    _pages = PageController(viewportFraction: 0.72, initialPage: c.index + 1);
    c.addListener(_sync);
  }

  @override
  void dispose() {
    c.removeListener(_sync);
    _text.dispose();
    _pages.dispose();
    super.dispose();
  }

  void _sync() {
    if (!_pages.hasClients || _dragging) return;
    final want = c.index + 1;
    final page = _pages.page?.round();
    if (page != want) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pages.hasClients && !_dragging) {
          _pages.animateToPage(want,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut);
        }
      });
    }
  }

  Future<void> _go() async {
    final t = _text.text.trim();
    if (t.isEmpty || c.busy) return;
    FocusScope.of(context).unfocus();
    await c.generate(ReskinPrompt.text(t));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final brightness = c.dark == null
        ? widget.host._base.brightness
        : (c.dark! ? Brightness.dark : Brightness.light);
    final variants = c.variants;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Material(
        color: const Color(0xFC15131C),
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0x33FFFFFF)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.auto_awesome,
                      size: 18, color: Color(0xFFB39DFF)),
                  const SizedBox(width: 6),
                  const Text('reskin',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(width: 8),
                  Text(c.provider.name,
                      style:
                          TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  const Spacer(),
                  IconButton(
                    key: const Key('reskin-close'),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.expand_more),
                    onPressed: () => c.setPanelOpen(false),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        key: const Key('reskin-prompt'),
                        controller: _text,
                        style: const TextStyle(fontSize: 14),
                        textInputAction: TextInputAction.go,
                        onSubmitted: (_) => _go(),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Describe a vibe — "gold on navy"',
                          filled: true,
                          fillColor: const Color(0xFF221F2C),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      key: const Key('reskin-generate'),
                      onPressed: c.busy ? null : _go,
                      icon: c.busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.arrow_upward),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 62,
                child: ScrollConfiguration(
                  // Let mouse and trackpad drag the carousel too (web/desktop).
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: PointerDeviceKind.values.toSet(),
                  ),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n is ScrollStartNotification &&
                          n.dragDetails != null) {
                        _dragging = true;
                      } else if (n is ScrollEndNotification) {
                        _dragging = false;
                      }
                      return false;
                    },
                    child: PageView.builder(
                      key: const Key('reskin-variants'),
                      controller: _pages,
                      padEnds: false,
                      itemCount: variants.length + 1,
                      onPageChanged: (i) {
                        if (_dragging) c.select(i - 1);
                      },
                      itemBuilder: (context, i) {
                        final selected = i == c.index + 1;
                        if (i == 0) {
                          return _VariantCard(
                            name: 'Original',
                            detail: 'your theme',
                            scheme:
                                widget.host._original(brightness).colorScheme,
                            selected: selected,
                            onTap: () => c.select(-1),
                          );
                        }
                        final t = variants[i - 1];
                        return _VariantCard(
                          name: t.name,
                          detail:
                              '${t.headingFont ?? 'default font'} · r${t.radius.round()}',
                          scheme: t.scheme(brightness),
                          selected: selected,
                          onTap: () => c.select(i - 1),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  SegmentedButton<bool>(
                    key: const Key('reskin-mode'),
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity:
                          VisualDensity(horizontal: -3, vertical: -3),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    segments: const <ButtonSegment<bool>>[
                      ButtonSegment<bool>(
                          value: false,
                          icon: Icon(Icons.light_mode, size: 16),
                          label: Text('Light')),
                      ButtonSegment<bool>(
                          value: true,
                          icon: Icon(Icons.dark_mode, size: 16),
                          label: Text('Dark')),
                    ],
                    selected: <bool>{brightness == Brightness.dark},
                    onSelectionChanged: (s) => c.setDark(s.first),
                  ),
                  const Spacer(),
                  FilterChip(
                    key: const Key('reskin-xray'),
                    visualDensity:
                        const VisualDensity(horizontal: -3, vertical: -3),
                    showCheckmark: false,
                    selected: c.xray,
                    selectedColor: const Color(0xFF5C0A1B),
                    avatar: Icon(Icons.radar,
                        size: 16,
                        color: c.xray ? _XrayPainter.red : cs.onSurfaceVariant),
                    label: Text(c.xray ? 'X-ray ${c.findingSites}' : 'X-ray'),
                    onSelected: (v) => c.setXray(v),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    key: const Key('reskin-export'),
                    tooltip: 'Export app_theme.dart',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.ios_share, size: 20),
                    onPressed: widget.host.export,
                  ),
                ],
              ),
              if (c.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Provider failed, used offline: ${c.error}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: cs.error)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VariantCard extends StatelessWidget {
  const _VariantCard({
    required this.name,
    required this.detail,
    required this.scheme,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String detail;
  final ColorScheme scheme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c) => Container(
          width: 18,
          height: 18,
          margin: const EdgeInsets.only(right: 3),
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x55FFFFFF)),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  selected ? const Color(0xFFB39DFF) : const Color(0x22FFFFFF),
              width: selected ? 2.5 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              dot(scheme.primary),
              dot(scheme.secondary),
              dot(scheme.tertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5)),
                    Text(detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, fontSize: 10.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────── Export ────────────────────────────────

class _ExportView extends StatefulWidget {
  const _ExportView({required this.host});
  final ReskinHostState host;

  @override
  State<_ExportView> createState() => _ExportViewState();
}

class _ExportViewState extends State<_ExportView> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final code = widget.host.exportCode();
    final c = widget.host.controller;
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => c.setShowExport(false),
        child: ColoredBox(
          color: const Color(0x99000000),
          child: SafeArea(
            child: Center(
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  key: const Key('reskin-export-view'),
                  margin: const EdgeInsets.all(14),
                  constraints: const BoxConstraints(maxWidth: 560),
                  decoration: BoxDecoration(
                    color: const Color(0xFF15131C),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0x33FFFFFF)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 6, 4),
                        child: Row(
                          children: <Widget>[
                            const Icon(Icons.description_outlined,
                                size: 18, color: Color(0xFFB39DFF)),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text('lib/app_theme.dart',
                                  style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontFamilyFallback: _mono,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                            ),
                            FilledButton.tonalIcon(
                              key: const Key('reskin-copy'),
                              onPressed: () async {
                                await Clipboard.setData(
                                    ClipboardData(text: code));
                                if (mounted) setState(() => _copied = true);
                              },
                              icon: Icon(_copied ? Icons.check : Icons.copy,
                                  size: 16),
                              label: Text(_copied ? 'Copied' : 'Copy'),
                            ),
                            IconButton(
                              key: const Key('reskin-export-close'),
                              icon: const Icon(Icons.close),
                              onPressed: () => c.setShowExport(false),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0x22FFFFFF)),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(14),
                          child: SelectableText.rich(
                            highlightDart(code),
                            style: const TextStyle(
                                fontFamily: 'monospace',
                                fontFamilyFallback: _mono,
                                fontSize: 11,
                                height: 1.45,
                                color: Color(0xFFE6E1F0)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Minimal Dart highlighter with inline color swatches for `Color(0x…)`.
TextSpan highlightDart(String code) {
  final spans = <InlineSpan>[];
  final re = RegExp(
      r"(//[^\n]*)|('(?:[^'\\\n]|\\.)*')|(Color\(0x([0-9A-Fa-f]{8})\))|\b(import|class|static|const|final|return|null|double|String)\b|\b(\d+(?:\.\d+)?)\b");
  var last = 0;
  for (final m in re.allMatches(code)) {
    if (m.start > last) {
      spans.add(TextSpan(text: code.substring(last, m.start)));
    }
    if (m.group(1) != null) {
      spans.add(TextSpan(
          text: m.group(1), style: const TextStyle(color: Color(0xFF7D7890))));
    } else if (m.group(2) != null) {
      spans.add(TextSpan(
          text: m.group(2), style: const TextStyle(color: Color(0xFF9CDB8C))));
    } else if (m.group(3) != null) {
      final c = Color(int.parse(m.group(4)!, radix: 16));
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(right: 3),
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: const Color(0x66FFFFFF), width: 0.5),
          ),
        ),
      ));
      spans.add(TextSpan(
          text: m.group(3), style: const TextStyle(color: Color(0xFFFFCB6B))));
    } else if (m.group(5) != null) {
      spans.add(TextSpan(
          text: m.group(5), style: const TextStyle(color: Color(0xFFC792EA))));
    } else {
      spans.add(TextSpan(
          text: m.group(0), style: const TextStyle(color: Color(0xFFF78C6C))));
    }
    last = m.end;
  }
  if (last < code.length) spans.add(TextSpan(text: code.substring(last)));
  return TextSpan(children: spans);
}
