import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// One color a widget asked for, by the property it came from.
typedef XrayColorSlot = (String property, Color color);

/// Reads the explicit colors of a widget. Return an empty list for widgets
/// you do not handle. Add your own via [XrayScanner.extraExtractors].
typedef XrayColorExtractor = List<XrayColorSlot> Function(Widget widget);

/// A widget whose color did not follow the theme.
@immutable
class XrayFinding {
  const XrayFinding({
    required this.widgetType,
    required this.property,
    required this.color,
    this.file,
    this.line,
    this.column,
    this.rect,
    this.element,
  });

  final String widgetType;

  /// The live element (used to track the box while scrolling). Not in JSON.
  final Element? element;

  /// Like `color`, `style.color`, `decoration.color`.
  final String property;
  final Color color;

  /// Source file from the widget inspector's creation tracking (debug only).
  final String? file;
  final int? line;
  final int? column;

  /// On-screen bounds in global logical pixels, when known.
  final Rect? rect;

  /// `lib/home/offer_card.dart:42`, or the widget type when no location.
  String get location {
    if (file == null) return widgetType;
    return '${shortenPath(file!)}:$line';
  }

  /// `Colors.blue` when the value is exactly a base Material color (or white /
  /// black variants), else `Color(0x…)`. Shades print as hex.
  String get colorLabel => describeColor(color);

  String get label => '$location  $colorLabel';

  XrayFinding withRect(Rect? r) => XrayFinding(
        widgetType: widgetType,
        property: property,
        color: color,
        file: file,
        line: line,
        column: column,
        rect: r,
        element: element,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'widget': widgetType,
        'property': property,
        'color': describeColor(color),
        if (file != null) 'file': shortenPath(file!),
        if (line != null) 'line': line,
        if (column != null) 'column': column,
      };

  @override
  String toString() => 'XrayFinding($label, $widgetType.$property)';
}

/// `file:///x/y/example/lib/home/card.dart` → `lib/home/card.dart`.
String shortenPath(String file) {
  var f = file;
  final uri = Uri.tryParse(f);
  if (uri != null && uri.hasScheme) f = uri.path;
  final i = f.lastIndexOf('/lib/');
  if (i >= 0) return f.substring(i + 1);
  final parts = f.split('/');
  return parts.length > 2 ? parts.sublist(parts.length - 2).join('/') : f;
}

final Map<int, String> _materialNames = () {
  final m = <int, String>{
    Colors.white.toARGB32(): 'Colors.white',
    Colors.black.toARGB32(): 'Colors.black',
    Colors.white70.toARGB32(): 'Colors.white70',
    Colors.white54.toARGB32(): 'Colors.white54',
    Colors.white38.toARGB32(): 'Colors.white38',
    Colors.white24.toARGB32(): 'Colors.white24',
    Colors.white12.toARGB32(): 'Colors.white12',
    Colors.black87.toARGB32(): 'Colors.black87',
    Colors.black54.toARGB32(): 'Colors.black54',
    Colors.black45.toARGB32(): 'Colors.black45',
    Colors.black38.toARGB32(): 'Colors.black38',
    Colors.black26.toARGB32(): 'Colors.black26',
    Colors.black12.toARGB32(): 'Colors.black12',
  };
  const names = <String>[
    'red', 'pink', 'purple', 'deepPurple', 'indigo', 'blue', 'lightBlue', //
    'cyan', 'teal', 'green', 'lightGreen', 'lime', 'yellow', 'amber',
    'orange', 'deepOrange', 'brown', 'blueGrey',
  ];
  for (var i = 0; i < Colors.primaries.length && i < names.length; i++) {
    m[Colors.primaries[i].toARGB32()] = 'Colors.${names[i]}';
  }
  m[Colors.grey.toARGB32()] = 'Colors.grey';
  return m;
}();

/// Human label for a color, preferring Material names.
String describeColor(Color c) {
  final v = c.toARGB32();
  return _materialNames[v] ??
      'Color(0x${v.toRadixString(16).padLeft(8, '0').toUpperCase()})';
}

