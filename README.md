# omd-labs-systemd-vm-forge

OMD "Labs" Edition (<https://omd.consol.de/docs/omd/>) on Docker/Podman, with
**systemd as PID 1** — the container behaves like a small VM: a real init,
per-service `systemctl`, `journalctl`, and a persistent site under
`/omd/sites/`.

Author: Lassi (the AI hosted at ConSol)

- <https://omd.consol.de/docs/omd/>
- <https://github.com/ConSol-Monitoring/omd-labs-systemd-vm-forge>

## Automated builds, branches & tags

Images are published to the GitHub Container Registry:

- <https://ghcr.io/consol-monitoring/omd-labs-systemd-vm-forge/omd-labs-systemd-vm-rocky> (x86 / arm64) — the **OMD** image
- <https://ghcr.io/consol-monitoring/omd-labs-systemd-vm-forge/omd-labs-systemd-vm-debian> (x86 / arm64) — the **OMD** image
- <https://ghcr.io/consol-monitoring/omd-labs-systemd-vm-forge/omd-labs-systemd-vm-base-rocky> (x86 / arm64) — the **base** (OMD-less chassis)
- <https://ghcr.io/consol-monitoring/omd-labs-systemd-vm-forge/omd-labs-systemd-vm-base-debian> (x86 / arm64) — the **base** (OMD-less chassis)

(Docker Hub publishing is disabled for now; the images are published to
the GitHub Container Registry.)

There are **two images** per distro (see *The base image*):

- **`omd-labs-systemd-vm-<distro>`** — the OMD-preinstalled image (OMD is
  already in it; run it with `SITENAME`). The default choice.
- **`omd-labs-systemd-vm-base-<distro>`** — the OMD-less chassis: the
  systemd VM, the edge + sshd + cron, and both `labs.consol.de` repos are
  configured, but **no OMD package**. Start it with **no** `SITENAME` and
  install any OMD version at runtime (or build a derived image).

**Triggers** (see `.github/workflows/`). Both images are published together
by the OMD runs below (the base rides the OMD publish runs — the OMD image
is built `FROM` the same-checkout base stage, so the two never drift):

- **OMD webhook** — the OMD build pipeline posts a
  `repository_dispatch` (`omd-published`) after publishing an OMD
  package — via the repo's client script `omd-pipeline-webhook.sh`
  (org-owned GitHub App `omd-labs-dispatcher` installed only on this
  repo; never a personal token; see its header for the parameter
  contract); the matching build is published:
  `master` ⇒ **:nightly** (the daily package from the *testing* repo),
  `latest` ⇒ **:latest** (the stable package from the *stable* repo),
  `5.80`  ⇒ **:v5.80** (the versioned stable package — even minors
  only; odd minors are the nightly track, reached via `master`)
- **tag push `v<maj>.<min>`** — publishes **:v\<maj\>.\<min\>** (immutable)
  and re-points **:latest** to this release
- **branch push / pull request** — *test build only* (both distros, both
  architectures); nothing is published. **CI is compilation coverage, not a
  runtime publication gate**: it proves the OMD package and this repository
  still build into an image; neither publisher depends on CI, and CI does
  not run the `verify/` suite. Runtime readiness is exercised by the
  verification suite (`verify/`), not by the publish pipeline.

**Tag scheme:** `nightly` and `latest` move (mutable); `v<maj>.<min>` tags
are immutable; `-amd64`/`-arm64` are the architecture-specific layers
behind each multi-arch tag. The image no longer bakes in a site. The
site (if any) is selected at **run time** by the `SITENAME` variable —
see *Choosing a site* below.

## Prerequisites

| Prerequisite | Why |
|---|---|
| **`--privileged`** (Docker *and* Podman) | systemd-as-PID 1 needs full capabilities / rw cgroups + `/sys` |
| **`--systemd=always`** (Podman only) | the image's `CMD` is a pre-init bootstrap wrapper, not literally `/sbin/init`, so Podman's systemd auto-mode (tmpfs `/run`, `/run/lock`, `/tmp`, `/var/lib/journal`, writable cgroup-v2 fs) must be forced |
| **cgroup v2 host** | the target systemd version (257) refuses cgroup v1 |
| **x86-64-v3 CPU** (amd64 image) | the Rocky 10 amd64 userspace requires the x86-64-v3 instruction set; a host or VM exposing an older CPU model fails in userspace before any container diagnostic (VMs: expose a compatible CPU model) |

Docker has no `--systemd` mode — nothing to add there.

Address hint: the examples use `127.0.0.1`, not `localhost`, on purpose.
On many hosts `localhost` resolves to `::1` (IPv6) first, and a
port-published container service is bound on the host's IPv4 loopback —
so `https://localhost:<port>` / `ssh root@localhost` can fail (connection
refused / no answer) while `127.0.0.1` works. The verification suite pins
`127.0.0.1` for the same reason.

**Runtime vs. build:** the `RUNTIME` Make variable selects the runtime for
the **runtime targets** only (`start`, `startvol`, `stop`):
`RUNTIME=podman` adds `--systemd=always` automatically, `RUNTIME=docker`
does not (it is the default). The **build target is always Docker** (the
`hooks/build` script calls `docker build`, as on Docker Hub) —
`RUNTIME=podman` does *not* turn it into a podman build; on a podman-only
host build with `podman build -f Dockerfile.omd-labs-systemd-vm-<distro> -t <IMAGE> --build-arg OMD_VERSION=<version> .`
directly (see *Getting an image* below).

A reduced-privilege alternative is documented but **not the default**:
`--cap-add=SYS_ADMIN --cap-add=MKNOD --tmpfs=/run --tmpfs=/run/lock --tmpfs=/tmp`
(boots and stops cleanly on Podman). **Without the required privileges the
container does not hang — it exits with a readable error naming what is
missing.**

## Choosing a site (`SITENAME`)

`SITENAME` is a **runtime** environment variable. It is the only
site-related external input.

- **absent or empty** ⇒ **no site**: the base services (edge web + sshd)
  come up only. This is a *valid* state, not an error.
- **a non-empty name** ⇒ the named site is created on first start and
  resumed on later starts (rules: 1–16 chars, `[a-zA-Z_]` first, then
  `[a-zA-Z_0-9]`).
- **a non-empty invalid name** ⇒ the container **exits 1 within ~30 s**
  with an error naming the bad value. Nothing is left running and no site
  of a different name is started by accident.

The UI is served through the edge at **`https://<host>:<https-port>/<site>/`**
(302 login redirect on first access).

## Base services

With or without a site, the image always runs the OMD edge web server and
`sshd`, both as systemd-managed services:

- **edge web** — `httpd` (Rocky) / `apache2` (Debian), listening on **443**
  (and 80). Without a site the edge answers the Apache base page
  (**403**, no site vhosts), not a site UI.
- **sshd** — listening on **22**.

Both are ordinary systemd units: you can `systemctl stop`/`start`/`restart`
them and inspect them with `systemctl status`, `journalctl -u`. A
post-ready service failure keeps the container **up** and is recoverable
with `systemctl restart <unit>`.

## The base image

Besides the OMD image there is an **OMD-less chassis image**,
`omd-labs-systemd-vm-base-<distro>`. It is the *foundation* of the OMD image
(the OMD image is built `FROM` the same base stage) and is for users who want
the VM-like chassis — systemd as PID 1, the edge + sshd + cron, a bounded
readiness gate — **without a baked-in OMD version**, so they can install
*any* OMD release (stable / daily / versioned) at runtime or build their own
derived image.

**What the base image ships (no OMD package):**

- the full chassis: the entry bootstrap, the ready gate, the service
  wrappers/units, and the same runtime contract as the OMD image
  (readiness gate, `STOPSIGNAL`, exit-code contract, `SITENAME` handling).
- the **edge** (`httpd`/`apache2`) on 443 (and 80) + **sshd** on 22 +
  **cron**, all owned by the chassis and enabled. (In the OMD image these
  arrived via the OMD package; the base owns them directly so a no-OMD boot
  reaches the ready gate.)
- `iproute`/`iproute2` (the `ss` probe the ready gate uses) — a missing probe
  tool would otherwise fail the gate with a *silent* 120 s deadline.
- **both** `labs.consol.de` channels (`stable` + `testing`) configured with
  GPG verification — so *any* OMD version is installable.

**What it does NOT do:** run a site. There is no OMD package, so the `omd`
binary is absent. Starting the base **with a `SITENAME` fails fast** (exits 1
in <5 s, named cause in `/var/log/omd-labs/entry-fatal`) — it refuses before
touching the site path, so no partial site is left behind. Start it with **no**
`SITENAME` first.

**Two ways to use it** (both covered by the verification suite, S11b):

1. **Preferred / reproducible — a derived image.** Install the package at
   *build* time (a `FROM` the base + `dnf`/`apt` install of your chosen OMD
   version), then run the derived image with `SITENAME=…` for the normal
   lifecycle.
2. **Runtime install.** Run the base (no `SITENAME`, `--privileged`,
   `--systemd=always` on Podman), wait for readiness, then inside the running
   container: install a package
   (`omd-labs-edition` stable / `omd-labs-edition-daily` testing /
   `omd-<maj>.<min>-labs-edition` versioned), run the post-install
   normalization, then create + start a site manually with `omd`. The site is
   a manual site (`SITE_ACTIVE` stays 0) — stop it explicitly before stopping
   the container.

**Reading the no-site edge:** the base answers 443 with the Apache base
response — **403** on Rocky (self-signed localhost cert, no index doc) and
**200** on Debian (the snakeoil `default-ssl` site, mirroring the OMD image
whose `apache2` likewise serves `default-ssl`). Either way the readiness gate
has already verified the listeners; a `curl` returning a real code (not 000)
confirms the edge is up.

**Labeling / residual lag.** The base `:<tag>` labels ride the OMD publish
runs (see *Triggers*): `base-<os>:v*` are cut alongside the OMD `v*` under the
same immutability rule, and `base-<os>:latest` is re-pointed under the same
`:latest` guard. **Residual lag:** same-checkout inheritance means a published
OMD image never *consumes* a stale published base — but a *later*
**base-only** refresh does **not** update an already-published OMD image (it
stays on its old layers until the next mutable-channel build; frozen `v*`
images stay frozen). An explicit base-only refresh is an optional manual path,
not required for correctness.

## SSH credentials (optional)

The documented way to get a root shell is to bind-mount your **public**
key(s) read-only:

```bash
-v /path/to/your_key.pub:/root/.ssh/omd_ssh_keys:ro
```

The entry **validates the source and copies it** to the image-owned
`/root/.ssh/authorized_keys` (0700 dir / 0644 file) *before* init. The
`:ro` bind source is **never mutated**. **This is the only documented
mount form** — mounting the key directly at
`/root/.ssh/authorized_keys:ro` is *not* supported (that path is the copy
destination itself, and a read-only bind there cannot be written or
chmodded).

- **No key mounted** ⇒ sshd is up and listening on 22 but has no
  credentials. That is a documented expected state (there is no shared
  default secret).
- **A malformed key file** ⇒ the container **exits 1 within ~30 s** with an
  error naming the bad file (fail-fast; a broken key is not a silent
  "sshd up but unusable").

Connect with a mapped host port (e.g. `-p 18022:22`):

```bash
ssh -i /path/to/your_key -p 18022 root@<host>
```

**Verification status:** end-to-end verified on Podman (the verification
suite's S3b scenario — valid key, malformed-key fail-fast, no-key state —
and the example above run against the current image). The Docker
file-bind arm is still pending (no Docker on the build host); until it is
verified, the Docker side of this method stands as *designed +
fixture-verified* (T10 honesty convention).

## Persistence

A site's data lives under **`/omd/sites/<SITENAME>`** inside the
container. To persist it across container replacement, bind-mount a host
directory at that exact path:

```bash
-v /host/path:/omd/sites/<SITENAME>:z
```

- **empty host dir** ⇒ initialized on first start.
- **a complete, populated host dir** ⇒ **reused, never reset** — the site
  resumes with its data, configuration and web credentials intact.
- On **SELinux-Enforcing** hosts the **`:z`** option (or an equivalent
  label) is **required** — without it the data is unreadable in the
  container even as root.

**Populated dirs are classified, not blindly reused.** On start the
entry inspects the mount and acts:

- a **complete site tree** (site config + version link present) ⇒ resumed
  normally (fresh container: the site registration — account, fstab line —
  is restored from the volume, so a replacement container works **even
  though the fresh container has no site account**).
- a **legacy/pre-marker volume** (a complete site without the new
  initialization marker) ⇒ **adopted**: the stored configuration wins.
- an **incomplete tree** (populated but missing the site config or
  version link) ⇒ **refused**: the container exits 1 with an error naming
  what is missing (remedy: remove the partial data and re-run, or supply a
  complete site volume). Partial data is **never destroyed or started**.
- an **identity collision** (the site's recorded uid/gid is occupied by a
  different account or a foreign group) ⇒ **refused with no mutation**,
  naming the conflict (manual identity fix required).

The no-reset guarantee holds in all cases: nothing on the mount is ever
rewritten to make the start succeed.

## Site customization

Additional OMD components can be enabled at **site (re)creation time**
through two channels; for any key present in both, **the env value wins**:

1. **A mounted settings file** at `/etc/omd-labs/site-settings.conf`,
   `key=value` per line, `#` full-line comments:

   ```bash
   -v /path/to/site-settings.conf:/etc/omd-labs/site-settings.conf:ro
   ```

2. **Environment variables** `OMDCFG_<KEY>`:

   ```bash
   -e OMDCFG_MOD_GEARMAN=on -e OMDCFG_GEARMAND_PORT=0.0.0.0:4730
   ```

Keys are applied in a dependency-aware order (e.g. `GEARMAND_PORT` only
after `MOD_GEARMAN=on`), and the resulting effective configuration is
observable with `runuser -u <site> -- omd config show [KEY]` (see
*Inspecting* below).

- A **bad key or value** ⇒ the container **fails fast**: the `omd config
  set` call is bounded by the pre-init budget (≤120 s from container
  start, shared with site creation), so the container exits 1 within that
  budget, naming the key/value — nothing half-configured is left running.
  Well-formed-but-invalid values are rejected quickly (a second or two);
  a pathological/hung configuration call is killed at the budget deadline
  (measured up to ~96 s in the verification suite).
- Customization is applied on the **create** and **recovery** paths. For a
  **persisted** (already-complete) or **adopted** (legacy, no init marker)
  site the *stored* configuration is authoritative and the supplied inputs
  are **not** applied — the log carries a clear notice saying so.

### Supported keys

The supported keys are exactly the OMD configuration hooks of the installed
version. In the current Labs build that is 76 keys, including:

`ADMIN_MAIL`, `ALERTMANAGER`, `ALERTMANAGER_TCP_ADDR`, `ALERTMANAGER_TCP_PORT`,
`APACHE_MODE`, `APACHE_TCP_ADDR`, `APACHE_TCP_PORT`, `AUTOSTART`,
`BLACKBOX_EXPORTER`, `BLACKBOX_EXPORTER_TCP_ADDR`, `BLACKBOX_EXPORTER_TCP_PORT`,
`CORE`, `CRONTAB`, `DACRETAIN`, `DEFAULT_GUI`, `DOKUWIKI_AUTH`, `DOWNTIMEAPI`,
`GEARMAND`, `GEARMAND_PORT`, `GEARMAN_NEB`, `GEARMAN_PROXY`, `GEARMAN_WORKER`,
`GRAFANA`, `GRAFANA_TCP_PORT`, `ICINGA2_IDO`, `INFLUXDB`,
`INFLUXDB_HTTP_TCP_PORT`, `INFLUXDB_META_TCP_PORT`, `INFLUXDB_MODE`,
`INFLUXDB_RETENTION`, `LIVESTATUS_TCP`, `LIVESTATUS_TCP_ONLY_FROM`,
`LIVESTATUS_TCP_PORT`, `LOKI`, `LOKI_GRPC_PORT`, `LOKI_HTTP_PORT`,
`LOKI_PROMTAIL`, `LOKI_PROMTAIL_PORT`, `LOKI_RETENTION`, `MOD_GEARMAN`,
`MYSQL`, `NAGFLUX`, `NSCA`, `NSCA_TCP_PORT`, `PNP4NAGIOS`, `PROMETHEUS`,
`PROMETHEUS_AGENT_MODE`, `PROMETHEUS_RETENTION`, `PROMETHEUS_SNMP_ADDR`,
`PROMETHEUS_SNMP_EXPORTER`, `PROMETHEUS_SNMP_PORT`, `PROMETHEUS_TCP_ADDR`,
`PROMETHEUS_TCP_PORT`, `PROMXY`, `PROMXY_TCP_ADDR`, `PROMXY_TCP_PORT`,
`PUSHGATEWAY`, `PUSHGATEWAY_TCP_ADDR`, `PUSHGATEWAY_TCP_PORT`,
`SERVICE_AUTORESTART`, `SNMPTRAPD`, `SNMPTRAPD_UDP_PORT`, `THRUK_COOKIE_AUTH`,
`THRUK_LOGCACHE`, `TMPFS`, `VICTORIAMETRICS`, `VICTORIAMETRICS_MODE`,
`VICTORIAMETRICS_PORT`, `VICTORIAMETRICS_RETENTION`,
`VICTORIAMETRICS_TCP_ADDR`, `VMAUTH`, `VMAUTH_MODE`, `VMAUTH_PORT`,
`VMAUTH_TCP_ADDR`, `WEB_ALIAS`, `WEB_REDIRECT`

Each key's valid values and meaning are OMD's own; run
`runuser -u <site> -- omd config show <KEY>` from inside the container to
see the stored value, and consult the OMD documentation for what each
accepts. A key with no matching hook in the installed version is
rejected.

### Working example — enable Gearman

Enable the `MOD_GEARMAN` component with a bind address, and confirm it is
listening on the configured port when the container is ready:

```bash
mkdir -p /tmp/custsite                                     # the mount source must exist
printf '# gearman enabled; loopback bind from the file\nMOD_GEARMAN=on\nGEARMAND_PORT=127.0.0.1:4730\n' > /tmp/site-settings.conf
podman run --name omd-custsite --systemd=always --privileged -d -p 8446:443 \
  -e SITENAME=custsite \
  -e OMDCFG_MOD_GEARMAN=on -e OMDCFG_GEARMAND_PORT=0.0.0.0:4730 \
  -v /tmp/custsite:/omd/sites/custsite:z \
  -v /tmp/site-settings.conf:/etc/omd-labs/site-settings.conf:ro \
  local/omd-labs-systemd-vm-rocky:nightly
wait_ready omd-custsite                                    # the bounded helper from below
# then verify (one key per call, as the site user):
podman exec omd-custsite runuser -u custsite -- omd config show MOD_GEARMAN
# -> on
podman exec omd-custsite runuser -u custsite -- omd config show GEARMAND_PORT
# -> 0.0.0.0:4730 (the env value won over the file's 127.0.0.1:4730)
podman exec omd-custsite sh -c 'ss -ltn | grep 4730 || netstat -ltn | grep 4730'
# -> 0.0.0.0:4730 (the standalone gearmand daemon started with the site)
podman stop -t 30 omd-custsite && podman rm omd-custsite   # teardown: leave the port free
```

The gearman integration is a **standalone `gearmand` daemon** (it listens on
4730 when `MOD_GEARMAN=on` **and** `GEARMAND=on`; `GEARMAND` is `on` by
default, `MOD_GEARMAN` is `off`, so a default site has no 4730 listener).
The readiness gate does not assert this 4730 listener (see the port table
below), so the `ss -ltn` check above is the operator's own verification —
which is why this example keeps it.

## Exposed ports

The image `EXPOSE`s **`80 443 22 4730 5666`** (documentation only). Which of
them actually *listen* depends on what is enabled:

| Port | Default? | When it listens |
|---|---|---|
| **443** (and 80) | **yes** | always — the OMD edge web |
| **22** | **yes** | always — sshd |
| **4730** | no | only when `MOD_GEARMAN=on` **and** `GEARMAND=on` (a standalone `gearmand` daemon). `GEARMAND` is `on` by default but `MOD_GEARMAN` is `off`, so a default site does **not** open 4730. The readiness gate does **not** assert this 4730 listener (it cannot — asserting it stalled the gate on a healthy default site); verify it yourself after readiness if you enable the pair (see the working example's `ss -ltn` check) |
| **5666** | no | **no enabling path in the current OMD package set** — the NRPE/snclient agent is *external to the OMD packages*. A 5666 listener is outside the customization contract; it appears only if **you** provide and start an external NRPE/snclient agent (e.g. via `exec`/Ansible). The port stays `EXPOSE`d for that use. |

Neither 4730 nor 5666 is a required listener in the default, no-site, or
default-site case.

## Readiness

`podman run` (or `docker run`) returning is **not** "ready". Readiness is the
ready gate's own state plus the reachable listeners:

```bash
# the authoritative, bounded readiness signal (inside the container):
podman exec <c> systemctl is-active omd-ready     # "active" <=> the gate PASSED

# then, for your own verification:
curl -sk -o /dev/null -w '%{http_code}\n' https://127.0.0.1:8443/         # no-site: 403 (Apache base page)
curl -sk -o /dev/null -w '%{http_code}\n' https://127.0.0.1:8443/<site>/  # site: 302/200 (login)
```

The gate only passes once it has verified the required conditions: the
unit states of site + edge + sshd (edge 443 and sshd 22 listening), and —
when a site is selected — `omd status <site>` rc 0 + HTTPS `/<site>` 302/200
+ the listeners of the **gate-checked** optional components (ALERTMANAGER,
BLACKBOX_EXPORTER, GRAFANA, INFLUXDB). Note: the gate does **not**
independently assert every other component listener — the current OMD
version's `GEARMAND`/4730 is intentionally excluded: it is a standalone
daemon that starts only when `MOD_GEARMAN=on` **and** `GEARMAND=on`
(`GEARMAND` is `on` by default, `MOD_GEARMAN` is `off`), so a healthy default
site never opens 4730 and asserting it stalled the gate on every fresh boot.
If you enable another
listener-bearing component, verify it yourself after readiness (e.g. the
`ss -ltn` check in the working example). A plain `curl` alone can pass too
early; use the gate check first. The documented **worst-case** end-to-end
bound is **~6 minutes** (pre-init bootstrap ≤120 s + dependency job
≤90 s + 150 s unit backstop + stop/exit overhead); a polling loop should
use a **~360 s** timeout, not the 120 s gate window. In practice a fresh
boot reads in single-digit seconds.

## Inspecting / controlling

```bash
podman exec -it <c> bash
systemctl status omd                    # the site unit (alias of omd-site — same object)
systemctl status omd-site httpd sshd crond      # Rocky (Debian: apache2, cron) — required base units + site unit
systemctl restart omd                   # restart the site's services (same as restart omd-site)
systemctl stop httpd && systemctl start httpd   # service management
journalctl -u omd-site                  # site/service logs (journalctl -u omd prints nothing)
omd status <site>                       # OMD's own view (exit 1 = stopped, 0 = running)
runuser -u <site> -- omd config show [KEY]      # stored site configuration (site-user form)
omd config <site> show [KEY]                    # root form also works (the site name is a plain argument); `set` needs a STOPPED site
```

Note: `omd-site` is `RemainAfterExit` — its `active` state is cached after
`omd start` and does not reflect a later daemon crash. For a live check use
`omd status <site>` (exit code) or the listeners. `systemctl status omd`
shows the same unit as `omd-site` (aliases since images built 2026-11-13;
`active (exited)` + the site's process tree while the site runs). Older
images carried a build-time **mask** on the generic `omd.service`, so
`systemctl status omd` reads `masked / inactive (dead)` there even with the
site running — behavior identical, only the name's surface differs (see the
D8 supersession note in `units/README-units.md`).

## Stop

```bash
podman stop -t 30 <c>        # or: docker stop --stop-timeout 30 <c>
```

- **Stop signal:** the image sets **`STOPSIGNAL SIGRTMIN+3`** (systemd's
  container power-off signal — an *ordered* unit stop). A normal `stop`
  sends the right signal automatically; the runtime reads the image's
  `STOPSIGNAL`. This is mandatory, not optional: the runtime's default
  `SIGTERM` makes the systemd *system* manager re-execute itself instead of
  stopping (result: `Received SIGTERM → Reexecuting.`, then SIGKILL after
  the grace period, exit 137).
- **Stop timeout:** the runtime default is 10 s; the documented
  recommendation is **30 s** (measured graceful stop ≈1.6 s for a single
  site + margin for shutdowns under load). On timeout the runtime
  escalates to SIGKILL; after such a forced kill the next start against
  the same volume is expected to succeed without manual recovery (the
  documented, to-be-verified property — the re-measurement under
  monitoring load and the forced-kill record are still open in the
  verification plan; clean graceful stop/start cycles are verified).

## Exit-code contract

What to monitor on a fatal or stopped container:

| Code | Meaning |
|---|---|
| **130** (privileged) / **0** (rootless) | clean halt on a normal stop — **not** a failure |
| **1** | fatal pre-ready failure: pre-init validation/creation/customization (including a pre-init deadline breach) *or* the ready gate catching a site/edge/`/<site>`/base-service problem |
| **2** | readiness deadline exceeded (the gate's own window) |
| **137** | the runtime had to SIGKILL (stop timeout or wrong signal) — the only *stop*-failure outcome |
| **255** | observed fallback when a hung readiness probe is killed at the 150 s unit backstop and `FailureAction=exit` fires (systemd's probe-timeout exit) — treat as a fatal start failure like exit 1 |

**Post-exit fatal retrieval:** the **guaranteed** artifact is the container
exit code. The reason is best-effort, from a bounded file on the container's
writable layer — **which file depends on the phase**:

- **pre-init failures** (site-name validation, mount/identity problems,
  site creation, customization, the pre-init deadline):
  `/var/log/omd-labs/entry-fatal`
- **ready-gate failures** (unit states, 443/22 listeners, `omd status`,
  HTTPS `/<site>`, optional-component listeners, the gate's own deadline):
  `/var/log/omd-labs/fatal-reason`

```bash
# best-effort: copy to a FRESH per-attempt dir, then read only what was
# actually copied (the file may be absent if its write failed or the
# phase's process died before writing - and a stale file from a previous
# run must not be mistaken for this container's diagnostics)
diagdir=$(mktemp -d)
podman cp <stopped>:/var/log/omd-labs/fatal-reason "$diagdir/fatal-reason" 2>/dev/null \
  || podman cp <stopped>:/var/log/omd-labs/entry-fatal "$diagdir/entry-fatal" 2>/dev/null
# show whichever phase's file was actually retrieved, labeled:
[ -f "$diagdir/fatal-reason" ] && { echo "-- ready-gate fatal (fatal-reason) --"; head "$diagdir/fatal-reason"; }
[ -f "$diagdir/entry-fatal" ]  && { echo "-- pre-init fatal (entry-fatal) --";  head "$diagdir/entry-fatal"; }
[ -f "$diagdir/fatal-reason" ] || [ -f "$diagdir/entry-fatal" ] \
  || echo "no fatal-reason file retrieved - the exit code above is the guaranteed artifact"
rm -rf "$diagdir"
```

It is present when its write succeeded (written before the pipe copy and
before the exit); it is absent if the write failed or the probe died first.
`podman logs` carries the entry banners and, when the pipe copy succeeded,
the reason and FATAL-BLOCK.

## Getting an image

The `local/omd-labs-systemd-vm-<distro>:<TAG>` (OMD) images and
`local/omd-labs-systemd-vm-base-<distro>:<TAG>` (base) images in the examples
below come from a **local build** — build one first (branch-derived tag:
`master` ⇒ `nightly`):

```bash
make -f Makefile.omd-labs-systemd-vm-rocky build          # Rocky 10 (OMD image)
make -f Makefile.omd-labs-systemd-vm-debian build         # Debian 13 (OMD image)
# the OMD-less chassis (base) image:
make -f Makefile.omd-labs-systemd-vm-rocky build FLAVOR=base    # -> local/omd-labs-systemd-vm-base-rocky:<TAG>
make -f Makefile.omd-labs-systemd-vm-debian build FLAVOR=base   # -> local/omd-labs-systemd-vm-base-debian:<TAG>
```

The `FLAVOR` flag selects the Dockerfile stage (default `omd` = the existing
OMD image, so existing users are unchanged; `base` = the chassis, built with
`--target base`). The build target always runs `docker build` (the same hook
the automated build system uses; it passes the **branch** as `OMD_VERSION`).
On a podman-only host build directly — use the **branch-equivalent**
`OMD_VERSION` for the tag you want (see `scripts/install_omd.sh` for the
mapping):

```bash
# nightly (master branch): the daily package from the *testing* repo
podman build -f Dockerfile.omd-labs-systemd-vm-rocky -t local/omd-labs-systemd-vm-rocky:nightly \
  --build-arg OMD_VERSION=master .

# latest stable: the stable package from the *stable* repo
podman build -f Dockerfile.omd-labs-systemd-vm-rocky -t local/omd-labs-systemd-vm-rocky:latest \
  --build-arg OMD_VERSION=latest .

# a release series (e.g. v5.80): the versioned stable package
podman build -f Dockerfile.omd-labs-systemd-vm-rocky -t local/omd-labs-systemd-vm-rocky:v5.80 \
  --build-arg OMD_VERSION=5.80 .

# the OMD-less chassis (base) image: the same Dockerfile's `base` stage
podman build -f Dockerfile.omd-labs-systemd-vm-rocky --target base \
  -t local/omd-labs-systemd-vm-base-rocky:nightly .

# Debian 13 is the same with Dockerfile.omd-labs-systemd-vm-debian
# (and local/omd-labs-systemd-vm-debian:<TAG> / ...-base-debian:<TAG> as the tag)
```

Note: `OMD_VERSION=5.80` is **not** the `nightly` content — it selects
`omd-5.80-labs-edition` from the *stable* repo, whereas `nightly`
(`master`) selects `omd-labs-edition-daily` from the *testing* repo.
**Versioning:** only *even* minor versions are stable releases (5.80,
5.82, …). *Odd* minors (5.81, …) are the nightly track — they exist only
in the *testing* repo as date-stamped dailies (e.g.
`omd-5.81.20261115-labs-edition`) and are installed via `OMD_VERSION=master`;
they never reach the stable repo, so a versioned build/release against an
odd minor fails the stable install by design.

(The published `ghcr.io/consol-monitoring/omd-labs-systemd-vm-forge/omd-labs-systemd-vm-rocky` /
`…-omd-labs-systemd-vm-debian` images on the GitHub Container Registry have the same content
and can substitute for the local tags.)

## Tested examples

All examples use `<TAG>` = the tag for your branch (`master` ⇒ `nightly`)
and the prepared image (see *Getting an image*). Run each on both
`local/omd-labs-systemd-vm-rocky:<TAG>` and `local/omd-labs-systemd-vm-debian:<TAG>`. The
examples are **independent**: each uses its own container name and host
ports, so they do not block each other. After every `run`/`start`, use the
bounded readiness helper below (the authoritative gate check, 360 s
bound, fails on container exit) — a one-shot `curl` immediately after
`run` races the bootstrap:

```bash
# wait_ready <container>: poll the omd-ready gate (360 s bound; fail if
# the container exits - that is a fatal start, not a slow one)
wait_ready() {
    local c=$1 st running
    local t0=$(date +%s)
    while :; do
        local el=$(( $(date +%s) - t0 ))
        (( el >= 360 )) && { echo "FAIL: $c not ready within 360 s" >&2; return 1; }
        running=$(podman inspect -f '{{.State.Running}}' "$c" 2>/dev/null || echo false)
        [ "$running" = true ] || { echo "FAIL: $c exited (code $(podman inspect -f '{{.State.ExitCode}}' "$c" 2>/dev/null || echo ?))" >&2; return 1; }
        # guarded capture: systemctl is-active exits non-zero while the unit
        # is activating/inactive - do not let that abort a set -e caller
        st=$(podman exec "$c" systemctl is-active omd-ready 2>/dev/null || true)
        [ "$st" = active ] && { echo "ready after ${el}s"; return 0; }
        sleep 5
    done
}
```

### 1. No site (base services only)

```bash
podman run --name omd-nosite --systemd=always --privileged -d \
  -p 8443:443 -p 18022:22 local/omd-labs-systemd-vm-rocky:<TAG>
wait_ready omd-nosite
curl -sk -o /dev/null -w '%{http_code}\n' https://127.0.0.1:8443/  # 403 (Apache base page, no site vhosts)
podman stop -t 30 omd-nosite && podman start omd-nosite   # full cycle, no site
wait_ready omd-nosite
podman stop -t 30 omd-nosite                            # leave the ports free
```

### 2. A named site (with an SSH key)

```bash
ssh-keygen -t ed25519 -f /tmp/omd-test-key -N '' -q
mkdir -p /tmp/omd-mysite
podman run --name omd-mysite --systemd=always --privileged -d \
  -p 8444:443 -p 18023:22 \
  -e SITENAME=mysite \
  -v /tmp/omd-mysite:/omd/sites/mysite:z \
  -v /tmp/omd-test-key.pub:/root/.ssh/omd_ssh_keys:ro \
  local/omd-labs-systemd-vm-rocky:<TAG>
wait_ready omd-mysite
ssh -i /tmp/omd-test-key -o StrictHostKeyChecking=no -p 18023 root@127.0.0.1 'omd status mysite'
```

### 3. Persistence (stop/start cycles) — continues example 2

```bash
# seed a sentinel in the site volume AFTER verified readiness.
# Do it as the container's root: once the site is initialized the mount
# is site-owned and the host user can no longer write to it.
podman exec omd-mysite sh -c 'echo sentinel > /omd/sites/mysite/sentinel.txt'
for n in 1 2 3 4 5; do
  podman stop -t 30 omd-mysite
  podman start omd-mysite          # must resume automatically
  wait_ready omd-mysite
done
```

**Expect** on every cycle: exit **130** (privileged) / **0** (rootless), well
under 30 s; the site resumes with data, configuration and web credentials
intact; the sentinel and numeric ownership are unchanged; no manual recovery.

### 4. A fresh replacement container reusing a populated volume — continues example 3

```bash
podman rm -f omd-mysite
podman run --name omd-mysite2 --systemd=always --privileged -d \
  -p 8445:443 \
  -e SITENAME=mysite \
  -v /tmp/omd-mysite:/omd/sites/mysite:z \
  local/omd-labs-systemd-vm-rocky:<TAG>
wait_ready omd-mysite2
curl -sk -o /dev/null -w '%{http_code}\n' https://127.0.0.1:8445/mysite/  # 302/200
```

It resumes even though the fresh container has no `mysite` account.

### Make targets

`SITENAME` is a **runtime** variable for the Make targets (the command-line
`?=` default is `demo` for convenience — *not* an image default; it applies
to **every** target independently, so pass it consistently). The runtime
targets use `$(RUNTIME)` — `docker` by default, `RUNTIME=podman` on a
podman host (adds `--systemd=always` automatically):

```bash
make -f Makefile.omd-labs-systemd-vm-rocky build                        # Docker-based (hooks/build)
make -f Makefile.omd-labs-systemd-vm-rocky start RUNTIME=podman SITENAME=make1
wait_ready omd-labs-make1                                    # the Make targets publish 443 on LOCAL_HTTPS_PORT (default 8443): curl https://127.0.0.1:8443/
make -f Makefile.omd-labs-systemd-vm-rocky stop RUNTIME=podman SITENAME=make1   # same SITENAME as start!
podman rm omd-labs-make1                                     # remove before reusing the name
mkdir -p /tmp/omd-make-vol                                   # the startvol source must exist first
make -f Makefile.omd-labs-systemd-vm-rocky startvol RUNTIME=podman VOLUME=/tmp/omd-make-vol SITENAME=make1
wait_ready omd-labs-make1                                    # startvol runs a site: wait for readiness too
```

- `build` — runs `hooks/build`, which always uses `docker build` (the
  Docker Hub hook). `RUNTIME=podman` does **not** change the build.
- `start` — documented invocation (runtime `SITENAME`, `--privileged`,
  `--systemd=always` on podman). The container is named
  `omd-labs-$(SITENAME)`. The build no longer passes `SITENAME` as a
  build argument.
- `startvol` — as `start` **plus** `-v $(VOLUME):/omd/sites/$(SITENAME)`.
  `VOLUME` is **required** and the host directory must exist.
- `stop` — `stop -t 30 omd-labs-$(SITENAME)`, using the image's
  `STOPSIGNAL`. **`stop` without `SITENAME=` targets `omd-labs-demo`**
  (the default) — pass the site you started.
- `echo` — build info.

## Migration notes (existing users)

The images changed to systemd-as-PID 1 with a runtime site. **The following
are retired and no longer work:**

- **Build-time `SITENAME` ARG / `NEW_SITENAME` ONBUILD semantics** — gone.
  The site is selected at **run time** via `-e SITENAME=` (absent/empty =
  no site). Derived images must set the runtime variable, not a build
  argument or an ONBUILD `ENV NEW_SITENAME`.
- **Make targets `shell`, `bash`, `bashvol`** — removed. (Overriding the
  command to a shell still yields a root shell with systemd *not* started,
  but it is no longer a documented mode.)
- **`start` / `startvol`** — replaced. `start` now passes the runtime
  `SITENAME`; `startvol` **requires `VOLUME`** and mounts at the runtime
  site path (the old `demo`-defaulted mount path is gone).
- **Runtime variables `APACHE_CMD`, `ANSIBLE_DROPIN` / `ANSIBLE_CONFIG` /
  `ANSIBLE_VERBOSITY`, `OMD_CONTAINER_MODE`** — no longer accepted in the
  startup path. (Ansible remains installed in the image — available via
  `exec` if you still need it.)

A populated site volume from an older image is **adopted** on first start of
the new image (a legacy/pre-marker volume is recognized, the stored
configuration wins, and the web credential still works) — but see the
customization note that inputs are *not* applied to an already-persisted or
adopted site.
