# Using Cursor as a provider (fork)

Use your **Cursor subscription** through VibeProxy at `http://localhost:8317` from agent tools.

## Prerequisites

- macOS with **Cursor IDE** installed and signed in (for local token fetch), or willingness to use browser login
- VibeProxy running (menu bar, server on port **8317**)
- Bundled **CLIProxyAPIPlus** from [kaitranntt/CLIProxyAPIPlus](https://github.com/kaitranntt/CLIProxyAPIPlus) (includes Cursor provider)

## Step 1: Enable Cursor in VibeProxy

1. Open **VibeProxy** settings from the menu bar.
2. Find **Cursor** in Services and turn the provider **on**.

## Step 2: Add credentials

Choose one:

### Fetch Auth Locally (recommended)

1. Stay signed in to **Cursor IDE** on this Mac.
2. Click **Fetch Auth Locally**.
3. VibeProxy reads `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb` and writes `~/.cli-proxy-api/cursor.json`.

You can sign in to Cursor IDE once and re-fetch when tokens rotate. VibeProxy also watches that database and re-imports when it changes.

### Add Account (browser)

1. Click **Add Account**.
2. Complete the browser PKCE login (`-cursor-login` via the bundled CLI).
3. Credentials are saved under `~/.cli-proxy-api/` as `cursor.json` (or `cursor.<hash>.json` for multiple accounts).

## Step 3: Point your client at VibeProxy

Example (OpenAI-compatible):

- **Base URL:** `http://localhost:8317/v1`
- **API key:** any placeholder (e.g. `dummy-not-used`), same as [FACTORY_SETUP.md](FACTORY_SETUP.md)

Pick a Cursor model exposed by the proxy (check with `curl http://localhost:8317/v1/models` and look for `owned_by: cursor` or model ids containing `cursor`).

### Example

Configure the tool's OpenAI-compatible provider to use `http://localhost:8317/v1` and a dummy API key. Select a Cursor-backed model from the proxy's model list.

## Troubleshooting

| Problem                          | What to try                                                                             |
|----------------------------------|-----------------------------------------------------------------------------------------|
| Fetch Auth Locally fails         | Open Cursor IDE, sign in, quit and reopen VibeProxy, try again                          |
| No Cursor models in `/v1/models` | Confirm `cursor.json` exists in `~/.cli-proxy-api/`, provider enabled, server restarted |
| 401 from proxy                   | Re-fetch tokens or use Add Account                                                      |
| Want upstream VibeProxy releases | This doc is for the **Drjacky** fork; see [README.md](README.md#maintaining-this-fork)   |

## Security

Fetch Auth Locally only reads Cursor's local SQLite store and writes tokens to `~/.cli-proxy-api/` on your Mac. Nothing is sent except through the normal proxy when you use port 8317.