List<XrayColorSlot> _slots(List<(String, Color?)> raw) => <XrayColorSlot>[
      for (final (p, c) in raw)
        if (c != null && c.a > 0) (p, c),
    ];

List<(String, Color?)> _decoration(Decoration? d, String prefix) {
  if (d is BoxDecoration) {
    final border = d.border;
    return <(String, Color?)>[
      ('$prefix.color', d.color),
      if (border is Border) ('$prefix.border', border.top.color),
      if (d.gradient != null)
        for (var i = 0; i < d.gradient!.colors.length; i++)
          ('$prefix.gradient[$i]', d.gradient!.colors[i]),
    ];
  }
  if (d is ShapeDecoration) {
    return <(String, Color?)>[('$prefix.color', d.color)];
  }
  return const <(String, Color?)>[];
}

/// Built-in extractors for the common color-bearing widgets.
List<XrayColorSlot> defaultColorExtractor(Widget w) {
  return _slots(switch (w) {
    Container c => <(String, Color?)>[
        ('color', c.color),
        ..._decoration(c.decoration, 'decoration'),
        ..._decoration(c.foregroundDecoration, 'foregroundDecoration'),
      ],
    DecoratedBox d => _decoration(d.decoration, 'decoration'),
    ColoredBox c => <(String, Color?)>[('color', c.color)],
    Text t => <(String, Color?)>[
        ('style.color', t.style?.color),
        ('style.backgroundColor', t.style?.backgroundColor),
        ('textSpan.style.color', t.textSpan?.style?.color),
      ],
    Icon i => <(String, Color?)>[('color', i.color)],
    ImageIcon i => <(String, Color?)>[('color', i.color)],
    Card c => <(String, Color?)>[('color', c.color)],
    Material m => <(String, Color?)>[('color', m.color)],
    CircleAvatar a => <(String, Color?)>[
        ('backgroundColor', a.backgroundColor),
        ('foregroundColor', a.foregroundColor),
      ],
    Divider d => <(String, Color?)>[('color', d.color)],
    VerticalDivider d => <(String, Color?)>[('color', d.color)],
    Chip c => <(String, Color?)>[('backgroundColor', c.backgroundColor)],
    AppBar a => <(String, Color?)>[
        ('backgroundColor', a.backgroundColor),
        ('foregroundColor', a.foregroundColor),
      ],
    Scaffold s => <(String, Color?)>[('backgroundColor', s.backgroundColor)],
    FloatingActionButton f => <(String, Color?)>[
        ('backgroundColor', f.backgroundColor),
        ('foregroundColor', f.foregroundColor),
      ],
    ProgressIndicator p => <(String, Color?)>[
        ('color', p.color),
        ('backgroundColor', p.backgroundColor),
      ],
    Badge b => <(String, Color?)>[
        ('backgroundColor', b.backgroundColor),
        ('textColor', b.textColor),
      ],
    _ => const <(String, Color?)>[],
  });
}

/// Where a widget was constructed, from the widget inspector's creation
/// tracking (`--track-widget-creation`, on by default in debug builds).
({String file, int line, int column})? creationLocationOf(Widget widget) {
  if (!kDebugMode) return null;
  try {
    final delegate = InspectorSerializationDelegate(
      service: WidgetInspectorService.instance,
    );
    final props = delegate.additionalNodeProperties(widget.toDiagnosticsNode());
    final loc = props['creationLocation'];
    if (loc is Map) {
      final file = loc['file'];
      final line = loc['line'];
      final column = loc['column'];
      if (file is String && line is int) {
        return (file: file, line: line, column: column is int ? column : 0);
      }
    }
  } catch (_) {
    // Creation tracking unavailable on this build.
  }
  return null;
}

/// Whether creation locations are available (debug + track-widget-creation).
bool get isCreationTracked {
  if (!kDebugMode) return false;
  try {
    return WidgetInspectorService.instance.isWidgetCreationTracked();
  } catch (_) {
    return false;
  }
}

