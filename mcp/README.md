# reskin-mcp

A small MCP server (stdio) for [reskin](../README.md). It lets an AI agent (Claude Code,
Cursor, …) find the hardcoded colors in a Flutter project and fix them, and drive the
reskin panel of a running app.

| Tool | What it does | Needs a running app? |
|---|---|---|
| `xray` | Static scan of `lib/**/*.dart` for `Color(0x…)`, `Color.fromARGB/RGBO`, `Colors.x`. Returns `file:line:column`, the exact source text, a suggested `Theme.of(context).colorScheme.<role>` and the `const` keywords that must go. With `vmServiceUri` it also returns the runtime X-ray. | No |
| `apply_theme` | Generates variants from `prompt` and/or `seed` and applies one in the running app. | Yes (debug, VM service URI) |
| `export_theme` | Returns the applied theme as `app_theme.dart`, optionally writes it into the project. | Yes |

## Setup

```bash
cd mcp && npm install && npm run build
```

Claude Code:

```bash
claude mcp add reskin -- node /path/to/reskin/mcp/dist/src/index.js
```

Cursor / any MCP client (`mcp.json`):

```json
{
  "mcpServers": {
    "reskin": {
      "command": "node",
      "args": ["/path/to/reskin/mcp/dist/src/index.js"],
      "env": { "RESKIN_PROJECT": "/path/to/your_flutter_app" }
    }
  }
}
```

For `apply_theme` / `export_theme`, run your app with `flutter run` (debug) and pass the
**Dart VM Service** URI it prints as `vmServiceUri` (or set `RESKIN_VM_SERVICE_URI`).
On web use the `chrome` device; the `web-server` device has no VM service.

Then ask the agent: *"X-ray this app and fix the red ones."*

## CLI

```bash
node dist/src/index.js scan ../example          # list hardcoded colors
node dist/src/index.js fix ../example --dry-run # what an agent would change
node dist/src/index.js fix ../example           # apply every suggestion
```

`fix` replaces each match with its suggestion and removes the `const` keywords that no
longer compile. Run `flutter analyze` afterwards and review the roles it picked.

## Tests

```bash
npm test   # scanner, VM client (fake VM service), and a real stdio MCP round-trip
```

## Limits

- The scanner is a masked-regex pass (comments and strings are ignored), not a full Dart
  parser. Colors built from variables or helper functions are not followed.
- Role suggestions are heuristics (where the color is used + its lightness/saturation).
  They compile, but review them.
- Theme definition files (`*theme*.dart`, `ColorScheme(...)`, `ThemeData(...)`, `seedColor:`)
  are skipped unless `includeThemeFiles: true`.
- Replacements use `Theme.of(context)`, so `context` must be in scope.
