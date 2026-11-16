# Units — intended final enabled-unit set (v2)

Source of truth: research.md **D8** (base services + build-time unit state, FR-002/FR-003 —
the inversion of the v1 sshd-off baseline) and **D3** (single-authority readiness gate).
The unit files themselves land with T006 (`omd-site.service`) and T011 (`omd-ready.service`);
this document is what the T012/T029 audits assert against.

> **D8 supersession (2026-11-13, `debate/100`–`103`):** the generic all-sites
> `omd.service` is **no longer masked**. `omd-site.service` now carries
> `Alias=omd.service`, so `systemctl status omd` reflects the selected site
> (the familiar OMD-VM surface) instead of reporting masked/inactive while the
> site runs. Everything below in *this file* reflects the post-supersession
> state; the historical D8 wording in `research.md`/`plan.md` carries a
> superseded note.

## Installed units (via `COPY units/ /usr/lib/systemd/system/`)

| Unit | Type | Purpose | Build-time state |
|---|---|---|---|
| `omd-site.service` | `oneshot`, `RemainAfterExit=yes`, `TimeoutStartSec=90s` | starts/stops the **single active OMD site** via the guarded wrappers `/usr/local/bin/omd-site-start` / `omd-site-stop` (no-op `exit 0` when `SITE_ACTIVE=0`; else `omd start`/`omd stop ${SITE_NAME}`, stop always exits 0) | **ENABLED** (always — the no-site path keeps it enabled, its start *and* stop wrappers no-op; codex N1) + **`Alias=omd.service`** (the shipped unit's own `[Install]` section — like `reboot.target`'s `Alias=ctrl-alt-del.target`; the Dockerfile's offline `systemctl enable` creates the `/etc` alias symlink) |
| `omd-ready.service` | `oneshot`, `RemainAfterExit=yes`, `TimeoutStartSec=150s` backstop | bounded readiness gate (FR-018): `/usr/local/bin/omd-ready-check`; `After=`-only on site + edge + sshd (NO `Requires=`/`Wants=` — `Requires=` cancels the gate job when a dependency failed, [EMPIRICAL]); the **only** unit with `[Unit] FailureAction=exit` (no `FailureActionExitStatus` — the probe's own exit 1/2 becomes the container's); `ExecStopPost=/usr/local/bin/omd-site-stop` (defense-in-depth) | **ENABLED** |

## Final enabled set per distro (the audit assertion, T012/T029)

**Rocky 10** — enabled exactly (plus distro defaults):

- `httpd.service` — the system web edge (443/80), **required** (FR-002); pre-enabled by the OMD package
- `sshd.service` — **required** (FR-003 — the v2 inversion: v1 disabled it)
- `crond.service` — OMD site jobs run via cron
- `omd-site.service`, `omd-ready.service` — the units above
- `omd.service` — **alias** of `omd-site.service` (`systemctl list-unit-files` state
  `alias`; `is-enabled omd` = `alias` rc 0; same canonical `Id`/`FragmentPath`/
  `ControlGroup` — one service object, one controller)

**Debian 13** — identical with distro names: `apache2.service` (edge), `cron` (cron daemon).

## Aliased / disabled (build-time, deterministic symlink operations)

| Unit | State | Why |
|---|---|---|
| `omd.service` (generic, all-sites) | **aliased** to `omd-site.service` (`systemctl enable` creates `/etc/systemd/system/omd.service -> omd-site.service` after the Dockerfile drops the old mask and the OMD package's pre-enabled `multi-user.target.wants/omd.service` link) | the vendor all-sites unit (package-owned, file kept untouched) is shadowed at load time by the alias; `systemctl status omd` / `start` / `stop` / `restart omd` operate the single active site |
| `getty@tty1.service` | **disabled** (plain `systemctl disable`, no mask) | container console model — no getty use in a container |

## Notes

- The site's Apache proxy include (`/omd/apache/<site>.conf`) is written **at `omd create` time
  (pre-init)**, so the edge picks it up on first boot — no post-init reload needed.
- Post-ready service crash: **no unit carries a container-fatal failure action except
  `omd-ready`** — a site/edge/sshd crash after readiness leaves the container up so the
  operator can inspect and restart (FR-019 second half).
- `systemctl is-active omd-ready` = the documented, bounded readiness signal
  (contracts/invocation.md "Readiness").
- **`omd.service` alias semantics (debate/101–103):** the `Alias=` is **inert until
  enablement** — an unactivated `Alias=` resolves to nothing (`systemctl status omd` →
  "could not be found"); the Dockerfile asserts the alias symlink at build time
  (a `test -L` + `readlink -f` check, C2 style). With the alias in place: `systemctl
  status omd` shows the `omd-site` unit (`active (exited)` + the site cgroup when the site
  runs; `inactive` when `SITE_ACTIVE=0` after an explicit stop — N1 no-op semantics
  unchanged); `systemctl stop/start/restart omd` operate the single site; `journalctl -u
  omd` yields **no entries** — use `journalctl -u omd-site` [EMPIRICAL, debate/102 E5].
  `active (exited)` is the cached oneshot state — it does **not** reflect a later daemon
  crash and is not a live health check (`omd status <site>` is).
- **Existing containers built before 2026-11-13 keep the old mask**: the alias lands with
  a rebuilt image; migrating a live site means the documented replacement-container
  rollout (TUTORIAL §5), not an in-place unmask.
