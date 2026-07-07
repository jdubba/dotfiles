# hyprlock per-host auth seam (fingerprint / PAM)

hyprlock's authentication backends are configured per machine via a **host
layer include**, mirroring the shared-mechanism + per-host-data pattern already
used by `hyprland.conf` -> `source = local.conf`.

## Why per-host

hyprlock (>= v0.9.5) ships **two independent auth backends**, configured under
an `auth {}` block:

- `auth:pam:enabled` / `auth:pam:module` — the password backend (PAM).
- `auth:fingerprint:enabled` — a **native** fingerprint backend that talks to
  fprintd directly over D-Bus (`net.reactivated.Fprint`). It is **separate**
  from PAM's `pam_fprintd.so` and runs **concurrently** with password entry
  (swipe or type at any time).
- Tuning keys: `auth:fingerprint:ready_message`,
  `auth:fingerprint:present_message`, `auth:fingerprint:retry_delay`.

Fingerprint hardware is **per host**, so whether the native backend is enabled
(and its messages/retry) belongs in the host layer, not the shared,
machine-agnostic `home/.config/hypr/hyprlock.conf`.

## Mechanism

The shared `home/.config/hypr/hyprlock.conf` includes, near the top (right after
`source = current-theme.conf`):

```
source = hyprlock-local.conf
```

`source =` in hypr configs is **relative to the file's own directory**
(`~/.config/hypr/`), so this resolves to the host-layer file the dotfiles tool
symlinks into `$HOME`. Every host ships a **real** `hyprlock-local.conf` so the
include always resolves:

- Active on hosts with a sensor: a full `auth {}` block.
- A comment-only stub elsewhere (hyprlock falls back to its password default).

This is a **separate file from `hypr/local.conf`** — that one is included by
`hyprland.conf` and holds hyprland-only directives (`exec-once`, session glue)
that are invalid inside hyprlock. The shared `hyprlock.conf` carries **no**
`auth {}` block, so the host file is authoritative.

## Which hosts enable fingerprint

| Host             | Sensor                 | Fingerprint backend |
|------------------|------------------------|---------------------|
| `cltc-aus-lws03` | Goodix MOC (enrolled)  | **enabled**         |
| `fedora`         | none confirmed         | stub (disabled)     |
| `stationzebra`   | none confirmed         | stub (disabled)     |

## Pairing with PAM (MANDATORY on a host that enables native fingerprint)

On a host that enables the **native** fingerprint backend, `/etc/pam.d/hyprlock`
**must** be **password-only** — it must NOT run `pam_fprintd.so`. On Fedora the
default `/etc/pam.d/hyprlock` is `auth include login`, which pulls in
`system-auth`, whose first auth line is `auth sufficient pam_fprintd.so`. So PAM
would also claim the fprintd sensor.

That double-claim is not just the ~30s serial pam_fprintd unlock delay — with
both hyprlock's native backend and `pam_fprintd` contending for the one sensor,
unlock can **wedge** (neither fingerprint nor password completes; hyprlock will
not exit on broken auth), which is effectively a lockout.

### The fix (verified on cltc-aus-lws03, Fedora 43)

Fedora ships `password-auth`, the fingerprint-free sibling of `system-auth`
(identical except for the `pam_fprintd.so` line). Point `/etc/pam.d/hyprlock` at
it instead of `login`. This is a **system-level** file (not managed by
dotfiles) and it is authselect-safe (uses a stock file, hand-edits nothing
authselect manages):

```
# /etc/pam.d/hyprlock  (password-only)
auth       include    password-auth
account    include    password-auth
password   include    password-auth
session    include    password-auth
```

Back up first: `sudo cp -a /etc/pam.d/hyprlock /etc/pam.d/hyprlock.bak`.

### Enable order (do the SYSTEM half first)

1. Make `/etc/pam.d/hyprlock` password-only as above.
2. **Verify password unlock still works** while fingerprint is off (the ~30s lag
   should also disappear once `pam_fprintd` is out of the stack).
3. **Only then** add/uncomment the `auth {}` block in the host's
   `hyprlock-local.conf`, and test unlock **with a spare root TTY already open**
   so a bad state is recoverable without a reboot.

## Lessons learned (do not regress)

- **Do not turn the old `# FINGERPRINT` block into a live `label {}`.** The
  shared `hyprlock.conf` historically carried a malformed block — a bare
  `{ ... }` referencing an undefined `$FPRINTPROMPT`. Being bare (no `label`
  keyword), hyprlock parsed it as unknown top-level keys and silently ignored
  it, so it never rendered. Converting it to a real `label {}` bound to the
  undefined variable makes hyprlock **crash at render** (~1-2s after lock ->
  Hyprland's "lockscreen app died"). The block is simply deleted; fingerprint
  status comes from the `auth {}` messages, not a custom label.
- **Recovering a dead lockscreen:** switch to a TTY (Ctrl+Alt+F3), log in, then
  `killall -9 hyprlock`; return with Ctrl+Alt+F<N>. If the compositor still
  considers the session locked, `hyprctl --instance 0 'keyword
  misc:allow_session_lock_restore 1'` then `hyprctl --instance 0 'dispatch exec
  hyprlock'`.
