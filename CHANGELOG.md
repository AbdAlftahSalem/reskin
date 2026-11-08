## 0.2.0 (unreleased)

- **AI first.** With a key (`--dart-define=RESKIN_GEMINI_KEY` / `RESKIN_OPENAI_KEY`, read by
  `ReskinProviders.fromEnvironment()`, the new default of `Reskin.builder`), Gemini designs
  4 variants with light + dark palettes (primary, secondary, background, surface), a font
  pair, radius and a name, as structured JSON (`responseSchema` / OpenAI strict
  `json_schema`). Default model `gemini-flash-lite-latest`; one retry on 429/500/503.
- Strict validation (`parseAiVariants`, `ReskinResponseException` with per-variant reasons),
  font allow-list (`fonts:`), Arabic prompt support (Arabic-capable fonts are named to the
  model when the brief is Arabic).
- Contrast: new `ensureAccentsVisible` (primary/secondary vs page at 3:1, same hue) before
  the WCAG AA `on*` fixes.
- Fallback to the offline generator on any error, timeout (`ReskinController.timeout`),
  bad JSON or empty answer; panel badge shows the provider or an amber **offline** pill
  with the reason; loading line while the model answers. `controller.source`,
  `usedFallback`, `fallbackReason`.
- Offline generator: ~45 more color words, ~30 more moods (calm, morning, students,
  cyberpunk, …), Arabic color and mood words with prefix / feminine / spelling
  normalization, «X على Y».
- `tool/live_test.dart`: live run of five prompts against your own key.

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
