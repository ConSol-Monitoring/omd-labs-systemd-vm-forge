# Historical baseline (OLD images) - 001-systemd-vm-startup, T004

**Scope note**: this file records the behavior of the **pre-change** images
(`local/omd-labs-{rocky,debian}:baseline-red`, built 2026-11-10 from the
pre-change Dockerfiles, `OMD_VERSION=master`). It is **NOT** the FR-018
readiness reference run - that is measured on the NEW image by T034
(research.md ?9 T8) and lands in `verify/results.md` / this file's
successor sections.

Invocation used: the OLD documented invocation (plain `podman run -d -p <port>:443`;
no `--systemd`, no `--privileged`, no site mount). Host: podman 6.1.3,
SELinux Enforcing, cgroup v2, amd64.

## Results (both distros - identical behavior, the defect class is shared)

| Probe | Rocky 9 (18462) | Debian 13 (18463) |
|---|---|---|
| (a) UI `/demo/` | 302 after 3 s | 302 after 1 s |
| (c) PID 1 cmdline | `/usr/bin/bash /root/start.sh` | `/usr/bin/bash /root/start.sh` |
| image `StopSignal` (runtime view) | `SIGTERM` (runtime default) | `SIGTERM` (runtime default) |
| (b) `podman stop -t 30` | "StopSignal SIGTERM failed to stop container ? **resorting to SIGKILL**" - wall 31 s - **exit 137** | identical - **exit 137** |

### (a) Current UI behavior - v1 "edge+backend" readiness context only
`https://127.0.0.1:<port>/demo/` answers 302 (the edge Apache proxies the
`demo` site's loopback backend). There is **no bounded readiness signal**:
"container started" ? "edge answers" - nothing verifies sshd, the site
daemons, or a selected site path. (v2 replaces this with the `omd-ready`
gate, contracts/invocation.md "Readiness".)

### (b) Stop behavior - the gap this feature fixes (plan.md empirical-baseline item 1)
```
$ podman stop -t 30 omd-baseline-rocky
time=? level=warning msg="StopSignal SIGTERM failed to stop container omd-baseline-rocky in 30 seconds, resorting to SIGKILL"
omd-baseline-rocky
# container exit code: 137
```
Root cause (C1): PID 1 is a bash script (`start.sh`); the script's
`trap _cleanup` cannot trap SIGKILL, and the SIGTERM path does not stop the
daemon children reliably within the grace period, so the runtime escalates to
SIGKILL. **Exit 137 on every stop - both distros.** The v2 contract:
`STOPSIGNAL SIGRTMIN+3` (systemd halt.target) + `stop -t 30` ? clean ordered
halt, exit **130** (privileged) / **0** (rootless); 137 = stop failure only.

### (c) PID 1 = script supervision - the root cause
```
$ podman exec omd-baseline-rocky sh -c 'tr "\0" " " < /proc/1/cmdline; echo; readlink -f /proc/1/exe'
/usr/bin/bash /root/start.sh
/usr/bin/bash
```
`start.sh` runs `omd start`, launches Apache as a background child
(`$APACHE_CMD &`) and ends in `sleep infinity` - the classic script-
supervision container: no ordered start/stop, no journal per service,
no stop semantics (C1). v2: `CMD ["/usr/local/bin/omd-labs-entry"]` ->
`exec /sbin/init` (systemd as PID 1).

## Suite's expected-FAIL state against these images (T003, RED mode)

`verify/run.sh s1 <distro> baseline-red` with `RED=1` (bounded 45 s
polling) is executed against these images and its FAIL sections are recorded
in `verify/results.md` (sections `S1-s1-<distro>-?`). Expected FAILs:
readiness (no `omd-ready` unit), no-site check (old image bakes the `demo`
site), sshd listener checks (sshd is installed and build-time-enabled in the
old images, but with no init system running it is never started - no port
22 listener at runtime), clean-stop check (exit 137).
The suite is designed to be runnable against ANY image - these FAIL sections
are the red half of the tests-first record.
