---
title: First-Run Setup (macOS)
---

# First-Run Setup (macOS)

On macOS, Conflab includes a menubar app (`Conflab.app`) alongside the CLI and the daemon. First-run sets up a local Certificate Authority so the browser and CLI can reach the daemon over HTTPS on `127.0.0.1:46327` without certificate warnings. This page walks through the flow and how to recover if something goes wrong.

Linux support is planned. Windows is not currently on the roadmap.

## Why a Local CA

The daemon serves its management API over HTTPS on localhost. HTTPS requires a certificate the browser trusts. Self-signed certs produce warnings on every connection, which is awful UX. The menubar app installs a small local CA into your login Keychain and marks it trusted for SSL. All daemon certificates are signed by this CA, so the browser connects silently.

The CA only signs certificates for `127.0.0.1` and `localhost`. It is scoped tightly to localhost TLS.

## The First-Run Flow

### Launch the Menubar App

1. Open **Conflab.app** from `/Applications` (installed by Homebrew) or by launching the menubar icon.
2. The menubar icon appears in the top-right of your screen.

On first launch, the app detects that the Conflab CA is not yet trusted and opens a **CA Trust** alert.

### The CA Trust Alert

The alert shows:

- An explanation of why the CA is needed.
- The exact operations the installer will perform.
- Three actions: **Install**, **Re-check**, and **Dismiss**.

**Install** triggers the trust-install flow. You are prompted for your macOS password (by the system, not by Conflab). The installer:

1. Generates the Conflab CA certificate if it does not exist.
2. Adds the CA to your login Keychain.
3. Marks the CA trusted for SSL on `127.0.0.1` / `localhost`.
4. Generates the daemon's leaf certificate signed by the CA.
5. Restarts the daemon listener with the new certificate.

The alert closes. The menubar shows **Ready**.

**Re-check** runs `conflab daemon cert status` and re-verifies whether the CA is trusted. Use this after manual intervention (e.g. after you manually trusted the cert via Keychain Access).

**Dismiss** closes the alert without installing. The menubar shows **Limited**. Certificate warnings persist until you install the CA or configure manual trust.

## CA Trust Settings

Open the menubar app and select **CA Trust Settings** to reach a pane that shows:

- Whether the CA is currently trusted.
- Whether the daemon's leaf certificate is valid.
- Buttons to **Re-check**, **Install**, and **Regenerate**.

**Regenerate** removes the CA and the daemon certificate, then installs fresh ones. Use this when certificates expire or when trust has been corrupted. You are prompted for your macOS password again.

## Equivalent CLI Commands

The menubar app is the recommended path on macOS. If you prefer the CLI or are scripting:

```bash
conflab daemon cert status         # show CA and cert status
conflab daemon cert generate       # create CA + leaf if missing
conflab daemon cert install        # install CA into login Keychain (prompts for password)
conflab daemon cert regenerate     # wipe and re-install
conflab daemon cert explainer --plain  # print the alert body for embedding
```

These commands exist to support the menubar app and to give CLI users an equivalent path. The menubar app wraps them with a native UI.

## Troubleshooting

| Issue                                     | Action                                                                                                 |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Alert does not appear                     | Open the menubar app and go to **CA Trust Settings**. Click **Install**.                               |
| Browser still shows certificate warnings  | Click **Re-check** in the menubar app. If still flagged, click **Regenerate**.                         |
| "Operation failed" after clicking Install | Check Keychain Access for a "Conflab" certificate. Remove stale entries and re-run Install.            |
| Certificate expired                       | Click **Regenerate** in the menubar app. The installer issues a new cert.                              |
| Running on Linux                          | Linux CA install is planned. Skip this page and start the daemon via `conflabd start`.                 |
| Need to un-trust the CA                   | Open Keychain Access, find the "Conflab CA" entry, delete it. Re-launch the menubar app to re-install. |

## Where Things Live

- CA certificate: `~/Library/Application Support/space.conflab.macos/ca.pem`.
- Daemon leaf certificate: `~/Library/Application Support/space.conflab.macos/daemon.pem`.
- Login Keychain entry: the Conflab CA appears under the name "Conflab CA".

All of these are managed by the menubar app and the `conflab daemon cert` subcommands. You rarely need to inspect them directly.

## Related

- [Daemon Overview](/app/help/daemon/overview) -- what the daemon does and how it is organised.
- [CLI Authentication](/app/help/cli/authentication) -- the daemon management-API auth flow (password, tokens, MCP boot token).
- [Installation](/app/help/cli/installation) -- the full install guide.
