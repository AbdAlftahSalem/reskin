# Bunn: reskin showcase app

A realistic coffee-ordering app used to demo [reskin](../README.md): home (search, promo banner,
category chips, product grid), product details (size, milk, extras), order/checkout, rewards and
profile, with Material 3 bottom navigation.

Colors come from the theme, except **12 deliberate hardcoded colors** (`Color(0xFF…)` and
`Colors.white` in `lib/widgets/` and `lib/screens/`) so X-ray has something real to find.

```bash
flutter run -d chrome --dart-define=RESKIN_GEMINI_KEY=$GEMINI_API_KEY   # AI themes
flutter run -d chrome                                                     # offline themes
flutter test                                                              # X-ray: 7 sites on Home
node ../mcp/dist/src/index.js fix . && flutter test --dart-define=RESKIN_EXPECT_SITES=0
```

Product photos (`assets/images/`) are AI-generated for this demo; fonts are the same open fonts
as `../example` (see `assets/fonts/FONTS.md`).
