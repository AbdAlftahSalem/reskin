## 0.1.0 (unreleased)

- `Reskin.builder()` for `MaterialApp.builder`: live theme override, floating panel
  (prompt, variant carousel, Light/Dark, X-ray, Export). Debug-only by default.
- X-ray: probe-diff detection of hardcoded colors on the running app, with file:line
  from widget-creation tracking.
- Offline deterministic theme generator (keywords, "X on Y", mood words) + Gemini and
  OpenAI providers (bring your own key). WCAG AA contrast check before applying.
- Export to a plain `app_theme.dart` (dialog with copy, `onExport` callback).
- VM service extensions `ext.reskin.applyTheme | setMode | xray | exportTheme`.
- `reskin-mcp` (Node/TypeScript, stdio): `xray`, `apply_theme`, `export_theme`.
