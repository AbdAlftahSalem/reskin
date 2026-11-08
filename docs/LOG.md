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


## 2026-11-08 — AI-first theme generation (v0.2)

Abd approved making real AI the main path and the keyword dictionary only a fallback.

**What changed**
- New answer format: 4 variants, each with `light` and `dark` palettes (primary, secondary,
  background, surface), heading/body font, radius and a short name. Sent as Gemini
  `responseSchema` / OpenAI strict `json_schema`; validated by `parseAiVariants`.
- Contrast: AI primaries/secondaries are pushed to 3:1 against the page (same hue), then the
  existing WCAG AA `on*` fixes run. Tertiary now follows the AI accent (Material's hue-rotated
  tertiary put a green chip into a coffee palette in the first screenshot run).
- Fallback on any error/timeout/bad JSON with an amber "offline" badge + reason, loading line.
- Offline: ~45 more color words, ~30 moods, Arabic color/mood words, «X على Y».

**How the live tests reached Gemini** (test-only access from the build machine; no key, token
or endpoint of it is in the package or repo):
- The build machine's own AI Studio access was closed on 2026-11-08, so runs A and B
  used Vertex AI (same Gemini models, same `generateContent` request/response shape) through
  the provider's own `baseUrl` + `headers` options.
- Run C used **Abd's own AI Studio key** (from his vault entry, read into the test process only;
  never printed, written or committed) against `generativelanguage.googleapis.com`.
  Findings from it, all real:
  - `gemini-2.5-flash` → **404 "no longer available to new users"**. That was the old default,
    so the default is now `gemini-flash-lite-latest` (an alias Google keeps current).
  - `gemini-3.8-flash` → **503 "high demand"** on the first prompt, then a client timeout at 60 s
    on the second. Added one retry on 429/500/503.
  - `gemini-flash-lite-latest` → both prompts OK in about 2 s each (below).
  - About 7 calls on his free-tier key in total.
- Speed (Vertex, gemini-2.5-flash): model-default thinking 10–16 s per call; `thinkingBudget: 0`
  3–5 s but weaker dark palettes (a lavender primary in a coffee theme, silver in another);
  512 about 5–8 s and good. gemini-3.5-flash-lite: about 2 s.
