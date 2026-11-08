import 'dart:async';

import 'package:flutter/material.dart';

import 'ai_providers.dart';
import 'contrast.dart';
import 'export.dart';
import 'generator.dart';
import 'spec.dart';
import 'xray.dart';

/// State behind the reskin panel. Drive it from code, tests, or the VM
/// service extensions the MCP server calls.
class ReskinController extends ChangeNotifier {
  ReskinController({
    ReskinThemeProvider? provider,
    this.fallback = const OfflineThemeProvider(),
    this.timeout = const Duration(seconds: 25),
  }) : provider = provider ?? const OfflineThemeProvider();

  /// Where variants come from first. Defaults to the offline generator;
  /// pass a [GeminiThemeProvider] / [OpenAIThemeProvider] (or
  /// [ReskinProviders.fromEnvironment]) to make AI the main path.
  ReskinThemeProvider provider;

  /// Used when [provider] fails, times out or returns an unusable answer.
  ReskinThemeProvider fallback;

  /// Upper bound for one [provider] call before falling back.
  Duration timeout;

  List<ReskinTheme> _variants = const <ReskinTheme>[];
  int _index = -1;
  bool? _dark;
  bool _xray = false;
  bool _panelOpen = false;
  bool _busy = false;
  bool _showExport = false;
  String? _error;
  String? _fallbackReason;
  String? _source;
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

  /// The full error of the last failed [provider] call, if any.
  String? get error => _error;

  /// Short reason the last generation fell back to [fallback] (like
  /// `timed out after 20s` or `API key rejected (401)`), or null.
  String? get fallbackReason => _fallbackReason;

  /// True when the shown variants came from [fallback], not [provider].
  bool get usedFallback => _fallbackReason != null;

  /// Name of the provider that produced the current variants (`gemini`,
  /// `openai`, `offline`...), or null before the first generation.
  String? get source => _source;

  /// True when [provider] is not the offline generator.
  bool get aiEnabled => provider is! OfflineThemeProvider;
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

  /// Generates variants and applies the first one. Tries [provider] first;
  /// on any error or after [timeout] it uses [fallback] and records why in
  /// [fallbackReason] (the panel shows an "offline" badge).
  Future<List<ReskinTheme>> generate(ReskinPrompt prompt) async {
    _busy = true;
    _error = null;
    _fallbackReason = null;
    _lastPrompt = prompt.label;
    notifyListeners();
    try {
      List<ReskinTheme> v;
      try {
        v = await provider.generate(prompt).timeout(timeout);
        if (v.isEmpty) {
          throw const ReskinResponseException(
              'The provider returned no themes.');
        }
        _source = provider.name;
      } catch (e) {
        if (identical(provider, fallback) || provider is OfflineThemeProvider) {
          rethrow;
        }
        // Never leave the developer with nothing: fall back offline.
        _error = '$e';
        _fallbackReason = reskinFailureReason(e);
        v = await fallback.generate(prompt);
        _source = fallback.name;
      }
      _variants = v;
      _index = v.isEmpty ? -1 : 0;
      return v;
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