bool _isFrameworkFile(String file) =>
    file.contains('/packages/flutter/') ||
    file.startsWith('package:flutter/') ||
    file.contains('/.pub-cache/') ||
    file.contains('/flutter/lib/src/');

/// Colors per element at one moment.
class XraySnapshot {
  XraySnapshot(this.colors);
  final Map<Element, List<XrayColorSlot>> colors;
}

/// Finds widgets whose explicit colors ignore the theme.
///
/// The check is a **probe diff**: the host reads every supported widget's
/// explicit colors under the live theme, re-renders the subtree for one frame
/// with a probe theme in which every color role is shifted to a different
/// value (same brightness, layout and fonts), and reads them again. A color
/// that is identical in both reads cannot come from the theme, so it is
/// hardcoded. Colors derived from the theme
/// (`colorScheme.primary.withValues(alpha: .1)`, `Color.lerp` of theme colors)
/// change with the probe and are not flagged.
class XrayScanner {
  const XrayScanner({
    this.extraExtractors = const <XrayColorExtractor>[],
    this.includeFrameworkWidgets = false,
  });

  /// Your own widget types, checked after the built-in ones.
  final List<XrayColorExtractor> extraExtractors;

  /// When creation tracking is on, widgets constructed inside package:flutter
  /// (or other pub packages) are skipped so a Container's internal
  /// DecoratedBox is not reported twice. Set true to include them.
  final bool includeFrameworkWidgets;

  List<XrayColorSlot> _extract(Widget w) {
    final slots = defaultColorExtractor(w);
    if (slots.isNotEmpty || extraExtractors.isEmpty) return slots;
    for (final e in extraExtractors) {
      final s = e(w);
      if (s.isNotEmpty) return s;
    }
    return const <XrayColorSlot>[];
  }

  /// Reads every supported widget under [root].
  XraySnapshot capture(Element root) {
    final tracked = isCreationTracked;
    final out = <Element, List<XrayColorSlot>>{};
    void visit(Element e) {
      final w = e.widget;
      final slots = _extract(w);
      if (slots.isNotEmpty) {
        var keep = true;
        if (tracked && !includeFrameworkWidgets) {
          final loc = creationLocationOf(w);
          keep = loc != null && !_isFrameworkFile(loc.file);
        }
        if (keep) out[e] = slots;
      }
      e.visitChildren(visit);
    }

    visit(root);
    return XraySnapshot(out);
  }

  /// Slots whose color is identical in both probe snapshots.
  List<XrayFinding> diff(XraySnapshot a, XraySnapshot b) {
    final findings = <XrayFinding>[];
    final seen = <String>{};
    a.colors.forEach((element, slotsA) {
      final slotsB = b.colors[element];
      if (slotsB == null || !element.mounted) return;
      for (final (prop, colorA) in slotsA) {
        final match = slotsB.where((s) => s.$1 == prop);
        if (match.isEmpty) continue;
        if (match.first.$2 != colorA) continue;
        final rect = globalRectOf(element);
        final key = '${rect?.toString()}|${colorA.toARGB32()}';
        // e.g. a Container and its own DecoratedBox: report once.
        if (rect != null && !seen.add(key)) continue;
        final loc = creationLocationOf(element.widget);
        findings.add(XrayFinding(
          widgetType: element.widget.runtimeType.toString(),
          property: prop,
          color: colorA,
          file: loc?.file,
          line: loc?.line,
          column: loc?.column,
          rect: rect,
          element: element,
        ));
      }
    });
    return findings;
  }
}

/// On-screen rect of [element]'s render box, or null when it is not painted
/// (offstage route, scrolled out of a lazy list, not laid out yet).
Rect? globalRectOf(Element element) {
  if (!element.mounted) return null;
  final ro = element.renderObject;
  if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
  RenderObject child = ro;
  var parent = ro.parent;
  while (parent != null) {
    if (!parent.paintsChild(child)) return null;
    child = parent;
    parent = parent.parent;
  }
  final m = ro.getTransformTo(null);
  return MatrixUtils.transformRect(m, Offset.zero & ro.size);
}
