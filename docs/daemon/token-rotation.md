---
title: Token Rotation
---

# Token Rotation

The Conflab daemon (`conflabd`) authenticates to the Conflab server with a long-lived API key stored in `~/.config/conflab/daemon.toml`. Cycling that key revokes the current one and issues a fresh replacement under the same user and host identity. This page covers when to cycle, what happens, what to do afterwards, and what to try if something goes wrong.

## When to Cycle

- **Suspected leak.** Another process on the host read `daemon.toml`, the file was backed up somewhere unintended, or the key appeared in a log you don't control.
- **Hygiene rotation.** A periodic rotation with no specific trigger. The operation is cheap; the running daemon keeps working with the old token until you restart it.
- **Handing off a machine.** The current owner is about to change. Cycle the key to invalidate anything the previous owner might still hold.

## What Happens

1. Your browser opens to `/app/daemon/token/cycle` on the server your daemon points at. If you're not signed in, you'll be prompted to sign in first.
2. You confirm the rotation in the browser. The server revokes your current host token and mints a replacement under the same `(user, host_identity)` pair, inside a single transaction. Concurrent cycle attempts see the revoke guard and fail cleanly, so exactly one new key is ever minted.
3. The new plaintext is redirected back to a short-lived loopback listener on `127.0.0.1`. The CLI validates a state nonce before accepting it, writes it atomically into `daemon.toml` (temp file + rename, preserving the surrounding TOML), and the browser shows a success page.

## How to Cycle

You can cycle from either the CLI or the menubar app. Both surfaces drive the same flow.

### CLI

```
conflab daemon token cycle
```

Optional flags:

- `--hostname <name>`: override the hostname label matched on the server. Defaults to `hostname(1)`.
- `--timeout <seconds>`: override the two-minute loopback deadline. Range 30 to 600 seconds.

On success the CLI prints:

```
  ✓ Daemon API key cycled successfully.
    Old token revoked; new token written to ~/.config/conflab/daemon.toml

  The running daemon is still using the old token.
  Run: conflab daemon restart
```

### Menubar App (macOS)

Open **Settings → Account**, select your active profile, and click **Cycle API Key** next to the Logout button. Confirm in the sheet. Your browser opens, you confirm, and a success alert offers a **Restart Daemon** button that drives `launchd` directly. The menubar path is the only one that restarts the daemon for you.

## What to Do Next

The running daemon is still using the old (now-revoked) token in memory. You must restart it to pick up the new one.

- **CLI path.** Run `conflab daemon restart` after the cycle succeeds.
- **Menubar path.** Click **Restart Daemon** in the success alert. The menubar drives `launchd` directly, no shell needed.

The restart contract is explicit by design: no file-watcher, no SIGHUP handler. You decide when in-flight requests can be dropped.

## Why It Needs a Browser

The current token alone is deliberately not enough authorisation to rotate itself. If it were, anyone with read access to `daemon.toml` could use it to rotate the key, locking the legitimate user out of their own daemon. Cycle therefore requires a live account session: you sign in (or are already signed in) in your browser, and that session gates the revoke-and-reissue transaction. The token never participates in its own rotation. This matches the OAuth loopback pattern already used by `conflab install connect` for the initial pairing.

## Troubleshooting

- **Browser didn't open.** The verb prints the URL before it tries to open it. Paste it into any browser on the same machine. The loopback listener waits up to two minutes (`--timeout` overrides the default).
- **Cycle cancelled in the browser.** The verb exits with a non-zero code and no key is changed. Re-run `conflab daemon token cycle` to try again.
- **"Already revoked" from the server.** Another session revoked this host's key since `daemon.toml` was last written. Re-run `conflab install setup` to mint a fresh host pairing.
- **"No matching host token" from the server.** The `host_identity` in `daemon.toml` doesn't match any active key on the server. Re-run `conflab install setup` to re-pair.
- **Loopback listener bind failure.** Something is blocking localhost binds, most often firewall software. The listener asks the OS for an ephemeral port, so a specific port conflict is unusual.
- **State-nonce mismatch.** An unexpected callback arrived on the loopback. Almost always a second cycle attempt overlapping with the first. Cancel both and re-run once.

## Out of Scope (v0.2.1)

- **No automatic hot-reload.** The daemon must be explicitly restarted after cycling.
- **No scheduled rotation.** If you want periodic cycling, run the verb from `launchd`, `cron`, or your automation tool of choice.

## See Also

- [Authentication](/app/help/cli/authentication): the server + daemon authentication model.
- [First-Run Setup (macOS)](/app/help/daemon/first-run): how initial host pairing works.
- [Overview](/app/help/daemon/overview): the daemon's architecture and configuration surface.
