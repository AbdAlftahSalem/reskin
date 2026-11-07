import 'package:flutter/material.dart';

import 'contrast.dart';
import 'export.dart';
import 'generator.dart';
import 'spec.dart';
import 'xray.dart';

/// State behind the reskin panel. Drive it from code, tests, or the VM
/// service extensions the MCP server calls.
class ReskinController extends ChangeNotifier {
  ReskinController({ReskinThemeProvider? provider})
      : provider = provider ?? const OfflineThemeProvider();

  /// Where variants come from. Defaults to the offline generator.
  ReskinThemeProvider provider;

  List<ReskinTheme> _variants = const <ReskinTheme>[];
  int _index = -1;
  bool? _dark;
  bool _xray = false;
  bool _panelOpen = false;
  bool _busy = false;
  bool _showExport = false;
  String? _error;
  String _lastPrompt = '';
  List<XrayFinding> _findings = const <XrayFinding>[];
  int _xrayRuns = 0;

  /// Generated variants. Index -1 means the app's original theme.
  List<ReskinTheme> get variants => _variants;
  int get index => _index;

  /// The applied variant, or null for the original theme.
  ReskinTheme? get current =>
      _index >= 0 && _index < _variants.length ? _variants[_index] : null;

  /// Null follows the app; true/false forces dark/light.
  bool? get dark => _dark;
  bool get xray => _xray;
  bool get panelOpen => _panelOpen;
  bool get busy => _busy;
  bool get showExport => _showExport;
  String? get error => _error;
  String get lastPrompt => _lastPrompt;

  /// Latest X-ray result (set by the host after each scan).
  List<XrayFinding> get findings => _findings;

  /// Distinct source locations (or widget types) among [findings]: the number
  /// of places in code to fix. Repeated list items count once.
  int get findingSites => _findings.map((f) => f.label).toSet().length;

  /// Increments whenever the host should re-run the X-ray probe.
  int get xrayRuns => _xrayRuns;

  /// Contrast report of the applied scheme for [brightness].
  ContrastReport? contrastFor(Brightness brightness) {
    final c = current;
    if (c == null) return null;
    return ensureReadable(c.scheme(brightness)).$2;
  }

  /// Generates variants and applies the first one.
  Future<List<ReskinTheme>> generate(ReskinPrompt prompt) async {
    _busy = true;
    _error = null;
    _lastPrompt = prompt.label;
    notifyListeners();
    try {
      final v = await provider.generate(prompt);
      _variants = v;
      _index = v.isEmpty ? -1 : 0;
      return v;
    } catch (e) {
      _error = '$e';
      if (provider is! OfflineThemeProvider) {
        // Never leave the developer with nothing: fall back offline.
        final v = await const OfflineThemeProvider().generate(prompt);
        _variants = v;
        _index = 0;
        return v;
      }
      rethrow;
    } finally {
      _busy = false;
      _bumpXray();
      notifyListeners();
    }
  }

  /// Shortcut for [generate] with text.
  Future<List<ReskinTheme>> generateFromText(String text) =>
      generate(ReskinPrompt.text(text));

  /// Applies variant [i]; -1 restores the original theme.
  void select(int i) {
    final next = i.clamp(-1, _variants.length - 1);
    if (next == _index) return;
    _index = next;
    _bumpXray();
    notifyListeners();
  }

  /// Applies a theme you built yourself (it is added to the variants).
  void apply(ReskinTheme theme) {
    _variants = <ReskinTheme>[theme, ..._variants];
    _index = 0;
    _bumpXray();
    notifyListeners();
  }

  void setDark(bool? dark) {
    if (_dark == dark) return;
    _dark = dark;
    _bumpXray();
    notifyListeners();
  }

  void setXray(bool on) {
    if (_xray == on) return;
    _xray = on;
    if (!on) _findings = const <XrayFinding>[];
    _bumpXray();
    notifyListeners();
  }

  void toggleXray() => setXray(!_xray);

  void setPanelOpen(bool open) {
    if (_panelOpen == open) return;
    _panelOpen = open;
    notifyListeners();
  }

  void setShowExport(bool show) {
    if (_showExport == show) return;
    _showExport = show;
    notifyListeners();
  }

  /// Re-runs the X-ray probe (e.g. after a hot reload).
  void rescan() {
    _bumpXray();
    notifyListeners();
  }

  /// Called by the host with fresh X-ray results.
  void reportFindings(List<XrayFinding> f) {
    _findings = List<XrayFinding>.unmodifiable(f);
    notifyListeners();
  }

  void _bumpXray() {
    if (_xray) _xrayRuns++;
  }

  /// Dart source for the applied theme (or [fallback] when none is applied).
  String exportDart({ReskinTheme? fallback}) {
    final t = current ?? fallback;
    if (t == null) {
      throw StateError('No reskin theme applied yet.');
    }
    return exportThemeDart(t);
  }
}
