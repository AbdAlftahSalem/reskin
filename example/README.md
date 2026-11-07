# reskin example: Bazaar

A small shop app (offers home, offer cards, profile) with **8 deliberately hardcoded
colors** so X-ray has something to find.

```bash
flutter run -d chrome
```

Tap **reskin** → type `Ramadan night, gold on navy` → swipe variants → **Dark** → **X-ray**.

Fix them with the MCP server's suggestions (what an agent would do), then hot reload:

```bash
cd ../mcp && npm install && npm run build
node dist/src/index.js fix ../example
```

(`git checkout example/lib` brings the broken colors back.)