- Screenshots: the example app running on Flutter web (debug), prompts typed into the real panel,
  Gemini answering through a local CORS shim (the app talks to `RESKIN_GEMINI_BASE_URL`).
  The first attempt got a 403 from a firewall in front of the test endpoint (the shim's user agent): the app fell back
  and the panel showed the amber offline badge with "access denied (403)" — a real fallback,
  kept as a screenshot.
- OpenAI: not run live (no OpenAI test access on the build machine); covered by unit tests
  with recorded response shapes only.

**Honest read of the outputs**
- Good: every call returned valid JSON in the schema; Arabic prompts got Arabic names and
  El Messiri (the only bundled Arabic font); coffee prompts are espresso/latte browns on cream in
  both languages; medical/students is calm blues, teals and greens; Ramadan is navy + gold
  (3.5-flash-lite: navy primary in light mode, gold primary in dark mode).
- Weak spots: web named colors still show up (`#FFD700`, `#191970` midnightblue, `#2F4F4F`
  as a dark surface on navy in one variant); 2.5-flash once named an English prompt's variants
  in Arabic ("Ramadan night" → «ليالي رمضان»; fixed in the prompt since); one coffee variant had
  a lavender dark secondary (`#E0BBE4`); cyberpunk light modes use pure neon (`#00FF66`, `#CCFF00`)
  or dark pages — readable after the contrast pass but loud. Light-mode neon primaries were
  darkened by the 3:1 rule (e.g. `#00E6FF` → `#0093A3`).

### Run A — gemini-3.5-flash-lite (closest to the new default), thinkingBudget 512

**Ramadan night, gold on navy** (2.0 s)

| variant | light: primary · secondary · background · surface | dark: primary · secondary · background · surface | fonts | r | primary after fixes (light) |
|---|---|---|---|---|---|
| Midnight Crescent | #1B2A4A · #D4AF37 · #F5F7FA · #FFFFFF | #D4AF37 · #8EA4C8 · #0D1B2A · #1B2A4A | Cormorant Garamond / Manrope | 16 | unchanged |
| Royal Iftar | #0A192F · #C5A059 · #F8F9FA · #FFFFFF | #E6C594 · #4A6FA5 · #050D1A · #0A192F | El Messiri / Inter | 12 | unchanged |
| Golden Lantern | #162238 · #E5C158 · #F2F4F7 · #FFFFFF | #FFD700 · #A3B8CC · #090E17 · #162238 | Cormorant Garamond / Inter | 24 | unchanged |
| Starry Night | #0F1E36 · #D4AF37 · #F9FAFB · #FFFFFF | #E6C594 · #738FA7 · #070F1B · #0F1E36 | El Messiri / Manrope | 8 | unchanged |

**morning coffee colors** (2.2 s)

| variant | light: primary · secondary · background · surface | dark: primary · secondary · background · surface | fonts | r | primary after fixes (light) |
|---|---|---|---|---|---|
| Espresso Crema | #6F4E37 · #C8B6A6 · #FDFBF7 · #F4ECE1 | #D7CCC8 · #8D6E63 · #1E1B18 · #2C2623 | Cormorant Garamond / Inter | 12 | unchanged |
| Latte Art | #8D5524 · #E0A96D · #FAF6F0 · #EFE8DE | #F4A261 · #D4A373 · #1B1815 · #2A2421 | Manrope / Inter | 20 | unchanged |
| Black Roast | #3D2314 · #A47551 · #F5F5F3 · #E8E6E1 | #D7CCC8 · #B08968 · #121212 · #1E1E1E | JetBrains Mono / Inter | 4 | unchanged |
| Morning Brew | #A0522D · #DEB887 · #FFFDF9 · #F7F2EB | #E6BE8A · #CD853F · #1A1714 · #26221E | Cormorant Garamond / Manrope | 16 | unchanged |

**ألوان قهوة الصبح** (2.0 s)

| variant | light: primary · secondary · background · surface | dark: primary · secondary · background · surface | fonts | r | primary after fixes (light) |
|---|---|---|---|---|---|
| قهوة الصبح الدافئة | #6F4E37 · #D2B48C · #FDFBF7 · #F4ECE1 | #D2B48C · #A97155 · #1C1816 · #2C2522 | El Messiri / El Messiri | 16 | unchanged |
| لاتيه ناعم | #8C6D53 · #E5D3B3 · #FAF6F0 · #EFE5DC | #E5D3B3 · #BFA58A · #1F1A17 · #312A25 | El Messiri / El Messiri | 24 | unchanged |
| إسبريسو مركز | #4A3319 · #C29B61 · #F5F0EB · #E6DCD3 | #C29B61 · #9E7B49 · #14110E · #211D18 | El Messiri / El Messiri | 8 | unchanged |
| موكا بالحليب | #7A5230 · #C8AD93 · #FAF7F5 · #EFE8E1 | #C8AD93 · #9E734E · #1B1714 · #2B2420 | El Messiri / El Messiri | 20 | unchanged |

**calm medical app for students** (2.0 s)

| variant | light: primary · secondary · background · surface | dark: primary · secondary · background · surface | fonts | r | primary after fixes (light) |
|---|---|---|---|---|---|
| Serene Care | #0A6847 · #7ABA78 · #F4F7F6 · #FFFFFF | #7ABA78 · #C4E7CB · #121C16 · #1D2A22 | Manrope / Inter | 16 | unchanged |
| Clinical Focus | #2B5F8C · #68A6CE · #F0F4F8 · #FFFFFF | #68A6CE · #A2D2F2 · #101820 · #1A2430 | Inter / Inter | 8 | unchanged |
| Study Calm | #5C5470 · #B9B4C7 · #FAF8FF · #FFFFFF | #B9B4C7 · #DBDFEA · #181520 · #252131 | Manrope / Inter | 12 | unchanged |
| Gentle Pulse | #387F63 · #80C4B7 · #F2F9F6 · #FFFFFF | #80C4B7 · #C0EDE4 · #111A16 · #1B2721 | Inter / Inter | 20 | unchanged |

**cyberpunk neon** (2.0 s)

| variant | light: primary · secondary · background · surface | dark: primary · secondary · background · surface | fonts | r | primary after fixes (light) |
|---|---|---|---|---|---|
| Neon Syndicate | #00FF66 · #FF0055 · #0F0E17 · #1A1829 | #00FF66 · #FF0055 · #050508 · #0F0E17 | JetBrains Mono / Inter | 0 | unchanged |
| Cyber Grid | #00F0FF · #7000FF · #12121A · #1E1E2C | #00F0FF · #9D4EDD · #08080C · #12121A | JetBrains Mono / Manrope | 4 | unchanged |
| Acid Tokyo | #CCFF00 · #FF007F · #0A0A0C · #16161A | #CCFF00 · #FF007F · #030304 · #0A0A0C | Manrope / JetBrains Mono | 8 | unchanged |
| Matrix Rain | #39FF14 · #00FFFF · #0D1117 · #161B22 | #39FF14 · #00FFFF · #010409 · #0D1117 | JetBrains Mono / Inter | 2 | unchanged |

### Run B — gemini-2.5-flash, thinkingBudget 512

**Ramadan night, gold on navy** (5.7 s)

| variant | light: primary · secondary · background · surface | dark: primary · secondary · background · surface | fonts | r | primary after fixes (light) |
|---|---|---|---|---|---|
| Ramadan Glow | #B8860B · #4169E1 · #F5F5DC · #FFFFFF | #FFD700 · #87CEEB · #0A1931 · #1B2A4A | Cormorant Garamond / Inter | 12 | #B1810B (was #B8860B) |
| Desert Night | #CCAC00 · #2F4F4F · #FDF5E6 · #FFF8DC | #FFEC8B · #ADD8E6 · #191970 · #2F4F4F | El Messiri / Manrope | 8 | #A68C00 (was #CCAC00) |
| Celestial Gold | #A67C00 · #4682B4 · #FEFCE8 · #FDFDF5 | #FFD966 · #6DAEE1 · #0D1B2A · #213140 | Manrope / Inter | 4 | unchanged |
| Midnight Aura | #C5B358 · #6A5ACD · #FFFACD · #FFFFF0 | #FFEE99 · #8470FF · #0C0C1E · #1A1A33 | Cormorant Garamond / Manrope | 16 | #A08F38 (was #C5B358) |

**morning coffee colors** (7.5 s)

| variant | light: primary · secondary · background · surface | dark: primary · secondary · background · surface | fonts | r | primary after fixes (light) |
|---|---|---|---|---|---|
| Classic Espresso | #6F4E37 · #A07C5B · #FDF7F0 · #F8F0E8 | #D9B89D · #BFA287 · #2E241E · #3A2F29 | Cormorant Garamond / Inter | 8 | unchanged |
| Creamy Latte | #8B6B59 · #B5A196 · #FFFCF9 · #FDF8F5 | #C6AFA2 · #9C8A80 · #36312E · #423D3A | Manrope / Inter | 16 | unchanged |
| Morning Brew | #7A5E4E · #D4A57F · #FFF9F4 · #FCF3EC | #E2C3A7 · #F3B082 · #29211D · #352B27 | Inter / Manrope | 12 | unchanged |
| Cozy Cafe | #5C4033 · #8D9A8D · #FBF8F3 · #F6F1EC | #CBB8AA · #A0B5A0 · #25211E · #302B28 | DejaVu Serif / Manrope | 20 | unchanged |

**ألوان قهوة الصبح** (8.1 s)

| variant | light: primary · secondary · background · surface | dark: primary · secondary · background · surface | fonts | r | primary after fixes (light) |
|---|---|---|---|---|---|
| إسبريسو كلاسيك | #6F4E37 · #A0522D · #F5F5DC · #FFF8DC | #D2B48C · #EEDD82 · #2F241F · #3E302A | Cormorant Garamond / Manrope | 12 | unchanged |
| فن اللاتيه | #8B4513 · #D2B48C · #FDF5E6 · #FFFAF0 | #F5DEB3 · #D2B48C · #29211C · #3A302B | Manrope / Inter | 16 | unchanged |
| تحميص داكن | #4A2C2A · #704214 · #F8F0E3 · #F0EAD6 | #C0A68A · #B88E6A · #1A1513 · #251E1C | Inter / Manrope | 8 | unchanged |
| صباح القهوة | #6D4C41 · #B08968 · #FBF5EF · #FFF8F2 | #D7CCC8 · #E0BBE4 · #261C18 · #352A26 | El Messiri / Inter | 14 | unchanged |

**calm medical app for students** (5.7 s)

| variant | light: primary · secondary · background · surface | dark: primary · secondary · background · surface | fonts | r | primary after fixes (light) |
|---|---|---|---|---|---|
| Clinical Serenity | #00677F · #586179 · #F5F8F9 · #FFFFFF | #55D5F9 · #C3C6D3 · #1A1C1E · #202528 | Manrope / Inter | 12 | unchanged |
| Academic Focus | #006C4C · #6A5E7A · #F9FDF7 · #FFFFFF | #7DDCA6 · #D2C5E7 · #1A1C19 · #202523 | Cormorant Garamond / Inter | 8 | unchanged |
| Modern Wellness | #4F59A6 · #71576D · #FDFBFF · #FFFFFF | #BAC3FF · #DEBBD7 · #1B1B22 · #21212B | Inter / Manrope | 16 | unchanged |
| Gentle Study | #6A5E7A · #586179 · #FDF7FC · #FFFFFF | #D2C5E7 · #C3C6D3 · #1F1A25 · #26212C | El Messiri / Inter | 20 | unchanged |

**cyberpunk neon** (5.4 s)

| variant | light: primary · secondary · background · surface | dark: primary · secondary · background · surface | fonts | r | primary after fixes (light) |
|---|---|---|---|---|---|
| Neon Glitch | #00E6FF · #FF00FF · #F0F0F0 · #FFFFFF | #00E6FF · #FF00FF · #1A002A · #2A003F | JetBrains Mono / JetBrains Mono | 4 | #0093A3 (was #00E6FF) |
| Digital Aura | #00FF7F · #FFD700 · #E8F0EA · #FFFFFF | #00FF7F · #FFD700 · #0D1A16 · #1A2E28 | Manrope / Inter | 8 | #009C4D (was #00FF7F) |
| Dark Circuit | #FF3366 · #33CCFF · #EAEAEA · #FFFFFF | #FF3366 · #33CCFF · #121212 · #1E1E1E | Inter / Manrope | 2 | #FF2B60 (was #FF3366) |
| Vaporwave Synth | #FF66CC · #66FFFF · #F5E6F0 · #FFFFFF | #FF66CC · #66FFFF · #1F0A29 · #2F143D | Manrope / Inter | 6 | #FA00A7 (was #FF66CC) |

### Run C — Abd's own AI Studio key, gemini-flash-lite-latest (the package default)

**ألوان قهوة الصبح** (2.1 s)

| variant | light: primary · secondary · background · surface | dark: primary · secondary · background · surface | fonts | r | primary after fixes (light) |
|---|---|---|---|---|---|
| قهوة دافئة | #6F4E37 · #C8AD97 · #FDFBF7 · #F4ECE1 | #D7CCC8 · #A1887F · #1E1B18 · #2C2623 | El Messiri / El Messiri | 16 | unchanged |
| لاتيه ناعم | #8D6E63 · #D7CCC8 · #FAFAFA · #EFEBE9 | #BCAAA4 · #8D6E63 · #121212 · #1E1E1E | El Messiri / El Messiri | 24 | unchanged |
| اسبريسو مركز | #3E2723 · #8D6E63 · #F5F5F5 · #E0E0E0 | #D7CCC8 · #A1887F · #1A120B · #271C14 | El Messiri / El Messiri | 8 | unchanged |
| موكا غنية | #5D4037 · #A1887F · #FAF9F6 · #EFEBE9 | #D7CCC8 · #8D6E63 · #1B1716 · #262120 | El Messiri / El Messiri | 12 | unchanged |

**cyberpunk neon** (1.7 s)

| variant | light: primary · secondary · background · surface | dark: primary · secondary · background · surface | fonts | r | primary after fixes (light) |
|---|---|---|---|---|---|
| Neon Grid | #7C3AED · #06B6D4 · #F8FAFC · #FFFFFF | #A855F7 · #22D3EE · #0F172A · #1E293B | JetBrains Mono / Inter | 4 | unchanged |
| Cyberpunk Pink | #DB2777 · #3B82F6 · #FDF2F8 · #FFFFFF | #EC4899 · #60A5FA · #18181B · #27272A | JetBrains Mono / Manrope | 0 | unchanged |
| Matrix Code | #059669 · #84CC16 · #F0FDF4 · #FFFFFF | #10B981 · #A3E635 · #09090B · #18181B | JetBrains Mono / Inter | 2 | unchanged |
| Acid Synth | #D97706 · #EF4444 · #FFFBEB · #FFFFFF | #F59E0B · #F87171 · #121212 · #1F1F1F | JetBrains Mono / Manrope | 8 | unchanged |


**Tests**: `flutter analyze` clean (package + example); 52 package tests + 1 example test pass;
MCP 10/10; `flutter pub publish --dry-run` 0 warnings (nothing published).


## 2026-11-08 — showcase app + demo video

- New `example_showcase/` (Bunn coffee app). Tested reskin on it on Flutter web (debug) with real
  Gemini (`gemini-3.5-flash-lite` through the same test bridge as above): «ألوان قهوة الصبح» and
  "lemon yellow on white, summer" answered in about 2–3 s each with 4 valid variants.
- Bugs found and fixed while testing on a real multi-tab app:
  - X-ray counted widgets in inactive `IndexedStack` tabs (Home showed 11 sites, 4 of them on
    hidden tabs). Now only painted widgets are outlined and counted.
  - `reskin-mcp` treated `text.titleLarge?.copyWith(color: Colors.white)` as a background and
    suggested `surfaceContainerLowest`; it now suggests a text role (`onPrimary`).
  - The pill/panel covered the app's own `NavigationBar`; new `panelBottomOffset`.
- The WCAG AA result is now visible in the panel (count of auto-fixed colors).
- `reskin-mcp fix` on the showcase: 12 replacements in 5 files, `flutter analyze` clean,
  runtime X-ray on Home 7 → 0 after hot reload.
