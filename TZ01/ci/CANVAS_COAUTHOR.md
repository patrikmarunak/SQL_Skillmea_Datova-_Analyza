# Live co-authoring TZ01 with Claude Code (run LOCALLY)

The Canvas co-authoring MCP server pairs your **open Power Apps Studio session** with a
Claude Code instance **running on the same machine**. It cannot be driven from the cloud
(Claude Code on the web) — run Claude Code locally on your PC for live editing.

Source: https://github.com/microsoft/power-platform-skills

## Prerequisites (one-time, on your PC)
1. **.NET 10 SDK** — the MCP server is launched via `dnx` (ships with .NET 10).
   - Verify: `dotnet --version` (should be 10.x) and `dnx --help` works.
2. **Claude Code** installed and signed in.
3. **Power Platform CLI** (`pac`) signed in to your tenant: `pac auth create` (interactive).
4. **Co-authoring ON** in Studio: open the TZ01 app → **Settings → Upcoming features → Co-authoring** → on.
5. Clone this repo locally (the `.mcp.json` at the repo root is already committed).

## Connect
```bash
# add the Microsoft marketplace and install the Canvas Apps plugin
/plugin marketplace add microsoft/power-platform-skills
/plugin install canvas-apps@power-platform-skills

# OR, if you cloned power-platform-skills, launch Claude Code pointing at the plugin:
claude --plugin-dir /path/to/power-platform-skills/plugins/canvas-apps
```
Run `claude` from the root of THIS repo so the committed `.mcp.json` (`canvas-authoring`
server) is picked up. With the TZ01 app open in Studio (co-authoring on), the MCP server
joins that live session; Claude can then read/edit the app's `.pa.yaml` and sync changes
live, and use the compile/validate tools to catch Power Fx / App Checker errors.

## Notes
- The co-authoring MCP edits the **live app** (`.pa.yaml`, the modern SourceCode format).
  This is a separate path from this repo's generated `TZ01/src` (`.fx.yaml`, format 0.24).
  For live debugging of the imported app, co-authoring is the right tool; the generator
  remains the reproducible build of the .msapp.
- The validate/compile tools in this plugin DO surface the canvas formula / App Checker
  errors that the CI Solution Checker cannot (see SETUP.md limitation note).
