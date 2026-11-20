# VM-like containers for Podman and Docker

Run an [OMD Labs](https://omd.consol.de/docs/omd/) monitoring site, test a
plugin, or try a Linux service without setting up a virtual machine.
These images run **systemd as PID 1**, so familiar commands such as
`systemctl`, `journalctl`, and `omd` work inside a Podman or Docker container.

There are two image variants, each available for **Rocky Linux 10** and **Debian 13**:

- **Base image** — Linux with systemd, Apache, SSH, and cron, without an
  OMD package. The stable and testing repositories at `labs.consol.de` are
  already configured. Use it to test services or install your chosen OMD version.
- **OMD image** — the base image with **OMD Labs Edition** installed.
  OMD Labs is ConSol's flavor of the Open Monitoring Distribution (OMD).
  Choose a site name when you start the container; it creates and starts
  the site for you. Start here if you want to try OMD or test against a
  running monitoring site.

For OMD developers, this means a disposable place to test against a real
site. For administrators, it means a demo you can open in a browser and
keep for later. For other Linux users, the base image offers a familiar
service environment with container startup and storage.

The containers share the host kernel. They need a **Linux host with
cgroup v2** and use **privileged mode**; choose a host suitable for that.
The Rocky amd64 image also needs an **x86-64-v3 CPU** (including the CPU
model exposed by a host VM).

[Try a demo](#try-a-demo) · [Keep your site](#keep-your-site) ·
[Test your code](#test-your-code) · [Use the base image](#use-the-base-image) ·
[Configure OMD](#configure-omd) · [Manage services](#manage-services) ·
[Tmpfs](#use-ram-for-temporary-files) · [Build an image](#build-your-own-image) ·
[Internals](#internals)

## Try a demo

The examples use **Bash and Podman**, with `--privileged` and
`--systemd=always` for service containers. Keep using the same Podman user
throughout: `podman` and `sudo podman` have separate image and container stores.

**For Docker**, replace `podman` with `docker` and omit `--systemd=always`.
If you use the readiness helper below, set `CONTAINER_RUNTIME=docker` too.
Docker has its own image store. The execution records cover Podman; Docker
commands have not yet been run on our test host.

Choose an image. `latest` follows stable OMD; use `nightly` to try the
current development build. Replace the final `rocky` with `debian` if you
prefer Debian.

Browse the [published container images](https://github.com/ConSol-Monitoring/omd-labs-systemd-vm-forge/packages)
and select an image to see its available tags, architectures, and other metadata.

```bash
IMAGE=ghcr.io/consol-monitoring/omd-labs-systemd-vm-forge/omd-labs-systemd-vm-rocky:latest
podman pull "$IMAGE"
podman run --name omd-demo --privileged --systemd=always -d \
  -p 127.0.0.1:8443:443 \
  -e SITENAME=demo \
  "$IMAGE"
```

Give the site a moment to start, then check:

```bash
podman exec omd-demo systemctl is-active omd-ready
podman exec omd-demo omd status demo
```

Wait for the first command to print **`active`**, then expect OMD to report
**`Overall state: running`**. If it is still starting, repeat the checks
after a few seconds. If the container exits, [inspect its logs](#if-startup-fails).
For scripts, use the [bounded readiness helper](#wait-for-startup-in-scripts).

Set a web password:

```bash
podman exec -it omd-demo su - demo -c set_admin_password
```

To set the password during initial site creation instead, add
`-e OMD_ADMIN_PASSWORD='your-lab-password'` to the run command. See
[Configure OMD](#configure-omd) for details.

Open **https://127.0.0.1:8443/demo/** and log in as **`omdadmin`** with that
password. The image uses a test TLS certificate, so expect a browser
certificate warning. The port mapping makes this demo available only on
your host. To serve other machines, choose a suitable host address and
configure access and trusted TLS for your deployment.

You now have a working monitoring site. Open a shell to explore it:

```bash
podman exec -it omd-demo bash
```

When finished:

```bash
podman stop -t 30 omd-demo
podman rm omd-demo
```

This demo stores its site in the container: stopping keeps it, removing
it deletes it. The next example adds storage that survives replacement.

## Keep your site

Mount the **whole site directory**, `/omd/sites/<name>`, to keep its
configuration, monitoring data, and web password outside the container.
Here is a separate site on port 8444:

```bash
DATA_ROOT="$HOME/omd-labs-data"
mkdir -p "$DATA_ROOT/lab"
podman run --name omd-lab --privileged --systemd=always -d \
  -p 127.0.0.1:8444:443 \
  -e SITENAME=lab \
  -v "$DATA_ROOT/lab:/omd/sites/lab:z" \
  "$IMAGE"
```

Check `omd-ready` as above, set the password with
`podman exec -it omd-lab su - lab -c set_admin_password`, and visit
**https://127.0.0.1:8444/lab/**.

An empty directory becomes a new site. A complete existing site is resumed
with its stored settings and credentials. Use the same site name in
`SITENAME` and the mount path `/omd/sites/<name>`. Changing these inputs
does not rename an existing site.

The `:z` option allows access on SELinux hosts and may relabel the host
directory. Site files acquire the site's numeric ownership; preserve that
ownership in backups rather than recursively changing it to your host user.
A named volume is another option: replace the bind mount with
`-v omd-lab-data:/omd/sites/lab`.

### Restart or replace the container

A stop/start cycle keeps the same container:

```bash
podman stop -t 30 omd-lab
podman start omd-lab
```

To replace it, stop and remove the old container, then run a new one with
the **same image, site name, and data directory**:

```bash
podman stop -t 30 omd-lab
podman rm omd-lab
podman run --name omd-lab --privileged --systemd=always -d \
  -p 127.0.0.1:8444:443 \
  -e SITENAME=lab \
  -v "$DATA_ROOT/lab:/omd/sites/lab:z" \
  "$IMAGE"
```

Wait for readiness after each start. The new container restores the site
account and resumes the site from the mounted data. Never run two
containers against the same site directory at once.

Keep a separate backup of a stopped site. Replacing a container with a
different OMD version is also an **OMD upgrade**: test it on a copy first.
The bootstrap attempts migration if the site's old version is absent;
that does not guarantee every upgrade or downgrade will work. For repeatable
tests and replacements, retain the original image ID or pin its digest,
since `latest` and `nightly` move.

## Test your code

A disposable OMD site lets you try a plugin or configuration change without
touching your own monitoring installation. This example creates a test
site, then copies a plugin from your current directory into it:

```bash
podman run --name omd-test --privileged --systemd=always -d \
  -e SITENAME=test \
  "$IMAGE"
# Wait for omd-ready to become active before the next commands.
podman exec omd-test systemctl is-active omd-ready
```

Repeat the check until it prints `active`, then copy and run your plugin:

```bash
podman cp ./check_example omd-test:/omd/sites/test/local/lib/monitoring-plugins/check_example
podman exec omd-test chmod 755 /omd/sites/test/local/lib/monitoring-plugins/check_example
podman exec omd-test su - test -c 'local/lib/monitoring-plugins/check_example --help'
```

Substitute your own plugin and arguments. Running it as the site user
exercises the OMD environment and permissions. No web port is needed for
this command-line test. For a test that needs the UI, add a host mapping
such as `-p 127.0.0.1:8445:443` when creating the container.

Try the same test with the Debian image, a stable release, or a nightly
build. Create a separate container and data volume for each independent
site. If your code requires extra packages, install them in a derived
image so the test environment can be rebuilt.

```bash
podman stop -t 30 omd-test
podman rm omd-test
```

### Try a component: Gearman

Initial OMD settings can be passed as `OMDCFG_<KEY>` variables. For example,
this new site enables the Gearman integration and makes its listener
available to programs on your host:

```bash
podman run --name omd-gearman --privileged --systemd=always -d \
  -p 127.0.0.1:4730:4730 \
  -e SITENAME=gearman \
  -e OMDCFG_MOD_GEARMAN=on \
  -e OMDCFG_GEARMAND_PORT=0.0.0.0:4730 \
  "$IMAGE"
# After readiness:
podman exec omd-gearman runuser -u gearman -- omd config show MOD_GEARMAN
podman exec omd-gearman ss -ltn
```

Expect `on` and a listener on port 4730. This uses OMD's default
`GEARMAND=on` together with `MOD_GEARMAN=on`. Enabling a component and
publishing its port are separate choices; `EXPOSE` alone does neither.

## Use the base image

For a Linux service lab without OMD, choose the base image. Apache, SSH,
and cron are already managed by systemd; the stable and testing ConSol
repositories are configured for later package installation.

```bash
BASE_IMAGE=ghcr.io/consol-monitoring/omd-labs-systemd-vm-forge/omd-labs-systemd-vm-base-rocky:latest
podman run --name linux-lab --privileged --systemd=always -d "$BASE_IMAGE"
podman exec linux-lab systemctl is-active omd-ready
# Once active:
podman exec -it linux-lab bash
```

Inside the container, work as you would in a small Linux installation:

```bash
systemctl status httpd sshd crond
journalctl -u httpd --no-pager -n 20
dnf install -y strace
```

For Debian, use `omd-labs-systemd-vm-base-debian:latest`; its units are
`apache2`, `ssh`, and `cron`, and its package manager is `apt`.

**Omit `SITENAME` on the base image**: it has no OMD to create a site and
will refuse a site request. You can also omit `SITENAME` on the full OMD
image to start it without a site. Without one, HTTPS serves Apache's base
response (typically 403 on Rocky, 200 on Debian).

To choose an OMD version reproducibly, [build the full image](#build-your-own-image)
with the desired `OMD_VERSION`. If you instead install OMD interactively
in the base container, follow the [package integration notes](#image-layers-and-package-installation)
before creating a site manually. Those package changes remain in that
container's writable layer and are lost when it is removed.

## Configure OMD

The container creates one active site selected by `SITENAME`. Names are
1–16 characters: start with a letter or underscore, then use letters,
digits, or underscores. Choose a name that does not collide with a system
user or group.

These are the startup controls:

| Input | Use |
|---|---|
| `SITENAME` | Create or resume the named site; empty or absent starts without a site. |
| `OMDCFG_<KEY>` | Set an OMD configuration key when the site is first created. |
| `OMD_ADMIN_PASSWORD` | Set the initial `omdadmin` web password when the site is first created. |
| `/etc/omd-labs/site-settings.conf` | Supply initial OMD settings from a mounted file. |

These inputs also apply when completing an interrupted first creation.
For an unattended lab, add `-e OMD_ADMIN_PASSWORD='your-lab-password'` to
its run command. An empty value leaves OMD's generated password in place;
non-empty values are passed literally. Environment values are visible in
container inspection and host process listings; use this as a lab convenience,
not a secret store. To set or rotate a password interactively, use `set_admin_password` as in the demo;
the generated password is not reliably available in container logs.

### Put initial settings in a file

A settings file uses literal `KEY=value` lines and full-line `#` comments.
Use OMD keys without the `OMDCFG_` prefix, shell quotes, or `export`:

```bash
cat > site-settings.conf <<'SETTINGS'
# Initial settings for the custom site
ADMIN_MAIL=monitoring@example.org
SETTINGS

podman run --name omd-custom --privileged --systemd=always -d \
  -p 127.0.0.1:8446:443 \
  -e SITENAME=custom \
  -e OMDCFG_ADMIN_MAIL=lab@example.org \
  -v "$PWD/site-settings.conf:/etc/omd-labs/site-settings.conf:ro,z" \
  "$IMAGE"
```

Environment values win over file values for the same key. Here the stored
administrator address becomes `lab@example.org`. Settings are applied
before the site starts; invalid keys or values fail startup with an error.

Available keys and values depend on the installed OMD version. Inspect the
actual site's settings rather than relying on a fixed catalog:

```bash
podman exec omd-custom runuser -u custom -- omd config show
podman exec omd-custom runuser -u custom -- omd config show ADMIN_MAIL
```

### Change an existing site deliberately

**Completed sites keep their stored configuration and password.** New
`OMDCFG_*`, file settings, and `OMD_ADMIN_PASSWORD` values do not overwrite
them on restart or container replacement. Remove obsolete initialization
inputs; malformed settings-file syntax can still fail validation.

To change a stored setting, stop the site, apply it, then start it again:

```bash
podman exec omd-lab systemctl stop omd
podman exec omd-lab runuser -u lab -- omd config set ADMIN_MAIL new-address@example.org
podman exec omd-lab systemctl start omd
podman exec omd-lab runuser -u lab -- omd config show ADMIN_MAIL
podman exec omd-lab omd status lab
```

`podman restart` does not change a container's environment or mounts. To
change those, create a replacement container; to try different *initial*
site settings, use a new site directory or volume.

## Manage services

Use the same tools you would use in an OMD VM:

```bash
podman exec omd-lab systemctl status omd
podman exec omd-lab systemctl restart omd
podman exec omd-lab journalctl -u omd-site --no-pager -n 40
podman exec omd-lab omd status lab
```

`omd` is an alias of `omd-site.service`. Its **`active (exited)`** state is
normal: the unit ran `omd start`. For current daemon health, use
`omd status lab`; the unit's cached state does not detect a later daemon
crash. Use the canonical `omd-site` name when querying its journal.

The system Apache is the HTTPS front end; each OMD site has its own web
backend. Rocky uses unit names `httpd`, `sshd`, and `crond`; Debian uses
`apache2`, `ssh`, and `cron`. If a service fails after startup, the container
stays up so you can inspect and restart it.

Stop the whole environment with `podman stop -t 30 NAME`. This gives systemd
time to stop the services in order. A clean halt may return container exit
code **0 or 130**; **137**
means it was killed, for example after the stop timeout.

### Add SSH access

For most tasks, `podman exec` is enough. If you want SSH, mount your
**public** key and publish port 22. This separate example starts without
a monitoring site:

```bash
# Use an existing public key, or generate a dedicated pair once:
[ -f ./omd-lab-key ] || ssh-keygen -t ed25519 -f ./omd-lab-key -N ''
podman run --name omd-ssh --privileged --systemd=always -d \
  -p 127.0.0.1:18022:22 \
  -v "$PWD/omd-lab-key.pub:/root/.ssh/omd_ssh_keys:ro,z" \
  "$IMAGE"
# After readiness:
ssh -i ./omd-lab-key -o IdentitiesOnly=yes -p 18022 root@127.0.0.1
```

Verify the host-key fingerprint on first connection. Keep the private key
on the host. The bootstrap validates the public key and copies it to
`authorized_keys`; mount the source at `omd_ssh_keys` as shown, since a
read-only mount over `authorized_keys` prevents provisioning. Without a
key, sshd runs but there is no shared default login credential.

Mounting a site directory does not preserve SSH host keys, installed
packages, or the journal. Reapply external provisioning when replacing a
container, and verify the SSH host key again if it changes.

### Wait for startup in scripts

`omd-ready` records successful startup. It checks the base services and,
when selected, the OMD site and its HTTPS endpoint. A container ID from
`run -d` does not mean these are ready yet.

<details>
<summary>Bash helper: wait for readiness, fail on exit or timeout</summary>

Define once and call after each `run` or `start`. The 360-second bound
allows for all startup phases; runtime commands must remain responsive.

```bash
CONTAINER_RUNTIME=podman  # set to docker when using Docker
wait_ready() {
    local name=$1 running state started=$SECONDS
    while (( SECONDS - started < 360 )); do
        running=$("$CONTAINER_RUNTIME" inspect -f '{{.State.Running}}' "$name") || return 1
        if [ "$running" != true ]; then
            "$CONTAINER_RUNTIME" logs --tail 40 "$name" >&2
            return 1
        fi
        state=$("$CONTAINER_RUNTIME" exec "$name" systemctl is-active omd-ready 2>/dev/null || true)
        [ "$state" != active ] || return 0
        sleep 2
    done
    echo "Timed out waiting for $name; inspect its logs" >&2
    return 1
}

wait_ready omd-lab || echo "Not ready; inspect the container logs."
```

</details>

The helper returns a nonzero status on failure; the example prints a message
and leaves your shell open.

Readiness is a startup result, not ongoing monitoring. Check live health
with `omd status <site>` and the services your test depends on. The gate
checks selected optional listeners, not every possible component; verify
additional ones yourself, as in the Gearman example.

### If startup fails

Start with the container logs and exit status:

```bash
podman logs --tail 60 omd-lab
podman inspect -f '{{.State.Status}} exit={{.State.ExitCode}}' omd-lab
```

Common causes are a missing Podman systemd flag, insufficient privileges,
an invalid site name or setting, a malformed SSH key, or an incomplete
site directory. Keep the failed container until you have collected its
diagnostics. Do not delete site data to bypass a startup error.

For a stopped container, retrieve the phase-specific error files into a
fresh directory:

```bash
DIAG=$(mktemp -d)
for file in entry-fatal fatal-reason; do
    if podman cp "omd-lab:/var/log/omd-labs/$file" "$DIAG/$file" 2>/dev/null; then
        cat "$DIAG/$file"
    fi
done
```

`entry-fatal` describes a bootstrap error; `fatal-reason` describes a
readiness failure. These files and log delivery are best effort; the
container's nonzero exit status remains the failure signal.

## Use RAM for temporary files

OMD can mount the site's `tmp/` directory as tmpfs. For a fresh site, enable
it with **`OMDCFG_TMPFS=on`**:

```bash
podman run --name omd-ram --privileged --systemd=always -d \
  -e SITENAME=ramdemo -e OMDCFG_TMPFS=on \
  -v omd-ram-data:/omd/sites/ramdemo \
  "$IMAGE"
# After readiness:
podman exec omd-ram runuser -u ramdemo -- omd config show TMPFS
podman exec omd-ram findmnt -T /omd/sites/ramdemo/tmp -o TARGET,FSTYPE,OPTIONS
```

Expect `on` and filesystem type `tmpfs`. The mount may appear under
`/opt/omd/sites/ramdemo/tmp`, because `/omd` is a symlink. Temporary files
vanish when the mount is torn down; `etc/`, `var/`, and `local/` remain on
the site volume. Keep irreplaceable files outside `tmp/`.

For an existing site, change the stored `TMPFS` setting while it is stopped,
using the [configuration procedure](#change-an-existing-site-deliberately).
A new environment variable alone will not override it.

For unrelated scratch space, add `--tmpfs /scratch:rw,size=64m,mode=1777`
to a run command. Let OMD manage its own `tmp/` rather than mounting a
runtime tmpfs there, which can interfere with site initialization. Never
mount tmpfs over the whole site if you need durable data. Tmpfs uses memory
and may use host swap; a size limit does not reserve extra RAM.

### Clean up the examples

Keep `omd-lab` if you want to return to your persistent site. To remove the
other optional examples you started:

```bash
for name in omd-gearman omd-custom omd-ssh linux-lab omd-ram; do
    if podman container inspect "$name" >/dev/null 2>&1; then
        podman stop -t 30 "$name"
        podman rm "$name"
    fi
done
```

The named volume `omd-ram-data` and the directory `$DATA_ROOT/lab` remain.
Delete them separately only when you no longer need their sites.

## Build your own image

Clone this repository and run from its root. The default Dockerfile target
builds the full OMD image:

```bash
podman build -f Dockerfile.omd-labs-systemd-vm-rocky \
  --build-arg OMD_VERSION=master \
  -t local/omd-labs-systemd-vm-rocky:nightly .
IMAGE=local/omd-labs-systemd-vm-rocky:nightly
```

Use the Debian Dockerfile for Debian.
`OMD_VERSION=master` selects the daily/testing package; `latest` selects
stable; a release such as `5.80` selects its versioned stable package.
Only even minor versions are stable releases; odd minors are reached
through the nightly track. The image tag itself does not choose a package.

To build the base without OMD:

```bash
podman build -f Dockerfile.omd-labs-systemd-vm-rocky --target base \
  -t local/omd-labs-systemd-vm-base-rocky:nightly .
```

After the Podman build above, you can also start and stop the local image
with the Makefile:

```bash
make -f Makefile.omd-labs-systemd-vm-rocky start RUNTIME=podman SITENAME=demo
make -f Makefile.omd-labs-systemd-vm-rocky stop RUNTIME=podman SITENAME=demo
```

Pass `RUNTIME=podman` to Make's `start`, `startvol`, and `stop` targets;
their default is Docker. The Make `build` target always calls Docker, even
with `RUNTIME=podman`, so use `podman build` as shown above on a Podman host.
Make derives the local tag from the branch (`master` → `nightly`); use the
matching local tag when building for these targets.
`FLAVOR=base` selects the base build. `startvol` requires an existing
absolute `VOLUME` directory and the matching `SITENAME`. Full-image Make
runs default to `SITENAME=demo`, unlike direct runs, which default to no
site. Pass the site name consistently, including to `stop`.

### Coming from the older images

Select the site at runtime with `SITENAME`; build-time site creation and
`NEW_SITENAME` are retired. Persist the whole site tree. Test a backup/copy
of an older site with the same name before switching over; complete legacy
sites are adopted with their stored settings and password.

The old `APACHE_CMD`, `ANSIBLE_DROPIN`, `ANSIBLE_CONFIG`,
`ANSIBLE_VERBOSITY`, and `OMD_CONTAINER_MODE` startup controls are retired.
Ansible is still installed for explicit use. Use `exec` or SSH in place of
the old `shell`, `bash`, and `bashvol` Make targets. Older systemd images
may show `omd.service` as masked; use `omd-site` there, or replace the
container with a current image to get the alias.

## Internals

This section explains how the VM-like behavior is assembled. The
[Rocky Dockerfile](Dockerfile.omd-labs-systemd-vm-rocky),
[Debian Dockerfile](Dockerfile.omd-labs-systemd-vm-debian),
[bootstrap](scripts/omd-labs-entry), and [systemd units](units/) are the
implementation references.

### Image layers and package installation

Each Dockerfile has a `base` stage and an `omd` stage built `FROM base`.
The base owns systemd, Apache with HTTPS, SSH, cron, listener-probe tools,
the startup scripts, and both ConSol repository channels with package
signature verification. The full image adds the OMD package and restores
the intended unit setup. No monitoring site is baked into either image.

#### Advanced: install OMD into a running base container

A manually created site is not managed by the startup wrapper: **stop it
with `omd stop <name>` before stopping the container**.

Installing OMD into the base also introduces the package's generic
all-sites `omd.service`. After installation, remove that enablement and
reassert the single-site alias and base services, as the final Dockerfile
stage does. For Rocky, the normalization is:

```bash
# Inside the base container, after installing OMD:
rm -f /etc/systemd/system/omd.service \
      /etc/systemd/system/multi-user.target.wants/omd.service
systemctl enable omd-site.service omd-ready.service sshd httpd crond
systemctl daemon-reload
```

On Debian use `ssh apache2 cron` for the last three units. For manual
runtime installation, start the base without `SITENAME`, install your
package (`omd-labs-edition`, `omd-labs-edition-daily`, or a versioned
`omd-<version>-labs-edition`), normalize the units, then create/start your
site with `omd`. The startup state still says no selected site, so the
wrapper unit will not manage this manually created site. For automatic site
lifecycle, install at image build time and run with `SITENAME` instead.

### Before systemd: select, create, or restore the site

The image command is `omd-labs-entry`. It runs as PID 1 during preparation,
checks prerequisites, and validates the requested site before starting
services. A nonempty `SITENAME` requires `/usr/bin/omd`; a base-image site
request is rejected before creating a partial site directory.

For a selected site, the bootstrap classifies the directory:

- **Empty or absent:** allocate a site identity, register its account and
  group, prepare the directory, and run `omd create --reuse`.
- **Completed:** restore registration in the new container and resume the
  site, keeping its stored configuration and credentials.
- **Complete legacy tree without markers:** infer the stored identity,
  restore registration, and adopt the site.
- **Interrupted first creation:** use its recorded identity and creation
  state to finish creation and initial configuration.
- **Incomplete or conflicting:** refuse startup with a reason rather than
  silently resetting the site or assigning it a foreign account.

Three files track this lifecycle: `.omd-labs-init-inprogress`,
`.omd-labs-init-complete`, and `.omd-labs-site-identity`. Leave them with
the volume. The identity record preserves numeric uid/gid across container
replacement; registration restores the account, Apache group membership,
fstab entry, and OMD web integration. If the old OMD version is absent,
registration attempts a bounded `omd update`.

For creation and recovery, settings-file values are combined with
`OMDCFG_*` overrides and applied in dependency order. Each stored value is
read back to detect rejected settings. A nonempty `OMD_ADMIN_PASSWORD` is
applied as one literal argument to the site's `set_admin_password` tool;
the success notice does not print the password. The completion marker is
written only after these steps succeed. Completed sites, including those
with a stale in-progress marker, keep their stored password and settings.

Preparation has a shared **120-second budget**, with bounded subprocess
calls. Failures record `entry-fatal` when possible and exit before init.

### Handoff to PID 1 and service ownership

The bootstrap copies validated SSH keys, writes `SITE_ACTIVE`, `SITE_NAME`,
and `SITE_CUSTOM_APPLIED` to `/run/omd-labs.env`, starts a log forwarder,
and finally **execs `/sbin/init`**. Systemd now owns PID 1 and the container
lifetime. The environment file passes resolved state to the site wrappers;
these internal variables are not user-facing startup controls.

`omd-site.service` is a `Type=oneshot`, `RemainAfterExit=yes` unit. Its
wrappers call `omd start/stop <site>` only when a site is selected; otherwise
they do nothing. `Alias=omd.service` and build-time enablement provide the
familiar service name without running a second all-sites controller. The
vendor unit file remains package-owned but is shadowed by this alias.
Apache, SSH, and cron run as separate systemd services.

Podman's `--systemd=always` provides the runtime tmpfs mounts (`/run`,
`/run/lock`, `/tmp`, and `/var/lib/journal`) and writable cgroup setup for
systemd. It must be forced because the image command is a bootstrap wrapper,
which Podman's automatic detection does not recognize as init. Docker has
no `--systemd` switch; the documented invocation uses privileged mode.

### Startup readiness and failures

`omd-ready.service` runs after the site, Apache, and SSH startup jobs.
It uses ordering (`After=`) without hard dependencies so it can inspect a
failed service instead of having its own job cancelled before inspection.
The probe checks unit states, TCP reachability on 443 and 22, and, for an
active site, `omd status`, HTTPS `/<site>/`, and selected component listeners.

The site start job has a **90-second timeout**. The readiness probe has
its own **120-second window**, backed by a **150-second systemd timeout**
if the probe hangs. Only the ready unit has `FailureAction=exit`:
startup failure terminates the container, while a later service crash leaves
it available for diagnosis. Successful readiness remains cached.

Before exiting, the probe attempts site cleanup and records a bounded
`/var/log/omd-labs/fatal-reason`, a journal excerpt, and container-log output.
The forwarder carries journal messages to the container log pipe; failure
of that channel does not control whether the container exits.

Exit meanings are: **1** for bootstrap/readiness failure, **2** for the
probe's readiness deadline, and **255** for the observed systemd backstop
when a hung probe is killed. Stop outcomes are described under
[Manage services](#manage-services). The image sets
`STOPSIGNAL SIGRTMIN+3`, so normal runtime stop commands ask systemd to
halt and stop units in order.

### How tmpfs works

The optional **OMD site tmpfs** is mounted by OMD itself. During site
registration, the bootstrap adds OMD's canonical entry to `/etc/fstab`:

```fstab
tmpfs /opt/omd/sites/<site>/tmp tmpfs noauto,user,mode=755,uid=<site>,gid=<site> 0 0
```

The real `/opt/omd` path is used because `/omd` is a symlink. `noauto`
leaves mounting to OMD; `user` and the site uid/gid allow its site-user
mounting path. With stored `TMPFS=on`, OMD mounts and populates `tmp/`
during site start. Registration recreates the fstab entry in a replacement
container, so the site's stored setting works again without repeating the
initial environment override. Only temporary data disappears; the rest of
the mounted site remains durable.

OMD normally defaults TMPFS off in containers. Privileged Podman testing
confirmed it can be enabled on these images. A separate runtime
`--tmpfs /scratch:...` mount is created by Podman/Docker instead and has no
connection to OMD's setting. Mount permissions depend on the host and user
namespace; consult the [verification records](verify/results.md) for the
executed cases.

### Publication and verification

Images are published to **GHCR** under
`ghcr.io/consol-monitoring/omd-labs-systemd-vm-forge/`, using these names:
`omd-labs-systemd-vm-{rocky,debian}` and
`omd-labs-systemd-vm-base-{rocky,debian}`. Published tags target amd64 and
arm64. `latest` and `nightly` move; version tags such as `v5.80` are
immutable. Architecture-specific tags use `-amd64` and `-arm64` suffixes.

The [workflows](.github/workflows/) publish both image variants on OMD publication
webhooks or release tags. The OMD image inherits the base from the same
checkout/build, rather than pulling an independently published base.
Refreshing a base tag later does not update existing full-image layers.
Branch and pull-request builds check that images build; they do not run
the runtime verification suite or gate publication on it. Docker Hub
publication is currently disabled.

Runtime scenarios live in [verify/](verify/), with executed results and
limitations in [verify/results.md](verify/results.md). The documented
local quickstart, SSH, site tmpfs, and volume reuse have Podman execution
records; those records do not establish Docker parity or universal
cross-version migration support.
