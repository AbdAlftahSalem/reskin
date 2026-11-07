# reskin

**Re-theme your *running* Flutter app from a prompt, and X-ray every hardcoded color.**

Type *"Ramadan night, gold on navy"* and your real screens restyle on the spot. Swipe
between variants. Flip to Dark, turn on X-ray, and every widget whose color ignores the
theme is outlined in red with its `file:line`. Those are the colors that break dark mode.
Then let an AI agent fix them through `reskin-mcp`, and export a clean `app_theme.dart`.

<!-- Demo GIF / video goes here -->
| Restyle from a prompt | X-ray in dark mode | After the fix | Export |
|---|---|---|---|
| ![](docs/images/still_1_restyled.jpg) | ![](docs/images/still_2_xray.jpg) | ![](docs/images/still_3_fixed.jpg) | ![](docs/images/still_4_export.jpg) |

> Debug-only dev tool. In release/profile builds `Reskin.builder()` returns your app
> untouched.

## Quick start

```yaml
# pubspec.yaml
dependencies:
  reskin:
    git: https://github.com/AbdAlftahSalem/reskin.git
```

```dart
import 'package:reskin/reskin.dart';

MaterialApp(
  theme: lightTheme,
  darkTheme: darkTheme,
  builder: Reskin.builder(theme: lightTheme, darkTheme: darkTheme), // one line
  home: const HomePage(),
);
```

Run in debug. Tap the **reskin** pill (bottom right):

- **Prompt**: describe a vibe (`gold on navy`, `minimal fintech`, `playful, very round`).
- **Carousel**: swipe between variants. *Original* is your own theme.
- **Light / Dark**: force either mode.
- **X-ray**: red boxes on every hardcoded color, labelled `lib/home/offer_card.dart:19  Colors.white`.
  The badge counts distinct places in code.
- **Export**: shows `lib/app_theme.dart` with a Copy button, and calls `onExport(code)`.

## Theme generation

| Provider | Key | Notes |
|---|---|---|
| `OfflineThemeProvider` (default) | none | Deterministic. Color words (40+), mood words (`ramadan`, `ocean`, `luxury`, `tech`…), the pattern **"X on Y"** (X accent, Y brand/background), `round` / `sharp` / `serif` / `mono`. Builds light + dark schemes with `ColorScheme.fromSeed` and Material 3 scheme variants. The same prompt always gives the same themes. |
| `GeminiThemeProvider(apiKey: …)` | yours | One JSON call, the model only picks seed/accent/background, fonts and radius. |
| `OpenAIThemeProvider(apiKey: …)` | yours | Chat Completions JSON mode, `baseUrl` for any compatible server. |
| your own | | implement `ReskinThemeProvider.generate(ReskinPrompt)` |

```dart
Reskin.builder(
  controller: ReskinController(
    provider: GeminiThemeProvider(apiKey: const String.fromEnvironment('GEMINI_KEY')),
  ),
)
```

A logo works too: `controller.generate(ReskinPrompt.image(AssetImage('assets/logo.png')))`
(the seed comes from `ColorScheme.fromImageProvider`). If an AI provider fails, reskin falls
back to the offline generator and shows the error in the panel.

Every scheme is checked against **WCAG AA (4.5:1)** for the on-color/background pairs
(`onPrimary/primary`, `onSurface/surface`, containers, error…). Failing foregrounds are moved
toward black or white until they pass, before the theme is applied.

Fonts are family names. Bundle them, or pass `fontResolver: (family, base) => GoogleFonts.getTextTheme(family, base)`.

## How X-ray works

1. reskin reads the explicit colors of supported widgets under the live theme.
2. It rebuilds the subtree once with a **probe theme** in which every color role is shifted
   to a different value (same layout and fonts), reads the colors again, and restores the
   real theme. The probe is built and reverted between frames, so it never reaches the screen.
3. A color that did not change cannot come from the theme, so it is hardcoded. Theme-derived
   colors (`colorScheme.primary.withValues(alpha: .1)`, lerps) move with the probe and are not flagged.
4. `file:line` comes from Flutter's widget-creation tracking (`--track-widget-creation`, on by
   default in debug), the same data the widget inspector uses. Widgets built inside
   `package:flutter` are skipped, so a `Container` is reported once, not again for its inner
   `DecoratedBox`.

**Detected:** `Container` (color, decoration color/border/gradient), `DecoratedBox`, `ColoredBox`,
`Text` (style color/background), `Icon`, `ImageIcon`, `Card`, `Material`, `CircleAvatar`,
`Divider`, `Chip`, `AppBar`, `Scaffold`, `FloatingActionButton`, progress indicators, `Badge`.
Add your own widgets with `XrayScanner(extraExtractors: [...])`.

**Not detected (yet):** colors inside `ButtonStyle`/`WidgetStateProperty`, `CustomPainter`,
images, `TextSpan` children beyond the root span, shadows, and colors set in your own
component themes (those are theme-level, by design). Without creation tracking (profile
builds) findings show the widget type instead of `file:line`. A hardcoded color that is
conditional on brightness (`isDark ? Colors.white : Colors.black`) is flagged, because it will
not follow a rebrand.

## reskin-mcp: let the agent fix the red ones

`mcp/` is a small Node/TypeScript MCP server with three tools: `xray` (static scan of
`lib/`, with a suggested `Theme.of(context).colorScheme.<role>` per hit), `apply_theme` and
`export_theme` (through the app's VM service). See [mcp/README.md](mcp/README.md).

```
lib/home/offer_card.dart:19:16  Colors.white  →  Theme.of(context).colorScheme.surfaceContainerLowest
lib/home/home_page.dart:126:32  Colors.black87 →  Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.87)   (remove const at 121:15)
```

The running app also exposes `ext.reskin.applyTheme`, `ext.reskin.setMode`, `ext.reskin.xray`
and `ext.reskin.exportTheme` as VM service extensions (debug only).

## Example

`example/` is a small shop app (offers home, offer cards, profile) with **8 deliberately
hardcoded colors**. `cd example && flutter run -d chrome`, then try `gold on navy`, Dark, X-ray.

## Tests

```bash
flutter analyze            # package + example: no issues
flutter test               # 24 package tests (contrast, generator, providers, export, panel, X-ray)
cd example && flutter test # X-ray on the real example screen finds its hardcoded colors
cd mcp && npm test         # 10 tests incl. a stdio MCP round-trip
```

## Limitations (v0.1)

- Debug tool: the AI key lives in your app process. Read it from `--dart-define`, never commit it.
- X-ray inspects the widgets that are on screen now (scroll or navigate, then X-ray again).
- The panel uses `MaterialApp.builder`; `CupertinoApp` is not supported yet.
- The static scanner is a masked regex pass, not a Dart parser; role suggestions are heuristics.
- Font pairing is by family name; reskin does not download fonts by itself.

## License

MIT, © 2026 Abd Alftah Salem
