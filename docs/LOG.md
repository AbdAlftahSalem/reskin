# Build log

## 2026-11-07

- Private repo `AbdAlftahSalem/reskin` created (private: true, read back from the GitHub API).
- Package: `Reskin.builder` host (live AnimatedTheme override above the Navigator, floating
  panel in its own Overlay), `ReskinController`, offline generator, Gemini/OpenAI providers,
  WCAG AA check, `app_theme.dart` export, VM service extensions.
- X-ray v1 used two seed-based probe themes rendered on screen. Found false positives: in M3
  light schemes `onPrimary` is pure white for every seed, so it never changed. Replaced with a
  single probe that shifts every color role, built and reverted inside one `buildScope` between
  frames (no flicker), and diffed against the live read.
- Web: a `didChangeViewFocus` assertion fired when the panel's focus nodes existed before the
  first layout; the panel is now inserted after the first frame.
- `AnimatedTheme` lerp crashed ("different inherit values") because `Theme.of` returns
  localized themes; the host localizes its theme the same way.
- Example: shop app with 8 deliberate hardcoded colors; example test asserts the runtime X-ray
  finds all 7 on the home screen with lib-relative `file:line`.
- reskin-mcp: scanner (masked regex, enclosing-constructor walk, const removal), VM client,
  three MCP tools, `scan`/`fix` CLI. Verified against the live app (Chrome device, DWDS):
  `apply_theme`, `xray` (runtime) and `export_theme` all answered; an exported file analyzes clean.
- Demo video recorded from the real app (headless Chrome screencast). The "fix" step ran
  `reskin-mcp fix example` (the scanner's suggestions applied by script, standing in for an
  agent) and a real hot reload; the example was restored to its broken state afterwards.
- Results: `flutter analyze` clean, 24 + 1 Flutter tests pass, 10 MCP tests pass.
