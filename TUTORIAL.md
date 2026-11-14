# Tutorial: running the systemd-based OMD Labs container

This tutorial covers the new Rocky Linux 9 and Debian 13 images. They boot
with **systemd as PID 1**, run system Apache and SSH, and optionally create
one OMD monitoring site selected at runtime. Site data can outlive both a
container restart and replacement with a fresh container.

**Site tmpfs works with the tested Podman invocation:** verified on both
local images on 2026-11-13 with `OMDCFG_TMPFS=on`. Docker is the default
runtime in the examples below; those tmpfs tests were run on Podman, not
Docker. See [Using tmpfs](#7-using-tmpfs) for the exact commands,
what survives a restart, and the distinction between OMD and runtime mounts.

## Quick Start

Use Bash on a Linux cgroup-v2 host with Docker, `ssh-keygen`, `ssh` and
`curl`. First build or obtain an image containing the new startup and
`omd.service` alias; see [Prepare an image](#1-prepare-an-image-and-a-runtime).
The local image must exist in the runtime's own image store.

This creates **one container with site `qs` and sshd**, a persistent site
directory, and a dedicated SSH key. Keep host ports **2222** and **8443**
free. Port 8443 is also used by section 2: tear down this container before
following that example, or choose a different host port there. Published
ports below bind on the host's interfaces; restrict access with your host
network policy if needed.

```bash
IMAGE=local/omd-labs-systemd-vm-rocky:nightly
# Alternatively: IMAGE=local/omd-labs-systemd-vm-debian:nightly
mkdir -p ./omd-qs-data
# Generate once; preserve an existing key on subsequent runs.
if [ ! -f ./omd-qs-key ]; then
    ssh-keygen -t ed25519 -f ./omd-qs-key -N '' || exit 1
fi
test -s ./omd-qs-key.pub || { echo 'Missing ./omd-qs-key.pub' >&2; exit 1; }

CONTAINER_RUNTIME=docker
docker run --name omd-qs --privileged -d \
  -p 2222:22 -p 8443:443 \
  -e SITENAME=qs \
  -v "$PWD/omd-qs-data:/omd/sites/qs:z" \
  -v "$PWD/omd-qs-key.pub:/root/.ssh/omd_ssh_keys:ro,z" \
  "$IMAGE" || exit 1
```

**Podman alternative:** use the following *instead of* the Docker run block
(keep the image, directory and key setup above). Podman needs
`--systemd=always` as well as `--privileged`:

```bash
CONTAINER_RUNTIME=podman
podman run --name omd-qs --privileged --systemd=always -d \
  -p 2222:22 -p 8443:443 \
  -e SITENAME=qs \
  -v "$PWD/omd-qs-data:/omd/sites/qs:z" \
  -v "$PWD/omd-qs-key.pub:/root/.ssh/omd_ssh_keys:ro,z" \
  "$IMAGE" || exit 1
```

Wait for the startup gate before connecting. This self-contained check
allows up to 360 seconds and fails if the container exits or the gate never
passes; section 1 has the [full helper](#1-prepare-an-image-and-a-runtime).
The runtime commands themselves must remain responsive.

```bash
qs_wait_ready() {
    local started=$SECONDS running state
    while (( SECONDS - started < 360 )); do
        running=$("$CONTAINER_RUNTIME" inspect -f '{{.State.Running}}' omd-qs) || return 1
        [ "$running" = true ] || { echo 'omd-qs exited; inspect its logs' >&2; return 1; }
        state=$("$CONTAINER_RUNTIME" exec omd-qs systemctl is-active omd-ready 2>/dev/null || true)
        [ "$state" != active ] || return 0
        sleep 2
    done
    echo 'omd-qs readiness timed out; inspect its logs' >&2
    return 1
}
qs_wait_ready || { "$CONTAINER_RUNTIME" logs --tail 40 omd-qs; exit 1; }

# Live site health; the expected result is "Overall state: running".
"$CONTAINER_RUNTIME" exec omd-qs omd status qs
ssh -i ./omd-qs-key -o IdentitiesOnly=yes -p 2222 root@127.0.0.1 'omd status qs'
curl -sk -o /dev/null -w '%{http_code}\n' https://127.0.0.1:8443/qs/
```

Verify the SSH host-key fingerprint before accepting the first connection.
For an interactive root shell, omit `'omd status qs'` from the SSH command.
Open **https://127.0.0.1:8443/qs/**; the initial HTTP response is normally
a login redirect (302). `-k` accepts the test TLS certificate. Set the web
password with `"$CONTAINER_RUNTIME" exec -it omd-qs su - qs -c set_admin_password`,
then log in as **omdadmin**; see [section 2](#2-start-a-persistent-monitoring-site).
The SSH key does not set the web password.

`systemctl status omd` shows the site's cached **active (exited)** unit through
the alias of `omd-site`, not live daemon health. Use `omd status qs` as above;
see [service administration](#6-ssh-and-service-administration).

Stop and remove the container when finished (this frees both host ports):

```bash
"$CONTAINER_RUNTIME" stop -t 30 omd-qs && "$CONTAINER_RUNTIME" rm omd-qs
```

Keep `./omd-qs-data` and the keypair. Re-running the chosen run block with
the same image and mounts reuses the site; wait for readiness again. Site
ownership can change on the host during initialization. Do not delete or
recursively chown the data to make it host-writable. The Podman path was
**executed verbatim on 2026-11-13** (image `local/omd-labs-systemd-vm-rocky:nightly`,
site `qs`, host ports 2222/8443; readiness 8 s, `omd status qs` = running,
mapped-SSH login + `omd status` over SSH, HTTPS `/qs/` = 302, clean
`stop -t 30` — evidence: `verify/results.md` section `QS-quickstart-
2026-11-13`). **Docker execution remains unverified** on the test host (no
Docker available); the Docker block is documented but not yet executed here.

## 1. Prepare an image and a runtime

The examples use **Docker by default**, with Bash on a Linux cgroup-v2
host. Run all commands with the same Docker daemon/context (and use `sudo`
consistently if your installation requires it). Podman-specific hints are
called out separately. Rootless Podman was used for the tmpfs tests below,
with `--privileged` inside its user namespace.

Build from this checkout if you do not already have the new image:

```bash
docker build -f Dockerfile.omd-labs-systemd-vm-rocky \
  --build-arg OMD_VERSION=master -t local/omd-labs-systemd-vm-rocky:nightly .
# Alternatively build Debian:
# docker build -f Dockerfile.omd-labs-systemd-vm-debian \
#   --build-arg OMD_VERSION=master -t local/omd-labs-systemd-vm-debian:nightly .

IMAGE=local/omd-labs-systemd-vm-rocky:nightly
# IMAGE=local/omd-labs-systemd-vm-debian:nightly
```

`master` selects OMD's daily/testing package; `latest` selects the stable
package; a version such as `5.80` selects that version's package. A local
`:nightly` tag does not itself determine the package: the build argument does.
Building requires repository/network access. For a published image, use a
release containing this implementation; an older tag may still have the old
startup script. Keep an image ID/digest for reproducible deployments.

Alternatively, `make -f Makefile.omd-labs-systemd-vm-rocky build` builds the local
Docker image using the branch-derived tag (`master` → `nightly`). The Make
build hook always invokes Docker.

**Podman users:** replace `docker build` with `podman build`. Docker and
Podman have separate image/container stores; build or pull the image using
the engine you will run it with. For Make runtime targets (`start`,
`startvol`, `stop`), pass `RUNTIME=podman`; this adds the Podman systemd flag.
It does not change Make's Docker-based build hook.

All Docker service-mode runs below use `--privileged`. These privileges are
substantial: use trusted images and a host suitable for privileged workloads.
Docker does **not** accept a `--systemd` flag.

**Podman users:** replace `docker` with `podman` in the commands, and add
`--systemd=always` to every service-mode `podman run`, alongside
`--privileged`. The image starts through a bootstrap wrapper, so Podman's
automatic systemd detection must be overridden. Keep one Podman user/context
throughout; switching between `podman` and `sudo podman` switches stores and
can change bind-mount ownership behavior. The `:z`/`:ro,z` bind options shown
below also apply to Podman on SELinux hosts.

A container ID means the runtime started the process, not that OMD is ready.
Define this helper once; it also works from a Bash script using `set -e`:

```bash
CONTAINER_RUNTIME=docker
# Podman users: set CONTAINER_RUNTIME=podman instead.
wait_ready() {
    local name=$1 state running
    local started=$SECONDS
    while (( SECONDS - started < 360 )); do
        running=$("$CONTAINER_RUNTIME" inspect -f '{{.State.Running}}' "$name" 2>/dev/null) || return 1
        if [ "$running" != true ]; then
            "$CONTAINER_RUNTIME" logs --tail 40 "$name" >&2 || true
            echo "Container $name exited before readiness" >&2
            return 1
        fi
        state=$("$CONTAINER_RUNTIME" exec "$name" systemctl is-active omd-ready 2>/dev/null || true)
        if [ "$state" = active ]; then
            return 0
        fi
        sleep 2
    done
    echo "Timed out waiting for $name; inspect its logs" >&2
    return 1
}
```

The helper uses `CONTAINER_RUNTIME`; choose `docker` (default) or `podman`
to match your other commands. The 360-second allowance covers the documented
startup phases; it is not the expected normal startup time. Runtime commands themselves must
also be responsive. The gate records startup success; use live service and
OMD status checks for health after startup.

## 2. Start a persistent monitoring site

Create the bind-mount source first. Use an absolute path and mount the
**whole site directory**, not just selected subdirectories:

```bash
DATA_ROOT="$PWD/omd-tutorial-data"
mkdir -p "$DATA_ROOT/prod"

docker run --name omd-prod --privileged -d \
  -p 8443:443 \
  -e SITENAME=prod \
  -v "$DATA_ROOT/prod:/omd/sites/prod:z" \
  "$IMAGE"

wait_ready omd-prod || exit 1
docker exec omd-prod omd status prod
curl -sk -o /dev/null -w '%{http_code}\n' https://127.0.0.1:8443/prod/
```

Open **https://127.0.0.1:8443/prod/** in a browser. The initial HTTP response
is normally a login redirect. `curl -k` accepts the container's test
certificate; configure trusted TLS for a public deployment.

To set a web password, enter the site user's login shell:

```bash
docker exec -it omd-prod su - prod
# Inside the container, as prod:
set_admin_password
# Enter your new password at the prompt, then:
exit
```

Log in to the web applications as **omdadmin** with that password. Web
credentials and root SSH credentials are separate. The bootstrap currently
captures successful creation output, so do not rely on seeing the generated
web password in `docker logs`; setting it explicitly avoids that dependency.

Choose an unused site/account name: 1–16 letters, digits or underscores,
starting with a letter or underscore. Avoid names of system users/groups.
The runtime site name and `/omd/sites/<name>` mount path must agree.

To run only base services, omit `SITENAME` or pass `-e SITENAME=`:

```bash
docker run --name omd-base --privileged -d \
  -p 8444:443 "$IMAGE"
wait_ready omd-base || exit 1
```

That creates **no site**, including no implicit `demo` site. Apache and
sshd still run. A populated mount does not select a site by itself.

## 3. Control the container from outside

Startup recognizes these user-facing environment variables:

| Variable | Effect |
|---|---|
| `SITENAME` | Select/create the site. Empty or absent means no site. |
| `OMDCFG_<KEY>` | Set an OMD configuration key during first creation or interrupted-creation recovery. Example: `OMDCFG_MOD_GEARMAN=on`. |

**`TMPFS=on` alone is not a startup setting. Use `OMDCFG_TMPFS=on`.**
`OMD_SITE` is internal to OMD tooling, not the external site selector.
`SITE_ACTIVE`, `SITE_NAME` and `SITE_CUSTOM_APPLIED` are generated internal
service state; do not use them as startup controls.

The current 76-hook configuration catalog gives the following environment
variable names. Availability and accepted values belong to the installed
OMD version; not every component is enabled by default.

```text
OMDCFG_ADMIN_MAIL OMDCFG_ALERTMANAGER OMDCFG_ALERTMANAGER_TCP_ADDR
OMDCFG_ALERTMANAGER_TCP_PORT OMDCFG_APACHE_MODE OMDCFG_APACHE_TCP_ADDR
OMDCFG_APACHE_TCP_PORT OMDCFG_AUTOSTART OMDCFG_BLACKBOX_EXPORTER
OMDCFG_BLACKBOX_EXPORTER_TCP_ADDR OMDCFG_BLACKBOX_EXPORTER_TCP_PORT OMDCFG_CORE
OMDCFG_CRONTAB OMDCFG_DACRETAIN OMDCFG_DEFAULT_GUI
OMDCFG_DOKUWIKI_AUTH OMDCFG_DOWNTIMEAPI OMDCFG_GEARMAND
OMDCFG_GEARMAND_PORT OMDCFG_GEARMAN_NEB OMDCFG_GEARMAN_PROXY
OMDCFG_GEARMAN_WORKER OMDCFG_GRAFANA OMDCFG_GRAFANA_TCP_PORT
OMDCFG_ICINGA2_IDO OMDCFG_INFLUXDB OMDCFG_INFLUXDB_HTTP_TCP_PORT
OMDCFG_INFLUXDB_META_TCP_PORT OMDCFG_INFLUXDB_MODE OMDCFG_INFLUXDB_RETENTION
OMDCFG_LIVESTATUS_TCP OMDCFG_LIVESTATUS_TCP_ONLY_FROM OMDCFG_LIVESTATUS_TCP_PORT
OMDCFG_LOKI OMDCFG_LOKI_GRPC_PORT OMDCFG_LOKI_HTTP_PORT
OMDCFG_LOKI_PROMTAIL OMDCFG_LOKI_PROMTAIL_PORT OMDCFG_LOKI_RETENTION
OMDCFG_MOD_GEARMAN OMDCFG_MYSQL OMDCFG_NAGFLUX
OMDCFG_NSCA OMDCFG_NSCA_TCP_PORT OMDCFG_PNP4NAGIOS
OMDCFG_PROMETHEUS OMDCFG_PROMETHEUS_AGENT_MODE OMDCFG_PROMETHEUS_RETENTION
OMDCFG_PROMETHEUS_SNMP_ADDR OMDCFG_PROMETHEUS_SNMP_EXPORTER OMDCFG_PROMETHEUS_SNMP_PORT
OMDCFG_PROMETHEUS_TCP_ADDR OMDCFG_PROMETHEUS_TCP_PORT OMDCFG_PROMXY
OMDCFG_PROMXY_TCP_ADDR OMDCFG_PROMXY_TCP_PORT OMDCFG_PUSHGATEWAY
OMDCFG_PUSHGATEWAY_TCP_ADDR OMDCFG_PUSHGATEWAY_TCP_PORT OMDCFG_SERVICE_AUTORESTART
OMDCFG_SNMPTRAPD OMDCFG_SNMPTRAPD_UDP_PORT OMDCFG_THRUK_COOKIE_AUTH
OMDCFG_THRUK_LOGCACHE OMDCFG_TMPFS OMDCFG_VICTORIAMETRICS
OMDCFG_VICTORIAMETRICS_MODE OMDCFG_VICTORIAMETRICS_PORT OMDCFG_VICTORIAMETRICS_RETENTION
OMDCFG_VICTORIAMETRICS_TCP_ADDR OMDCFG_VMAUTH OMDCFG_VMAUTH_MODE
OMDCFG_VMAUTH_PORT OMDCFG_VMAUTH_TCP_ADDR OMDCFG_WEB_ALIAS
OMDCFG_WEB_REDIRECT
```

For example, `OMDCFG_ADMIN_MAIL=monitoring@example.org` changes the site's
administrator address. `OMDCFG_MOD_GEARMAN=on` enables the Gearman
integration; with the default `GEARMAND=on`, it starts the standalone
gearmand listener. `OMDCFG_GEARMAND_PORT=0.0.0.0:4730` changes its bind address.
Enabling that listener does not automatically publish a host port: add
`-p 127.0.0.1:4730:4730` if host-local access is required.

Inspect the actual version's catalog and the site's stored values:

```bash
docker exec omd-prod sh -c 'ls /omd/versions/default/lib/omd/hooks'
docker exec omd-prod runuser -u prod -- omd config show
docker exec omd-prod runuser -u prod -- omd config show TMPFS
```

`show KEY` displays the stored value, not a list of acceptable values.
For a specific hook's choices, for example TMPFS:

```bash
docker exec omd-prod bash /omd/versions/default/lib/omd/hooks/TMPFS choices
```

Use the site-user form of `omd config` with one key per `show KEY` call. A
root-side `omd config <site> show [KEY]` also works (the site name is a
plain argument — `omd config set …` as root parses `set` as the site name
and fails); `set` additionally requires the site to be **stopped**
("Cannot change config variables while site is running").

The old `APACHE_CMD`, `ANSIBLE_DROPIN`, `ANSIBLE_CONFIG`,
`ANSIBLE_VERBOSITY` and `OMD_CONTAINER_MODE` controls do not drive the new
startup. `VOL_ETC_MB_MIN`, `VOL_VAR_MB_MIN` and `VOL_LOCAL_MB_MIN` remain
image metadata but are not new bootstrap disk-space controls.
`OMD_VERSION` and `INSTALL_COMMON_RETRIES` are **build arguments**, not a
way to change an existing container's installed package at runtime.

Environment variables and mounts are fixed when the container is created.
`docker restart` (or `podman restart`) does not accept a new
site name or configuration set. Create a replacement container to change its startup inputs, subject to the
persisted-configuration rule below.

## 4. Keep initial settings in a file

The optional file is mounted at **/etc/omd-labs/site-settings.conf**. It uses
literal `KEY=value` lines and full-line `#` comments. Use uppercase OMD
keys, no `OMDCFG_` prefix in the file, no shell `export`, and no surrounding
shell quotes. Tabs/newlines within values are unsupported. Keep comment
markers at the beginning of a line.

This independent example initializes a new site:

```bash
mkdir -p "$DATA_ROOT/custom"
cat > "$DATA_ROOT/custom-settings.conf" <<'EOF'
# Initial settings for custom
ADMIN_MAIL=monitoring@example.org
MOD_GEARMAN=on
GEARMAND_PORT=127.0.0.1:4730
EOF

docker run --name omd-custom --privileged -d \
  -p 8445:443 \
  -e SITENAME=custom \
  -e OMDCFG_GEARMAND_PORT=0.0.0.0:4730 \
  -v "$DATA_ROOT/custom:/omd/sites/custom:z" \
  -v "$DATA_ROOT/custom-settings.conf:/etc/omd-labs/site-settings.conf:ro,z" \
  "$IMAGE"

wait_ready omd-custom || exit 1
docker exec omd-custom runuser -u custom -- omd config show GEARMAND_PORT
docker exec omd-custom ss -ltn
```

The stored bind address should be `0.0.0.0:4730`: **environment values win
over file values for the same key**. Confirm a corresponding 4730 listener.
The startup applies settings after creation and before site start, orders
prerequisites before dependent keys, and checks stored values after setting
them. Invalid settings cause a startup failure rather than a running,
partially configured site.

### Existing sites keep their configuration

On a completed persistent site, supplied startup settings **are not
re-applied**. Changing the file or passing a different `OMDCFG_*` value to
a fresh container does not overwrite the stored configuration. A notice in
the logs says those inputs were not applied. The same rule applies to
adopted legacy sites. Syntax errors in a supplied settings file can still
fail validation; remove inputs that are no longer needed.

To deliberately change an existing site, use OMD while it is stopped:

```bash
docker exec omd-prod systemctl stop omd-site
docker exec omd-prod runuser -u prod -- omd config set ADMIN_MAIL new-address@example.org
docker exec omd-prod systemctl start omd-site
docker exec omd-prod runuser -u prod -- omd config show ADMIN_MAIL
docker exec omd-prod omd status prod
```

Keep a record of these changes in your deployment configuration. To rebuild
a site from different initial settings, create a **new** data directory;
pointing at an existing directory is a resume operation, not a reset.

## 5. Stop, restart and replace without losing the site

A stop preserves the container's writable layer. A bind mount or named
volume is what also preserves the site when the container itself is removed.

```bash
docker exec omd-prod sh -c 'echo durable > /omd/sites/prod/local/tutorial-sentinel'
docker stop -t 30 omd-prod
docker inspect -f '{{.State.ExitCode}}' omd-prod
docker start omd-prod
wait_ready omd-prod || exit 1
docker exec omd-prod cat /omd/sites/prod/local/tutorial-sentinel
```

Seed data through container root, as above: initialization changes the site
folder's numeric ownership, so the host user may no longer be able to write
to it directly. Preserve that numeric ownership in backups; do not solve an
identity conflict by recursively chowning the whole site.

Now replace the container with the **same image and site name**:

```bash
docker stop -t 30 omd-prod
docker rm omd-prod
docker run --name omd-prod-v2 --privileged -d \
  -p 8443:443 \
  -e SITENAME=prod \
  -v "$DATA_ROOT/prod:/omd/sites/prod:z" \
  "$IMAGE"
wait_ready omd-prod-v2 || exit 1
docker exec omd-prod-v2 cat /omd/sites/prod/local/tutorial-sentinel
docker exec omd-prod-v2 omd status prod
```

The fresh image initially has no `prod` account. The bootstrap restores
registration using the stored numeric identity and resumes the site.
Configuration, monitoring data and the web password reside on the mount.
Do not run two containers against the same site directory concurrently.

A named Docker volume (or a Podman volume) is an alternative to the host directory:

```bash
docker volume create omd-lab-data
docker run --name omd-lab --privileged -d \
  -p 8446:443 -e SITENAME=lab \
  -v omd-lab-data:/omd/sites/lab "$IMAGE"
wait_ready omd-lab || exit 1
```

Removing a container does not remove a bind directory; keep named volumes
when removing containers too. Do not use `volume rm`/volume-pruning as part
of replacement. A persistent mount is not a backup: make separate backups
of a stopped, consistent site before upgrades or manual recovery.

If the mount is incomplete or its numeric identity conflicts with an
account/group in the image, startup can refuse with an actionable error.
Interrupted first creation is distinguished from a completed site using
`.omd-labs-init-inprogress`, `.omd-labs-init-complete` and
`.omd-labs-site-identity`. Leave those files with the site; deleting them can
change recovery classification. The bootstrap can finish interrupted
creation, or refuse an unsafe state, rather than silently resetting data.

Using a newer image with a different OMD version is also a software upgrade,
not merely container replacement. The current bootstrap attempts OMD version
migration when the old version is absent. Back up first and test the actual
source/target versions on a copy; same-image reuse is not proof that every
cross-version upgrade or downgrade is supported.

## 6. SSH and service administration

For SSH, create a key if needed and recreate a container with the public
key source mounted read-only. For example, this separate no-site container
provides an administrative shell:

```bash
ssh-keygen -t ed25519 -f "$DATA_ROOT/admin-key" -N ''
docker run --name omd-ssh --privileged -d \
  -p 127.0.0.1:18022:22 \
  -v "$DATA_ROOT/admin-key.pub:/root/.ssh/omd_ssh_keys:ro,z" \
  "$IMAGE"
wait_ready omd-ssh || exit 1
ssh -i "$DATA_ROOT/admin-key" -p 18022 root@127.0.0.1
```

The entry validates each public key, then copies it to image-owned
`/root/.ssh/authorized_keys` (root-owned, mode 0644; parent directory 0700).
It does not chmod or overwrite the bind source. SELinux `:z` can relabel a
host file as part of mounting it. Do not mount directly over the destination
`authorized_keys` with `:ro`, because provisioning needs to write that path.
With no supplied key, sshd still runs but this method provides no login
credential. Keep the private key on the host.

Use service management from the host:

```bash
docker exec omd-prod-v2 systemctl status omd-site httpd sshd crond
docker exec omd-prod-v2 journalctl -u omd-site --no-pager -n 40
docker exec omd-prod-v2 systemctl restart omd-site
docker exec omd-prod-v2 omd status prod
docker logs --tail 60 omd-prod-v2
```

**The OMD-VM habit works:** `omd.service` is an **alias** of `omd-site.service`
(one service object, one controller — introduced in this checkout on
2026-11-13; use an image built with that change, not just a tag/date; see
the note below for older images). So the familiar commands operate the site:

```bash
docker exec omd-prod-v2 systemctl status omd      # = omd-site, with the site's process tree
docker exec omd-prod-v2 systemctl restart omd     # restarts the site's services
docker exec omd-prod-v2 systemctl is-active omd   # active after a successful (or no-op) start
```

Read the output carefully: `systemctl status omd` shows the unit as
**`active (exited)`** (oneshot + `RemainAfterExit`), with the site's
processes (naemon, npcd, rrdcached, the site Apache) in its cgroup when the
site runs. That state is **cached** after `omd start` — a later daemon
crash leaves it `active`, and the no-site container's `stop omd`
(guarded no-op) also ends in `inactive`. It is *not* a live health check:
use `omd status <site>` for daemon health and `systemctl is-active
omd-ready` for the bounded startup readiness signal. And
`journalctl -u omd` prints no entries — filter with
`journalctl -u omd-site`.

Earlier systemd images built **before** the 2026-11-13 alias change carry the build-time **mask**
on the generic `omd.service`: there, `systemctl status omd` reads
`Loaded: masked / Active: inactive (dead)` even though the site runs —
by design of those images (the generic unit starts *all* sites, so it was
masked; the site unit is `omd-site`). The site behaves identically; only
the `omd` name's surface differs. Existing running containers keep their
image's behavior: to move a site onto a new image, use the documented
replacement-container rollout ([section 5](#5-stop-restart-and-replace-without-losing-the-site)).

On Debian the system web unit is `apache2`, SSH is `ssh`, and cron is
`cron`; substitute those for Rocky's `httpd`, `sshd`, `crond`. `omd-site`
starts/stops the selected site, while system Apache is the web edge in
front of its backend. A service failure after startup leaves the container
running for diagnosis. `omd-site` and `omd-ready` are oneshot units whose
active state can remain cached; check OMD's live status and listeners too.

Stop with `docker stop -t 30 NAME` (Podman: `podman stop -t 30 NAME`). The
image's `STOPSIGNAL SIGRTMIN+3` asks systemd to halt in order. A clean halt
can have exit **130 or 0**; neither is a failed stop. Exit **137** means
SIGKILL, commonly after the stop timeout. Startup failures normally use
**1**, a readiness deadline **2**, and the observed hung-probe systemd
backstop **255**. Investigate a failure before repeatedly restarting it.

For a stopped container, copy diagnostics into a fresh directory so that
old files cannot be mistaken for this container's errors:

```bash
DIAG=$(mktemp -d)
for file in entry-fatal fatal-reason; do
  if docker cp "omd-prod-v2:/var/log/omd-labs/$file" "$DIAG/$file" 2>/dev/null; then
    printf '\n%s\n' "$file"
    cat "$DIAG/$file"
  fi
done
```

`entry-fatal` is for pre-init failures; `fatal-reason` is for the readiness
probe. The exit status is the guaranteed failure signal; files/log delivery
are best effort if their channel or the probe itself fails. Journals are
not included in site-volume persistence.

## 7. Using tmpfs

### OMD-managed temporary site data: verified on Podman

OMD normally defaults `TMPFS` to **off in containers**. Its hook contains a
comment saying mounts do not work in containers. That is a conservative
default, not a universal restriction: the new privileged invocation was
successfully tested with it enabled on both images.

For a **new** site, let OMD mount its own temporary filesystem:

```bash
docker volume create omd-ramdemo-data
docker run --name omd-ramdemo --privileged -d \
  -p 8447:443 \
  -e SITENAME=ramdemo -e OMDCFG_TMPFS=on \
  -v omd-ramdemo-data:/omd/sites/ramdemo "$IMAGE"
wait_ready omd-ramdemo || exit 1
docker exec omd-ramdemo runuser -u ramdemo -- omd config show TMPFS
docker exec omd-ramdemo findmnt -T /omd/sites/ramdemo/tmp -o TARGET,FSTYPE,SOURCE,OPTIONS
docker exec omd-ramdemo omd status ramdemo
```

Expect `on`, filesystem type **tmpfs**, and running site services. The mount
may be shown at **/opt/omd/sites/ramdemo/tmp** because `/omd` is a symlink to
`/opt/omd`. The bootstrap creates the required per-site fstab registration;
OMD mounts and populates the temporary directory during start. The familiar
OMD-VM habit also works: `systemctl status omd` (alias of `omd-site`,
section 6) shows the site unit with its process tree while the site runs.

For an **existing** site, an extra environment variable will be ignored as
initial customization. Change its stored configuration while stopped:

```bash
docker exec omd-prod-v2 systemctl stop omd-site
docker exec omd-prod-v2 runuser -u prod -- omd config set TMPFS on
docker exec omd-prod-v2 systemctl start omd-site
docker exec omd-prod-v2 findmnt -T /omd/sites/prod/tmp -o TARGET,FSTYPE,SOURCE,OPTIONS
docker exec omd-prod-v2 omd status prod
```

Temporary runtime data under `tmp/` disappears when the tmpfs is unmounted
or the container stops. The durable site directories (`etc/`, `var/`,
`local/`) stay on the persistent volume. This is intentional: do not store
credentials, custom configuration or other irreplaceable files in `tmp/`.

### Runtime-managed scratch tmpfs

A separate runtime mount can be useful for your own scratch files:

```bash
docker run --name omd-scratch --privileged -d \
  --tmpfs /scratch:rw,size=64m,mode=1777 "$IMAGE"
wait_ready omd-scratch || exit 1
docker exec omd-scratch findmnt -T /scratch -o TARGET,FSTYPE,SOURCE,OPTIONS
docker stop -t 30 omd-scratch
docker rm omd-scratch
```

Podman supports the same `--tmpfs /scratch:rw,size=64m,mode=1777` flag;
remember `--systemd=always` for its service-mode run. Unlike OMD-managed
mounting, the container runtime creates this mount.
Do not mount a tmpfs over the **whole site directory** if you want durable
data. Prefer `OMDCFG_TMPFS=on` for the site's `tmp/`; pre-mounting a nested
runtime tmpfs there can hide files or interfere with fresh-site detection
and OMD's initialization.

Tmpfs consumes memory and may use host swap. A size limit is a maximum,
not reserved or extra RAM; budget it together with monitoring processes.
Mount permission depends on the host, user namespace and runtime security
policy. These tests demonstrate the documented privileged Podman case,
not every reduced-capability or Docker/Desktop configuration. See the
[Docker tmpfs documentation](https://docs.docker.com/engine/storage/tmpfs/)
and [Podman run documentation](https://docs.podman.io/en/latest/markdown/podman-run.1.html).

### What was actually tested

On **2026-11-13**, using **Podman 6.1.3**, rootless mode, Linux cgroup v2:

- Rocky image ID `ea8bf405bcd8` and Debian image ID `98d35bbf8e76`,
  OMD `5.81.20261109-labs-edition`.
- `--systemd=always --privileged -e OMDCFG_TMPFS=on`: site reached ready,
  configuration showed `on`, `findmnt` showed a real site tmpfs, and all
  five default site services reported running. Clean stops returned 130.
- With a persistent named volume on each distro, a file in `local/`
  survived stop/start and reuse by a fresh container. A file in `tmp/`
  disappeared. The fresh container remounted tmpfs using the **stored**
  setting even though `OMDCFG_TMPFS` was omitted on replacement.
- A runtime `--tmpfs /tutorial-scratch:rw,size=16m,mode=1777` mount was
  verified writable and of type tmpfs on Rocky.

Only disposable containers/volumes were used and they were removed.
Docker was unavailable on the test host, so these new tmpfs tests do not
claim Docker execution. The commands explain its corresponding interface.

## 8. Differences from the old image and practical compatibility

The new image does not have a switch that restores the old PID1/startup
script. It can provide the familiar **single demo site, HTTPS endpoint and
persistent data** while retaining systemd:

```bash
mkdir -p "$DATA_ROOT/demo"
docker run --name omd-demo --privileged -d \
  -p 8448:443 -e SITENAME=demo -e OMDCFG_TMPFS=off \
  -v "$DATA_ROOT/demo:/omd/sites/demo:z" "$IMAGE"
wait_ready omd-demo || exit 1
# Familiar endpoint: https://127.0.0.1:8448/demo/
```

For a complete older `demo` site, use a **backup/copy of its existing whole
site directory** as the source instead of an empty directory, keep
`SITENAME=demo`, and test reuse before switching production. Stored
configuration and credentials take precedence over initialization settings.
Do not point `SITENAME=prod` at a `demo` tree and expect an automatic rename.

| Old non-systemd behavior | New behavior / migration |
|---|---|
| Site created at build time; default demo | Select at runtime with `SITENAME=demo`; no variable means no site. |
| Build `SITENAME`, derived `NEW_SITENAME` | Retired. Set the runtime `SITENAME` on the new container. |
| Startup shell owns PID1 | systemd owns lifetime and service management. |
| sshd installed but disabled | sshd starts; publishing host port 22 and provisioning keys are separate choices. |
| `APACHE_CMD` selected the foreground web command | Use the distro's Apache unit and service configuration. |
| Ansible drop-in ran automatically before site start | No startup playbook execution. Run Ansible explicitly through exec or build/deploy your configuration separately. |
| Old script managed separate etc/var/local initialization | Persist the complete `/omd/sites/<site>` tree. Separate old mounts need a planned migration/backup; the old initialization loop is not restored. |
| `make shell`, `bash`, `bashvol` | Retired. Use `docker exec -it NAME bash` (Podman: `podman exec -it NAME bash`) or SSH for a running service container. |
| Script/signal handling could end in forced kill | Ordered systemd stop with SIGRTMIN+3 and an explicit 30-second grace period. |

Leaving host port 22 unpublished approximates the old external access
surface; it does not disable the internal SSH service. Likewise, selecting
`demo` restores that familiar URL, not all old variables or lifecycle
semantics. Exact old-command compatibility is **not promised**. Keep an old
image available if you require its original startup contract unchanged.

## 9. Limits to plan for

- This is a container sharing the host kernel, not a full virtual machine.
  Privileged mode is part of the documented deployment; a general
  unprivileged invocation is not equivalent.
- One active site is selected per container. Use separate containers and
  separate data volumes for independent sites. Do not share one live site
  volume between writers.
- Environment customization is an initialization mechanism, not a live
  configuration API. Completed/adopted sites keep stored values.
- Only installed OMD hooks are configurable. Enabling a component does not
  install arbitrary software or publish a host port.
- Default web ports are 80/443 and SSH is 22; host mappings are explicit.
  Gearman 4730 is conditional. NRPE/snclient **5666 is external to the OMD
  package set**: EXPOSE does not install an agent or create a listener.
- Readiness checks do not independently test every optional listener;
  verify the services you enabled. Cached ready-unit state is not ongoing
  monitoring of all daemons. The `omd.service` alias (section 6) reports
  the site unit's *cached* oneshot state, not live daemon health — and
  earlier systemd images without the alias change show it as masked instead; `omd status <site>` is
  the live check in both cases.
- Site storage is persistent only where you mount it. The container's root
  authorized_keys copy, package modifications, host keys and journal are
  not preserved merely by mounting the site. Reapply external provisioning
  to replacement containers; changing SSH host keys may require updating
  the client's known_hosts after verification.
- Keep backups and test cross-version migration. Forced-kill recovery,
  Docker parity, arm64 and performance/release gates must not be treated
  as universally validated just because the local Podman examples work.
  See `verify/results.md` for the verification records and the current
  scope (task status is tracked in the development repository, not here).
- A bind mount can be relabeled by `:z` and its site files become owned by
  the site's numeric identity. Plan host backup access accordingly.

Use `docker stop -t 30` (or `podman stop -t 30`) on the tutorial containers
when finished. Remove containers only after deciding which persisted site directories/volumes
you want to retain; removing the container is different from deleting its
data.
