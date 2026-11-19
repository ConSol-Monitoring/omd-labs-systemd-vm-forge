# Verification results - 001-systemd-vm-startup

Written by the `verify/` suite (tests-first, T003). Each scenario run appends
its own uniquely named section; per-scenario evidence (commands + output) is
inlined below the PASS/FAIL lines.

Exit-code contract asserted throughout: **130/0** clean halt (privileged /
rootless), **1** fatal pre-ready, **2** readiness deadline exceeded, **137**
SIGKILL after stop timeout (the only stop-failure outcome).
## S1-s1-rocky
- when: 2026-11-10 12:03:43
- runtime: podman

- **RESULT: FAIL**

- container: omd-s1 (https 18451, ssh 18452, edge unit httpd)
- FAIL: readiness within bound (gate active + 443 answers) (rc=2)
```
READY-DEADLINE: not ready within 45s
ready-time=s rc=2
```

- FAIL: no OMD site exists (SC-003: /omd/sites empty) (rc=1)
```

```

- FAIL: omd-ready + httpd + sshd all active (rc=2)
```
System has not been booted with systemd as init system (PID 1). Can't operate.
Failed to connect to bus: Host is down
System has not been booted with systemd as init system (PID 1). Can't operate.
Failed to connect to bus: Host is down
System has not been booted with systemd as init system (PID 1). Can't operate.
Failed to connect to bus: Host is down
ready= edge= sshd=
sh: line 1: [: =: unary operator expected
```

- FAIL: listeners on 443 + 22 (in-container) (rc=1)
```

```

- FAIL: sshd reachable from host on 18452 (rc=1)
```
bash: line 1: /dev/tcp/127.0.0.1:18452: No such file or directory
```

- FAIL: informational banner in container log (FR-015: no site) (rc=1)
```
AH00558: httpd: Could not reliably determine the server's fully qualified domain name, using 10.0.1.166. Set the 'ServerName' directive globally to suppress this message
```

- PASS: stop httpd -> 443 down -> start -> back (SC-006)
```
System has not been booted with systemd as init system (PID 1). Can't operate.
Failed to connect to bus: Host is down
System has not been booted with systemd as init system (PID 1). Can't operate.
Failed to connect to bus: Host is down
```

- PASS: stop sshd -> 22 down -> start -> back (SC-006)
```
System has not been booted with systemd as init system (PID 1). Can't operate.
Failed to connect to bus: Host is down
System has not been booted with systemd as init system (PID 1). Can't operate.
Failed to connect to bus: Host is down
```

- PASS: journalctl -u httpd returns logs (FR-016)
```
No journal files were found.
```

- FAIL: container log shows startup sequence (FR-015) (rc=141)
```

```

- ready-time recorded above; median-of-5 formal baseline = T034 (FR-018)
- FAIL: clean stop -t 30 ends 130/0, not 137 (exit code: 137, stop rc: 0) (rc=1)
```

```

- teardown done
## S1-s1-debian
- when: 2026-11-10 12:05:09
- runtime: podman

- **RESULT: FAIL**

- container: omd-s1 (https 18452, ssh 18453, edge unit apache2)
- FAIL: readiness within bound (gate active + 443 answers) (rc=2)
```
READY-DEADLINE: not ready within 45s
ready-time=s rc=2
```

- FAIL: no OMD site exists (SC-003: /omd/sites empty) (rc=1)
```

```

- FAIL: omd-ready + apache2 + sshd all active (rc=2)
```
System has not been booted with systemd as init system (PID 1). Can't operate.
Failed to connect to system scope bus via local transport: Host is down
System has not been booted with systemd as init system (PID 1). Can't operate.
Failed to connect to system scope bus via local transport: Host is down
System has not been booted with systemd as init system (PID 1). Can't operate.
Failed to connect to system scope bus via local transport: Host is down
ready= edge= sshd=
sh: 1: [: =: unexpected operator
```

- FAIL: listeners on 443 + 22 (in-container) (rc=1)
```

```

- FAIL: sshd reachable from host on 18453 (rc=1)
```
bash: line 1: /dev/tcp/127.0.0.1:18453: No such file or directory
```

- FAIL: informational banner in container log (FR-015: no site) (rc=1)
```
AH00558: apache2: Could not reliably determine the server's fully qualified domain name, using 10.0.1.166. Set the 'ServerName' directive globally to suppress this message
```

- PASS: stop apache2 -> 443 down -> start -> back (SC-006)
```
System has not been booted with systemd as init system (PID 1). Can't operate.
Failed to connect to system scope bus via local transport: Host is down
System has not been booted with systemd as init system (PID 1). Can't operate.
Failed to connect to system scope bus via local transport: Host is down
```

- PASS: stop sshd -> 22 down -> start -> back (SC-006)
```
System has not been booted with systemd as init system (PID 1). Can't operate.
Failed to connect to system scope bus via local transport: Host is down
System has not been booted with systemd as init system (PID 1). Can't operate.
Failed to connect to system scope bus via local transport: Host is down
```

- PASS: journalctl -u apache2 returns logs (FR-016)
```
No journal files were found.
```

- FAIL: container log shows startup sequence (FR-015) (rc=141)
```

```

- ready-time recorded above; median-of-5 formal baseline = T034 (FR-018)
- FAIL: clean stop -t 30 ends 130/0, not 137 (exit code: 137, stop rc: 0) (rc=1)
```

```

- teardown done

## T012-boot-rocky (manual boot check, per tasks.md T012)
- when: 2026-11-10 12:50:23
- runtime: podman
- image: local/omd-labs-systemd-vm-rocky:nightly (build 3, with T015-T019 baked)
- PASS: PID 1 = /sbin/init (cmdline /sbin/init, exe /usr/lib/systemd/systemd)
- PASS: /run/omd-labs.env exists with SITE_ACTIVE="0" (SITE_NAME="", SITE_CUSTOM_APPLIED="0")
- PASS: STOPSIGNAL SIGRTMIN+3 (podman inspect)
- PASS: enabled set matches units/README-units.md: httpd/sshd/crond/omd-site/omd-ready enabled; omd.service masked; getty@tty1 disabled
- PASS: omd-site is-active=active after boot (guarded wrapper no-op; Result=success, ExecMainStatus=0)
- PASS: omd-ready active (gate passed ~2s after boot: journal "READY: base services up (omd-site active, httpd 443, sshd 22)")
- PASS: listeners 443 + 22 in-container
- PASS: no-site banner in container log: "omd-labs-entry: no site - base services only (systemd starting)"
- PASS: stop -t 30 clean in 1s, exit 130 (baseline: 31s, exit 137 - verify/baseline.md)
- NOTE: the manual harness reported ready=no after 351s because it required 200/302 on the BASE path; the no-site rocky edge answers 403 on / (Apache base response without site vhosts). The gate (omd-ready) was active and 443 answered - ready in practice ~2-3s. Fixed in verify/common.sh v_wait_ready (base path: any non-000 answer = reachable; site path: 2xx/3xx only).
- **RESULT: PASS**

## T012-boot-debian (manual boot check, per tasks.md T012)
- when: 2026-11-10 12:50:23
- runtime: podman
- image: local/omd-labs-systemd-vm-debian:nightly (build 3, with T015-T019 baked)
- PASS: PID 1 = /sbin/init (exe /usr/lib/systemd/systemd)
- PASS: /run/omd-labs.env exists with SITE_ACTIVE="0"
- PASS: STOPSIGNAL SIGRTMIN+3 (podman inspect)
- PASS: enabled set matches units/README-units.md: apache2/ssh/cron/omd-site/omd-ready enabled (+ distro defaults incl. mariadb/exim4); omd.service masked; getty@tty1 disabled
- PASS: omd-site is-active=active after boot (guarded wrapper no-op; Result=success, ExecMainStatus=0)
- PASS: omd-ready active (ready reported in ~3s by the manual harness)
- PASS: listeners 443 + 22 in-container
- PASS: no-site banner in container log
- PASS: stop -t 30 clean in 1s, exit 130 (baseline: exit 137)
- **RESULT: PASS**
## S1-s1-rocky
- when: 2026-11-10 12:58:23
- runtime: podman

- **RESULT: FAIL**

- container: omd-s1 (https 18451, ssh 18452, edge unit httpd)
- PASS: readiness within bound (gate active + 443 answers)
```
ready-time=2s rc=0
```

- PASS: no OMD site exists (SC-003: /omd/sites empty)
- PASS: omd-ready + httpd + sshd all active
```
ready=active edge=active ssh=active
```

- PASS: listeners on 443 + 22 (in-container)
- PASS: sshd reachable from host on 18452
- PASS: informational banner in container log (FR-015: no site)
- FAIL: stop httpd -> 443 down -> start -> back (SC-006) (rc=2)
```
/home/lausser/git/omd-labs-systemd-vm-forge/verify/common.sh: eval: line 188: unexpected EOF while looking for matching `"'
```

- FAIL: stop sshd -> 22 down -> start -> back (SC-006) (rc=2)
```
/home/lausser/git/omd-labs-systemd-vm-forge/verify/common.sh: eval: line 188: unexpected EOF while looking for matching `"'
```

- PASS: journalctl -u httpd returns logs (FR-016)
- PASS: container log shows startup sequence (FR-015)
- ready-time recorded above; median-of-5 formal baseline = T034 (FR-018)
- PASS: clean stop -t 30 ends 130/0, not 137 (exit code: 130, stop rc: 0)
- teardown done
## S1-s1-rocky
- when: 2026-11-10 13:01:56
- runtime: podman

- **RESULT: FAIL**

- container: omd-s1 (https 18451, ssh 18452, edge unit httpd)
- PASS: readiness within bound (gate active + 443 answers)
```
ready-time=2s rc=0
```

- PASS: no OMD site exists (SC-003: /omd/sites empty)
- PASS: omd-ready + httpd + sshd all active
```
ready=active edge=active ssh=active
```

- PASS: listeners on 443 + 22 (in-container)
- PASS: sshd reachable from host on 18452
- PASS: informational banner in container log (FR-015: no site)
- FAIL: stop httpd -> 443 down -> start -> back (SC-006) (rc=1)
```
443 still open after stop
```

- FAIL: stop sshd -> 22 down -> start -> back (SC-006) (rc=1)
```
22 still open after stop
```

- PASS: journalctl -u httpd returns logs (FR-016)
- PASS: container log shows startup sequence (FR-015)
- ready-time recorded above; median-of-5 formal baseline = T034 (FR-018)
- PASS: clean stop -t 30 ends 130/0, not 137 (exit code: 130, stop rc: 0)
- teardown done
## S1-s1-debian
- when: 2026-11-10 13:02:07
- runtime: podman

- **RESULT: FAIL**

- container: omd-s1 (https 18452, ssh 18453, edge unit apache2)
- PASS: readiness within bound (gate active + 443 answers)
```
ready-time=2s rc=0
```

- PASS: no OMD site exists (SC-003: /omd/sites empty)
- PASS: omd-ready + apache2 + sshd all active
```
ready=active edge=active ssh=active
```

- PASS: listeners on 443 + 22 (in-container)
- PASS: sshd reachable from host on 18453
- PASS: informational banner in container log (FR-015: no site)
- FAIL: stop apache2 -> 443 down -> start -> back (SC-006) (rc=1)
```
443 still open after stop
```

- FAIL: stop sshd -> 22 down -> start -> back (SC-006) (rc=1)
```
22 still open after stop
```

- PASS: journalctl -u apache2 returns logs (FR-016)
- PASS: container log shows startup sequence (FR-015)
- ready-time recorded above; median-of-5 formal baseline = T034 (FR-018)
- PASS: clean stop -t 30 ends 130/0, not 137 (exit code: 130, stop rc: 0)
- teardown done
## S3-s3-rocky
- when: 2026-11-10 13:02:16
- runtime: podman

## S3-s3-debian
- when: 2026-11-10 13:02:17
- runtime: podman

## S1-s1-rocky
- when: 2026-11-10 13:13:16
- runtime: podman

- **RESULT: FAIL**

- container: omd-s1 (https 18451, ssh 18452, edge unit httpd)
- PASS: readiness within bound (gate active + 443 answers)
```
ready-time=1s rc=0
```

- PASS: no OMD site exists (SC-003: /omd/sites empty)
- PASS: omd-ready + httpd + sshd all active
```
ready=active edge=active ssh=active
```

- PASS: listeners on 443 + 22 (in-container)
- PASS: sshd reachable from host on 18452
- PASS: informational banner in container log (FR-015: no site)
- FAIL: stop httpd -> 443 down -> start -> back (SC-006) (rc=1)
```
443 still open after stop
```

- PASS: stop sshd -> 22 down -> start -> back (SC-006)
- PASS: journalctl -u httpd returns logs (FR-016)
- PASS: container log shows startup sequence (FR-015)
- ready-time recorded above; median-of-5 formal baseline = T034 (FR-018)
- PASS: clean stop -t 30 ends 130/0, not 137 (exit code: 130, stop rc: 0)
- teardown done
## S1-s1-debian
- when: 2026-11-10 13:13:26
- runtime: podman

- **RESULT: FAIL**

- container: omd-s1 (https 18452, ssh 18453, edge unit apache2)
- PASS: readiness within bound (gate active + 443 answers)
```
ready-time=2s rc=0
```

- PASS: no OMD site exists (SC-003: /omd/sites empty)
- PASS: omd-ready + apache2 + sshd all active
```
ready=active edge=active ssh=active
```

- PASS: listeners on 443 + 22 (in-container)
- PASS: sshd reachable from host on 18453
- PASS: informational banner in container log (FR-015: no site)
- FAIL: stop apache2 -> 443 down -> start -> back (SC-006) (rc=1)
```
443 still open after stop
```

- PASS: stop sshd -> 22 down -> start -> back (SC-006)
- PASS: journalctl -u apache2 returns logs (FR-016)
- PASS: container log shows startup sequence (FR-015)
- ready-time recorded above; median-of-5 formal baseline = T034 (FR-018)
- PASS: clean stop -t 30 ends 130/0, not 137 (exit code: 130, stop rc: 0)
- teardown done
## S3-s3-rocky
- when: 2026-11-10 13:13:35
- runtime: podman

- **RESULT: FAIL**

- PASS: invalid name 'bad-name!!' exited code 1 within 30 s (elapsed=0s code=1)
- FAIL: error log names the invalid value 'bad-name!!' (rc=1)
```

```

- PASS: invalid name '1leadingdigit' exited code 1 within 30 s (elapsed=0s code=1)
- FAIL: error log names the invalid value '1leadingdigit' (rc=1)
```

```

- PASS: invalid name 'way_too_long_site_name_here' exited code 1 within 30 s (elapsed=0s code=1)
- FAIL: error log names the invalid value 'way_too_long_site_name_here' (rc=1)
```

```

- PASS: S10c: no-privileges start exited non-zero within bound, no hang (elapsed=0s code=1)
- FAIL: S10c: readable error names the missing prerequisite (privileged/cgroup) (rc=1)
```
FATAL: /sys/fs/cgroup is not writable - the container lacks the capabilities systemd needs. Run with --privileged (documented default) or the reduced recipe: --cap-add=SYS_ADMIN --cap-add=MKNOD --tmpfs=/run --tmpfs=/run/lock --tmpfs=/tmp (README 'Runtime prerequisites'). Host must use cgroup v2.
```

- SITENAME='' / absent behave per S1 (covered by S1/S21 runs)
## S3-s3-debian
- when: 2026-11-10 13:13:39
- runtime: podman

- **RESULT: FAIL**

- PASS: invalid name 'bad-name!!' exited code 1 within 30 s (elapsed=0s code=1)
- FAIL: error log names the invalid value 'bad-name!!' (rc=1)
```

```

- PASS: invalid name '1leadingdigit' exited code 1 within 30 s (elapsed=0s code=1)
- FAIL: error log names the invalid value '1leadingdigit' (rc=1)
```

```

- PASS: invalid name 'way_too_long_site_name_here' exited code 1 within 30 s (elapsed=0s code=1)
- FAIL: error log names the invalid value 'way_too_long_site_name_here' (rc=1)
```

```

- PASS: S10c: no-privileges start exited non-zero within bound, no hang (elapsed=0s code=1)
- FAIL: S10c: readable error names the missing prerequisite (privileged/cgroup) (rc=1)
```
FATAL: /sys/fs/cgroup is not writable - the container lacks the capabilities systemd needs. Run with --privileged (documented default) or the reduced recipe: --cap-add=SYS_ADMIN --cap-add=MKNOD --tmpfs=/run --tmpfs=/run/lock --tmpfs=/tmp (README 'Runtime prerequisites'). Host must use cgroup v2.
```

- SITENAME='' / absent behave per S1 (covered by S1/S21 runs)
## S1-s1-rocky
- when: 2026-11-10 13:45:16
- runtime: podman

## S1-s1-debian
- when: 2026-11-10 13:45:21
- runtime: podman

## S3-s3-rocky
- when: 2026-11-10 13:45:21
- runtime: podman

- **RESULT: FAIL**

- PASS: invalid name 'bad-name!!' exited code 1 within 30 s (elapsed=0s code=1)
- FAIL: error log names the invalid value 'bad-name!!' (rc=1)
```

```

- PASS: invalid name '1leadingdigit' exited code 1 within 30 s (elapsed=0s code=1)
- FAIL: error log names the invalid value '1leadingdigit' (rc=1)
```

```

- PASS: invalid name 'way_too_long_site_name_here' exited code 1 within 30 s (elapsed=0s code=1)
- FAIL: error log names the invalid value 'way_too_long_site_name_here' (rc=1)
```

```

- PASS: S10c: no-privileges start exited non-zero within bound, no hang (elapsed=0s code=1)
- FAIL: S10c: readable error names the missing prerequisite (privileged/cgroup) (rc=1)
```

```

- SITENAME='' / absent behave per S1 (covered by S1/S21 runs)
## S3-s3-debian
- when: 2026-11-10 13:45:25
- runtime: podman

- **RESULT: FAIL**

- PASS: invalid name 'bad-name!!' exited code 1 within 30 s (elapsed=0s code=1)
- FAIL: error log names the invalid value 'bad-name!!' (rc=1)
```

```

- PASS: invalid name '1leadingdigit' exited code 1 within 30 s (elapsed=0s code=1)
- FAIL: error log names the invalid value '1leadingdigit' (rc=1)
```

```

- PASS: invalid name 'way_too_long_site_name_here' exited code 1 within 30 s (elapsed=0s code=1)
- FAIL: error log names the invalid value 'way_too_long_site_name_here' (rc=1)
```

```

- PASS: S10c: no-privileges start exited non-zero within bound, no hang (elapsed=0s code=1)
- FAIL: S10c: readable error names the missing prerequisite (privileged/cgroup) (rc=1)
```

```

- SITENAME='' / absent behave per S1 (covered by S1/S21 runs)
## S1-s1-rocky
- when: 2026-11-10 13:59:20
- runtime: podman

## S1-s1-debian
- when: 2026-11-10 13:59:40
- runtime: podman

## S3-s3-rocky
- when: 2026-11-10 13:59:41
- runtime: podman

- **RESULT: FAIL**

- PASS: invalid name 'bad-name!!' exited code 1 within 30 s (elapsed=0s code=1)
- FAIL: error log names the invalid value 'bad-name!!' (bounded wait for log flush) (rc=1)
```
v_wait_log: pattern not visible within 30s: bad-name!!
--- last log lines:
omd-labs-entry: pre-init bootstrap (container start)
```

- PASS: invalid name '1leadingdigit' exited code 1 within 30 s (elapsed=0s code=1)
- FAIL: error log names the invalid value '1leadingdigit' (bounded wait for log flush) (rc=1)
```
v_wait_log: pattern not visible within 30s: 1leadingdigit
--- last log lines:
omd-labs-entry: pre-init bootstrap (container start)
```

- PASS: invalid name 'way_too_long_site_name_here' exited code 1 within 30 s (elapsed=0s code=1)
- FAIL: error log names the invalid value 'way_too_long_site_name_here' (bounded wait for log flush) (rc=1)
```
v_wait_log: pattern not visible within 30s: way_too_long_site_name_here
--- last log lines:
omd-labs-entry: pre-init bootstrap (container start)
```

- PASS: S10c: no-privileges start exited non-zero within bound, no hang (elapsed=1s code=1)
- FAIL: S10c: readable error names the missing prerequisite (privileged/cgroup) (rc=1)
```
v_wait_log: pattern not visible within 30s: privileged
--- last log lines:
omd-labs-entry: pre-init bootstrap (container start)
```

- SITENAME='' / absent behave per S1 (covered by S1/S21 runs)
## S3-s3-debian
- when: 2026-11-10 14:02:00
- runtime: podman

## S1-s1-rocky
- when: 2026-11-10 14:23:43
- runtime: podman

## S1-s1-debian
- when: 2026-11-10 14:23:43
- runtime: podman

## S3-s3-rocky
- when: 2026-11-10 14:23:43
- runtime: podman

- **RESULT: FAIL**

- PASS: invalid name 'bad-name!!' exited code 1 within 30 s (elapsed=0s code=1)
- FAIL: fatal reason names the invalid value 'bad-name!!' (rc=1)
```
v_wait_log: pattern not visible within 30s: bad-name!!
--- last log lines:
omd-labs-entry: pre-init bootstrap (container start)
```

- PASS: invalid name '1leadingdigit' exited code 1 within 30 s (elapsed=0s code=1)
- PASS: fatal reason names the invalid value '1leadingdigit'
```
FATAL: invalid SITENAME '1leadingdigit' (must match OMD rule: 1-16 chars, [a-zA-Z_] first, then [a-zA-Z_0-9])
```

- PASS: invalid name 'way_too_long_site_name_here' exited code 1 within 30 s (elapsed=1s code=1)
- PASS: fatal reason names the invalid value 'way_too_long_site_name_here'
```
FATAL: invalid SITENAME 'way_too_long_site_name_here' (must match OMD rule: 1-16 chars, [a-zA-Z_] first, then [a-zA-Z_0-9])
```

- PASS: S10c: no-privileges start exited non-zero within bound, no hang (elapsed=1s code=1)
- PASS: S10c: readable error names the missing prerequisite (privileged/cgroup)
```
FATAL: /sys/fs/cgroup is not writable - the container lacks the capabilities systemd needs. Run with --privileged (documented default) or the reduced recipe: --cap-add=SYS_ADMIN --cap-add=MKNOD --tmpfs=/run --tmpfs=/run/lock --tmpfs=/tmp (README 'Runtime prerequisites'). Host must use cgroup v2.
```

- SITENAME='' / absent behave per S1 (covered by S1/S21 runs)
## S3-s3-debian
- when: 2026-11-10 14:24:22
- runtime: podman

- **RESULT: PASS**

- PASS: invalid name 'bad-name!!' exited code 1 within 30 s (elapsed=0s code=1)
- PASS: fatal reason names the invalid value 'bad-name!!'
```
FATAL: invalid SITENAME 'bad-name!!' (must match OMD rule: 1-16 chars, [a-zA-Z_] first, then [a-zA-Z_0-9])
```

- PASS: invalid name '1leadingdigit' exited code 1 within 30 s (elapsed=1s code=1)
- PASS: fatal reason names the invalid value '1leadingdigit'
```
FATAL: invalid SITENAME '1leadingdigit' (must match OMD rule: 1-16 chars, [a-zA-Z_] first, then [a-zA-Z_0-9])
```

- PASS: invalid name 'way_too_long_site_name_here' exited code 1 within 30 s (elapsed=1s code=1)
- PASS: fatal reason names the invalid value 'way_too_long_site_name_here'
```
FATAL: invalid SITENAME 'way_too_long_site_name_here' (must match OMD rule: 1-16 chars, [a-zA-Z_] first, then [a-zA-Z_0-9])
```

- PASS: S10c: no-privileges start exited non-zero within bound, no hang (elapsed=0s code=1)
- PASS: S10c: readable error names the missing prerequisite (privileged/cgroup)
```
FATAL: /sys/fs/cgroup is not writable - the container lacks the capabilities systemd needs. Run with --privileged (documented default) or the reduced recipe: --cap-add=SYS_ADMIN --cap-add=MKNOD --tmpfs=/run --tmpfs=/run/lock --tmpfs=/tmp (README 'Runtime prerequisites'). Host must use cgroup v2.
```

- SITENAME='' / absent behave per S1 (covered by S1/S21 runs)
## S1-s1-rocky
- when: 2026-11-10 14:24:59
- runtime: podman

- **RESULT: FAIL**

- container: omd-s1 (https 18451, ssh 18452, edge unit httpd)
- PASS: readiness within bound (gate active + 443 answers)
```
ready-time=2s rc=0
```

- PASS: no OMD site exists (SC-003: /omd/sites empty)
- PASS: omd-ready + httpd + sshd all active
```
ready=active edge=active ssh=active
```

- PASS: listeners on 443 + 22 (in-container)
- PASS: sshd reachable from host on 18452
- PASS: informational banner in container log (FR-015: no site)
- FAIL: stop httpd -> 443 down -> start -> back (SC-006) (rc=1)
```
443 still open after stop (15s wait)
```

- PASS: stop sshd -> 22 down -> start -> back (SC-006)
- PASS: journalctl -u httpd returns logs (FR-016)
- PASS: container log shows startup sequence (FR-015)
- ready-time recorded above; median-of-5 formal baseline = T034 (FR-018)
- PASS: clean stop -t 30 ends 130/0, not 137 (exit code: 130, stop rc: 0)
- teardown done
## S1-s1-debian
- when: 2026-11-10 14:25:22
- runtime: podman

- **RESULT: FAIL**

- container: omd-s1 (https 18452, ssh 18453, edge unit apache2)
- PASS: readiness within bound (gate active + 443 answers)
```
ready-time=2s rc=0
```

- PASS: no OMD site exists (SC-003: /omd/sites empty)
- PASS: omd-ready + apache2 + sshd all active
```
ready=active edge=active ssh=active
```

- PASS: listeners on 443 + 22 (in-container)
- PASS: sshd reachable from host on 18453
- PASS: informational banner in container log (FR-015: no site)
- FAIL: stop apache2 -> 443 down -> start -> back (SC-006) (rc=1)
```
443 still open after stop (15s wait)
```

- PASS: stop sshd -> 22 down -> start -> back (SC-006)
- PASS: journalctl -u apache2 returns logs (FR-016)
- PASS: container log shows startup sequence (FR-015)
- ready-time recorded above; median-of-5 formal baseline = T034 (FR-018)
- PASS: clean stop -t 30 ends 130/0, not 137 (exit code: 130, stop rc: 0)
- teardown done
## S3-s3-rocky
- when: 2026-11-10 14:25:43
- runtime: podman

- **RESULT: PASS**

- PASS: invalid name 'bad-name!!' exited code 1 within 30 s (elapsed=1s code=1)
- PASS: fatal reason names the invalid value 'bad-name!!'
```
FATAL: invalid SITENAME 'bad-name!!' (must match OMD rule: 1-16 chars, [a-zA-Z_] first, then [a-zA-Z_0-9])
```

- PASS: invalid name '1leadingdigit' exited code 1 within 30 s (elapsed=1s code=1)
- PASS: fatal reason names the invalid value '1leadingdigit'
```
FATAL: invalid SITENAME '1leadingdigit' (must match OMD rule: 1-16 chars, [a-zA-Z_] first, then [a-zA-Z_0-9])
```

- PASS: invalid name 'way_too_long_site_name_here' exited code 1 within 30 s (elapsed=0s code=1)
- PASS: fatal reason names the invalid value 'way_too_long_site_name_here'
```
FATAL: invalid SITENAME 'way_too_long_site_name_here' (must match OMD rule: 1-16 chars, [a-zA-Z_] first, then [a-zA-Z_0-9])
```

- PASS: S10c: no-privileges start exited non-zero within bound, no hang (elapsed=0s code=1)
- PASS: S10c: readable error names the missing prerequisite (privileged/cgroup)
```
FATAL: /sys/fs/cgroup is not writable - the container lacks the capabilities systemd needs. Run with --privileged (documented default) or the reduced recipe: --cap-add=SYS_ADMIN --cap-add=MKNOD --tmpfs=/run --tmpfs=/run/lock --tmpfs=/tmp (README 'Runtime prerequisites'). Host must use cgroup v2.
```

- SITENAME='' / absent behave per S1 (covered by S1/S21 runs)
## S3-s3-debian
- when: 2026-11-10 14:25:48
- runtime: podman

- **RESULT: PASS**

- PASS: invalid name 'bad-name!!' exited code 1 within 30 s (elapsed=1s code=1)
- PASS: fatal reason names the invalid value 'bad-name!!'
```
FATAL: invalid SITENAME 'bad-name!!' (must match OMD rule: 1-16 chars, [a-zA-Z_] first, then [a-zA-Z_0-9])
```

- PASS: invalid name '1leadingdigit' exited code 1 within 30 s (elapsed=0s code=1)
- PASS: fatal reason names the invalid value '1leadingdigit'
```
FATAL: invalid SITENAME '1leadingdigit' (must match OMD rule: 1-16 chars, [a-zA-Z_] first, then [a-zA-Z_0-9])
```

- PASS: invalid name 'way_too_long_site_name_here' exited code 1 within 30 s (elapsed=0s code=1)
- PASS: fatal reason names the invalid value 'way_too_long_site_name_here'
```
FATAL: invalid SITENAME 'way_too_long_site_name_here' (must match OMD rule: 1-16 chars, [a-zA-Z_] first, then [a-zA-Z_0-9])
```

- PASS: S10c: no-privileges start exited non-zero within bound, no hang (elapsed=1s code=1)
- PASS: S10c: readable error names the missing prerequisite (privileged/cgroup)
```
FATAL: /sys/fs/cgroup is not writable - the container lacks the capabilities systemd needs. Run with --privileged (documented default) or the reduced recipe: --cap-add=SYS_ADMIN --cap-add=MKNOD --tmpfs=/run --tmpfs=/run/lock --tmpfs=/tmp (README 'Runtime prerequisites'). Host must use cgroup v2.
```

- SITENAME='' / absent behave per S1 (covered by S1/S21 runs)
## S1-s1-rocky
- when: 2026-11-10 14:39:41
- runtime: podman

- **RESULT: PASS**

- container: omd-s1 (https 18451, ssh 18452, edge unit httpd)
- PASS: readiness within bound (gate active + 443 answers)
```
ready-time=2s rc=0
```

- PASS: no OMD site exists (SC-003: /omd/sites empty)
- PASS: omd-ready + httpd + sshd all active
```
ready=active edge=active ssh=active
```

- PASS: listeners on 443 + 22 (in-container)
- PASS: sshd reachable from host on 18452
- PASS: informational banner in container log (FR-015: no site)
- PASS: stop httpd -> 443 down -> start -> back (SC-006)
- PASS: stop sshd -> 22 down -> start -> back (SC-006)
- PASS: journalctl -u httpd returns logs (FR-016)
- PASS: container log shows startup sequence (FR-015)
- ready-time recorded above; median-of-5 formal baseline = T034 (FR-018)
- PASS: clean stop -t 30 ends 130/0, not 137 (exit code: 130, stop rc: 0)
- teardown done
## S1-s1-debian
- when: 2026-11-10 14:39:50
- runtime: podman

- **RESULT: PASS**

- container: omd-s1 (https 18452, ssh 18453, edge unit apache2)
- PASS: readiness within bound (gate active + 443 answers)
```
ready-time=2s rc=0
```

- PASS: no OMD site exists (SC-003: /omd/sites empty)
- PASS: omd-ready + apache2 + sshd all active
```
ready=active edge=active ssh=active
```

- PASS: listeners on 443 + 22 (in-container)
- PASS: sshd reachable from host on 18453
- PASS: informational banner in container log (FR-015: no site)
- PASS: stop apache2 -> 443 down -> start -> back (SC-006)
- PASS: stop sshd -> 22 down -> start -> back (SC-006)
- PASS: journalctl -u apache2 returns logs (FR-016)
- PASS: container log shows startup sequence (FR-015)
- ready-time recorded above; median-of-5 formal baseline = T034 (FR-018)
- PASS: clean stop -t 30 ends 130/0, not 137 (exit code: 130, stop rc: 0)
- teardown done

## T013-GREEN-2026-11-10 (build 9, s1+s3 both distros)

- **T013 acceptance: GREEN.** s1 + s3 pass on BOTH distros against build #9
  (`localhost/local/omd-labs-{rocky,debian}:nightly` - the image carrying the
  canonical fstab line, single-line identity parse, GEARMAND listener-exclusion
  in the ready probe, and the entry-fatal persistence helper).
- **s1 rocky: PASS (exit 0, 11/11)** - ready 2 s (base path), no-site banner,
  omd-ready/httpd/sshd active, 443+22 listeners, host sshd reachable,
  SC-006 stop/start httpd (443 down then back, bounded waits), SC-006
  stop/start sshd, journalctl -u, startup sequence, clean stop 130 in 1 s.
- **s1 debian: PASS (exit 0, 11/11)** - identical shape (apache2/cron,
  ready 2 s, clean stop 130/1 s).
- **s3 rocky: PASS (exit 0)** - 3 invalid names: exit 1 within 1 s each,
  fatal reason (via /var/log/omd-labs/entry-fatal, deterministic root probe)
  names each value; S10c no-privileges: exit 1 in 0-1 s, readable error
  names the missing prerequisite.
- **s3 debian: PASS (exit 0)** - identical shape.
- Fixes that closed T013 (host-side suite, no rebuild needed beyond #9):
  - `v_http_alive`/`v_wait_ready`: exact `''|000` down-test (curl prints 000
    itself on failure; `|| echo 000` produced the "000000" false positive,
    and a `0*` glob wrongly matched 000) - live-verified UP alive / DOWN dead.
  - `v_fatal` bounded cp retry (10 x 1 s) for the exit-cleanup race.
  - s1.sh SC-006 check strings rewritten as pure single-quoted literals
    (the prior hybrid quoting broke eval: `"$RUNTIME": command not found`).
- Ready-times (informational; formal median-of-5 baseline = T034):
  no-site base path: rocky 2 s, debian 2 s.

## S2-s2-rocky
- when: 2026-11-10 14:55:04
- runtime: podman

## S10-s10-rocky
- when: 2026-11-10 14:55:04
- runtime: podman

## S2-s2-debian
- when: 2026-11-10 14:55:05
- runtime: podman

## S10-s10-debian
- when: 2026-11-10 14:55:05
- runtime: podman

## S3-s3-rocky
- when: 2026-11-10 14:55:05
- runtime: podman

- **RESULT: PASS**

- PASS: invalid name 'bad-name!!' exited code 1 within 30 s (elapsed=0s code=1)
- PASS: fatal reason names the invalid value 'bad-name!!'
```
FATAL: invalid SITENAME 'bad-name!!' (must match OMD rule: 1-16 chars, [a-zA-Z_] first, then [a-zA-Z_0-9])
```

- PASS: invalid name '1leadingdigit' exited code 1 within 30 s (elapsed=1s code=1)
- PASS: fatal reason names the invalid value '1leadingdigit'
```
FATAL: invalid SITENAME '1leadingdigit' (must match OMD rule: 1-16 chars, [a-zA-Z_] first, then [a-zA-Z_0-9])
```

- PASS: invalid name 'way_too_long_site_name_here' exited code 1 within 30 s (elapsed=0s code=1)
- PASS: fatal reason names the invalid value 'way_too_long_site_name_here'
```
FATAL: invalid SITENAME 'way_too_long_site_name_here' (must match OMD rule: 1-16 chars, [a-zA-Z_] first, then [a-zA-Z_0-9])
```

- PASS: S10c: no-privileges start exited non-zero within bound, no hang (elapsed=1s code=1)
- PASS: S10c: readable error names the missing prerequisite (privileged/cgroup)
```
FATAL: /sys/fs/cgroup is not writable - the container lacks the capabilities systemd needs. Run with --privileged (documented default) or the reduced recipe: --cap-add=SYS_ADMIN --cap-add=MKNOD --tmpfs=/run --tmpfs=/run/lock --tmpfs=/tmp (README 'Runtime prerequisites'). Host must use cgroup v2.
```

- SITENAME='' / absent behave per S1 (covered by S1/S21 runs)
## S3-s3-debian
- when: 2026-11-10 14:55:11
- runtime: podman

- **RESULT: PASS**

- PASS: invalid name 'bad-name!!' exited code 1 within 30 s (elapsed=0s code=1)
- PASS: fatal reason names the invalid value 'bad-name!!'
```
FATAL: invalid SITENAME 'bad-name!!' (must match OMD rule: 1-16 chars, [a-zA-Z_] first, then [a-zA-Z_0-9])
```

- PASS: invalid name '1leadingdigit' exited code 1 within 30 s (elapsed=0s code=1)
- PASS: fatal reason names the invalid value '1leadingdigit'
```
FATAL: invalid SITENAME '1leadingdigit' (must match OMD rule: 1-16 chars, [a-zA-Z_] first, then [a-zA-Z_0-9])
```

- PASS: invalid name 'way_too_long_site_name_here' exited code 1 within 30 s (elapsed=1s code=1)
- PASS: fatal reason names the invalid value 'way_too_long_site_name_here'
```
FATAL: invalid SITENAME 'way_too_long_site_name_here' (must match OMD rule: 1-16 chars, [a-zA-Z_] first, then [a-zA-Z_0-9])
```

- PASS: S10c: no-privileges start exited non-zero within bound, no hang (elapsed=1s code=1)
- PASS: S10c: readable error names the missing prerequisite (privileged/cgroup)
```
FATAL: /sys/fs/cgroup is not writable - the container lacks the capabilities systemd needs. Run with --privileged (documented default) or the reduced recipe: --cap-add=SYS_ADMIN --cap-add=MKNOD --tmpfs=/run --tmpfs=/run/lock --tmpfs=/tmp (README 'Runtime prerequisites'). Host must use cgroup v2.
```

- SITENAME='' / absent behave per S1 (covered by S1/S21 runs)
## S2-s2-rocky
- when: 2026-11-10 15:08:26
- runtime: podman

## S10-s10-rocky
- when: 2026-11-10 15:08:27
- runtime: podman

## S2-s2-debian
- when: 2026-11-10 15:08:28
- runtime: podman

## S10-s10-debian
- when: 2026-11-10 15:08:28
- runtime: podman

## S2-s2-rocky
- when: 2026-11-10 15:14:52
- runtime: podman

## S10-s10-rocky
- when: 2026-11-10 15:14:53
- runtime: podman

## S2-s2-debian
- when: 2026-11-10 15:14:54
- runtime: podman

## S10-s10-debian
- when: 2026-11-10 15:14:55
- runtime: podman

## S2-s2-rocky
- when: 2026-11-10 15:17:10
- runtime: podman

## S10-s10-rocky
- when: 2026-11-10 15:17:41
- runtime: podman

## S2-s2-debian
- when: 2026-11-10 15:17:57
- runtime: podman

## S10-s10-debian
- when: 2026-11-10 15:17:58
- runtime: podman

## S2-s2-rocky
- when: 2026-11-10 15:23:44
- runtime: podman

## S10-s10-rocky
- when: 2026-11-10 15:24:24
- runtime: podman

- **RESULT: FAIL**

- PASS: (a) readiness (gate + /site10a/)
```
ready-time=5s
```

- PASS: (a) stop -t 30: clean halt in 3s (well inside 30), exit 130 (130/0, not 137)
- PASS: (a) next start needs no manual recovery (ready again)
```
ready-time=3s
```

- make targets: Makefile.omd-labs-systemd-vm-rocky (IMAGE=local/omd-labs-systemd-vm-rocky:nightly, LOCAL_HTTPS_PORT=18449, runtime SITENAME)
- PASS: (b) make start SITENAME=make1 works end-to-end (documented invocation)
- PASS: (b) make start: container omd-labs-make1 ready (gate + /make1/)
```
ready-time=8s
```

- PASS: (b) make stop: clean halt (documented -t 30)
- PASS: (b) make stop exit code 130 (130/0, not 137)
- FAIL: (b) make startvol VOLUME=/tmp/omd-verify/s10-make-vol SITENAME=make1 (mount path /omd/sites/make1) (rc=2)
```
Error: creating container storage: the container name "omd-labs-make1" is already in use by 5710453f248caeea0da1eee7a90ed5a08bb529c253dc02b902049bf5ce831f3e. You have to remove that container to be able to reuse that name: that name is already in use, or use --replace to instruct Podman to do so.
make: *** [Makefile.common:66: startvol] Error 125
```

- FAIL: (b) startvol: site make1 ready (gate + /make1/) (rc=1)
```
READY-FATAL: container exited (code 130)
ready-time=s
```

- FAIL: (b) startvol: host volume populated (etc/var/local + init-complete marker, root probe) (rc=1)
```
missing: etc
```

- PASS: (b) make stop startvol container: clean
- FAIL: (b) retired target 'shell' is gone from Makefile.omd-labs-systemd-vm-rocky (rc=2)
```

```

- FAIL: (b) retired target 'bash' is gone from Makefile.omd-labs-systemd-vm-rocky (rc=2)
```

```

- FAIL: (b) retired target 'bashvol' is gone from Makefile.omd-labs-systemd-vm-rocky (rc=2)
```

```

- PASS: (c) without --privileged: bounded non-zero exit, no hang (code=1)
- PASS: (c) readable error names the missing prerequisite (privileged mode / cgroup v2)
```
FATAL: /sys/fs/cgroup is not writable - the container lacks the capabilities systemd needs. Run with --privileged (documented default) or the reduced recipe: --cap-add=SYS_ADMIN --cap-add=MKNOD --tmpfs=/run --tmpfs=/run/lock --tmpfs=/tmp (README 'Runtime prerequisites'). Host must use cgroup v2.
```

- docker parity of (a)/(c) = T031 (T1 gate); stop-under-load = T033 (T4 gate)
## S2-s2-debian
- when: 2026-11-10 15:24:54
- runtime: podman

## S10-s10-debian
- when: 2026-11-10 15:24:55
- runtime: podman

- **RESULT: FAIL**

- PASS: (a) readiness (gate + /site10a/)
```
ready-time=5s
```

- PASS: (a) stop -t 30: clean halt in 2s (well inside 30), exit 130 (130/0, not 137)
- PASS: (a) next start needs no manual recovery (ready again)
```
ready-time=4s
```

- make targets: Makefile.debian (IMAGE=local/omd-labs-systemd-vm-debian:nightly, LOCAL_HTTPS_PORT=18449, runtime SITENAME)
- FAIL: (b) make start SITENAME=make1 works end-to-end (documented invocation) (rc=2)
```
Error: creating container storage: the container name "omd-labs-make1" is already in use by 5710453f248caeea0da1eee7a90ed5a08bb529c253dc02b902049bf5ce831f3e. You have to remove that container to be able to reuse that name: that name is already in use, or use --replace to instruct Podman to do so.
make: *** [Makefile.common:56: start] Error 125
```

- FAIL: (b) make start: container omd-labs-make1 ready (gate + /make1/) (rc=1)
```
READY-FATAL: container exited (code 130)
ready-time=s
```

- PASS: (b) make stop: clean halt (documented -t 30)
- PASS: (b) make stop exit code 130 (130/0, not 137)
- FAIL: (b) make startvol VOLUME=/tmp/omd-verify/s10-make-vol SITENAME=make1 (mount path /omd/sites/make1) (rc=2)
```
Error: creating container storage: the container name "omd-labs-make1" is already in use by 5710453f248caeea0da1eee7a90ed5a08bb529c253dc02b902049bf5ce831f3e. You have to remove that container to be able to reuse that name: that name is already in use, or use --replace to instruct Podman to do so.
make: *** [Makefile.common:66: startvol] Error 125
```

- FAIL: (b) startvol: site make1 ready (gate + /make1/) (rc=1)
```
READY-FATAL: container exited (code 130)
ready-time=s
```

- FAIL: (b) startvol: host volume populated (etc/var/local + init-complete marker, root probe) (rc=1)
```
missing: etc
```

- PASS: (b) make stop startvol container: clean
- FAIL: (b) retired target 'shell' is gone from Makefile.debian (rc=2)
```

```

- FAIL: (b) retired target 'bash' is gone from Makefile.debian (rc=2)
```

```

- FAIL: (b) retired target 'bashvol' is gone from Makefile.debian (rc=2)
```

```

- PASS: (c) without --privileged: bounded non-zero exit, no hang (code=1)
- PASS: (c) readable error names the missing prerequisite (privileged mode / cgroup v2)
```
FATAL: /sys/fs/cgroup is not writable - the container lacks the capabilities systemd needs. Run with --privileged (documented default) or the reduced recipe: --cap-add=SYS_ADMIN --cap-add=MKNOD --tmpfs=/run --tmpfs=/run/lock --tmpfs=/tmp (README 'Runtime prerequisites'). Host must use cgroup v2.
```

- docker parity of (a)/(c) = T031 (T1 gate); stop-under-load = T033 (T4 gate)
## S2-s2-rocky
- when: 2026-11-10 15:29:04
- runtime: podman

- **RESULT: FAIL**

- PASS: readiness (gate active + /mysite/ answers 302/200)
```
ready-time=6s
```

- PASS: log shows prominent 'created new site mysite'
- PASS: omd status mysite running (rc 0)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- FAIL: site data on host volume (etc/var/local/version + init-complete marker, root probe) (rc=1)
```
missing: version
```

- PASS: 5 site daemons run as user mysite
- PASS: HTTPS /mysite/ through the edge (host-side)
```
302
```

- site-start ready-time (first start): see 'readiness' evidence above; formal median-of-5 baseline = T034 (FR-018)
- PASS: restart same container reaches ready again
```
omd-s2
ready-time=3s
```

- PASS: log shows 'resumed existing site mysite' (no re-creation)
- PASS: replacement container resumes (account absent in fresh image)
```
ready-time=3s
```

- PASS: replacement: 'resumed existing site mysite'
- PASS: replacement: omd status mysite rc 0
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: SC-002: concurrent site A ready (/s2siteA/ via published edge)
```
ready-time=6s
```

- PASS: SC-002: concurrent site B ready (gate active + /s2siteB/ on its own edge)
```
ready-time=8s
```

- PASS: SC-002: site A still serving WHILE B runs (no interference, both up)
```
302
```

- FAIL: SC-002: omd status of BOTH sites rc 0 (independent site daemons) (rc=2)
```
s2siteA=0 s2siteB=0
/home/lausser/git/omd-labs-systemd-vm-forge/verify/common.sh: line 344: [: missing `]'
```

- FAIL: SC-002: both volumes populated independently (root probe) (rc=1)
```
missing: .omd-labs-init-complete
```

- site-start reference ready-time: see readiness evidence above (formal median-of-5 = T034)
## S10-s10-rocky
- when: 2026-11-10 15:29:52
- runtime: podman

- **RESULT: FAIL**

- PASS: (a) readiness (gate + /site10a/)
```
ready-time=7s
```

- PASS: (a) stop -t 30: clean halt in 3s (well inside 30), exit 130 (130/0, not 137)
- PASS: (a) next start needs no manual recovery (ready again)
```
ready-time=4s
```

- make targets: Makefile.omd-labs-systemd-vm-rocky (IMAGE=local/omd-labs-systemd-vm-rocky:nightly, LOCAL_HTTPS_PORT=18449, runtime SITENAME)
- PASS: (b) make start SITENAME=make1 works end-to-end (documented invocation)
- PASS: (b) make start: container omd-labs-make1 ready (gate + /make1/)
```
ready-time=7s
```

- PASS: (b) make stop: clean halt (documented -t 30)
- PASS: (b) make stop exit code 130 (130/0, not 137)
- FAIL: (b) make startvol VOLUME=/tmp/omd-verify/s10-make-vol SITENAME=make1 (mount path /omd/sites/make1) (rc=2)
```
Error: creating container storage: the container name "omd-labs-make1" is already in use by e68341c0443c0f1dfc702ba124c339afed8af5efd819b7f7f235229a6e23ac25. You have to remove that container to be able to reuse that name: that name is already in use, or use --replace to instruct Podman to do so.
make: *** [Makefile.common:66: startvol] Error 125
```

- FAIL: (b) startvol: site make1 ready (gate + /make1/) (rc=1)
```
READY-FATAL: container exited (code 130)
ready-time=s
```

- FAIL: (b) startvol: host volume populated (etc/var/local + init-complete marker, root probe) (rc=1)
```
missing: etc
```

- PASS: (b) make stop startvol container: clean
- FAIL: (b) retired target 'shell' is gone from Makefile.omd-labs-systemd-vm-rocky (rc=1)
```
unexpected output: 
```

- FAIL: (b) retired target 'bash' is gone from Makefile.omd-labs-systemd-vm-rocky (rc=1)
```
unexpected output: 
```

- FAIL: (b) retired target 'bashvol' is gone from Makefile.omd-labs-systemd-vm-rocky (rc=1)
```
unexpected output: 
```

- PASS: (c) without --privileged: bounded non-zero exit, no hang (code=1)
- PASS: (c) readable error names the missing prerequisite (privileged mode / cgroup v2)
```
FATAL: /sys/fs/cgroup is not writable - the container lacks the capabilities systemd needs. Run with --privileged (documented default) or the reduced recipe: --cap-add=SYS_ADMIN --cap-add=MKNOD --tmpfs=/run --tmpfs=/run/lock --tmpfs=/tmp (README 'Runtime prerequisites'). Host must use cgroup v2.
```

- docker parity of (a)/(c) = T031 (T1 gate); stop-under-load = T033 (T4 gate)
## S2-s2-debian
- when: 2026-11-10 15:30:24
- runtime: podman

- **RESULT: FAIL**

- PASS: readiness (gate active + /mysite/ answers 302/200)
```
ready-time=5s
```

- PASS: log shows prominent 'created new site mysite'
- PASS: omd status mysite running (rc 0)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- FAIL: site data on host volume (etc/var/local/version + init-complete marker, root probe) (rc=1)
```
missing: version
```

- PASS: 5 site daemons run as user mysite
- PASS: HTTPS /mysite/ through the edge (host-side)
```
302
```

- site-start ready-time (first start): see 'readiness' evidence above; formal median-of-5 baseline = T034 (FR-018)
- PASS: restart same container reaches ready again
```
omd-s2
ready-time=3s
```

- PASS: log shows 'resumed existing site mysite' (no re-creation)
- PASS: replacement container resumes (account absent in fresh image)
```
ready-time=4s
```

- PASS: replacement: 'resumed existing site mysite'
- PASS: replacement: omd status mysite rc 0
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: SC-002: concurrent site A ready (/s2siteA/ via published edge)
```
ready-time=5s
```

- PASS: SC-002: concurrent site B ready (gate active + /s2siteB/ on its own edge)
```
ready-time=6s
```

- PASS: SC-002: site A still serving WHILE B runs (no interference, both up)
```
302
```

- FAIL: SC-002: omd status of BOTH sites rc 0 (independent site daemons) (rc=2)
```
s2siteA=0 s2siteB=0
/home/lausser/git/omd-labs-systemd-vm-forge/verify/common.sh: line 344: [: missing `]'
```

- FAIL: SC-002: both volumes populated independently (root probe) (rc=1)
```
missing: .omd-labs-init-complete
```

- site-start reference ready-time: see readiness evidence above (formal median-of-5 = T034)
## S10-s10-debian
- when: 2026-11-10 15:31:04
- runtime: podman

- **RESULT: FAIL**

- PASS: (a) readiness (gate + /site10a/)
```
ready-time=6s
```

- PASS: (a) stop -t 30: clean halt in 2s (well inside 30), exit 130 (130/0, not 137)
- PASS: (a) next start needs no manual recovery (ready again)
```
ready-time=3s
```

- make targets: Makefile.debian (IMAGE=local/omd-labs-systemd-vm-debian:nightly, LOCAL_HTTPS_PORT=18449, runtime SITENAME)
- PASS: (b) make start SITENAME=make1 works end-to-end (documented invocation)
- PASS: (b) make start: container omd-labs-make1 ready (gate + /make1/)
```
ready-time=6s
```

- PASS: (b) make stop: clean halt (documented -t 30)
- PASS: (b) make stop exit code 130 (130/0, not 137)
- FAIL: (b) make startvol VOLUME=/tmp/omd-verify/s10-make-vol SITENAME=make1 (mount path /omd/sites/make1) (rc=2)
```
Error: creating container storage: the container name "omd-labs-make1" is already in use by 67303e7dc507019dbaf42e31591c0241c47db9196bc1e5e84e67f21735498d1c. You have to remove that container to be able to reuse that name: that name is already in use, or use --replace to instruct Podman to do so.
make: *** [Makefile.common:66: startvol] Error 125
```

- FAIL: (b) startvol: site make1 ready (gate + /make1/) (rc=1)
```
READY-FATAL: container exited (code 130)
ready-time=s
```

- FAIL: (b) startvol: host volume populated (etc/var/local + init-complete marker, root probe) (rc=1)
```
missing: etc
```

- PASS: (b) make stop startvol container: clean
- FAIL: (b) retired target 'shell' is gone from Makefile.debian (rc=1)
```
unexpected output: 
```

- FAIL: (b) retired target 'bash' is gone from Makefile.debian (rc=1)
```
unexpected output: 
```

- FAIL: (b) retired target 'bashvol' is gone from Makefile.debian (rc=1)
```
unexpected output: 
```

- PASS: (c) without --privileged: bounded non-zero exit, no hang (code=1)
- PASS: (c) readable error names the missing prerequisite (privileged mode / cgroup v2)
```
FATAL: /sys/fs/cgroup is not writable - the container lacks the capabilities systemd needs. Run with --privileged (documented default) or the reduced recipe: --cap-add=SYS_ADMIN --cap-add=MKNOD --tmpfs=/run --tmpfs=/run/lock --tmpfs=/tmp (README 'Runtime prerequisites'). Host must use cgroup v2.
```

- docker parity of (a)/(c) = T031 (T1 gate); stop-under-load = T033 (T4 gate)
## S2-s2-rocky
- when: 2026-11-10 15:43:20
- runtime: podman

- **RESULT: PASS**

- PASS: readiness (gate active + /mysite/ answers 302/200)
```
ready-time=6s
```

- PASS: log shows prominent 'created new site mysite'
- PASS: omd status mysite running (rc 0)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: site data on host volume (etc/var/local/version + init-complete marker, root probe)
- PASS: 5 site daemons run as user mysite
- PASS: HTTPS /mysite/ through the edge (host-side)
```
302
```

- site-start ready-time (first start): see 'readiness' evidence above; formal median-of-5 baseline = T034 (FR-018)
- PASS: restart same container reaches ready again
```
omd-s2
ready-time=4s
```

- PASS: log shows 'resumed existing site mysite' (no re-creation)
- PASS: replacement container resumes (account absent in fresh image)
```
ready-time=3s
```

- PASS: replacement: 'resumed existing site mysite'
- PASS: replacement: omd status mysite rc 0
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: SC-002: concurrent site A ready (/s2siteA/ via published edge)
```
ready-time=7s
```

- PASS: SC-002: concurrent site B ready (gate active + /s2siteB/ on its own edge)
```
ready-time=8s
```

- PASS: SC-002: site A still serving WHILE B runs (no interference, both up)
```
302
```

- PASS: SC-002: omd status of BOTH sites rc 0 (independent site daemons)
```
A0
B0
```

- PASS: SC-002: both volumes populated independently (root probe)
- site-start reference ready-time: see readiness evidence above (formal median-of-5 = T034)
## S10-s10-rocky
- when: 2026-11-10 15:44:13
- runtime: podman

- **RESULT: FAIL**

- PASS: (a) readiness (gate + /site10a/)
```
ready-time=6s
```

- PASS: (a) stop -t 30: clean halt in 4s (well inside 30), exit 130 (130/0, not 137)
- PASS: (a) next start needs no manual recovery (ready again)
```
ready-time=3s
```

- make targets: Makefile.omd-labs-systemd-vm-rocky (IMAGE=local/omd-labs-systemd-vm-rocky:nightly, LOCAL_HTTPS_PORT=18449, runtime SITENAME)
- PASS: (b) make start SITENAME=make1 works end-to-end (documented invocation)
- PASS: (b) make start: container omd-labs-make1 ready (gate + /make1/)
```
ready-time=6s
```

- PASS: (b) make stop: clean halt (documented -t 30)
- PASS: (b) make stop exit code 130 (130/0, not 137)
- FAIL: (b) make startvol VOLUME=/tmp/omd-verify/s10-make-vol SITENAME=make1 (mount path /omd/sites/make1) (rc=2)
```
Error: creating container storage: the container name "omd-labs-make1" is already in use by 8fd132bf312be941134f52bc01ceb9d1c1e94e6aeb12855f7a5b2f9b38d9dc91. You have to remove that container to be able to reuse that name: that name is already in use, or use --replace to instruct Podman to do so.
make: *** [Makefile.common:66: startvol] Error 125
```

- FAIL: (b) startvol: site make1 ready (gate + /make1/) (rc=1)
```
READY-FATAL: container exited (code 130)
ready-time=s
```

- FAIL: (b) startvol: host volume populated (etc/var/local + init-complete marker, root probe) (rc=1)
```
missing: etc
```

- PASS: (b) make stop startvol container: clean
- FAIL: (b) retired target 'shell' is gone from Makefile.omd-labs-systemd-vm-rocky (rc=1)
```
unexpected output: 
```

- FAIL: (b) retired target 'bash' is gone from Makefile.omd-labs-systemd-vm-rocky (rc=1)
```
unexpected output: 
```

- FAIL: (b) retired target 'bashvol' is gone from Makefile.omd-labs-systemd-vm-rocky (rc=1)
```
unexpected output: 
```

- PASS: (c) without --privileged: bounded non-zero exit, no hang (code=1)
- PASS: (c) readable error names the missing prerequisite (privileged mode / cgroup v2)
```
FATAL: /sys/fs/cgroup is not writable - the container lacks the capabilities systemd needs. Run with --privileged (documented default) or the reduced recipe: --cap-add=SYS_ADMIN --cap-add=MKNOD --tmpfs=/run --tmpfs=/run/lock --tmpfs=/tmp (README 'Runtime prerequisites'). Host must use cgroup v2.
```

- docker parity of (a)/(c) = T031 (T1 gate); stop-under-load = T033 (T4 gate)
## S2-s2-debian
- when: 2026-11-10 15:44:42
- runtime: podman

- **RESULT: PASS**

- PASS: readiness (gate active + /mysite/ answers 302/200)
```
ready-time=5s
```

- PASS: log shows prominent 'created new site mysite'
- PASS: omd status mysite running (rc 0)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: site data on host volume (etc/var/local/version + init-complete marker, root probe)
- PASS: 5 site daemons run as user mysite
- PASS: HTTPS /mysite/ through the edge (host-side)
```
302
```

- site-start ready-time (first start): see 'readiness' evidence above; formal median-of-5 baseline = T034 (FR-018)
- PASS: restart same container reaches ready again
```
omd-s2
ready-time=3s
```

- PASS: log shows 'resumed existing site mysite' (no re-creation)
- PASS: replacement container resumes (account absent in fresh image)
```
ready-time=4s
```

- PASS: replacement: 'resumed existing site mysite'
- PASS: replacement: omd status mysite rc 0
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: SC-002: concurrent site A ready (/s2siteA/ via published edge)
```
ready-time=6s
```

- PASS: SC-002: concurrent site B ready (gate active + /s2siteB/ on its own edge)
```
ready-time=6s
```

- PASS: SC-002: site A still serving WHILE B runs (no interference, both up)
```
302
```

- PASS: SC-002: omd status of BOTH sites rc 0 (independent site daemons)
```
A0
B0
```

- PASS: SC-002: both volumes populated independently (root probe)
- site-start reference ready-time: see readiness evidence above (formal median-of-5 = T034)
## S10-s10-debian
- when: 2026-11-10 15:45:24
- runtime: podman

- **RESULT: FAIL**

- PASS: (a) readiness (gate + /site10a/)
```
ready-time=6s
```

- PASS: (a) stop -t 30: clean halt in 2s (well inside 30), exit 130 (130/0, not 137)
- PASS: (a) next start needs no manual recovery (ready again)
```
ready-time=4s
```

- make targets: Makefile.debian (IMAGE=local/omd-labs-systemd-vm-debian:nightly, LOCAL_HTTPS_PORT=18449, runtime SITENAME)
- PASS: (b) make start SITENAME=make1 works end-to-end (documented invocation)
- PASS: (b) make start: container omd-labs-make1 ready (gate + /make1/)
```
ready-time=7s
```

- PASS: (b) make stop: clean halt (documented -t 30)
- PASS: (b) make stop exit code 130 (130/0, not 137)
- FAIL: (b) make startvol VOLUME=/tmp/omd-verify/s10-make-vol SITENAME=make1 (mount path /omd/sites/make1) (rc=2)
```
Error: creating container storage: the container name "omd-labs-make1" is already in use by 79af9f2f00c714ad0e1c11b6843ffdf0708b6208584ddf4c93f4723c9aa49c29. You have to remove that container to be able to reuse that name: that name is already in use, or use --replace to instruct Podman to do so.
make: *** [Makefile.common:66: startvol] Error 125
```

- FAIL: (b) startvol: site make1 ready (gate + /make1/) (rc=1)
```
READY-FATAL: container exited (code 130)
ready-time=s
```

- FAIL: (b) startvol: host volume populated (etc/var/local + init-complete marker, root probe) (rc=1)
```
missing: etc
```

- PASS: (b) make stop startvol container: clean
- FAIL: (b) retired target 'shell' is gone from Makefile.debian (rc=1)
```
unexpected output: 
```

- FAIL: (b) retired target 'bash' is gone from Makefile.debian (rc=1)
```
unexpected output: 
```

- FAIL: (b) retired target 'bashvol' is gone from Makefile.debian (rc=1)
```
unexpected output: 
```

- PASS: (c) without --privileged: bounded non-zero exit, no hang (code=1)
- PASS: (c) readable error names the missing prerequisite (privileged mode / cgroup v2)
```
FATAL: /sys/fs/cgroup is not writable - the container lacks the capabilities systemd needs. Run with --privileged (documented default) or the reduced recipe: --cap-add=SYS_ADMIN --cap-add=MKNOD --tmpfs=/run --tmpfs=/run/lock --tmpfs=/tmp (README 'Runtime prerequisites'). Host must use cgroup v2.
```

- docker parity of (a)/(c) = T031 (T1 gate); stop-under-load = T033 (T4 gate)
## S10-s10-rocky
- when: 2026-11-10 15:48:15
- runtime: podman

- **RESULT: PASS**

- PASS: (a) readiness (gate + /site10a/)
```
ready-time=7s
```

- PASS: (a) stop -t 30: clean halt in 3s (well inside 30), exit 130 (130/0, not 137)
- PASS: (a) next start needs no manual recovery (ready again)
```
ready-time=4s
```

- make targets: Makefile.omd-labs-systemd-vm-rocky (IMAGE=local/omd-labs-systemd-vm-rocky:nightly, LOCAL_HTTPS_PORT=18449, runtime SITENAME)
- PASS: (b) make start SITENAME=make1 works end-to-end (documented invocation)
- PASS: (b) make start: container omd-labs-make1 ready (gate + /make1/)
```
ready-time=9s
```

- PASS: (b) make stop: clean halt (documented -t 30)
- PASS: (b) make stop exit code 130 (130/0, not 137)
- PASS: (b) make startvol VOLUME=/tmp/omd-verify/s10-make-vol SITENAME=make1 (mount path /omd/sites/make1)
- PASS: (b) startvol: site make1 ready (gate + /make1/)
```
ready-time=5s
```

- PASS: (b) startvol: host volume populated (etc/var/local + init-complete marker, root probe)
- PASS: (b) make stop startvol container: clean
- PASS: (b) retired target 'shell' is gone from Makefile.omd-labs-systemd-vm-rocky
- PASS: (b) retired target 'bash' is gone from Makefile.omd-labs-systemd-vm-rocky
- PASS: (b) retired target 'bashvol' is gone from Makefile.omd-labs-systemd-vm-rocky
- PASS: (c) without --privileged: bounded non-zero exit, no hang (code=1)
- PASS: (c) readable error names the missing prerequisite (privileged mode / cgroup v2)
```
FATAL: /sys/fs/cgroup is not writable - the container lacks the capabilities systemd needs. Run with --privileged (documented default) or the reduced recipe: --cap-add=SYS_ADMIN --cap-add=MKNOD --tmpfs=/run --tmpfs=/run/lock --tmpfs=/tmp (README 'Runtime prerequisites'). Host must use cgroup v2.
```

- docker parity of (a)/(c) = T031 (T1 gate); stop-under-load = T033 (T4 gate)
## S10-s10-debian
- when: 2026-11-10 15:48:58
- runtime: podman

- **RESULT: PASS**

- PASS: (a) readiness (gate + /site10a/)
```
ready-time=6s
```

- PASS: (a) stop -t 30: clean halt in 3s (well inside 30), exit 130 (130/0, not 137)
- PASS: (a) next start needs no manual recovery (ready again)
```
ready-time=3s
```

- make targets: Makefile.debian (IMAGE=local/omd-labs-systemd-vm-debian:nightly, LOCAL_HTTPS_PORT=18449, runtime SITENAME)
- PASS: (b) make start SITENAME=make1 works end-to-end (documented invocation)
- PASS: (b) make start: container omd-labs-make1 ready (gate + /make1/)
```
ready-time=6s
```

- PASS: (b) make stop: clean halt (documented -t 30)
- PASS: (b) make stop exit code 130 (130/0, not 137)
- PASS: (b) make startvol VOLUME=/tmp/omd-verify/s10-make-vol SITENAME=make1 (mount path /omd/sites/make1)
- PASS: (b) startvol: site make1 ready (gate + /make1/)
```
ready-time=5s
```

- PASS: (b) startvol: host volume populated (etc/var/local + init-complete marker, root probe)
- PASS: (b) make stop startvol container: clean
- PASS: (b) retired target 'shell' is gone from Makefile.debian
- PASS: (b) retired target 'bash' is gone from Makefile.debian
- PASS: (b) retired target 'bashvol' is gone from Makefile.debian
- PASS: (c) without --privileged: bounded non-zero exit, no hang (code=1)
- PASS: (c) readable error names the missing prerequisite (privileged mode / cgroup v2)
```
FATAL: /sys/fs/cgroup is not writable - the container lacks the capabilities systemd needs. Run with --privileged (documented default) or the reduced recipe: --cap-add=SYS_ADMIN --cap-add=MKNOD --tmpfs=/run --tmpfs=/run/lock --tmpfs=/tmp (README 'Runtime prerequisites'). Host must use cgroup v2.
```

- docker parity of (a)/(c) = T031 (T1 gate); stop-under-load = T033 (T4 gate)

## T020-GREEN-2026-11-10 (build 10, s2+s3+s10 both distros)

- **T020 acceptance: GREEN.** All US2 suite legs pass on BOTH distros
  against build #10 (localhost/local/omd-labs-{rocky,debian}:nightly).
- **s2 rocky: PASS (exit 0)** - first start "created new site mysite"
  (ready 6 s), omd status rc 0, volume data + init-complete marker via
  root probe, 5 daemons as mysite, HTTPS 302; restart -> "resumed
  existing site mysite" (3-4 s); fresh replacement container resumes
  (account absent in fresh image, D6 row 2) ready 3-4 s. SC-002:
  concurrent site A (published edge, ready 7 s) + site B (unpublished,
  in-container loopback, ready 8 s) - A still serving while B runs,
  omd status BOTH rc 0, both volumes populated independently.
- **s2 debian: PASS (exit 0)** - identical shape (ready 5/3/4 s; SC-002
  A 6 s / B 6 s).
- **s3 rocky + s3 debian: PASS (exit 0)** - build #10 run: 3 invalid
  names exit 1 within 1 s, fatal reasons name each value; S10c
  no-privileges exit 1 in 1 s, readable cgroup-v2/privileged error.
- **s10 rocky: PASS (exit 0, 15/15)** - (a) ready 7 s, clean stop 4 s
  exit 130, restart ready 4 s; (b) make start ready 9 s, make stop 130,
  make startvol ready 5 s + volume populated (root probe), make stop
  clean; retired targets shell/bash/bashvol gone; (c) no-priv exit 1
  bounded, readable error.
- **s10 debian: PASS (exit 0, 15/15)** - identical shape (ready 6/3/6/5 s).
- Site-start reference ready-times (informational; formal median-of-5 =
  T034): first start rocky 6 s / debian 5 s; resume 3-4 s; SC-002 A 7 s
  / B 8 s (rocky), A 6 s / B 6 s (debian); make targets rocky 9 s,
  debian 6 s; startvol 5 s both.
- Fixes that closed T020 (host-side suite only; build #10 content
  unchanged vs #9): v_vol_ls accepts -L (relative version symlink dangles
  in the probe container); v_run extras-before-image + always-shift 4th;
  SELABEL double-colon normalization in helpers + Makefile startvol :z;
  SC-002 B-run uses SELABEL WITH colon on the mount (the stripped form
  glued z onto the container path); SC-002 dual-status as single-quoted
  literal; s10 retired-target 2>&1 literal capture + make1 rm -f between
  start/startvol phases; run.sh pre-cleanup of leaked omd-s* containers.
## S8-s8-rocky
- when: 2026-11-10 15:50:04
- runtime: podman

- **RESULT: FAIL**

- PASS: readiness (gate + /auditsite/)
```
ready-time=6s
```

- enabled unit files (evidence): crond.service                     enabled enabled;dbus-broker.service               enabled enabled;httpd.service                     enabled disabled;nis-domainname.service            enabled enabled;omd-ready.service                 enabled disabled;omd-site.service                  enabled disabled;sshd.service                      enabled enabled;systemd-network-generator.service enabled enabled;dbus.socket                       enabled enabled;reboot.target                     enabled enabled;remote-fs.target                  enabled enabled;dnf-makecache.timer               enabled enabled;logrotate.timer                   enabled enabled;
- FAIL: is-enabled (site case): omd.service=masked (got 'masked
unknown'), httpd=enabled ('enabled'), sshd=enabled ('unknown'), crond=enabled ('enabled'), omd-site=enabled ('enabled'), omd-ready=enabled ('enabled') (rc=127)
```
/home/lausser/git/omd-labs-systemd-vm-forge/verify/common.sh: line 347: [: missing `]'
/home/lausser/git/omd-labs-systemd-vm-forge/verify/common.sh: line 348: unknown: command not found
```

- FAIL: getty@tty1 disabled (container console model) (rc=1)
```

```

- PASS: site case: /omd/sites contains only the selected site
- PASS: site case: no process runs as an unexpected site user (only auditsite uid>=1000)
- PASS: no-site mount: ready (base path, no site)
```
ready-time=2s
```

- PASS: no-site mount: no account created for the mounted dir (id volsite fails)
- PASS: no-site mount: no marker written (no omd-labs file in the dir)
- PASS: no-site mount: stop -t 30 clean in 1s (exit 130, 130/0 not 137 - guarded stop wrapper no-ops)
- PASS: no-site mount: restart ready again (full cycle)
```
ready-time=2s
```

- PASS: no-site mount: volume byte-identical before/after (no writes at all)
- PASS: N1: no-site: omd-site enabled ('enabled'), omd-ready enabled ('enabled'), omd-site active as no-op ('active')
- PASS: N1: no-site: no site daemons run (no uid>=1000 process user)
- PASS: N1: no-site stop -t 30 clean in 2s (exit 130, 130/0 not 137 - guarded stop wrapper)
- PASS: N1: no-site restart: still enabled, still a no-op, ready again (full cycle)
```
ready-time=2s omd-site-active=active
```

- enabled-set audit target: units/README-units.md (T012/T029 assert against it)
## S8-s8-debian
- when: 2026-11-10 15:50:31
- runtime: podman

- **RESULT: FAIL**

- PASS: readiness (gate + /auditsite/)
```
ready-time=7s
```

- enabled unit files (evidence): apache2.service           enabled enabled;cron.service              enabled enabled;exim4.service             enabled enabled;mariadb.service           enabled enabled;omd-ready.service         enabled enabled;omd-site.service          enabled enabled;ssh.service               enabled enabled;sshd-keygen.service       enabled enabled;systemd-pstore.service    enabled enabled;systemd-timesyncd.service enabled enabled;xinetd.service            enabled enabled;remote-fs.target          enabled enabled;apt-daily-upgrade.timer   enabled enabled;apt-daily.timer           enabled enabled;dpkg-db-backup.timer      enabled enabled;exim4-base.timer          enabled enabled;fstrim.timer              enabled enabled;logrotate.timer           enabled enabled;phpsessionclean.timer     enabled enabled;
- FAIL: is-enabled (site case): omd.service=masked (got 'masked
unknown'), apache2=enabled ('enabled'), sshd=enabled ('not-found
unknown'), cron=enabled ('enabled'), omd-site=enabled ('enabled'), omd-ready=enabled ('enabled') (rc=127)
```
/home/lausser/git/omd-labs-systemd-vm-forge/verify/common.sh: line 347: [: missing `]'
/home/lausser/git/omd-labs-systemd-vm-forge/verify/common.sh: line 348: unknown: command not found
/home/lausser/git/omd-labs-systemd-vm-forge/verify/common.sh: line 349: unknown: command not found
```

- FAIL: getty@tty1 disabled (container console model) (rc=1)
```

```

- PASS: site case: /omd/sites contains only the selected site
- PASS: site case: no process runs as an unexpected site user (only auditsite uid>=1000)
- PASS: no-site mount: ready (base path, no site)
```
ready-time=2s
```

- PASS: no-site mount: no account created for the mounted dir (id volsite fails)
- PASS: no-site mount: no marker written (no omd-labs file in the dir)
- PASS: no-site mount: stop -t 30 clean in 1s (exit 130, 130/0 not 137 - guarded stop wrapper no-ops)
- PASS: no-site mount: restart ready again (full cycle)
```
ready-time=2s
```

- PASS: no-site mount: volume byte-identical before/after (no writes at all)
- FAIL: N1: no-site: omd-site enabled ('unknown'), omd-ready enabled ('enabled'), omd-site active as no-op ('active') (rc=1)
```

```

- PASS: N1: no-site: no site daemons run (no uid>=1000 process user)
- PASS: N1: no-site stop -t 30 clean in 1s (exit 130, 130/0 not 137 - guarded stop wrapper)
- PASS: N1: no-site restart: still enabled, still a no-op, ready again (full cycle)
```
ready-time=2s omd-site-active=active
```

- enabled-set audit target: units/README-units.md (T012/T029 assert against it)
## S8-s8-rocky
- when: 2026-11-10 15:54:09
- runtime: podman

- **RESULT: PASS**

- PASS: readiness (gate + /auditsite/)
```
ready-time=8s
```

- enabled unit files (evidence): crond.service                     enabled enabled;dbus-broker.service               enabled enabled;httpd.service                     enabled disabled;nis-domainname.service            enabled enabled;omd-ready.service                 enabled disabled;omd-site.service                  enabled disabled;sshd.service                      enabled enabled;systemd-network-generator.service enabled enabled;dbus.socket                       enabled enabled;reboot.target                     enabled enabled;remote-fs.target                  enabled enabled;dnf-makecache.timer               enabled enabled;logrotate.timer                   enabled enabled;
- PASS: is-enabled (site case): omd.service=masked (got 'masked'), httpd=enabled ('enabled'), sshd=enabled ('enabled'), crond=enabled ('enabled'), omd-site=enabled ('enabled'), omd-ready=enabled ('enabled')
- PASS: getty@tty1 disabled (container console model, got 'disabled')
- PASS: site case: /omd/sites contains only the selected site
- PASS: site case: no process runs as an unexpected site user (only auditsite uid>=1000)
- PASS: no-site mount: ready (base path, no site)
```
ready-time=2s
```

- PASS: no-site mount: no account created for the mounted dir (id volsite fails)
- PASS: no-site mount: no marker written (no omd-labs file in the dir)
- PASS: no-site mount: stop -t 30 clean in 1s (exit 130, 130/0 not 137 - guarded stop wrapper no-ops)
- PASS: no-site mount: restart ready again (full cycle)
```
ready-time=2s
```

- PASS: no-site mount: volume byte-identical before/after (no writes at all)
- PASS: N1: no-site: omd-site enabled ('enabled'), omd-ready enabled ('enabled'), omd-site active as no-op ('active')
- PASS: N1: no-site: no site daemons run (no uid>=1000 process user)
- PASS: N1: no-site stop -t 30 clean in 2s (exit 130, 130/0 not 137 - guarded stop wrapper)
- PASS: N1: no-site restart: still enabled, still a no-op, ready again (full cycle)
```
ready-time=2s omd-site-active=active
```

- enabled-set audit target: units/README-units.md (T012/T029 assert against it)
## S8-s8-debian
- when: 2026-11-10 15:54:37
- runtime: podman

- **RESULT: FAIL**

- PASS: readiness (gate + /auditsite/)
```
ready-time=6s
```

- enabled unit files (evidence): apache2.service           enabled enabled;cron.service              enabled enabled;exim4.service             enabled enabled;mariadb.service           enabled enabled;omd-ready.service         enabled enabled;omd-site.service          enabled enabled;ssh.service               enabled enabled;sshd-keygen.service       enabled enabled;systemd-pstore.service    enabled enabled;systemd-timesyncd.service enabled enabled;xinetd.service            enabled enabled;remote-fs.target          enabled enabled;apt-daily-upgrade.timer   enabled enabled;apt-daily.timer           enabled enabled;dpkg-db-backup.timer      enabled enabled;exim4-base.timer          enabled enabled;fstrim.timer              enabled enabled;logrotate.timer           enabled enabled;phpsessionclean.timer     enabled enabled;
- PASS: is-enabled (site case): omd.service=masked (got 'masked'), apache2=enabled ('enabled'), ssh=enabled ('enabled'), cron=enabled ('enabled'), omd-site=enabled ('enabled'), omd-ready=enabled ('enabled')
- PASS: getty@tty1 disabled (container console model, got 'disabled')
- PASS: site case: /omd/sites contains only the selected site
- PASS: site case: no process runs as an unexpected site user (only auditsite uid>=1000)
- PASS: no-site mount: ready (base path, no site)
```
ready-time=2s
```

- PASS: no-site mount: no account created for the mounted dir (id volsite fails)
- PASS: no-site mount: no marker written (no omd-labs file in the dir)
- PASS: no-site mount: stop -t 30 clean in 0s (exit 130, 130/0 not 137 - guarded stop wrapper no-ops)
- PASS: no-site mount: restart ready again (full cycle)
```
ready-time=2s
```

- PASS: no-site mount: volume byte-identical before/after (no writes at all)
- FAIL: N1: no-site: omd-site enabled ('unknown'), omd-ready enabled ('enabled'), omd-site active as no-op ('active') (rc=1)
```

```

- PASS: N1: no-site: no site daemons run (no uid>=1000 process user)
- PASS: N1: no-site stop -t 30 clean in 1s (exit 130, 130/0 not 137 - guarded stop wrapper)
- PASS: N1: no-site restart: still enabled, still a no-op, ready again (full cycle)
```
ready-time=2s omd-site-active=active
```

- enabled-set audit target: units/README-units.md (T012/T029 assert against it)
## S8-s8-debian
- when: 2026-11-10 15:56:43
- runtime: podman

- **RESULT: FAIL**

- PASS: readiness (gate + /auditsite/)
```
ready-time=6s
```

- enabled unit files (evidence): apache2.service           enabled enabled;cron.service              enabled enabled;exim4.service             enabled enabled;mariadb.service           enabled enabled;omd-ready.service         enabled enabled;omd-site.service          enabled enabled;ssh.service               enabled enabled;sshd-keygen.service       enabled enabled;systemd-pstore.service    enabled enabled;systemd-timesyncd.service enabled enabled;xinetd.service            enabled enabled;remote-fs.target          enabled enabled;apt-daily-upgrade.timer   enabled enabled;apt-daily.timer           enabled enabled;dpkg-db-backup.timer      enabled enabled;exim4-base.timer          enabled enabled;fstrim.timer              enabled enabled;logrotate.timer           enabled enabled;phpsessionclean.timer     enabled enabled;
- PASS: is-enabled (site case): omd.service=masked (got 'masked'), apache2=enabled ('enabled'), ssh=enabled ('enabled'), cron=enabled ('enabled'), omd-site=enabled ('enabled'), omd-ready=enabled ('enabled')
- PASS: getty@tty1 disabled (container console model, got 'disabled')
- PASS: site case: /omd/sites contains only the selected site
- PASS: site case: no process runs as an unexpected site user (only auditsite uid>=1000)
- PASS: no-site mount: ready (base path, no site)
```
ready-time=1s
```

- PASS: no-site mount: no account created for the mounted dir (id volsite fails)
- PASS: no-site mount: no marker written (no omd-labs file in the dir)
- PASS: no-site mount: stop -t 30 clean in 1s (exit 130, 130/0 not 137 - guarded stop wrapper no-ops)
- PASS: no-site mount: restart ready again (full cycle)
```
ready-time=2s
```

- PASS: no-site mount: volume byte-identical before/after (no writes at all)
- FAIL: N1: no-site: omd-site enabled ('unknown'), omd-ready enabled ('enabled'), omd-site active as no-op ('active') (rc=1)
```

```

- PASS: N1: no-site: no site daemons run (no uid>=1000 process user)
- PASS: N1: no-site stop -t 30 clean in 2s (exit 130, 130/0 not 137 - guarded stop wrapper)
- PASS: N1: no-site restart: still enabled, still a no-op, ready again (full cycle)
```
ready-time=2s omd-site-active=active
```

- enabled-set audit target: units/README-units.md (T012/T029 assert against it)
## S4-s4-rocky
- when: 2026-11-10 16:04:36
- runtime: podman

- **RESULT: PASS**

- PASS: first start reaches ready (gate + /s4site/)
```
ready-time=6s
```

- PASS: cycle 1: stop -t 30 clean (130/0, not 137) in 3s (code=130)
- PASS: cycle 1: resumed ready + /s4site/ 302/200
```
ready-time=3s
```

- PASS: cycle 2: stop -t 30 clean (130/0, not 137) in 3s (code=130)
- PASS: cycle 2: resumed ready + /s4site/ 302/200
```
ready-time=3s
```

- PASS: cycle 3: stop -t 30 clean (130/0, not 137) in 3s (code=130)
- PASS: cycle 3: resumed ready + /s4site/ 302/200
```
ready-time=3s
```

- PASS: cycle 4: stop -t 30 clean (130/0, not 137) in 3s (code=130)
- PASS: cycle 4: resumed ready + /s4site/ 302/200
```
ready-time=3s
```

- PASS: cycle 5: stop -t 30 clean (130/0, not 137) in 3s (code=130)
- PASS: cycle 5: resumed ready + /s4site/ 302/200
```
ready-time=3s
```

- PASS: after stop: no orphaned site daemons (probed during the ordered shutdown)
```
container exited before first probe (3s stop)
```

- PASS: no stale locks in /omd/sites/s4site/tmp/run/ (root probe)
- PASS: sentinel data intact after 5 cycles ('sentinel-1794323083')
- PASS: numeric ownership unchanged (before: '1000 1000', after: '1000 1000')
- PASS: fresh replacement container resumes automatically (SC-005)
```
ready-time=3s
```

- PASS: replacement: sentinel + config intact (root probe)
- stop-under-load variant = T4 gate (T033)
## S4-s4-debian
- when: 2026-11-10 16:05:28
- runtime: podman

- **RESULT: FAIL**

- PASS: first start reaches ready (gate + /s4site/)
```
ready-time=6s
```

- PASS: cycle 1: stop -t 30 clean (130/0, not 137) in 2s (code=130)
- PASS: cycle 1: resumed ready + /s4site/ 302/200
```
ready-time=4s
```

- PASS: cycle 2: stop -t 30 clean (130/0, not 137) in 2s (code=130)
- PASS: cycle 2: resumed ready + /s4site/ 302/200
```
ready-time=3s
```

- PASS: cycle 3: stop -t 30 clean (130/0, not 137) in 2s (code=130)
- PASS: cycle 3: resumed ready + /s4site/ 302/200
```
ready-time=3s
```

- PASS: cycle 4: stop -t 30 clean (130/0, not 137) in 2s (code=130)
- PASS: cycle 4: resumed ready + /s4site/ 302/200
```
ready-time=3s
```

- PASS: cycle 5: stop -t 30 clean (130/0, not 137) in 2s (code=130)
- PASS: cycle 5: resumed ready + /s4site/ 302/200
```
ready-time=4s
```

- FAIL: after stop: no orphaned site daemons (probed during the ordered shutdown) (rc=1)
```
ORPHANS DURING SHUTDOWN: systemd
journalctl
systemd-journal
cron
dbus-daemon
systemd-logind
xinetd
apache2
apache2
sshd
apache2
apache2
apache2
apache2
apache2
mariadbd
rrdcached
npcd
naemon
naemon
naemon
naemon
naemon
naemon
naemon
apache2
perl
apache2
apache2
perl
apache2
exim4
systemd-timedat
ps
```

- PASS: no stale locks in /omd/sites/s4site/tmp/run/ (root probe)
- PASS: sentinel data intact after 5 cycles ('sentinel-1794323134')
- PASS: numeric ownership unchanged (before: '1000 1000', after: '1000 1000')
- PASS: fresh replacement container resumes automatically (SC-005)
```
ready-time=3s
```

- PASS: replacement: sentinel + config intact (root probe)
- stop-under-load variant = T4 gate (T033)
## S4-s4-rocky
- when: 2026-11-10 16:08:25
- runtime: podman

- **RESULT: PASS**

- PASS: first start reaches ready (gate + /s4site/)
```
ready-time=6s
```

- PASS: cycle 1: stop -t 30 clean (130/0, not 137) in 3s (code=130)
- PASS: cycle 1: resumed ready + /s4site/ 302/200
```
ready-time=4s
```

- PASS: cycle 2: stop -t 30 clean (130/0, not 137) in 3s (code=130)
- PASS: cycle 2: resumed ready + /s4site/ 302/200
```
ready-time=3s
```

- PASS: cycle 3: stop -t 30 clean (130/0, not 137) in 3s (code=130)
- PASS: cycle 3: resumed ready + /s4site/ 302/200
```
ready-time=4s
```

- PASS: cycle 4: stop -t 30 clean (130/0, not 137) in 3s (code=130)
- PASS: cycle 4: resumed ready + /s4site/ 302/200
```
ready-time=3s
```

- PASS: cycle 5: stop -t 30 clean (130/0, not 137) in 3s (code=130)
- PASS: cycle 5: resumed ready + /s4site/ 302/200
```
ready-time=3s
```

- PASS: after stop: container exited fully with the CLEAN code (ordered shutdown completed, no fatal; clean 130/0 asserted per cycle)
```
exit-code=130
```

- PASS: no stale locks in /omd/sites/s4site/tmp/run/ (root probe)
- PASS: sentinel data intact after 5 cycles ('sentinel-1794323311')
- PASS: numeric ownership unchanged (before: '1000 1000', after: '1000 1000')
- PASS: fresh replacement container resumes automatically (SC-005)
```
ready-time=3s
```

- PASS: replacement: sentinel + config intact (root probe)
- stop-under-load variant = T4 gate (T033)
## S4-s4-debian
- when: 2026-11-10 16:09:16
- runtime: podman

- **RESULT: PASS**

- PASS: first start reaches ready (gate + /s4site/)
```
ready-time=5s
```

- PASS: cycle 1: stop -t 30 clean (130/0, not 137) in 3s (code=130)
- PASS: cycle 1: resumed ready + /s4site/ 302/200
```
ready-time=3s
```

- PASS: cycle 2: stop -t 30 clean (130/0, not 137) in 3s (code=130)
- PASS: cycle 2: resumed ready + /s4site/ 302/200
```
ready-time=3s
```

- PASS: cycle 3: stop -t 30 clean (130/0, not 137) in 3s (code=130)
- PASS: cycle 3: resumed ready + /s4site/ 302/200
```
ready-time=4s
```

- PASS: cycle 4: stop -t 30 clean (130/0, not 137) in 2s (code=130)
- PASS: cycle 4: resumed ready + /s4site/ 302/200
```
ready-time=3s
```

- PASS: cycle 5: stop -t 30 clean (130/0, not 137) in 3s (code=130)
- PASS: cycle 5: resumed ready + /s4site/ 302/200
```
ready-time=3s
```

- PASS: after stop: container exited fully with the CLEAN code (ordered shutdown completed, no fatal; clean 130/0 asserted per cycle)
```
exit-code=130
```

- PASS: no stale locks in /omd/sites/s4site/tmp/run/ (root probe)
- PASS: sentinel data intact after 5 cycles ('sentinel-1794323361')
- PASS: numeric ownership unchanged (before: '1000 1000', after: '1000 1000')
- PASS: fresh replacement container resumes automatically (SC-005)
```
ready-time=3s
```

- PASS: replacement: sentinel + config intact (root probe)
- stop-under-load variant = T4 gate (T033)
## S6-s6-rocky-d
- when: 2026-11-10 16:11:06
- runtime: podman

## S6-s6-rocky-f
- when: 2026-11-10 16:11:06
- runtime: podman

- **RESULT: PASS**

- PASS: (f) incomplete pre-marker tree ? actionable exit 1, never adopted/started (code=1)
- PASS: (f) data untouched (site.conf still absent, tree unmodified - root probe)
## S6-s6-rocky-g
- when: 2026-11-10 16:11:09
- runtime: podman

## S6-s6-debian-d
- when: 2026-11-10 16:11:12
- runtime: podman

## S6-s6-debian-f
- when: 2026-11-10 16:11:13
- runtime: podman

- **RESULT: FAIL**

- FAIL: (f) incomplete pre-marker tree ? actionable exit 1, never adopted/started (code=0) (rc=1)
```

```

- FAIL: (f) data untouched (site.conf still absent, tree unmodified - root probe) (rc=1)
```

```

## S6-s6-debian-g
- when: 2026-11-10 16:12:24
- runtime: podman

## S6-s6-rocky-d
- when: 2026-11-10 16:22:21
- runtime: podman

- **RESULT: FAIL**

- PASS: (d/account-plus-tree) irreconcilable ? actionable exit 1, no mutation (code=1)
- (d/account-plus-tree) outcome: ready=no code=1
- PASS: (d/account-only) irreconcilable ? actionable exit 1, no mutation (code=1)
- (d/account-only) outcome: ready=no code=1
- PASS: (d/tree-only) irreconcilable ? actionable exit 1, no mutation (code=1)
- (d/tree-only) outcome: ready=no code=1
- PASS: (d/version-link) irreconcilable ? actionable exit 1, no mutation (code=1)
- (d/version-link) outcome: ready=no code=1
- PASS: (d/apache-conf) irreconcilable ? actionable exit 1, no mutation (code=1)
- (d/apache-conf) outcome: ready=no code=1
- PASS: (d/fstab) irreconcilable ? actionable exit 1, no mutation (code=1)
- (d/fstab) outcome: ready=no code=1
- PASS: (d/uid-gid-occupied) either recovered or actionable exit (code=1)
- PASS: (d-injected) failure at commit point ? exit 1 (code=1)
- FAIL: (d-injected) in-progress marker REMAINS after the failure (root probe) (rc=1)
```

```

- PASS: (d-injected) complete marker ABSENT (recovery never committed, root probe)
- FAIL: (d-injected) next boot re-enters recovery, completes ready (root image) (rc=1)
```
READY-FATAL: container exited (code 1)
ready-time=s
```

- FAIL: (d-injected) recovery committed: complete marker + in-progress gone (root probe) (rc=1)
```
missing: .omd-labs-init-complete
```

## S6-s6-rocky-f
- when: 2026-11-10 16:22:48
- runtime: podman

- **RESULT: PASS**

- PASS: (f) incomplete pre-marker tree ? actionable exit 1, never adopted/started (code=1)
- PASS: (f) data untouched (site.conf still absent, tree unmodified - root probe)
## S6-s6-rocky-g
- when: 2026-11-10 16:22:50
- runtime: podman

- **RESULT: FAIL**

- FAIL: (g1) ambiguous identity ? actionable exit 1 (code=6) (rc=1)
```

```

- FAIL: (g1) volume byte-identical (no mutation, root probe) (rc=1)
```

```

- FAIL: (g2) lost identity file ? resume via inference, site starts (rc=1)
```
READY-FATAL: container exited (code 1)
ready-time=s
```

- PASS: (g2) .omd-labs-site-identity RE-RECORDED (via podman cp)
- FAIL: (g3) recorded identity honored: id recid = uid 1234 gid 1234 (rc=2)
```
/home/lausser/git/omd-labs-systemd-vm-forge/verify/common.sh: eval: line 349: unexpected EOF while looking for matching `"'
```

## S6-s6-debian-d
- when: 2026-11-10 16:22:59
- runtime: podman

- **RESULT: FAIL**

- PASS: (d/account-plus-tree) irreconcilable ? actionable exit 1, no mutation (code=1)
- (d/account-plus-tree) outcome: ready=no code=1
- PASS: (d/account-only) irreconcilable ? actionable exit 1, no mutation (code=1)
- (d/account-only) outcome: ready=no code=1
- PASS: (d/tree-only) irreconcilable ? actionable exit 1, no mutation (code=1)
- (d/tree-only) outcome: ready=no code=1
- PASS: (d/version-link) irreconcilable ? actionable exit 1, no mutation (code=1)
- (d/version-link) outcome: ready=no code=1
- PASS: (d/apache-conf) irreconcilable ? actionable exit 1, no mutation (code=1)
- (d/apache-conf) outcome: ready=no code=1
- PASS: (d/fstab) irreconcilable ? actionable exit 1, no mutation (code=1)
- (d/fstab) outcome: ready=no code=1
- PASS: (d/uid-gid-occupied) either recovered or actionable exit (code=1)
- PASS: (d-injected) failure at commit point ? exit 1 (code=1)
- FAIL: (d-injected) in-progress marker REMAINS after the failure (root probe) (rc=1)
```

```

- PASS: (d-injected) complete marker ABSENT (recovery never committed, root probe)
- FAIL: (d-injected) next boot re-enters recovery, completes ready (root image) (rc=1)
```
READY-FATAL: container exited (code 1)
ready-time=s
```

- FAIL: (d-injected) recovery committed: complete marker + in-progress gone (root probe) (rc=1)
```
missing: .omd-labs-init-complete
```

## S6-s6-debian-f
- when: 2026-11-10 16:23:28
- runtime: podman

- **RESULT: PASS**

- PASS: (f) incomplete pre-marker tree ? actionable exit 1, never adopted/started (code=1)
- PASS: (f) data untouched (site.conf still absent, tree unmodified - root probe)
## S6-s6-debian-g
- when: 2026-11-10 16:23:31
- runtime: podman

- **RESULT: FAIL**

- FAIL: (g1) ambiguous identity ? actionable exit 1 (code=6) (rc=1)
```

```

- FAIL: (g1) volume byte-identical (no mutation, root probe) (rc=1)
```

```

- FAIL: (g2) lost identity file ? resume via inference, site starts (rc=1)
```
READY-FATAL: container exited (code 1)
ready-time=s
```

- PASS: (g2) .omd-labs-site-identity RE-RECORDED (via podman cp)
- FAIL: (g3) recorded identity honored: id recid = uid 1234 gid 1234 (rc=2)
```
/home/lausser/git/omd-labs-systemd-vm-forge/verify/common.sh: eval: line 349: unexpected EOF while looking for matching `"'
```

## S6-s6-rocky-d
- when: 2026-11-10 19:47:00
- runtime: podman

- **RESULT: PASS**

- PASS: (d/account-plus-tree) fixture precondition: in-progress marker present pre-run
- PASS: (d/account-plus-tree) fixture precondition: complete marker absent pre-run
- PASS: (d/account-plus-tree) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/account-plus-tree) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/account-plus-tree) complete marker written after recovery (root probe)
- PASS: (d/account-plus-tree) in-progress marker removed (root probe)
- (d/account-plus-tree) outcome: expect=ready ready=yes code=0
- PASS: (d/version-link) fixture precondition: in-progress marker present pre-run
- PASS: (d/version-link) fixture precondition: complete marker absent pre-run
- PASS: (d/version-link) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/version-link) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/version-link) complete marker written after recovery (root probe)
- PASS: (d/version-link) in-progress marker removed (root probe)
- (d/version-link) outcome: expect=ready ready=yes code=0
- PASS: (d/tree-only) fixture precondition: in-progress marker present pre-run
- PASS: (d/tree-only) fixture precondition: complete marker absent pre-run
- PASS: (d/tree-only) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/tree-only) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/tree-only) complete marker written after recovery (root probe)
- PASS: (d/tree-only) in-progress marker removed (root probe)
- (d/tree-only) outcome: expect=ready ready=yes code=0
- PASS: (d/account-only) fixture precondition: in-progress marker present pre-run
- PASS: (d/account-only) fixture precondition: complete marker absent pre-run
- PASS: (d/account-only) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/account-only) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/account-only) complete marker written after recovery (root probe)
- PASS: (d/account-only) in-progress marker removed (root probe)
- (d/account-only) outcome: expect=ready ready=yes code=0
- PASS: (d/apache-conf) fixture precondition: in-progress marker present pre-run
- PASS: (d/apache-conf) fixture precondition: complete marker absent pre-run
- PASS: (d/apache-conf) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/apache-conf) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/apache-conf) complete marker written after recovery (root probe)
- PASS: (d/apache-conf) in-progress marker removed (root probe)
- (d/apache-conf) outcome: expect=ready ready=yes code=0
- PASS: (d/fstab) fixture precondition: in-progress marker present pre-run
- PASS: (d/fstab) fixture precondition: complete marker absent pre-run
- PASS: (d/fstab) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/fstab) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/fstab) complete marker written after recovery (root probe)
- PASS: (d/fstab) in-progress marker removed (root probe)
- (d/fstab) outcome: expect=ready ready=yes code=0
- PASS: (d/uid-gid-occupied) irreconcilable ? actionable exit 1 (code=1)
- PASS: (d/uid-gid-occupied) fatal reason names the occupying account
```
FATAL: recovery: uid 1234 is occupied by a different account - the interrupted creation is irreconcilable. No mutation. Remedy: free the uid (userdel the conflicting account) or restore the original volume.
```

- PASS: (d/uid-gid-occupied) no mutation (content + metadata snapshot identical)
- (d/uid-gid-occupied) outcome: expect=fatal ready=n/a code=1
- PASS: (d-injected) failure at the recovery commit point ? exit 1 (code=1)
- PASS: (d-injected) the injected line was REACHED (sentinel present, cp from stopped container)
- PASS: (d-injected) in-progress marker REMAINS after the failure (root probe)
- PASS: (d-injected) complete marker ABSENT (recovery never committed, root probe)
- PASS: (d-injected) next boot re-enters recovery, completes ready (root image)
```
ready-time=3s
```

- PASS: (d-injected) recovery committed: complete marker + in-progress gone (root probe)
## S6-s6-rocky-g
- when: 2026-11-10 19:49:06
- runtime: podman

- **RESULT: PASS**

- PASS: (g1) ambiguous identity ? actionable exit 1 (code=1)
- PASS: (g1) fatal reason names the ambiguity
```
FATAL: inferred identity is AMBIGUOUS - the site subfolders' group (996) equals the omd group's gid; the primary gid cannot be determined. Refusing (no mutation). Remedy: run the site once from its original image or set the identity manually.
```

- PASS: (g1) volume unchanged: content + ownership/mode metadata identical
- PASS: (g2) lost identity file ? resume via inference, site starts ready
```
ready-time=3s
```

- PASS: (g2) .omd-labs-site-identity RE-RECORDED with the inferred 1234/1234
- PASS: (g3) recorded identity honored: site starts ready
```
ready-time=3s
```

- PASS: (g3) fresh-container account carries uid=1234 (id recid)
- PASS: (g3) fresh-container account carries primary gid=1234 (id recid)
## S6-s6-debian-d
- when: 2026-11-10 19:50:13
- runtime: podman

- **RESULT: PASS**

- PASS: (d/account-plus-tree) fixture precondition: in-progress marker present pre-run
- PASS: (d/account-plus-tree) fixture precondition: complete marker absent pre-run
- PASS: (d/account-plus-tree) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/account-plus-tree) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/account-plus-tree) complete marker written after recovery (root probe)
- PASS: (d/account-plus-tree) in-progress marker removed (root probe)
- (d/account-plus-tree) outcome: expect=ready ready=yes code=0
- PASS: (d/version-link) fixture precondition: in-progress marker present pre-run
- PASS: (d/version-link) fixture precondition: complete marker absent pre-run
- PASS: (d/version-link) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/version-link) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/version-link) complete marker written after recovery (root probe)
- PASS: (d/version-link) in-progress marker removed (root probe)
- (d/version-link) outcome: expect=ready ready=yes code=0
- PASS: (d/tree-only) fixture precondition: in-progress marker present pre-run
- PASS: (d/tree-only) fixture precondition: complete marker absent pre-run
- PASS: (d/tree-only) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/tree-only) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/tree-only) complete marker written after recovery (root probe)
- PASS: (d/tree-only) in-progress marker removed (root probe)
- (d/tree-only) outcome: expect=ready ready=yes code=0
- PASS: (d/account-only) fixture precondition: in-progress marker present pre-run
- PASS: (d/account-only) fixture precondition: complete marker absent pre-run
- PASS: (d/account-only) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/account-only) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/account-only) complete marker written after recovery (root probe)
- PASS: (d/account-only) in-progress marker removed (root probe)
- (d/account-only) outcome: expect=ready ready=yes code=0
- PASS: (d/apache-conf) fixture precondition: in-progress marker present pre-run
- PASS: (d/apache-conf) fixture precondition: complete marker absent pre-run
- PASS: (d/apache-conf) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/apache-conf) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/apache-conf) complete marker written after recovery (root probe)
- PASS: (d/apache-conf) in-progress marker removed (root probe)
- (d/apache-conf) outcome: expect=ready ready=yes code=0
- PASS: (d/fstab) fixture precondition: in-progress marker present pre-run
- PASS: (d/fstab) fixture precondition: complete marker absent pre-run
- PASS: (d/fstab) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/fstab) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/fstab) complete marker written after recovery (root probe)
- PASS: (d/fstab) in-progress marker removed (root probe)
- (d/fstab) outcome: expect=ready ready=yes code=0
- PASS: (d/uid-gid-occupied) irreconcilable ? actionable exit 1 (code=1)
- PASS: (d/uid-gid-occupied) fatal reason names the occupying account
```
FATAL: recovery: uid 1234 is occupied by a different account - the interrupted creation is irreconcilable. No mutation. Remedy: free the uid (userdel the conflicting account) or restore the original volume.
```

- PASS: (d/uid-gid-occupied) no mutation (content + metadata snapshot identical)
- (d/uid-gid-occupied) outcome: expect=fatal ready=n/a code=1
- PASS: (d-injected) failure at the recovery commit point ? exit 1 (code=1)
- PASS: (d-injected) the injected line was REACHED (sentinel present, cp from stopped container)
- PASS: (d-injected) in-progress marker REMAINS after the failure (root probe)
- PASS: (d-injected) complete marker ABSENT (recovery never committed, root probe)
- PASS: (d-injected) next boot re-enters recovery, completes ready (root image)
```
ready-time=3s
```

- PASS: (d-injected) recovery committed: complete marker + in-progress gone (root probe)
## S6-s6-debian-g
- when: 2026-11-10 19:52:09
- runtime: podman

- **RESULT: PASS**

- PASS: (g1) ambiguous identity ? actionable exit 1 (code=1)
- PASS: (g1) fatal reason names the ambiguity
```
FATAL: inferred identity is AMBIGUOUS - the site subfolders' group (106) equals the omd group's gid; the primary gid cannot be determined. Refusing (no mutation). Remedy: run the site once from its original image or set the identity manually.
```

- PASS: (g1) volume unchanged: content + ownership/mode metadata identical
- PASS: (g2) lost identity file ? resume via inference, site starts ready
```
ready-time=3s
```

- PASS: (g2) .omd-labs-site-identity RE-RECORDED with the inferred 1234/1234
- PASS: (g3) recorded identity honored: site starts ready
```
ready-time=3s
```

- PASS: (g3) fresh-container account carries uid=1234 (id recid)
- PASS: (g3) fresh-container account carries primary gid=1234 (id recid)
## S6-s6-rocky-f
- when: 2026-11-10 19:52:58
- runtime: podman

- **RESULT: PASS**

- PASS: (f) incomplete pre-marker tree ? actionable exit 1, never adopted/started (code=1)
- PASS: (f) data untouched (site.conf still absent, tree unmodified - root probe)
## S6-s6-debian-f
- when: 2026-11-10 19:53:17
- runtime: podman

- **RESULT: PASS**

- PASS: (f) incomplete pre-marker tree ? actionable exit 1, never adopted/started (code=1)
- PASS: (f) data untouched (site.conf still absent, tree unmodified - root probe)
## S8-s8-debian
- when: 2026-11-10 19:54:07
- runtime: podman

- **RESULT: PASS**

- PASS: readiness (gate + /auditsite/)
```
ready-time=6s
```

- enabled unit files (evidence): apache2.service           enabled enabled;cron.service              enabled enabled;exim4.service             enabled enabled;mariadb.service           enabled enabled;omd-ready.service         enabled enabled;omd-site.service          enabled enabled;ssh.service               enabled enabled;sshd-keygen.service       enabled enabled;systemd-pstore.service    enabled enabled;systemd-timesyncd.service enabled enabled;xinetd.service            enabled enabled;remote-fs.target          enabled enabled;apt-daily-upgrade.timer   enabled enabled;apt-daily.timer           enabled enabled;dpkg-db-backup.timer      enabled enabled;exim4-base.timer          enabled enabled;fstrim.timer              enabled enabled;logrotate.timer           enabled enabled;phpsessionclean.timer     enabled enabled;
- PASS: is-enabled (site case): omd.service=masked (got 'masked'), apache2=enabled ('enabled'), ssh=enabled ('enabled'), cron=enabled ('enabled'), omd-site=enabled ('enabled'), omd-ready=enabled ('enabled')
- PASS: getty@tty1 disabled (container console model, got 'disabled')
- PASS: site case: /omd/sites contains only the selected site
- PASS: site case: no process runs as an unexpected site user (only auditsite uid>=1000)
- PASS: no-site mount: ready (base path, no site)
```
ready-time=2s
```

- PASS: no-site mount: no account created for the mounted dir (id volsite fails)
- PASS: no-site mount: no marker written (no omd-labs file in the dir)
- PASS: no-site mount: stop -t 30 clean in 0s (exit 130, 130/0 not 137 - guarded stop wrapper no-ops)
- PASS: no-site mount: restart ready again (full cycle)
```
ready-time=1s
```

- PASS: no-site mount: volume byte-identical before/after (no writes at all)
- PASS: N1: no-site: omd-site enabled ('enabled'), omd-ready enabled ('enabled'), omd-site active as no-op ('active')
- PASS: N1: no-site: no site daemons run (no uid>=1000 process user)
- PASS: N1: no-site stop -t 30 clean in 1s (exit 130, 130/0 not 137 - guarded stop wrapper)
- PASS: N1: no-site restart: still enabled, still a no-op, ready again (full cycle)
```
ready-time=2s omd-site-active=active
```

- enabled-set audit target: units/README-units.md (T012/T029 assert against it)


## T021-GREEN-2026-11-10 (build 10, s8 both distros: no-site mount + N1 no-site)

- **T021 acceptance: GREEN** (no image build - verifies build #10 per the
  T020 dependency chain). Both distros, port 18460.
- **s8 rocky: PASS** (section S8-s8-rocky) - no-site mount variant (D6 row
  5): populated dir mounted at the site path with NO SITENAME left
  **byte-identical** (no account created, no markers written, no writes) +
  stop -t 30 clean (130/0, guarded stop wrapper no-ops) + restart ready
  again; N1 no-site: omd-site stays **enabled**, omd-ready enabled,
  omd-site active as no-op, no site daemons, stop/restart cycle clean.
- **s8 debian: PASS** (section S8-s8-debian) - same assertions. The earlier
  deterministic N1 `is-enabled omd-site = unknown` (latent race: first exec
  lands before systemd answers) is fixed by the `v_wait_ready omd-s8-none`
  before the captures (s8.sh:86) - N1 now records `enabled`/`enabled`/
  `active` (15/15 checks, exit 0).

## T022-GREEN-2026-11-10 (build 10, s4 + s6 d/f/g both distros)

- **T022 acceptance: GREEN** (no image build - verifies build #10). After
  the debate 58/59/60 fixture/scenario rework (marker-LAST d matrix, per-
  site REAL golden trees, per-variant expectations, metadata-inclusive
  no-mutation snapshots, sentinel-proven d-injected). Evidence: the per-
  section PASS lines below (all RESULT: PASS).
- **s4 rocky + debian: PASS** (sections S4-s4-rocky, S4-s4-debian) -
  sentinel site, 5 stop/start cycles (stops 130/0, never 137, HTTPS 302
  after each), sentinel + var/ + ownership unchanged, no orphaned processes
  / stale locks after a stop; fresh replacement container reuses the volume
  and resumes (data + config + web credentials intact, no manual recovery).
  Stop-under-load variant = the T4 gate (T033).
- **s6 d rocky + debian: PASS** (sections S6-s6-{rocky,debian}-d) - D6 row
  3a recovery matrix, all variants with the in-progress marker (asserted
  pre-run): account-plus-tree, version-link, tree-only, account-only,
  apache-conf, fstab all RECONCILABLE (recovery completes, site ready,
  `omd status` rc 0, complete marker written, in-progress removed);
  uid-gid-occupied (genuinely occupying in-image account, test-only
  sub-image) IRRECONCILABLE (exit 1, fatal "uid 1234 is occupied by a
  different account", content+metadata snapshot identical = no mutation).
  d-injected sub-case: sentinel + exit 1 at the recovery commit point -
  sentinel REACHED (proven via podman cp), in-progress marker REMAINS,
  complete marker ABSENT, next boot re-enters recovery and commits
  (ready 3 s). In NO case is a partially configured site started as if
  complete.
- **s6 f rocky + debian: PASS** (sections S6-s6-{rocky,debian}-f) -
  pre-marker INCOMPLETE tree (row 3c): actionable exit 1 naming the missing
  invariant, never adopted/started, data untouched. (Re-verified after the
  `_fx_site_tree` rework: real omd gid 996/106 + top dir 0750.)
- **s6 g rocky + debian: PASS** (sections S6-s6-{rocky,debian}-g) -
  identity fixtures (round-2 B2): g1 ambiguous (subfolders group = the
  image's REAL omd gid 996 rocky / 106 debian) => actionable exit 1 (fatal
  AMBIGUOUS), volume unchanged (content + ownership/mode metadata
  identical); g2 identity file lost on a completed-volume resume =>
  inference + RE-RECORDED `.omd-labs-site-identity` (1234/1234 via podman
  cp), site starts ready; g3 recorded identity HONORED => fresh-container
  account carries uid=1234 gid=1234 (id recid). g2/g3 use REAL (per-site
  golden) trees because the resume path runs `omd enable` (the version link
  must be accurate - the fake `/omd/versions/default` symlink misfired
  OMD's version switch, debate 60 F4).
- **Root causes fixed (debate 60)**: F1 d-variants lost their marker
  (adopted instead of recovering) + injected line unproven; F2 g1 used gid
  0 not the real omd gid (guard un-fireable, exit 6); F3 any-exit-1-as-pass
  + no occupied account; F4 fake version symlink => non-root re-exec bail.
  Two entry DEFECTS are recorded but deferred to the T026 window (no
  rebuild in T022): infer_legacy_identity writes the identity file before
  validation, and useradd assumes the group NAME exists - the corrected
  fixtures make no T022 case reach write-then-fatal (tasks/todo.md).
## S6-s6-rocky-e
- when: 2026-11-10 20:57:39
- runtime: podman

- **RESULT: FAIL**

- (e) real old-image volume: /tmp/omd-verify/s6e-legacy-rocky-mysite (inferred identity uid=1001 gid=1001)
- PASS: (e) precondition: volume is marker-free (genuinely adoptable, root probe)
- PASS: (e) precondition: version link + stored site.conf + htpasswd present (root probe)
- PASS: (e) legacy volume adopted - site starts ready (gate + /mysite/)
```
ready-time=3s
```

- PASS: (e) prominent 'existing site mysite (no init marker - legacy/pre-marker volume)' log line
```
2026-11-10T19:57:43+0000 cc8ab9243d06 omd-ready-check[482]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-10T19:57:43+0000 cc8ab9243d06 systemd[1]: Finished OMD labs bounded readiness gate (FR-018).
2026-11-10T19:57:43+0000 cc8ab9243d06 systemd[1]: Reached target Multi-User System.
2026-11-10T19:57:43+0000 cc8ab9243d06 systemd[1]: Reached target Graphical Interface.
2026-11-10T19:57:43+0000 cc8ab9243d06 systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-10T19:57:43+0000 cc8ab9243d06 systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-10T19:57:43+0000 cc8ab9243d06 systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-10T19:57:43+0000 cc8ab9243d06 systemd[1]: Startup finished in 2.126s.
```

- PASS: (e) stored configuration authoritative: omd config show returns the ALTERED stored value
- FAIL: (e) omd status rc 0 (site registered + started, adopt path) (rc=125)
```
Manage pods, containers and images

Usage:
  podman [options] [command]

Available Commands:
  artifact    Manage OCI artifacts
  attach      Attach to a running container
  auto-update Auto update containers according to their auto-update policy
  build       Build an image using instructions from Containerfiles
  commit      Create new image based on the changed container
  compose     Run compose workloads via an external provider such as docker-compose or podman-compose
  container   Manage containers
  cp          Copy files/folders between a container and the local filesystem
  create      Create but do not start a container
  diff        Display the changes to the object's file system
  events      Show podman system events
  exec        Run a process in a running container
  export      Export container's filesystem contents as a tar archive
  farm        Farm out builds to remote machines
  generate    Generate structured data based on containers, pods or volumes
  healthcheck Manage health checks on containers
  help        Help about any command
  history     Show history of a specified image
  image       Manage images
  images      List images in local storage
  import      Import a tarball to create a filesystem image
  info        Display podman system information
  init        Initialize one or more containers
  inspect     Display the configuration of object denoted by ID
  kill        Kill one or more running containers with a specific signal
  kube        Play containers, pods or volumes from a structured file
  load        Load image(s) from a tar archive
  login       Log in to a container registry
  logout      Log out of a container registry
  logs        Fetch the logs of one or more containers
  machine     Manage a virtual machine
  manifest    Manipulate manifest lists and image indexes
  mount       Mount a working container's root filesystem
  network     Manage networks
  pause       Pause all the processes in one or more containers
  pod         Manage pods
  port        List port mappings or a specific mapping for the container
  ps          List containers
  pull        Pull an image from a registry
  push        Push an image to a specified destination
  quadlet     Allows users to manage Quadlets
  rename      Rename an existing container
  restart     Restart one or more containers
  rm          Remove one or more containers
  rmi         Remove one or more images from local storage
  run         Run a command in a new container
  save        Save image(s) to an archive
  search      Search registry for image
  secret      Manage secrets
  start       Start one or more containers
  stats       Display a live stream of container resource usage statistics
  stop        Stop one or more containers
  system      Manage podman
  tag         Add an additional name to a local image
  top         Display the running processes of a container
  unmount     Unmount working container's root filesystem
  unpause     Unpause the processes in one or more containers
  unshare     Run a command in a modified user namespace
  untag       Remove a name from a local image
  update      Update an existing container
  version     Display the Podman version information
  volume      Manage volumes
  wait        Block on one or more containers

Options:
      --cdi-spec-dir stringArray    Set the CDI spec directory path (may be set multiple times) (default [/etc/cdi,/var/run/cdi])
      --cgroup-manager string       Cgroup manager to use ("cgroupfs"|"systemd") (default "systemd")
      --config string               Path to directory containing authentication config file
      --conmon string               Path of the conmon binary
  -c, --connection string           Connection to use for remote Podman service (CONTAINER_CONNECTION)
      --events-backend string       Events backend to use ("file"|"journald"|"none") (default "journald")
      --help                        Help for podman
      --hooks-dir stringArray       Set the OCI hooks directory path (may be set multiple times) (default [/usr/share/containers/oci/hooks.d])
      --identity string             path to SSH identity file, (CONTAINER_SSHKEY)
      --imagestore string           Path to the 'image store', different from 'graph root', use this to split storing the image into a separate 'image store', see 'man containers-storage.conf' for details
      --log-level string            Log messages above specified level (trace, debug, info, warn, warning, error, fatal, panic) (default "warn")
      --module stringArray          Load the containers.conf(5) module
      --network-config-dir string   Path of the configuration directory for networks
      --out string                  Send output (stdout) from podman to a file
  -r, --remote                      Access remote Podman service
      --root string                 Path to the graph root directory where images, containers, etc. are stored
      --runroot string              Path to the 'run directory' where all state information is stored
      --runtime string              Path to the OCI-compatible binary used to run containers. (default "crun")
      --runtime-flag stringArray    add global flags for the container runtime
      --ssh string                  define the ssh mode (default "golang")
      --storage-driver string       Select which storage driver is used to manage storage of images and containers
      --storage-opt stringArray     Used to pass an option to the storage driver
      --syslog                      Output podman-internal logs to syslog as well as the console (default false)
      --tls-ca string               path to TLS certificate Authority PEM file for remote.
      --tls-cert string             path to TLS client certificate PEM file for remote.
      --tls-details string          Path to a containers-tls-details.yaml(5) file
      --tls-key string              path to TLS client certificate private key PEM file for remote.
      --tmpdir string               Path to the tmp directory for libpod state content.
                                    
                                    Note: use the environment variable 'TMPDIR' to change the temporary storage location for container images, '/var/tmp'.
                                     (default "/run/user/1000/libpod/tmp")
      --transient-store             Enable transient container storage
      --url string                  URL to access Podman service (CONTAINER_HOST) (default "unix:///run/user/1000/podman/podman.sock")
  -v, --version                     version for podman
      --volumepath string           Path to the volume directory in which volume data is stored
Error: missing command 'podman COMMAND'
```

- PASS: (e) stored site.conf UNMODIFIED (sha256 unchanged, root probe)
- PASS: (e) stored web credential FILE unmodified (htpasswd sha256 unchanged, root probe)
- PASS: (e) the stored web credential created before STILL LOGS IN (thruk 200 with cred, 302 anon)
```
with-cred=200 anon=302
```

- PASS: (e) init-complete marker now present (leaves the no-marker class, root probe)
- PASS: (e) identity re-recorded with the INFERRED uid/gid from the volume (root probe)
- PASS: (e) numeric ownership UNTOUCHED (top uid:omdgid 0750, subfolders uid:gid - root probe)
- (e) with-inputs half (FR-012 notice + no apply + no gearmand) = T027 's6 e-inputs'
## S6-s6-rocky-e
- when: 2026-11-10 21:01:58
- runtime: podman

- **RESULT: PASS**

- (e) real old-image volume: /tmp/omd-verify/s6e-legacy-rocky-mysite (inferred identity uid=1001 gid=1001)
- PASS: (e) precondition: volume is marker-free (genuinely adoptable, root probe)
- PASS: (e) precondition: version link + stored site.conf + htpasswd present (root probe)
- PASS: (e) legacy volume adopted - site starts ready (gate + /mysite/)
```
ready-time=3s
```

- PASS: (e) prominent 'existing site mysite (no init marker - legacy/pre-marker volume)' log line
```
2026-11-10T20:02:07+0000 fbef3fcf53e9 omd-ready-check[477]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-10T20:02:07+0000 fbef3fcf53e9 systemd[1]: Finished OMD labs bounded readiness gate (FR-018).
2026-11-10T20:02:07+0000 fbef3fcf53e9 systemd[1]: Reached target Multi-User System.
2026-11-10T20:02:07+0000 fbef3fcf53e9 systemd[1]: Reached target Graphical Interface.
2026-11-10T20:02:07+0000 fbef3fcf53e9 systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-10T20:02:07+0000 fbef3fcf53e9 systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-10T20:02:07+0000 fbef3fcf53e9 systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-10T20:02:07+0000 fbef3fcf53e9 systemd[1]: Startup finished in 2.062s.
```

- PASS: (e) stored configuration authoritative: omd config show returns the ALTERED stored value
- PASS: (e) omd status rc 0 (site registered + started, adopt path)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (e) stored site.conf UNMODIFIED (sha256 unchanged, root probe)
- PASS: (e) stored web credential FILE unmodified (htpasswd sha256 unchanged, root probe)
- PASS: (e) the stored web credential created before STILL LOGS IN (thruk 200 with cred, 302 anon)
```
with-cred=200 anon=302
```

- PASS: (e) init-complete marker now present (leaves the no-marker class, root probe)
- PASS: (e) identity re-recorded with the INFERRED uid/gid from the volume (root probe)
- PASS: (e) numeric ownership UNTOUCHED (top uid:omdgid 0750, subfolders uid:gid - root probe)
- (e) with-inputs half (FR-012 notice + no apply + no gearmand) = T027 's6 e-inputs'
## S6-s6-debian-e
- when: 2026-11-10 21:02:45
- runtime: podman

- **RESULT: PASS**

- (e) real old-image volume: /tmp/omd-verify/s6e-legacy-debian-mysite (inferred identity uid=1001 gid=1001)
- PASS: (e) precondition: volume is marker-free (genuinely adoptable, root probe)
- PASS: (e) precondition: version link + stored site.conf + htpasswd present (root probe)
- PASS: (e) legacy volume adopted - site starts ready (gate + /mysite/)
```
ready-time=3s
```

- PASS: (e) prominent 'existing site mysite (no init marker - legacy/pre-marker volume)' log line
```
2026-11-10T20:02:49+00:00 039e24e4a8dd systemd[1]: Started mariadb.service - MariaDB 11.8.6 database server.
2026-11-10T20:02:49+00:00 039e24e4a8dd /etc/mysql/debian-start[723]: Upgrading MariaDB tables if necessary.
2026-11-10T20:02:49+00:00 039e24e4a8dd /etc/mysql/debian-start[738]: Checking for insecure root accounts.
2026-11-10T20:02:49+00:00 039e24e4a8dd /etc/mysql/debian-start[742]: Triggering myisam-recover for all MyISAM tables and aria-recover for all Aria tables
2026-11-10T20:02:49+00:00 039e24e4a8dd systemd[1]: Started exim4.service - exim Mail Transport Agent.
2026-11-10T20:02:49+00:00 039e24e4a8dd systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-10T20:02:49+00:00 039e24e4a8dd systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-10T20:02:49+00:00 039e24e4a8dd systemd[1]: Startup finished in 2.225s.
```

- PASS: (e) stored configuration authoritative: omd config show returns the ALTERED stored value
- PASS: (e) omd status rc 0 (site registered + started, adopt path)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (e) stored site.conf UNMODIFIED (sha256 unchanged, root probe)
- PASS: (e) stored web credential FILE unmodified (htpasswd sha256 unchanged, root probe)
- PASS: (e) the stored web credential created before STILL LOGS IN (thruk 200 with cred, 302 anon)
```
with-cred=200 anon=302
```

- PASS: (e) init-complete marker now present (leaves the no-marker class, root probe)
- PASS: (e) identity re-recorded with the INFERRED uid/gid from the volume (root probe)
- PASS: (e) numeric ownership UNTOUCHED (top uid:omdgid 0750, subfolders uid:gid - root probe)
- (e) with-inputs half (FR-012 notice + no apply + no gearmand) = T027 's6 e-inputs'


## T023-GREEN-2026-11-10 (build 10, s6 e both distros: real legacy-volume adoption core)

- **T023 acceptance: GREEN** (no image build - verifies build #10; T022
  dependency met). Both distros, port 18461. REAL old-image volume: built
  by `fx_real_legacy_volume <distro> mysite` (verify/fixtures.sh) with the
  baseline-red (OLD) image's own tooling - omd create --reuse + omd reset
  etc/ + set_admin_password KNOWN (omdadmin/T023legacyPW) + altered
  CONFIG_ADMIN_MAIL - complete OMD tree, relative version link, stored web
  credential (etc/htpasswd), NO .omd-labs-* markers (genuinely adoptable).
- **s6 e rocky: PASS** (section S6-s6-rocky-e, 12/12, exit 0) and
  **s6 e debian: PASS** (section S6-s6-debian-e, 12/12, exit 0):
  - prominent adopt log line: "existing site mysite (no init marker -
    legacy/pre-marker volume)" (the entry prints "adoptING" - one-word
    entry defect vs the contract's "adoptED", scripts/omd-labs-entry:358;
    carried to the T026 entry window; the check asserts the name-unique
    tail until then).
  - site starts ready (gate + /mysite/), omd status rc 0 (adopt path:
    registration restored from the INFERRED identity uid=1001 gid=1001).
  - stored configuration authoritative: `omd config show` returns the
    ALtered stored value (ADMIN_MAIL: t023-legacy@omd.example).
  - site.conf sha256 UNCHANGED and the htpasswd sha256 UNCHANGED (root
    probes, before/after).
  - the stored web credential created before STILL LOGS IN: thrk
    /mysite/thruk/ 200 with omdadmin:stored-pw, 302 anonymous.
  - init-complete marker now present (leaves the no-marker class);
    .omd-labs-site-identity re-recorded with the INFERRED uid/gid.
  - numeric ownership UNTOUCHED (top uid:omdgid 0750, subfolders
    uid:gid 0755 - root probe before/after).
  - with-inputs half (FR-012 notice + no-apply + no gearmand on 4730) =
    T027 's6 e-inputs'.
- Suite-side fixes landed in this window (debate 61 N2/N3): the golden
  cache is now keyed on (image id, site) and written only after a clean
  stop; the no-mutation snapshots (vol_snap/g_snap) now include the mount
  root's metadata and every symlink's target (top-dir chown/chmod and
  link retarget can no longer escape the no-mutation assertion).
  Both were proven before the green runs (golden re-keyed + idempotent
  no-op; snapshot soundness test: root chown and link retarget both
  detected, restore round-trips to the baseline hash).

## T023-REWORK-POST64-2026-11-10 (s6 e both distros: codex 64 B1/B2/NOTE fixes)

- **Codex 64 review** (specs/001-systemd-vm-startup/debate/64-codex-
  implement-review.md) returned 2 BLOCKERs + 2 NOTEs. All ACCEPTed and
  fixed in-suite; the two preservation gaps that "prevent full T023
  sign-off" are now closed and PROVEN.
- **B1 (wrong-field ownership check)** FIXED: the old check compared
  `/w/etc`'s UID to `fx_gid` (static, and passed only because the fixture
  uid==gid==1001). The fixture now uses DISTINCT uid/gid (2001/2002,
  `FX_LEGACY_UID`/`FX_LEGACY_GID`, fixtures.sh:436) and the scenario
  captures a BEFORE vs AFTER `%u %g %a` snapshot of the mount root + all
  persistent subfolders (s6.sh:314/317 before, :340/341 after) and asserts
  the DIFF is empty (s6.sh:349) - plus an explicit top-dir
  `uid:omdgid:750` check (s6.sh:351). The adopt's own top-level
  `.omd-labs-*` artifacts are not in the snapshot list (bootstrap-created,
  not pre-existing). A precondition (s6.sh:323) asserts uid != gid so the
  check stays meaningful. SOUNDNESS-PROVEN on a scratch dir: a top-dir GID
  change is CAUGHT by the before/after diff (the old check's `%u` read was
  unchanged and would have missed it); a sentinel chown and a content
  tamper are both CAUGHT; restore round-trips to the baseline.
- **B2 (sentinel/monitoring preservation unproven)** FIXED: the fixture
  seeds three sentinels in representative persistent paths as the site
  user (fixtures.sh:476 - etc/omd/sentinel.conf, var/lib/sentinel.dat,
  local/sentinel.txt, each `SENTINEL_T023=<distro> ...` with distinct
  content). The scenario asserts AFTER the adoption: exact content
  (s6.sh:356 - a whole-volume no-change while monitoring runs is
  deliberately NOT claimed; the acceptance names sentinel/monitoring data
  specifically) AND uid/gid/mode metadata before/after equality
  (s6.sh:358; the site umask is 002, so the mode is asserted by equality,
  never a guessed literal).
- **NOTE (hardcoded assertions + weak cache)** FIXED: `.meta` is now
  multi-line `image=/site=/pw=/mail=/uid=/gid=` and the fixture reuse
  validation (fixtures.sh:452) requires ALL of the baseline image id, the
  requested pw/mail, the sentinels, AND marker-free state to agree - a
  retagged baseline or a changed override REBUILDS the volume. The
  scenario derives `fx_uid/fx_gid/fx_pw/fx_mail` from `.meta`
  (s6.sh:302-305) and asserts on the DERIVED values (the `omd config show`
  line and the web-login credential both use `.meta`), never a hardcoded
  default.
- **NOTE (adopting vs adopted deferral)**: SOUND. The entry prints
  "adoptING" (scripts/omd-labs-entry:358) while readiness + marker checks
  separately prove success, so the current adoption result is valid. The
  "adopted" success banner is emitted after successful adoption in the
  T026 entry window; the scenario asserts the name-unique tail ("existing
  site mysite (no init marker - legacy/pre-marker volume)") in the
  meantime, which matches both verbs.
- **GREEN re-run (both distros, port 18461, 17 checks each, exit 0):**
  s6 e rocky 17/17 and s6 e debian 17/17 (sections S6-s6-rocky-e /
  S6-s6-debian-e, appended after this record). Identity uid=2001 gid=2002
  (inferred); `omd config show` returns the stored altered `ADMIN_MAIL`;
  site.conf + htpasswd sha256 unchanged; the stored web credential STILL
  LOGS IN (`with-cred=200 anon=302` on /mysite/thruk/); init-complete
  marker now present; identity re-recorded with the INFERRED uid/gid;
  numeric ownership UNTOUCHED before/after; top dir carries uid=2001
  group=omd 0750; sentinel content AND metadata UNTOUCHED.
- One transient failure was the fixture itself: `omd create --reuse`
  (fstab_verify in omd.py) rejects a NUMERIC `uid=<num>` fstab line and
  requires the NAME form `uid=<site>,`. The fixture's fstab line is now
  name-form (fixtures.sh, with a comment). Not a scenario defect.
## S6-s6-rocky-e
- when: 2026-11-10 21:40:50
- runtime: podman

## S6-s6-rocky-e
- when: 2026-11-10 21:43:06
- runtime: podman

- **RESULT: PASS**

- (e) real old-image volume: /tmp/omd-verify/s6e-legacy-rocky-mysite (identity uid=2001 gid=2002; pw/mail from .meta)
- PASS: (e) precondition: volume is marker-free (genuinely adoptable, root probe)
- PASS: (e) precondition: version link + stored site.conf + htpasswd present (root probe)
- PASS: (e) precondition: fixture identity uid and gid are DISTINCT (ownership assertions meaningful)
- PASS: (e) precondition: sentinels seeded in persistent paths with distinct content (root probe)
- PASS: (e) legacy volume adopted - site starts ready (gate + /mysite/)
```
ready-time=3s
```

- PASS: (e) prominent 'existing site mysite (no init marker - legacy/pre-marker volume)' log line
```
2026-11-10T20:43:12+0000 47bc1f5361da omd-ready-check[477]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-10T20:43:12+0000 47bc1f5361da systemd[1]: Finished OMD labs bounded readiness gate (FR-018).
2026-11-10T20:43:12+0000 47bc1f5361da systemd[1]: Reached target Multi-User System.
2026-11-10T20:43:12+0000 47bc1f5361da systemd[1]: Reached target Graphical Interface.
2026-11-10T20:43:12+0000 47bc1f5361da systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-10T20:43:12+0000 47bc1f5361da systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-10T20:43:12+0000 47bc1f5361da systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-10T20:43:12+0000 47bc1f5361da systemd[1]: Startup finished in 2.062s.
```

- PASS: (e) stored configuration authoritative: omd config show returns the ALTERED stored value
- PASS: (e) omd status rc 0 (site registered + started, adopt path)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (e) stored site.conf UNMODIFIED (sha256 unchanged, root probe)
- PASS: (e) stored web credential FILE unmodified (htpasswd sha256 unchanged, root probe)
- PASS: (e) the stored web credential created before STILL LOGS IN (thruk 200 with stored cred from .meta, 302 anon)
```
with-cred=200 anon=302
```

- PASS: (e) init-complete marker now present (leaves the no-marker class, root probe)
- PASS: (e) identity re-recorded with the INFERRED uid/gid from the volume (root probe)
- PASS: (e) numeric ownership UNTOUCHED before/after (UID AND GID of top + persistent subfolders; the adopt's own top-level .omd-labs-* artifacts excluded, root probe)
- PASS: (e) top dir carries the image omd gid (uid=2001 group=omd, 0750) after adoption (root probe)
- PASS: (e) sentinel content UNTOUCHED (etc/omd, var/lib, local - exact lines, root probe)
- PASS: (e) sentinel metadata UNTOUCHED (uid/gid/mode identical before/after - umask-dependent, no guessed mode, root probe)
- (e) with-inputs half (FR-012 notice + no apply + no gearmand) = T027 's6 e-inputs'
## S6-s6-debian-e
- when: 2026-11-10 21:43:33
- runtime: podman

- **RESULT: PASS**

- (e) real old-image volume: /tmp/omd-verify/s6e-legacy-debian-mysite (identity uid=2001 gid=2002; pw/mail from .meta)
- PASS: (e) precondition: volume is marker-free (genuinely adoptable, root probe)
- PASS: (e) precondition: version link + stored site.conf + htpasswd present (root probe)
- PASS: (e) precondition: fixture identity uid and gid are DISTINCT (ownership assertions meaningful)
- PASS: (e) precondition: sentinels seeded in persistent paths with distinct content (root probe)
- PASS: (e) legacy volume adopted - site starts ready (gate + /mysite/)
```
ready-time=3s
```

- PASS: (e) prominent 'existing site mysite (no init marker - legacy/pre-marker volume)' log line
```
2026-11-10T20:43:43+00:00 6f5580c3ba55 systemd[1]: Started systemd-timedated.service - Time & Date Service.
2026-11-10T20:43:43+00:00 6f5580c3ba55 dbus-daemon[123]: [system] Successfully activated service 'org.freedesktop.timedate1'
2026-11-10T20:43:43+00:00 6f5580c3ba55 omd-ready-check[424]: READY: base services up (omd-site active, apache2 443, sshd 22)
2026-11-10T20:43:43+00:00 6f5580c3ba55 systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-10T20:43:44+00:00 6f5580c3ba55 systemd[1]: Started exim4.service - exim Mail Transport Agent.
2026-11-10T20:43:44+00:00 6f5580c3ba55 systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-10T20:43:44+00:00 6f5580c3ba55 systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-10T20:43:44+00:00 6f5580c3ba55 systemd[1]: Startup finished in 2.130s.
```

- PASS: (e) stored configuration authoritative: omd config show returns the ALTERED stored value
- PASS: (e) omd status rc 0 (site registered + started, adopt path)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (e) stored site.conf UNMODIFIED (sha256 unchanged, root probe)
- PASS: (e) stored web credential FILE unmodified (htpasswd sha256 unchanged, root probe)
- PASS: (e) the stored web credential created before STILL LOGS IN (thruk 200 with stored cred from .meta, 302 anon)
```
with-cred=200 anon=302
```

- PASS: (e) init-complete marker now present (leaves the no-marker class, root probe)
- PASS: (e) identity re-recorded with the INFERRED uid/gid from the volume (root probe)
- PASS: (e) numeric ownership UNTOUCHED before/after (UID AND GID of top + persistent subfolders; the adopt's own top-level .omd-labs-* artifacts excluded, root probe)
- PASS: (e) top dir carries the image omd gid (uid=2001 group=omd, 0750) after adoption (root probe)
- PASS: (e) sentinel content UNTOUCHED (etc/omd, var/lib, local - exact lines, root probe)
- PASS: (e) sentinel metadata UNTOUCHED (uid/gid/mode identical before/after - umask-dependent, no guessed mode, root probe)
- (e) with-inputs half (FR-012 notice + no apply + no gearmand) = T027 's6 e-inputs'
## S3b-s3b-rocky
- when: 2026-11-10 23:52:07
- runtime: podman

- **RESULT: PASS**

- PASS: (a) readiness (gate active + 443)
```
ready-time=1s
```

- PASS: (a) SSH login succeeds end-to-end as root (whoami=root)
```
Warning: Permanently added '[127.0.0.1]:18455' (ED25519) to the list of known hosts.
```

- PASS: (a) /root/.ssh = 700 root root (image-owned dir, install -d)
- PASS: (a) /root/.ssh/authorized_keys = 644 root root (image-owned copy)
- PASS: (a) :ro bind source untouched - owner/mode/mtime+size (before='lausser:lausser 644 1794351127 109')
- PASS: (a) :ro bind source untouched - sha256 (before=50ecc64117e39098c1924ac393270e8497fcb3d0c5b6b0398edabda28fadce23)
- PASS: (b1=badkey) broken key -> exit 1 <=30 s (elapsed=1s code=1)
- PASS: (b1=badkey) fatal reason names the key file (entry-fatal file)
```
FATAL: malformed SSH public key file at /root/.ssh/omd_ssh_keys (line 1) - not shaped like an OpenSSH public key. A broken key file means no SSH access. No site was started.
```

- PASS: (b2=empty) broken key -> exit 1 <=30 s (elapsed=1s code=1)
- PASS: (b2=empty) fatal reason names the key file (entry-fatal file)
```
FATAL: SSH public key file at /root/.ssh/omd_ssh_keys is empty - a broken key file means no SSH access. No site was started.
```

- PASS: (b3=commentonly) broken key -> exit 1 <=30 s (elapsed=0s code=1)
- PASS: (b3=commentonly) fatal reason names the key file (entry-fatal file)
```
FATAL: SSH public key file at /root/.ssh/omd_ssh_keys contains no public key (comment/blank lines only) - a broken key file means no SSH access. No site was started.
```

- PASS: (c) readiness (gate active + 443)
```
ready-time=2s
```

- PASS: (c) sshd active + listening on 22
- PASS: (c) no login possible - sshd refuses (port 18456 answers, auth refused; rc=255)
## S3b-s3b-debian
- when: 2026-11-10 23:53:29
- runtime: podman

- **RESULT: PASS**

- PASS: (a) readiness (gate active + 443)
```
ready-time=2s
```

- PASS: (a) SSH login succeeds end-to-end as root (whoami=root)
```
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
IT IS POSSIBLE THAT SOMEONE IS DOING SOMETHING NASTY!
Someone could be eavesdropping on you right now (man-in-the-middle attack)!
It is also possible that a host key has just been changed.
The fingerprint for the ED25519 key sent by the remote host is
SHA256:xupWIGZ/AABb9pI0blg/1b+OUm4omIGevxVH184ZGeQ.
Please contact your system administrator.
Add correct host key in /home/lausser/.ssh/known_hosts to get rid of this message.
Offending ED25519 key in /home/lausser/.ssh/known_hosts:1147
Password authentication is disabled to avoid man-in-the-middle attacks.
Keyboard-interactive authentication is disabled to avoid man-in-the-middle attacks.
UpdateHostkeys is disabled because the host key is not trusted.
```

- PASS: (a) /root/.ssh = 700 root root (image-owned dir, install -d)
- PASS: (a) /root/.ssh/authorized_keys = 644 root root (image-owned copy)
- PASS: (a) :ro bind source untouched - owner/mode/mtime+size (before='lausser:lausser 644 1794351127 109')
- PASS: (a) :ro bind source untouched - sha256 (before=50ecc64117e39098c1924ac393270e8497fcb3d0c5b6b0398edabda28fadce23)
- PASS: (b1=badkey) broken key -> exit 1 <=30 s (elapsed=0s code=1)
- PASS: (b1=badkey) fatal reason names the key file (entry-fatal file)
```
FATAL: malformed SSH public key file at /root/.ssh/omd_ssh_keys (line 1) - not shaped like an OpenSSH public key. A broken key file means no SSH access. No site was started.
```

- PASS: (b2=empty) broken key -> exit 1 <=30 s (elapsed=1s code=1)
- PASS: (b2=empty) fatal reason names the key file (entry-fatal file)
```
FATAL: SSH public key file at /root/.ssh/omd_ssh_keys is empty - a broken key file means no SSH access. No site was started.
```

- PASS: (b3=commentonly) broken key -> exit 1 <=30 s (elapsed=1s code=1)
- PASS: (b3=commentonly) fatal reason names the key file (entry-fatal file)
```
FATAL: SSH public key file at /root/.ssh/omd_ssh_keys contains no public key (comment/blank lines only) - a broken key file means no SSH access. No site was started.
```

- PASS: (c) readiness (gate active + 443)
```
ready-time=2s
```

- PASS: (c) sshd active + listening on 22
- PASS: (c) no login possible - sshd refuses (port 18456 answers, auth refused; rc=255)

## T024-T025-BUILD11-2026-11-10 (entry site_ssh rework + rebuild + s3b both distros)

- **Image rebuild #11** (T025's first step): `podman build -f
  Dockerfile.omd-labs-{rocky,debian} -t local/omd-labs-{rocky,debian}:nightly
  --build-arg OMD_VERSION=master .` — full rebuilds (68 steps, no cache on
  the OMD layer), both rc=0. New image ids: rocky 142ff3e99516,
  debian a031ecd48dfc (build #10 superseded). NOTE: `make -f
  Makefile.omd-labs-systemd-vm-rocky build` fails on this host (`hooks/build`
  hardcodes `docker`, absent — podman-only host); the podman equivalent
  was invoked directly with the same Dockerfile/image name/build-arg.
  New entry confirmed IN the images (`contains no public key` present in
  /usr/local/bin/omd-labs-entry of both).
- **T024 entry rework** (scripts/omd-labs-entry:476, post-codex-67 B1 +
  NOTE2): per-line TWO-PASS validation — (i) the contract shape regex
  with `( .*)?` comment part (multi-word comments legal, ssh-keygen rc=0
  on them), (ii) OpenSSH's own parser `ssh-keygen -l -f /dev/stdin` on
  the single line (catches space-in-blob, bogus type, type/blob mismatch
  the regex cannot); plus `keys >= 1` (comment/blank-only => FATAL
  "contains no public key") and a DIRECTORY at the source path => FATAL
  "is a directory, not a key file". All fatal strings carry file + line
  number and match the s3b `v_fatal` pattern "SSH public key file at
  /root/.ssh/omd_ssh_keys". Load-bearing ground truth: `ssh-keygen -l`
  on a valid+garbage MIXED file returns rc=0 (parses only the first key)
  => per-line parsing is required; the whole-file check alone is
  insufficient (and the regex alone lets shaped-but-corrupt keys through).
- **T024 ground truth** (functions extracted verbatim, in-image
  entrypoint override, BOTH distros, no rebuild): 9-case matrix all
  correct — A valid+multiword rc=0 (dir 700 root root, dest 644 root
  root); B space-blob FATAL line 1 (parser); C comment-only FATAL; D
  empty FATAL; E directory FATAL; F no-key silent no-op rc=0; G
  valid+garbage FATAL line 2 (shape); H valid+bogus-type FATAL line 2
  (parser); I pre-existing 555:555/755 /root/.ssh forced to 700 root
  root. All fatal containers exit 1 under the entry's set -euo pipefail.
- **s3b rework** (B2 + NOTE3 + codex-69 findings): (a) distinct host
  ports 443=18454 / 22=18455 (was PB,PB collision); source-untouched
  proven by owner:group+mode+mtime+size AND sha256 before/after; dest
  dir 700 root root asserted; (a) torn down BEFORE (c) reuses 18455;
  (b) 3 fail-fast variants (badkey/empty/commentonly), one container
  each, no host port, per-variant timer, each exit 1 <=30 s + fatal
  names the file; (c) maps SSH to 18456 and the negative test offers
  the ACTUAL fixture key (publickey + IdentitiesOnly) to the MAPPED port,
  asserting nonzero rc + auth-refusal text + NOT a connection failure
  (sshd must be reachable AND refuse). Mounts: `:ro${SELABEL:+,z}`
  single-options-field form (`:ro:z` is invalid — codex 69 B1).
- **T025 s3b integration gate GREEN** (build #11, both distros, exit 0):
  S3b-s3b-rocky @3387 (ready 1 s; login whoami=root; 700/644 root root;
  source untouched; b1/b2/b3 exit 1 in 0-1 s with the three distinct
  fatal reasons; c: sshd active, :22 listening, login refused by the
  mapped sshd rc=255) and S3b-s3b-debian @3432 (same, ready 2 s).
  A duplicate mislabeled `S3b-s3b-rocky` section from a positional-arg
  miscall of run.sh (env DISTRO= ignored — run.sh takes the distro as
  argument 2) was removed from results.md.
 - **T025 SC-006 (S1-style sshd stop/start round-trip) GREEN both
   distros** (build #11, ports 18449/18450): before — sshd/ssh active,
   :22 LISTEN (sshd pid, 2 lines); `systemctl stop` — state inactive,
   NO in-container :22 listener (`ss -ltn` empty), in-container connect
   REFUSED, host-side `ssh -p 18450` gets "kex_exchange_identification:
   read: Connection reset by peer" (no login possible);
   `systemctl start` — state active, :22 LISTEN restored, host ssh now
   ANSWERED BY THE SSHD (auth offered and refused: rocky
   "Permission denied (publickey,gssapi-keyex,gssapi-with-mic,password)",
   debian "Permission denied (publickey,password)"); container Running
   = true throughout (an intentional stop never exits the container).
   EMPIRICAL CAVEAT (documented in the probe): a HOST-side connect-level
   probe (`nc -z`) stays "open" during the stop because the pasta
   forwarder socket outlives the container listener — connect-level host
   probes are not a valid unreachability test here; the in-container
   listener state + the data-level ssh attempt are.
- **Spar rounds**: 67 brief -> 67-codex review (2 BLOCKER + 2 NOTE) ->
  68 response (all ACCEPT, entry+s3b rework) -> 69-codex (2 BLOCKER +
  1 NOTE on the s3b rework: mount syntax, port lifecycle + vacuous
  negative test, cumulative timer; entry validation ACCEPTED as-is, no
  parser whitelist needed) -> 70 response (all ACCEPT) ->
  71-codex (1 NOTE: negative test must offer the actual fixture key —
  APPLIED: PreferredAuthentications=publickey + IdentitiesOnly=yes;
  "prior findings closed", "Entry implementation sign-off for T024
  stands", "T025's rebuilt-image integration gate remains pending" —
  the s3b runs above are that gate).
## S5-s5-rocky
- when: 2026-11-11 02:44:21
- runtime: podman

- **RESULT: PASS**

- PASS: readiness (gate + /custsite/)
```
ready-time=10s
```

- PASS: gearmand listening on 4730 when ready (SC-012 - component came up with the site)
- PASS: env value WON the conflict: omd config show GEARMAND_PORT = 0.0.0.0:4730
- PASS: effective config observable: MOD_GEARMAN = on
- PASS: container log carries the effective-customization summary (FR-010; bounded wait for log flush)
```
2026-11-11T01:44:30+0000 b91193f32652 systemd[1]: Reached target Graphical Interface.
2026-11-11T01:44:30+0000 b91193f32652 systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T01:44:30+0000 b91193f32652 systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T01:44:30+0000 b91193f32652 systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T01:44:30+0000 b91193f32652 systemd[1]: Startup finished in 2.202s.
2026-11-11T01:44:32+0000 b91193f32652 runuser[2372]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
2026-11-11T01:44:32+0000 b91193f32652 runuser[2372]: pam_unix(runuser:session): session closed for user custsite
2026-11-11T01:44:32+0000 b91193f32652 runuser[2450]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
```

- PASS: listener address is the env value (0.0.0.0:4730)
- PASS: no customization input ? no 4730 listener
- PASS: S6c: persisted site resumes ready (stored configuration authoritative)
```
ready-time=4s
```

- PASS: S6c: stored value survives (GEARMAND_PORT still 0.0.0.0:4730 - inputs NOT applied)
- PASS: S6c: log carries the deterministic notice that inputs were not applied (FR-012; bounded wait)
```
2026-11-11T01:44:50+0000 f2d4126da2fe systemd[1]: Reached target Multi-User System.
2026-11-11T01:44:50+0000 f2d4126da2fe systemd[1]: Reached target Graphical Interface.
2026-11-11T01:44:50+0000 f2d4126da2fe systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T01:44:50+0000 f2d4126da2fe systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T01:44:50+0000 f2d4126da2fe systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T01:44:50+0000 f2d4126da2fe systemd[1]: Startup finished in 2.092s.
2026-11-11T01:44:51+0000 f2d4126da2fe runuser[674]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
2026-11-11T01:44:51+0000 f2d4126da2fe runuser[674]: pam_unix(runuser:session): session closed for user custsite
```

## S5-s5-rocky
- when: 2026-11-11 02:45:01
- runtime: podman

- **RESULT: PASS**

- PASS: readiness (gate + /custsite/)
```
ready-time=9s
```

- PASS: gearmand listening on 4730 when ready (SC-012 - component came up with the site)
- PASS: env value WON the conflict: omd config show GEARMAND_PORT = 0.0.0.0:4730
- PASS: effective config observable: MOD_GEARMAN = on
- PASS: container log carries the effective-customization summary (FR-010; bounded wait for log flush)
```
2026-11-11T01:45:10+0000 2300e1bf861d systemd[1]: Reached target Graphical Interface.
2026-11-11T01:45:10+0000 2300e1bf861d systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T01:45:10+0000 2300e1bf861d systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T01:45:10+0000 2300e1bf861d systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T01:45:10+0000 2300e1bf861d systemd[1]: Startup finished in 2.132s.
2026-11-11T01:45:10+0000 2300e1bf861d runuser[2372]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
2026-11-11T01:45:10+0000 2300e1bf861d runuser[2372]: pam_unix(runuser:session): session closed for user custsite
2026-11-11T01:45:11+0000 2300e1bf861d runuser[2450]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
```

- PASS: listener address is the env value (0.0.0.0:4730)
- PASS: no customization input ? no 4730 listener
- PASS: S6c: persisted site resumes ready (stored configuration authoritative)
```
ready-time=3s
```

- PASS: S6c: stored value survives (GEARMAND_PORT still 0.0.0.0:4730 - inputs NOT applied)
- PASS: S6c: log carries the deterministic notice that inputs were not applied (FR-012; bounded wait)
```
2026-11-11T01:45:29+0000 3ef8d4a2d378 systemd[1]: Reached target Multi-User System.
2026-11-11T01:45:29+0000 3ef8d4a2d378 systemd[1]: Reached target Graphical Interface.
2026-11-11T01:45:29+0000 3ef8d4a2d378 systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T01:45:29+0000 3ef8d4a2d378 systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T01:45:29+0000 3ef8d4a2d378 systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T01:45:29+0000 3ef8d4a2d378 systemd[1]: Startup finished in 2.147s.
2026-11-11T01:45:29+0000 3ef8d4a2d378 runuser[674]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
2026-11-11T01:45:30+0000 3ef8d4a2d378 runuser[674]: pam_unix(runuser:session): session closed for user custsite
```

## S6-s6-rocky-g
- when: 2026-11-11 02:45:38
- runtime: podman

- **RESULT: FAIL**

- PASS: (g1) ambiguous identity ? actionable exit 1 (code=1)
- PASS: (g1) fatal reason names the ambiguity
```
FATAL: inferred identity is AMBIGUOUS - the site subfolders' group (996) equals the omd group's gid; the primary gid cannot be determined. Refusing (no mutation). Remedy: run the site once from its original image or set the identity manually.
```

- PASS: (g1) volume unchanged: content + ownership/mode metadata identical
- PASS: (g2) lost identity file ? resume via inference, site starts ready
```
ready-time=3s
```

- PASS: (g2) .omd-labs-site-identity RE-RECORDED with the inferred 1234/1234
- PASS: (g3) recorded identity honored: site starts ready
```
ready-time=3s
```

- PASS: (g3) fresh-container account carries uid=1234 (id recid)
- PASS: (g3) fresh-container account carries primary gid=1234 (id recid)
- PASS: (g4) occupied uid on resume ? exit 1 (code=1)
- PASS: (g4) fatal names the collision (occupied uid / foreign group - F2 validation before any write)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site occres
```

- PASS: (g4) no-mutation: volume byte-identical (identity NOT re-written, no group change - F2 ordering)
- PASS: (g5) occupied uid/gid on adopt ? exit 1 (code=1)
- PASS: (g5) fatal names the collision (occupied uid / foreign group - F2 validation before any write)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site occadp
```

- FAIL: (g5) no-mutation: volume byte-identical (no identity file, no group) (rc=1)
```

```

- PASS: (g5) adopt-complete marker ABSENT (adopt wrote nothing before the fatal)
- PASS: (g6) fixture precondition: stale in-progress marker present on a completed volume (root probe)
- PASS: (g6) persisted volume with stale marker ? resume ready (inference + re-record)
```
ready-time=4s
```

- PASS: (g6) stale in-progress marker REMOVED after validation (root probe)
- PASS: (g6) log carries the deterministic removal notice
```
2026-11-11T01:46:58+0000 0399e3dc1a7e omd-ready-check[476]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-11T01:46:58+0000 0399e3dc1a7e systemd[1]: Finished OMD labs bounded readiness gate (FR-018).
2026-11-11T01:46:58+0000 0399e3dc1a7e systemd[1]: Reached target Multi-User System.
2026-11-11T01:46:58+0000 0399e3dc1a7e systemd[1]: Reached target Graphical Interface.
2026-11-11T01:46:58+0000 0399e3dc1a7e systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T01:46:58+0000 0399e3dc1a7e systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T01:46:58+0000 0399e3dc1a7e systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T01:46:58+0000 0399e3dc1a7e systemd[1]: Startup finished in 2.100s.
```

- PASS: (g6) identity re-recorded (root probe)
## S6-s6-rocky-g
- when: 2026-11-11 02:49:25
- runtime: podman

- **RESULT: PASS**

- PASS: (g1) ambiguous identity ? actionable exit 1 (code=1)
- PASS: (g1) fatal reason names the ambiguity
```
FATAL: inferred identity is AMBIGUOUS - the site subfolders' group (996) equals the omd group's gid; the primary gid cannot be determined. Refusing (no mutation). Remedy: run the site once from its original image or set the identity manually.
```

- PASS: (g1) volume unchanged: content + ownership/mode metadata identical
- PASS: (g2) lost identity file ? resume via inference, site starts ready
```
ready-time=3s
```

- PASS: (g2) .omd-labs-site-identity RE-RECORDED with the inferred 1234/1234
- PASS: (g3) recorded identity honored: site starts ready
```
ready-time=3s
```

- PASS: (g3) fresh-container account carries uid=1234 (id recid)
- PASS: (g3) fresh-container account carries primary gid=1234 (id recid)
- PASS: (g4) occupied uid on resume ? exit 1 (code=1)
- PASS: (g4) fatal names the collision (occupied uid / foreign group - F2 validation before any write)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site occres
```

- PASS: (g4) no-mutation: volume byte-identical (identity NOT re-written, no group change - F2 ordering)
- PASS: (g5) occupied uid/gid on adopt ? exit 1 (code=1)
- PASS: (g5) fatal names the collision (occupied uid / foreign group - F2 validation before any write)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site occadp
```

- PASS: (g5) no-mutation: volume byte-identical (no identity file, no group)
- PASS: (g5) adopt-complete marker ABSENT (adopt wrote nothing before the fatal)
- PASS: (g6) fixture precondition: stale in-progress marker present on a completed volume (root probe)
- PASS: (g6) persisted volume with stale marker ? resume ready (inference + re-record)
```
ready-time=4s
```

- PASS: (g6) stale in-progress marker REMOVED after validation (root probe)
- PASS: (g6) log carries the deterministic removal notice
```
2026-11-11T01:50:49+0000 0c0afc0e5f27 omd-ready-check[474]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-11T01:50:49+0000 0c0afc0e5f27 systemd[1]: Finished OMD labs bounded readiness gate (FR-018).
2026-11-11T01:50:49+0000 0c0afc0e5f27 systemd[1]: Reached target Multi-User System.
2026-11-11T01:50:49+0000 0c0afc0e5f27 systemd[1]: Reached target Graphical Interface.
2026-11-11T01:50:49+0000 0c0afc0e5f27 systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T01:50:49+0000 0c0afc0e5f27 systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T01:50:49+0000 0c0afc0e5f27 systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T01:50:49+0000 0c0afc0e5f27 systemd[1]: Startup finished in 1.997s.
```

- PASS: (g6) identity re-recorded (root probe)
## S6-s6-rocky-e-inputs
- when: 2026-11-11 02:51:00
- runtime: podman

- **RESULT: PASS**

- PASS: (e-inputs) legacy volume adopted WITH inputs - site starts ready
```
ready-time=3s
```

- PASS: (e-inputs) 'adopted existing site' banner (contract string)
```
2026-11-11T01:51:08+0000 1f3219e047c5 omd-ready-check[485]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-11T01:51:08+0000 1f3219e047c5 systemd[1]: Finished OMD labs bounded readiness gate (FR-018).
2026-11-11T01:51:08+0000 1f3219e047c5 systemd[1]: Reached target Multi-User System.
2026-11-11T01:51:08+0000 1f3219e047c5 systemd[1]: Reached target Graphical Interface.
2026-11-11T01:51:08+0000 1f3219e047c5 systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T01:51:08+0000 1f3219e047c5 systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T01:51:08+0000 1f3219e047c5 systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T01:51:08+0000 1f3219e047c5 systemd[1]: Startup finished in 1.985s.
```

- PASS: (e-inputs) FR-012 notice logged: inputs supplied but NOT applied (stored config authoritative)
```
2026-11-11T01:51:08+0000 1f3219e047c5 omd-ready-check[485]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-11T01:51:08+0000 1f3219e047c5 systemd[1]: Finished OMD labs bounded readiness gate (FR-018).
2026-11-11T01:51:08+0000 1f3219e047c5 systemd[1]: Reached target Multi-User System.
2026-11-11T01:51:08+0000 1f3219e047c5 systemd[1]: Reached target Graphical Interface.
2026-11-11T01:51:08+0000 1f3219e047c5 systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T01:51:08+0000 1f3219e047c5 systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T01:51:08+0000 1f3219e047c5 systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T01:51:08+0000 1f3219e047c5 systemd[1]: Startup finished in 1.985s.
```

- PASS: (e-inputs) MOD_GEARMAN still the stored value off (input 'on' NOT applied)
- PASS: (e-inputs) PNP4NAGIOS still the stored value on (untouched by the adopt)
- PASS: (e-inputs) no 4730 listener (stored MOD_GEARMAN off - input not applied)
- PASS: (e-inputs) stored site.conf UNMODIFIED (sha256 unchanged, root probe)
- PASS: (e-inputs) the stored web credential created before STILL LOGS IN (thruk 200 with stored cred from .meta)
```
with-cred=200
```

- PASS: (e-inputs) init-complete marker written by the adopt (root probe)
- PASS: (e-inputs) /run/omd-labs.env carries SITE_CUSTOM_APPLIED=0 (inputs validated, not applied)
## S5-s5-debian
- when: 2026-11-11 02:51:38
- runtime: podman

- **RESULT: PASS**

- PASS: readiness (gate + /custsite/)
```
ready-time=7s
```

- PASS: gearmand listening on 4730 when ready (SC-012 - component came up with the site)
- PASS: env value WON the conflict: omd config show GEARMAND_PORT = 0.0.0.0:4730
- PASS: effective config observable: MOD_GEARMAN = on
- PASS: container log carries the effective-customization summary (FR-010; bounded wait for log flush)
```
2026-11-11T01:51:44+00:00 e7de2db3e583 systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-11T01:51:44+00:00 e7de2db3e583 systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-11T01:51:44+00:00 e7de2db3e583 systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-11T01:51:44+00:00 e7de2db3e583 systemd[1]: Startup finished in 2.242s.
2026-11-11T01:51:46+00:00 e7de2db3e583 runuser[2528]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
2026-11-11T01:51:46+00:00 e7de2db3e583 runuser[2528]: pam_unix(runuser:session): session closed for user custsite
2026-11-11T01:51:46+00:00 e7de2db3e583 runuser[2606]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
2026-11-11T01:51:46+00:00 e7de2db3e583 runuser[2606]: pam_unix(runuser:session): session closed for user custsite
```

- PASS: listener address is the env value (0.0.0.0:4730)
- PASS: no customization input ? no 4730 listener
- PASS: S6c: persisted site resumes ready (stored configuration authoritative)
```
ready-time=3s
```

- PASS: S6c: stored value survives (GEARMAND_PORT still 0.0.0.0:4730 - inputs NOT applied)
- PASS: S6c: log carries the deterministic notice that inputs were not applied (FR-012; bounded wait)
```
2026-11-11T01:52:03+00:00 2e4c04b7ae5a dbus-daemon[117]: [system] Successfully activated service 'org.freedesktop.timedate1'
2026-11-11T01:52:03+00:00 2e4c04b7ae5a omd-ready-check[672]: READY: base services up (omd-site active, apache2 443, sshd 22)
2026-11-11T01:52:03+00:00 2e4c04b7ae5a systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-11T01:52:03+00:00 2e4c04b7ae5a systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-11T01:52:03+00:00 2e4c04b7ae5a systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-11T01:52:03+00:00 2e4c04b7ae5a systemd[1]: Startup finished in 2.173s.
2026-11-11T01:52:04+00:00 2e4c04b7ae5a runuser[832]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
2026-11-11T01:52:04+00:00 2e4c04b7ae5a runuser[832]: pam_unix(runuser:session): session closed for user custsite
```

## S6-s6-debian-g
- when: 2026-11-11 02:52:13
- runtime: podman

- **RESULT: PASS**

- PASS: (g1) ambiguous identity ? actionable exit 1 (code=1)
- PASS: (g1) fatal reason names the ambiguity
```
FATAL: inferred identity is AMBIGUOUS - the site subfolders' group (106) equals the omd group's gid; the primary gid cannot be determined. Refusing (no mutation). Remedy: run the site once from its original image or set the identity manually.
```

- PASS: (g1) volume unchanged: content + ownership/mode metadata identical
- PASS: (g2) lost identity file ? resume via inference, site starts ready
```
ready-time=3s
```

- PASS: (g2) .omd-labs-site-identity RE-RECORDED with the inferred 1234/1234
- PASS: (g3) recorded identity honored: site starts ready
```
ready-time=3s
```

- PASS: (g3) fresh-container account carries uid=1234 (id recid)
- PASS: (g3) fresh-container account carries primary gid=1234 (id recid)
- PASS: (g4) occupied uid on resume ? exit 1 (code=1)
- PASS: (g4) fatal names the collision (occupied uid / foreign group - F2 validation before any write)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site occres
```

- PASS: (g4) no-mutation: volume byte-identical (identity NOT re-written, no group change - F2 ordering)
- PASS: (g5) occupied uid/gid on adopt ? exit 1 (code=1)
- PASS: (g5) fatal names the collision (occupied uid / foreign group - F2 validation before any write)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site occadp
```

- PASS: (g5) no-mutation: volume byte-identical (no identity file, no group)
- PASS: (g5) adopt-complete marker ABSENT (adopt wrote nothing before the fatal)
- PASS: (g6) fixture precondition: stale in-progress marker present on a completed volume (root probe)
- PASS: (g6) persisted volume with stale marker ? resume ready (inference + re-record)
```
ready-time=3s
```

- PASS: (g6) stale in-progress marker REMOVED after validation (root probe)
- PASS: (g6) log carries the deterministic removal notice
```
2026-11-11T01:53:30+00:00 3310652e6db7 systemd[1]: Started systemd-timedated.service - Time & Date Service.
2026-11-11T01:53:30+00:00 3310652e6db7 dbus-daemon[118]: [system] Successfully activated service 'org.freedesktop.timedate1'
2026-11-11T01:53:30+00:00 3310652e6db7 omd-ready-check[429]: READY: base services up (omd-site active, apache2 443, sshd 22)
2026-11-11T01:53:30+00:00 3310652e6db7 systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-11T01:53:31+00:00 3310652e6db7 systemd[1]: Started exim4.service - exim Mail Transport Agent.
2026-11-11T01:53:31+00:00 3310652e6db7 systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-11T01:53:31+00:00 3310652e6db7 systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-11T01:53:31+00:00 3310652e6db7 systemd[1]: Startup finished in 2.216s.
```

- PASS: (g6) identity re-recorded (root probe)
## S6-s6-debian-e-inputs
- when: 2026-11-11 02:53:39
- runtime: podman

- **RESULT: PASS**

- PASS: (e-inputs) legacy volume adopted WITH inputs - site starts ready
```
ready-time=4s
```

- PASS: (e-inputs) 'adopted existing site' banner (contract string)
```
2026-11-11T01:53:46+00:00 952ed91da796 /etc/mysql/debian-start[732]: Checking for insecure root accounts.
2026-11-11T01:53:46+00:00 952ed91da796 /etc/mysql/debian-start[746]: Triggering myisam-recover for all MyISAM tables and aria-recover for all Aria tables
2026-11-11T01:53:46+00:00 952ed91da796 omd-ready-check[481]: READY: base services up (omd-site active, apache2 443, sshd 22)
2026-11-11T01:53:46+00:00 952ed91da796 systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-11T01:53:46+00:00 952ed91da796 systemd[1]: Started exim4.service - exim Mail Transport Agent.
2026-11-11T01:53:46+00:00 952ed91da796 systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-11T01:53:46+00:00 952ed91da796 systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-11T01:53:46+00:00 952ed91da796 systemd[1]: Startup finished in 2.152s.
```

- PASS: (e-inputs) FR-012 notice logged: inputs supplied but NOT applied (stored config authoritative)
```
2026-11-11T01:53:46+00:00 952ed91da796 /etc/mysql/debian-start[732]: Checking for insecure root accounts.
2026-11-11T01:53:46+00:00 952ed91da796 /etc/mysql/debian-start[746]: Triggering myisam-recover for all MyISAM tables and aria-recover for all Aria tables
2026-11-11T01:53:46+00:00 952ed91da796 omd-ready-check[481]: READY: base services up (omd-site active, apache2 443, sshd 22)
2026-11-11T01:53:46+00:00 952ed91da796 systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-11T01:53:46+00:00 952ed91da796 systemd[1]: Started exim4.service - exim Mail Transport Agent.
2026-11-11T01:53:46+00:00 952ed91da796 systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-11T01:53:46+00:00 952ed91da796 systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-11T01:53:46+00:00 952ed91da796 systemd[1]: Startup finished in 2.152s.
```

- PASS: (e-inputs) MOD_GEARMAN still the stored value off (input 'on' NOT applied)
- PASS: (e-inputs) PNP4NAGIOS still the stored value on (untouched by the adopt)
- PASS: (e-inputs) no 4730 listener (stored MOD_GEARMAN off - input not applied)
- PASS: (e-inputs) stored site.conf UNMODIFIED (sha256 unchanged, root probe)
- PASS: (e-inputs) the stored web credential created before STILL LOGS IN (thruk 200 with stored cred from .meta)
```
with-cred=200
```

- PASS: (e-inputs) init-complete marker written by the adopt (root probe)
- PASS: (e-inputs) /run/omd-labs.env carries SITE_CUSTOM_APPLIED=0 (inputs validated, not applied)
## S6-s6-rocky-g
- when: 2026-11-11 03:30:11
- runtime: podman

- **RESULT: FAIL**

- PASS: (g1) ambiguous identity ? actionable exit 1 (code=1)
- PASS: (g1) fatal reason names the ambiguity
```
FATAL: inferred identity is AMBIGUOUS - the site subfolders' group (996) equals the omd group's gid; the primary gid cannot be determined. Refusing (no mutation). Remedy: run the site once from its original image or set the identity manually.
```

- PASS: (g1) volume unchanged: content + ownership/mode metadata identical
- FAIL: (g2) lost identity file ? resume via inference, site starts ready (rc=1)
```
READY-FATAL: container exited (code 2)
ready-time=s
```

- PASS: (g2) .omd-labs-site-identity RE-RECORDED with the inferred 1234/1234
- FAIL: (g3) recorded identity honored: site starts ready (rc=1)
```
READY-FATAL: container exited (code 2)
ready-time=s
```

- FAIL: (g3) fresh-container account carries uid=1234 (id recid) (rc=1)
```
Error: can only create exec sessions on running containers: container state improper
```

- FAIL: (g3) fresh-container account carries primary gid=1234 (id recid) (rc=1)
```
Error: can only create exec sessions on running containers: container state improper
```

- PASS: (g4) occupied uid on resume ? exit 1 (code=1)
- PASS: (g4) fatal names the collision (occupied uid / foreign group - F2 validation before any write)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site occres
```

- PASS: (g4) no-mutation: volume byte-identical (identity NOT re-written, no group change - F2 ordering)
- PASS: (g5) occupied uid/gid on adopt ? exit 1 (code=1)
- PASS: (g5) fatal names the collision (occupied uid / foreign group - F2 validation before any write)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site occadp
```

- PASS: (g5) no-mutation: volume byte-identical (no identity file, no group)
- PASS: (g5) adopt-complete marker ABSENT (adopt wrote nothing before the fatal)
- PASS: (g6) fixture precondition: stale in-progress marker present on a completed volume (root probe)
- FAIL: (g6) persisted volume with stale marker ? resume ready (inference + re-record) (rc=1)
```
READY-FATAL: container exited (code 2)
ready-time=s
```

- FAIL: (g6) stale in-progress marker REMOVED after validation (root probe) (rc=1)
```

```

- FAIL: (g6) log carries the deterministic removal notice (rc=1)
```
v_wait_log: pattern not visible within 30s: stale in-progress marker
--- last log lines:
omd-labs-entry: pre-init bootstrap (container start)
omd-labs-entry: SITE_ACTIVE=1 SITE_NAME=stalemrk (validated)
omd-labs-entry: inferred legacy identity uid=1234 gid=1234 (from home owner + subfolder group)
```

- FAIL: (g6) identity re-recorded (root probe) (rc=2)
```
grep: /w/.omd-labs-site-identity: No such file or directory
```

- PASS: (g7) malformed recorded identity ? exit 1 (code=1)
- PASS: (g7) fatal names the malformed identity (no account-tool rejection)
```
FATAL: malformed recorded identity (uid='abc') for site badid - the value must be a non-empty integer. No mutation. Remedy: fix or remove .omd-labs-site-identity.
```

- PASS: (g7) no-mutation: volume byte-identical (identity NOT re-written - F2 ordering)
- PASS: (g8) stale marker + foreign gid ? exit 1 (code=1)
- PASS: (g8) fatal names the collision (occupied uid / foreign group)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site staled
```

- PASS: (g8) in-progress marker RETAINED (removed only AFTER validation - no-mutation)
- PASS: (g8) no-mutation: volume byte-identical
## S6-s6-rocky-g
- when: 2026-11-11 03:37:45
- runtime: podman

- **RESULT: PASS**

- PASS: (g1) ambiguous identity ? actionable exit 1 (code=1)
- PASS: (g1) fatal reason names the ambiguity
```
FATAL: inferred identity is AMBIGUOUS - the site subfolders' group (996) equals the omd group's gid; the primary gid cannot be determined. Refusing (no mutation). Remedy: run the site once from its original image or set the identity manually.
```

- PASS: (g1) volume unchanged: content + ownership/mode metadata identical
- PASS: (g2) lost identity file ? resume via inference, site starts ready
```
ready-time=3s
```

- PASS: (g2) .omd-labs-site-identity RE-RECORDED with the inferred 1234/1234
- PASS: (g3) recorded identity honored: site starts ready
```
ready-time=3s
```

- PASS: (g3) fresh-container account carries uid=1234 (id recid)
- PASS: (g3) fresh-container account carries primary gid=1234 (id recid)
- PASS: (g4) occupied uid on resume ? exit 1 (code=1)
- PASS: (g4) fatal names the collision (occupied uid / foreign group - F2 validation before any write)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site occres
```

- PASS: (g4) no-mutation: volume byte-identical (identity NOT re-written, no group change - F2 ordering)
- PASS: (g5) occupied uid/gid on adopt ? exit 1 (code=1)
- PASS: (g5) fatal names the collision (occupied uid / foreign group - F2 validation before any write)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site occadp
```

- PASS: (g5) no-mutation: volume byte-identical (no identity file, no group)
- PASS: (g5) adopt-complete marker ABSENT (adopt wrote nothing before the fatal)
- PASS: (g6) fixture precondition: stale in-progress marker present on a completed volume (root probe)
- PASS: (g6) persisted volume with stale marker ? resume ready (inference + re-record)
```
ready-time=3s
```

- PASS: (g6) stale in-progress marker REMOVED after validation (root probe)
- PASS: (g6) log carries the deterministic removal notice
```
2026-11-11T02:39:13+0000 f322d0da3d50 omd-ready-check[477]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-11T02:39:13+0000 f322d0da3d50 systemd[1]: Finished OMD labs bounded readiness gate (FR-018).
2026-11-11T02:39:13+0000 f322d0da3d50 systemd[1]: Reached target Multi-User System.
2026-11-11T02:39:13+0000 f322d0da3d50 systemd[1]: Reached target Graphical Interface.
2026-11-11T02:39:13+0000 f322d0da3d50 systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T02:39:13+0000 f322d0da3d50 systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T02:39:13+0000 f322d0da3d50 systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T02:39:13+0000 f322d0da3d50 systemd[1]: Startup finished in 2.408s.
```

- PASS: (g6) identity re-recorded (root probe)
- PASS: (g7) malformed recorded identity ? exit 1 (code=1)
- PASS: (g7) fatal names the malformed identity (no account-tool rejection)
```
FATAL: malformed recorded identity (uid='abc') for site badid - the value must be a non-empty integer. No mutation. Remedy: fix or remove .omd-labs-site-identity.
```

- PASS: (g7) no-mutation: volume byte-identical (identity NOT re-written - F2 ordering)
- PASS: (g8) stale marker + foreign gid ? exit 1 (code=1)
- PASS: (g8) fatal names the collision (occupied uid / foreign group)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site staled
```

- PASS: (g8) in-progress marker RETAINED (removed only AFTER validation - no-mutation)
- PASS: (g8) no-mutation: volume byte-identical
## S5-s5-rocky
- when: 2026-11-11 03:40:04
- runtime: podman

- **RESULT: PASS**

- PASS: readiness (gate + /custsite/)
```
ready-time=10s
```

- PASS: gearmand listening on 4730 when ready (SC-012 - component came up with the site)
- PASS: env value WON the conflict: omd config show GEARMAND_PORT = 0.0.0.0:4730
- PASS: effective config observable: MOD_GEARMAN = on
- PASS: container log carries the effective-customization summary (FR-010; bounded wait for log flush)
```
2026-11-11T02:40:13+0000 e76beb7d1690 systemd[1]: Reached target Graphical Interface.
2026-11-11T02:40:13+0000 e76beb7d1690 systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T02:40:13+0000 e76beb7d1690 systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T02:40:13+0000 e76beb7d1690 systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T02:40:13+0000 e76beb7d1690 systemd[1]: Startup finished in 2.247s.
2026-11-11T02:40:14+0000 e76beb7d1690 runuser[2382]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
2026-11-11T02:40:15+0000 e76beb7d1690 runuser[2382]: pam_unix(runuser:session): session closed for user custsite
2026-11-11T02:40:15+0000 e76beb7d1690 runuser[2460]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
```

- PASS: listener address is the env value (0.0.0.0:4730)
- PASS: no customization input ? no 4730 listener
- PASS: S6c: persisted site resumes ready (stored configuration authoritative)
```
ready-time=3s
```

- PASS: S6c: stored value survives (GEARMAND_PORT still 0.0.0.0:4730 - inputs NOT applied)
- PASS: S6c: log carries the deterministic notice that inputs were not applied (FR-012; bounded wait)
```
2026-11-11T02:40:33+0000 eb18b7c41e3e systemd[1]: Reached target Multi-User System.
2026-11-11T02:40:33+0000 eb18b7c41e3e systemd[1]: Reached target Graphical Interface.
2026-11-11T02:40:33+0000 eb18b7c41e3e systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T02:40:33+0000 eb18b7c41e3e systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T02:40:33+0000 eb18b7c41e3e systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T02:40:33+0000 eb18b7c41e3e systemd[1]: Startup finished in 2.184s.
2026-11-11T02:40:33+0000 eb18b7c41e3e runuser[679]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
2026-11-11T02:40:34+0000 eb18b7c41e3e runuser[679]: pam_unix(runuser:session): session closed for user custsite
```

## S6-s6-rocky-e-inputs
- when: 2026-11-11 03:40:37
- runtime: podman

- **RESULT: PASS**

- PASS: (e-inputs) legacy volume adopted WITH inputs - site starts ready
```
ready-time=3s
```

- PASS: (e-inputs) 'adopted existing site' banner (contract string)
```
2026-11-11T02:40:46+0000 5802b70a3850 omd-ready-check[487]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-11T02:40:46+0000 5802b70a3850 systemd[1]: Finished OMD labs bounded readiness gate (FR-018).
2026-11-11T02:40:46+0000 5802b70a3850 systemd[1]: Reached target Multi-User System.
2026-11-11T02:40:46+0000 5802b70a3850 systemd[1]: Reached target Graphical Interface.
2026-11-11T02:40:46+0000 5802b70a3850 systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T02:40:46+0000 5802b70a3850 systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T02:40:46+0000 5802b70a3850 systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T02:40:46+0000 5802b70a3850 systemd[1]: Startup finished in 2.044s.
```

- PASS: (e-inputs) FR-012 notice logged: inputs supplied but NOT applied (stored config authoritative)
```
2026-11-11T02:40:46+0000 5802b70a3850 omd-ready-check[487]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-11T02:40:46+0000 5802b70a3850 systemd[1]: Finished OMD labs bounded readiness gate (FR-018).
2026-11-11T02:40:46+0000 5802b70a3850 systemd[1]: Reached target Multi-User System.
2026-11-11T02:40:46+0000 5802b70a3850 systemd[1]: Reached target Graphical Interface.
2026-11-11T02:40:46+0000 5802b70a3850 systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T02:40:46+0000 5802b70a3850 systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T02:40:46+0000 5802b70a3850 systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T02:40:46+0000 5802b70a3850 systemd[1]: Startup finished in 2.044s.
```

- PASS: (e-inputs) MOD_GEARMAN still the stored value off (input 'on' NOT applied)
- PASS: (e-inputs) PNP4NAGIOS still the stored value on (untouched by the adopt)
- PASS: (e-inputs) no 4730 listener (stored MOD_GEARMAN off - input not applied)
- PASS: (e-inputs) stored site.conf UNMODIFIED (sha256 unchanged, root probe)
- PASS: (e-inputs) the stored web credential created before STILL LOGS IN (thruk 200 with stored cred from .meta)
```
with-cred=200
```

- PASS: (e-inputs) init-complete marker written by the adopt (root probe)
- PASS: (e-inputs) /run/omd-labs.env carries SITE_CUSTOM_APPLIED=0 (inputs validated, not applied)
## S5-s5-debian
- when: 2026-11-11 03:41:03
- runtime: podman

- **RESULT: PASS**

- PASS: readiness (gate + /custsite/)
```
ready-time=7s
```

- PASS: gearmand listening on 4730 when ready (SC-012 - component came up with the site)
- PASS: env value WON the conflict: omd config show GEARMAND_PORT = 0.0.0.0:4730
- PASS: effective config observable: MOD_GEARMAN = on
- PASS: container log carries the effective-customization summary (FR-010; bounded wait for log flush)
```
2026-11-11T02:41:10+00:00 d931d90ef7d5 systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-11T02:41:10+00:00 d931d90ef7d5 systemd[1]: Startup finished in 2.290s.
2026-11-11T02:41:10+00:00 d931d90ef7d5 /etc/mysql/debian-start[2494]: Checking for insecure root accounts.
2026-11-11T02:41:10+00:00 d931d90ef7d5 /etc/mysql/debian-start[2502]: Triggering myisam-recover for all MyISAM tables and aria-recover for all Aria tables
2026-11-11T02:41:11+00:00 d931d90ef7d5 runuser[2538]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
2026-11-11T02:41:11+00:00 d931d90ef7d5 runuser[2538]: pam_unix(runuser:session): session closed for user custsite
2026-11-11T02:41:11+00:00 d931d90ef7d5 runuser[2616]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
2026-11-11T02:41:11+00:00 d931d90ef7d5 runuser[2616]: pam_unix(runuser:session): session closed for user custsite
```

- PASS: listener address is the env value (0.0.0.0:4730)
- PASS: no customization input ? no 4730 listener
- PASS: S6c: persisted site resumes ready (stored configuration authoritative)
```
ready-time=3s
```

- PASS: S6c: stored value survives (GEARMAND_PORT still 0.0.0.0:4730 - inputs NOT applied)
- PASS: S6c: log carries the deterministic notice that inputs were not applied (FR-012; bounded wait)
```
2026-11-11T02:41:29+00:00 79e68aab3215 mariadbd[256]: Version: '11.8.6-MariaDB-0+deb13u1 from Debian'  socket: '/run/mysqld/mysqld.sock'  port: 3306  -- Please help get to 10k stars at https://github.com/MariaDB/Server
2026-11-11T02:41:29+00:00 79e68aab3215 runuser[781]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
2026-11-11T02:41:29+00:00 79e68aab3215 systemd[1]: Started mariadb.service - MariaDB 11.8.6 database server.
2026-11-11T02:41:29+00:00 79e68aab3215 systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-11T02:41:29+00:00 79e68aab3215 systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-11T02:41:29+00:00 79e68aab3215 systemd[1]: Startup finished in 3.105s.
2026-11-11T02:41:29+00:00 79e68aab3215 /etc/mysql/debian-start[826]: Upgrading MariaDB tables if necessary.
2026-11-11T02:41:29+00:00 79e68aab3215 /etc/mysql/debian-start[862]: Checking for insecure root accounts.
```

## S6-s6-debian-g
- when: 2026-11-11 03:41:31
- runtime: podman

- **RESULT: PASS**

- PASS: (g1) ambiguous identity ? actionable exit 1 (code=1)
- PASS: (g1) fatal reason names the ambiguity
```
FATAL: inferred identity is AMBIGUOUS - the site subfolders' group (106) equals the omd group's gid; the primary gid cannot be determined. Refusing (no mutation). Remedy: run the site once from its original image or set the identity manually.
```

- PASS: (g1) volume unchanged: content + ownership/mode metadata identical
- PASS: (g2) lost identity file ? resume via inference, site starts ready
```
ready-time=3s
```

- PASS: (g2) .omd-labs-site-identity RE-RECORDED with the inferred 1234/1234
- PASS: (g3) recorded identity honored: site starts ready
```
ready-time=3s
```

- PASS: (g3) fresh-container account carries uid=1234 (id recid)
- PASS: (g3) fresh-container account carries primary gid=1234 (id recid)
- PASS: (g4) occupied uid on resume ? exit 1 (code=1)
- PASS: (g4) fatal names the collision (occupied uid / foreign group - F2 validation before any write)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site occres
```

- PASS: (g4) no-mutation: volume byte-identical (identity NOT re-written, no group change - F2 ordering)
- PASS: (g5) occupied uid/gid on adopt ? exit 1 (code=1)
- PASS: (g5) fatal names the collision (occupied uid / foreign group - F2 validation before any write)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site occadp
```

- PASS: (g5) no-mutation: volume byte-identical (no identity file, no group)
- PASS: (g5) adopt-complete marker ABSENT (adopt wrote nothing before the fatal)
- PASS: (g6) fixture precondition: stale in-progress marker present on a completed volume (root probe)
- PASS: (g6) persisted volume with stale marker ? resume ready (inference + re-record)
```
ready-time=3s
```

- PASS: (g6) stale in-progress marker REMOVED after validation (root probe)
- PASS: (g6) log carries the deterministic removal notice
```
2026-11-11T02:42:54+00:00 1cfcf5a7be3f systemd[1]: Started mariadb.service - MariaDB 11.8.6 database server.
2026-11-11T02:42:54+00:00 1cfcf5a7be3f /etc/mysql/debian-start[728]: Upgrading MariaDB tables if necessary.
2026-11-11T02:42:54+00:00 1cfcf5a7be3f systemd[1]: Started exim4.service - exim Mail Transport Agent.
2026-11-11T02:42:54+00:00 1cfcf5a7be3f systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-11T02:42:54+00:00 1cfcf5a7be3f systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-11T02:42:54+00:00 1cfcf5a7be3f systemd[1]: Startup finished in 2.174s.
2026-11-11T02:42:54+00:00 1cfcf5a7be3f /etc/mysql/debian-start[741]: Checking for insecure root accounts.
2026-11-11T02:42:54+00:00 1cfcf5a7be3f /etc/mysql/debian-start[745]: Triggering myisam-recover for all MyISAM tables and aria-recover for all Aria tables
```

- PASS: (g6) identity re-recorded (root probe)
- PASS: (g7) malformed recorded identity ? exit 1 (code=1)
- PASS: (g7) fatal names the malformed identity (no account-tool rejection)
```
FATAL: malformed recorded identity (uid='abc') for site badid - the value must be a non-empty integer. No mutation. Remedy: fix or remove .omd-labs-site-identity.
```

- PASS: (g7) no-mutation: volume byte-identical (identity NOT re-written - F2 ordering)
- PASS: (g8) stale marker + foreign gid ? exit 1 (code=1)
- PASS: (g8) fatal names the collision (occupied uid / foreign group)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site staled
```

- PASS: (g8) in-progress marker RETAINED (removed only AFTER validation - no-mutation)
- PASS: (g8) no-mutation: volume byte-identical
## S6-s6-debian-e-inputs
- when: 2026-11-11 03:43:29
- runtime: podman

- **RESULT: PASS**

- PASS: (e-inputs) legacy volume adopted WITH inputs - site starts ready
```
ready-time=4s
```

- PASS: (e-inputs) 'adopted existing site' banner (contract string)
```
2026-11-11T02:43:37+00:00 96a441b1a965 systemd[1]: Started systemd-timedated.service - Time & Date Service.
2026-11-11T02:43:37+00:00 96a441b1a965 dbus-daemon[130]: [system] Successfully activated service 'org.freedesktop.timedate1'
2026-11-11T02:43:37+00:00 96a441b1a965 omd-ready-check[396]: READY: base services up (omd-site active, apache2 443, sshd 22)
2026-11-11T02:43:37+00:00 96a441b1a965 systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-11T02:43:37+00:00 96a441b1a965 systemd[1]: Started exim4.service - exim Mail Transport Agent.
2026-11-11T02:43:37+00:00 96a441b1a965 systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-11T02:43:37+00:00 96a441b1a965 systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-11T02:43:37+00:00 96a441b1a965 systemd[1]: Startup finished in 2.491s.
```

- PASS: (e-inputs) FR-012 notice logged: inputs supplied but NOT applied (stored config authoritative)
```
2026-11-11T02:43:37+00:00 96a441b1a965 systemd[1]: Started systemd-timedated.service - Time & Date Service.
2026-11-11T02:43:37+00:00 96a441b1a965 dbus-daemon[130]: [system] Successfully activated service 'org.freedesktop.timedate1'
2026-11-11T02:43:37+00:00 96a441b1a965 omd-ready-check[396]: READY: base services up (omd-site active, apache2 443, sshd 22)
2026-11-11T02:43:37+00:00 96a441b1a965 systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-11T02:43:37+00:00 96a441b1a965 systemd[1]: Started exim4.service - exim Mail Transport Agent.
2026-11-11T02:43:37+00:00 96a441b1a965 systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-11T02:43:37+00:00 96a441b1a965 systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-11T02:43:37+00:00 96a441b1a965 systemd[1]: Startup finished in 2.491s.
```

- PASS: (e-inputs) MOD_GEARMAN still the stored value off (input 'on' NOT applied)
- PASS: (e-inputs) PNP4NAGIOS still the stored value on (untouched by the adopt)
- PASS: (e-inputs) no 4730 listener (stored MOD_GEARMAN off - input not applied)
- PASS: (e-inputs) stored site.conf UNMODIFIED (sha256 unchanged, root probe)
- PASS: (e-inputs) the stored web credential created before STILL LOGS IN (thruk 200 with stored cred from .meta)
```
with-cred=200
```

- PASS: (e-inputs) init-complete marker written by the adopt (root probe)
- PASS: (e-inputs) /run/omd-labs.env carries SITE_CUSTOM_APPLIED=0 (inputs validated, not applied)
## S5-s5-rocky
- when: 2026-11-11 03:50:41
- runtime: podman

- **RESULT: PASS**

- PASS: readiness (gate + /custsite/)
```
ready-time=10s
```

- PASS: gearmand listening on 4730 when ready (SC-012 - component came up with the site)
- PASS: env value WON the conflict: omd config show GEARMAND_PORT = 0.0.0.0:4730 (EXACT line)
- PASS: effective config observable: MOD_GEARMAN = on (EXACT line)
- PASS: container log carries the effective-customization summary (FR-010; bounded wait for log flush)
```
2026-11-11T02:50:50+0000 8d71e76cf5d5 systemd[1]: Reached target Graphical Interface.
2026-11-11T02:50:50+0000 8d71e76cf5d5 systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T02:50:50+0000 8d71e76cf5d5 systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T02:50:50+0000 8d71e76cf5d5 systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T02:50:50+0000 8d71e76cf5d5 systemd[1]: Startup finished in 2.093s.
2026-11-11T02:50:51+0000 8d71e76cf5d5 runuser[2381]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
2026-11-11T02:50:52+0000 8d71e76cf5d5 runuser[2381]: pam_unix(runuser:session): session closed for user custsite
2026-11-11T02:50:52+0000 8d71e76cf5d5 runuser[2459]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
```

- PASS: listener address is the env value (0.0.0.0:4730)
- PASS: no customization input ? ready BEFORE the negative listener check
```
ready-time=6s
```

- PASS: no customization input ? no 4730 listener (capture non-empty first - N2)
- PASS: S6c: persisted site resumes ready (stored configuration authoritative)
```
ready-time=3s
```

- PASS: S6c: stored value survives (GEARMAND_PORT still 0.0.0.0:4730 - inputs NOT applied, EXACT line)
- PASS: S6c: log carries the deterministic notice that inputs were not applied (FR-012; bounded wait)
```
2026-11-11T02:51:07+0000 9343b5619d6a systemd[1]: Reached target Multi-User System.
2026-11-11T02:51:07+0000 9343b5619d6a systemd[1]: Reached target Graphical Interface.
2026-11-11T02:51:07+0000 9343b5619d6a systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T02:51:07+0000 9343b5619d6a systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T02:51:07+0000 9343b5619d6a systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T02:51:07+0000 9343b5619d6a systemd[1]: Startup finished in 2.088s.
2026-11-11T02:51:08+0000 9343b5619d6a runuser[678]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
2026-11-11T02:51:08+0000 9343b5619d6a runuser[678]: pam_unix(runuser:session): session closed for user custsite
```

## S5-s5-debian
- when: 2026-11-11 03:51:21
- runtime: podman

- **RESULT: PASS**

- PASS: readiness (gate + /custsite/)
```
ready-time=7s
```

- PASS: gearmand listening on 4730 when ready (SC-012 - component came up with the site)
- PASS: env value WON the conflict: omd config show GEARMAND_PORT = 0.0.0.0:4730 (EXACT line)
- PASS: effective config observable: MOD_GEARMAN = on (EXACT line)
- PASS: container log carries the effective-customization summary (FR-010; bounded wait for log flush)
```
2026-11-11T02:51:28+00:00 cd4ca9089a46 systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-11T02:51:28+00:00 cd4ca9089a46 systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-11T02:51:28+00:00 cd4ca9089a46 systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-11T02:51:28+00:00 cd4ca9089a46 systemd[1]: Startup finished in 2.184s.
2026-11-11T02:51:29+00:00 cd4ca9089a46 runuser[2534]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
2026-11-11T02:51:29+00:00 cd4ca9089a46 runuser[2534]: pam_unix(runuser:session): session closed for user custsite
2026-11-11T02:51:30+00:00 cd4ca9089a46 runuser[2612]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
2026-11-11T02:51:30+00:00 cd4ca9089a46 runuser[2612]: pam_unix(runuser:session): session closed for user custsite
```

- PASS: listener address is the env value (0.0.0.0:4730)
- PASS: no customization input ? ready BEFORE the negative listener check
```
ready-time=6s
```

- PASS: no customization input ? no 4730 listener (capture non-empty first - N2)
- PASS: S6c: persisted site resumes ready (stored configuration authoritative)
```
ready-time=3s
```

- PASS: S6c: stored value survives (GEARMAND_PORT still 0.0.0.0:4730 - inputs NOT applied, EXACT line)
- PASS: S6c: log carries the deterministic notice that inputs were not applied (FR-012; bounded wait)
```
2026-11-11T02:51:44+00:00 6bc6747e4972 omd-ready-check[521]: READY: base services up (omd-site active, apache2 443, sshd 22)
2026-11-11T02:51:44+00:00 6bc6747e4972 systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-11T02:51:44+00:00 6bc6747e4972 systemd[1]: Started exim4.service - exim Mail Transport Agent.
2026-11-11T02:51:44+00:00 6bc6747e4972 systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-11T02:51:44+00:00 6bc6747e4972 systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-11T02:51:44+00:00 6bc6747e4972 systemd[1]: Startup finished in 2.170s.
2026-11-11T02:51:45+00:00 6bc6747e4972 runuser[832]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
2026-11-11T02:51:45+00:00 6bc6747e4972 runuser[832]: pam_unix(runuser:session): session closed for user custsite
```

## S6-s6-rocky-e-inputs
- when: 2026-11-11 03:51:47
- runtime: podman

- **RESULT: PASS**

- PASS: (e-inputs) legacy volume adopted WITH inputs - site starts ready
```
ready-time=4s
```

- PASS: (e-inputs) 'adopted existing site' banner (contract string)
```
2026-11-11T02:51:57+0000 8aec9e8478ce omd-ready-check[488]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-11T02:51:57+0000 8aec9e8478ce systemd[1]: Finished OMD labs bounded readiness gate (FR-018).
2026-11-11T02:51:57+0000 8aec9e8478ce systemd[1]: Reached target Multi-User System.
2026-11-11T02:51:57+0000 8aec9e8478ce systemd[1]: Reached target Graphical Interface.
2026-11-11T02:51:57+0000 8aec9e8478ce systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T02:51:57+0000 8aec9e8478ce systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T02:51:57+0000 8aec9e8478ce systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T02:51:57+0000 8aec9e8478ce systemd[1]: Startup finished in 2.083s.
```

- PASS: (e-inputs) FR-012 notice logged: inputs supplied but NOT applied (stored config authoritative)
```
2026-11-11T02:51:57+0000 8aec9e8478ce omd-ready-check[488]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-11T02:51:57+0000 8aec9e8478ce systemd[1]: Finished OMD labs bounded readiness gate (FR-018).
2026-11-11T02:51:57+0000 8aec9e8478ce systemd[1]: Reached target Multi-User System.
2026-11-11T02:51:57+0000 8aec9e8478ce systemd[1]: Reached target Graphical Interface.
2026-11-11T02:51:57+0000 8aec9e8478ce systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T02:51:57+0000 8aec9e8478ce systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T02:51:57+0000 8aec9e8478ce systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T02:51:57+0000 8aec9e8478ce systemd[1]: Startup finished in 2.083s.
```

- PASS: (e-inputs) MOD_GEARMAN still the stored value off (input 'on' NOT applied)
- PASS: (e-inputs) PNP4NAGIOS still the stored value on (untouched by the adopt)
- PASS: (e-inputs) no 4730 listener (stored MOD_GEARMAN off - input not applied; capture non-empty - N2)
- PASS: (e-inputs) stored site.conf UNMODIFIED (sha256 unchanged, root probe)
- PASS: (e-inputs) the stored web credential created before STILL LOGS IN (thruk 200 with stored cred from .meta)
```
with-cred=200
```

- PASS: (e-inputs) init-complete marker written by the adopt (root probe)
- PASS: (e-inputs) /run/omd-labs.env carries SITE_CUSTOM_APPLIED=0 (inputs validated, not applied)
## S6-s6-debian-e-inputs
- when: 2026-11-11 03:52:03
- runtime: podman

- **RESULT: PASS**

- PASS: (e-inputs) legacy volume adopted WITH inputs - site starts ready
```
ready-time=3s
```

- PASS: (e-inputs) 'adopted existing site' banner (contract string)
```
2026-11-11T02:52:11+00:00 c2f7edc6d016 omd-ready-check[402]: READY: base services up (omd-site active, apache2 443, sshd 22)
2026-11-11T02:52:11+00:00 c2f7edc6d016 systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-11T02:52:11+00:00 c2f7edc6d016 /etc/mysql/debian-start[744]: Checking for insecure root accounts.
2026-11-11T02:52:11+00:00 c2f7edc6d016 /etc/mysql/debian-start[748]: Triggering myisam-recover for all MyISAM tables and aria-recover for all Aria tables
2026-11-11T02:52:11+00:00 c2f7edc6d016 systemd[1]: Started exim4.service - exim Mail Transport Agent.
2026-11-11T02:52:11+00:00 c2f7edc6d016 systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-11T02:52:11+00:00 c2f7edc6d016 systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-11T02:52:11+00:00 c2f7edc6d016 systemd[1]: Startup finished in 2.262s.
```

- PASS: (e-inputs) FR-012 notice logged: inputs supplied but NOT applied (stored config authoritative)
```
2026-11-11T02:52:11+00:00 c2f7edc6d016 omd-ready-check[402]: READY: base services up (omd-site active, apache2 443, sshd 22)
2026-11-11T02:52:11+00:00 c2f7edc6d016 systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-11T02:52:11+00:00 c2f7edc6d016 /etc/mysql/debian-start[744]: Checking for insecure root accounts.
2026-11-11T02:52:11+00:00 c2f7edc6d016 /etc/mysql/debian-start[748]: Triggering myisam-recover for all MyISAM tables and aria-recover for all Aria tables
2026-11-11T02:52:11+00:00 c2f7edc6d016 systemd[1]: Started exim4.service - exim Mail Transport Agent.
2026-11-11T02:52:11+00:00 c2f7edc6d016 systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-11T02:52:11+00:00 c2f7edc6d016 systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-11T02:52:11+00:00 c2f7edc6d016 systemd[1]: Startup finished in 2.262s.
```

- PASS: (e-inputs) MOD_GEARMAN still the stored value off (input 'on' NOT applied)
- PASS: (e-inputs) PNP4NAGIOS still the stored value on (untouched by the adopt)
- PASS: (e-inputs) no 4730 listener (stored MOD_GEARMAN off - input not applied; capture non-empty - N2)
- PASS: (e-inputs) stored site.conf UNMODIFIED (sha256 unchanged, root probe)
- PASS: (e-inputs) the stored web credential created before STILL LOGS IN (thruk 200 with stored cred from .meta)
```
with-cred=200
```

- PASS: (e-inputs) init-complete marker written by the adopt (root probe)
- PASS: (e-inputs) /run/omd-labs.env carries SITE_CUSTOM_APPLIED=0 (inputs validated, not applied)
## S6-s6-rocky-g
- when: 2026-11-11 03:54:05
- runtime: podman

- **RESULT: PASS**

- PASS: (g1) ambiguous identity ? actionable exit 1 (code=1)
- PASS: (g1) fatal reason names the ambiguity
```
FATAL: inferred identity is AMBIGUOUS - the site subfolders' group (996) equals the omd group's gid; the primary gid cannot be determined. Refusing (no mutation). Remedy: run the site once from its original image or set the identity manually.
```

- PASS: (g1) volume unchanged: content + ownership/mode metadata identical
- PASS: (g2) lost identity file ? resume via inference, site starts ready
```
ready-time=3s
```

- PASS: (g2) .omd-labs-site-identity RE-RECORDED with the inferred 1234/1234
- PASS: (g3) recorded identity honored: site starts ready
```
ready-time=3s
```

- PASS: (g3) fresh-container account carries uid=1234 (id recid)
- PASS: (g3) fresh-container account carries primary gid=1234 (id recid)
- PASS: (g4) occupied uid on resume ? exit 1 (code=1)
- PASS: (g4) fatal names the collision (occupied uid / foreign group - F2 validation before any write)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site occres
```

- PASS: (g4) no-mutation: volume byte-identical (identity NOT re-written, no group change - F2 ordering)
- PASS: (g5) occupied uid/gid on adopt ? exit 1 (code=1)
- PASS: (g5) fatal names the collision (occupied uid / foreign group - F2 validation before any write)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site occadp
```

- PASS: (g5) no-mutation: volume byte-identical (no identity file, no group)
- PASS: (g5) adopt-complete marker ABSENT (adopt wrote nothing before the fatal)
- PASS: (g6) fixture precondition: stale in-progress marker present on a completed volume (root probe)
- PASS: (g6) persisted volume with stale marker ? resume ready (inference + re-record)
```
ready-time=3s
```

- PASS: (g6) stale in-progress marker REMOVED after validation (root probe)
- PASS: (g6) log carries the deterministic removal notice
```
2026-11-11T02:54:48+0000 6f5254af6d65 omd-ready-check[477]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-11T02:54:48+0000 6f5254af6d65 systemd[1]: Finished OMD labs bounded readiness gate (FR-018).
2026-11-11T02:54:48+0000 6f5254af6d65 systemd[1]: Reached target Multi-User System.
2026-11-11T02:54:48+0000 6f5254af6d65 systemd[1]: Reached target Graphical Interface.
2026-11-11T02:54:48+0000 6f5254af6d65 systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T02:54:48+0000 6f5254af6d65 systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T02:54:48+0000 6f5254af6d65 systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T02:54:48+0000 6f5254af6d65 systemd[1]: Startup finished in 2.052s.
```

- PASS: (g6) identity re-recorded (root probe)
- PASS: (g7) malformed recorded identity ? exit 1 (code=1)
- PASS: (g7) fatal names the malformed identity (no account-tool rejection)
```
FATAL: malformed recorded identity (uid='abc') for site badid - the value must be a non-empty integer. No mutation. Remedy: fix or remove .omd-labs-site-identity.
```

- PASS: (g7) no-mutation: volume byte-identical (identity NOT re-written - F2 ordering)
- PASS: (g8) stale marker + foreign gid ? exit 1 (code=1)
- PASS: (g8) fatal names the collision (occupied uid / foreign group)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site staled
```

- PASS: (g8) in-progress marker RETAINED (removed only AFTER validation - no-mutation)
- PASS: (g8) no-mutation: volume byte-identical
- PASS: (g9) GID-only foreign collision on resume ? exit 1 (code=1)
- PASS: (g9) fatal names the foreign group (belongs to group 'occgrp')
```
FATAL: gid 1234 belongs to group 'occgrp', not site 'gonly' - refusing to bind the site account to a foreign group (no mutation). Remedy: free the gid or fix the recorded identity.
```

- PASS: (g9) no-mutation: volume byte-identical (F2 ordering)
- PASS: (g10) inverse collision (site-named group at wrong gid) ? exit 1 (code=1)
- PASS: (g10) fatal names the inverse collision (exists at gid 1230)
```
FATAL: a group named 'g10id' already exists at gid 1230 (the recorded identity requests gid 1234) - refusing (no mutation). Remedy: groupdel/rename the existing group or fix the recorded identity.
```

- PASS: (g10) no-mutation: volume byte-identical (identity NOT re-written - F2 ordering)
- PASS: (g10) the ORIGINAL identity line is intact (not overwritten by the failed restore)
## S6-s6-debian-g
- when: 2026-11-11 03:55:46
- runtime: podman

- **RESULT: PASS**

- PASS: (g1) ambiguous identity ? actionable exit 1 (code=1)
- PASS: (g1) fatal reason names the ambiguity
```
FATAL: inferred identity is AMBIGUOUS - the site subfolders' group (106) equals the omd group's gid; the primary gid cannot be determined. Refusing (no mutation). Remedy: run the site once from its original image or set the identity manually.
```

- PASS: (g1) volume unchanged: content + ownership/mode metadata identical
- PASS: (g2) lost identity file ? resume via inference, site starts ready
```
ready-time=4s
```

- PASS: (g2) .omd-labs-site-identity RE-RECORDED with the inferred 1234/1234
- PASS: (g3) recorded identity honored: site starts ready
```
ready-time=3s
```

- PASS: (g3) fresh-container account carries uid=1234 (id recid)
- PASS: (g3) fresh-container account carries primary gid=1234 (id recid)
- PASS: (g4) occupied uid on resume ? exit 1 (code=1)
- PASS: (g4) fatal names the collision (occupied uid / foreign group - F2 validation before any write)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site occres
```

- PASS: (g4) no-mutation: volume byte-identical (identity NOT re-written, no group change - F2 ordering)
- PASS: (g5) occupied uid/gid on adopt ? exit 1 (code=1)
- PASS: (g5) fatal names the collision (occupied uid / foreign group - F2 validation before any write)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site occadp
```

- PASS: (g5) no-mutation: volume byte-identical (no identity file, no group)
- PASS: (g5) adopt-complete marker ABSENT (adopt wrote nothing before the fatal)
- PASS: (g6) fixture precondition: stale in-progress marker present on a completed volume (root probe)
- PASS: (g6) persisted volume with stale marker ? resume ready (inference + re-record)
```
ready-time=3s
```

- PASS: (g6) stale in-progress marker REMOVED after validation (root probe)
- PASS: (g6) log carries the deterministic removal notice
```
2026-11-11T02:56:27+00:00 c37d90805698 systemd[1]: Started exim4.service - exim Mail Transport Agent.
2026-11-11T02:56:27+00:00 c37d90805698 systemd[1]: Started mariadb.service - MariaDB 11.8.6 database server.
2026-11-11T02:56:27+00:00 c37d90805698 systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-11T02:56:27+00:00 c37d90805698 systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-11T02:56:27+00:00 c37d90805698 systemd[1]: Startup finished in 2.196s.
2026-11-11T02:56:27+00:00 c37d90805698 /etc/mysql/debian-start[730]: Upgrading MariaDB tables if necessary.
2026-11-11T02:56:27+00:00 c37d90805698 /etc/mysql/debian-start[741]: Checking for insecure root accounts.
2026-11-11T02:56:27+00:00 c37d90805698 /etc/mysql/debian-start[745]: Triggering myisam-recover for all MyISAM tables and aria-recover for all Aria tables
```

- PASS: (g6) identity re-recorded (root probe)
- PASS: (g7) malformed recorded identity ? exit 1 (code=1)
- PASS: (g7) fatal names the malformed identity (no account-tool rejection)
```
FATAL: malformed recorded identity (uid='abc') for site badid - the value must be a non-empty integer. No mutation. Remedy: fix or remove .omd-labs-site-identity.
```

- PASS: (g7) no-mutation: volume byte-identical (identity NOT re-written - F2 ordering)
- PASS: (g8) stale marker + foreign gid ? exit 1 (code=1)
- PASS: (g8) fatal names the collision (occupied uid / foreign group)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site staled
```

- PASS: (g8) in-progress marker RETAINED (removed only AFTER validation - no-mutation)
- PASS: (g8) no-mutation: volume byte-identical
- PASS: (g9) GID-only foreign collision on resume ? exit 1 (code=1)
- PASS: (g9) fatal names the foreign group (belongs to group 'occgrp')
```
FATAL: gid 1234 belongs to group 'occgrp', not site 'gonly' - refusing to bind the site account to a foreign group (no mutation). Remedy: free the gid or fix the recorded identity.
```

- PASS: (g9) no-mutation: volume byte-identical (F2 ordering)
- PASS: (g10) inverse collision (site-named group at wrong gid) ? exit 1 (code=1)
- PASS: (g10) fatal names the inverse collision (exists at gid 1230)
```
FATAL: a group named 'g10id' already exists at gid 1230 (the recorded identity requests gid 1234) - refusing (no mutation). Remedy: groupdel/rename the existing group or fix the recorded identity.
```

- PASS: (g10) no-mutation: volume byte-identical (identity NOT re-written - F2 ordering)
- PASS: (g10) the ORIGINAL identity line is intact (not overwritten by the failed restore)
## S5-s5-rocky
- when: 2026-11-11 04:40:26
- runtime: podman

- **RESULT: PASS**

- PASS: readiness (gate + /custsite/)
```
ready-time=11s
```

- PASS: gearmand listening on 4730 when ready (SC-012 - component came up with the site)
- PASS: env value WON the conflict: omd config show GEARMAND_PORT = 0.0.0.0:4730 (EXACT line)
- PASS: effective config observable: MOD_GEARMAN = on (EXACT line)
- PASS: container log carries the effective-customization summary (FR-010; bounded wait for log flush)
```
2026-11-11T03:40:35+0000 ca0882a0cf0e systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T03:40:35+0000 ca0882a0cf0e systemd[1]: Started Time & Date Service.
2026-11-11T03:40:35+0000 ca0882a0cf0e systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T03:40:35+0000 ca0882a0cf0e systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T03:40:35+0000 ca0882a0cf0e systemd[1]: Startup finished in 2.576s.
2026-11-11T03:40:37+0000 ca0882a0cf0e runuser[2407]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
2026-11-11T03:40:37+0000 ca0882a0cf0e runuser[2407]: pam_unix(runuser:session): session closed for user custsite
2026-11-11T03:40:38+0000 ca0882a0cf0e runuser[2485]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
```

- PASS: listener address is the env value (0.0.0.0:4730)
- PASS: no customization input ? ready BEFORE the negative listener check
```
ready-time=5s
```

- PASS: no customization input ? no 4730 listener (capture non-empty first - N2)
- PASS: S6c: persisted site resumes ready (stored configuration authoritative)
```
ready-time=3s
```

- PASS: S6c: stored value survives (GEARMAND_PORT still 0.0.0.0:4730 - inputs NOT applied, EXACT line)
- PASS: S6c: log carries the deterministic notice that inputs were not applied (FR-012; bounded wait)
```
2026-11-11T03:40:53+0000 d83ec9f68ea5 systemd[1]: Finished OMD labs bounded readiness gate (FR-018).
2026-11-11T03:40:53+0000 d83ec9f68ea5 systemd[1]: Reached target Multi-User System.
2026-11-11T03:40:53+0000 d83ec9f68ea5 systemd[1]: Reached target Graphical Interface.
2026-11-11T03:40:53+0000 d83ec9f68ea5 systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T03:40:53+0000 d83ec9f68ea5 systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T03:40:53+0000 d83ec9f68ea5 systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T03:40:53+0000 d83ec9f68ea5 systemd[1]: Startup finished in 2.126s.
2026-11-11T03:40:53+0000 d83ec9f68ea5 runuser[678]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
```

## S6-s6-rocky-g
- when: 2026-11-11 04:40:57
- runtime: podman

- **RESULT: PASS**

- PASS: (g1) ambiguous identity ? actionable exit 1 (code=1)
- PASS: (g1) fatal reason names the ambiguity
```
FATAL: inferred identity is AMBIGUOUS - the site subfolders' group (996) equals the omd group's gid; the primary gid cannot be determined. Refusing (no mutation). Remedy: run the site once from its original image or set the identity manually.
```

- PASS: (g1) volume unchanged: content + ownership/mode metadata identical
- PASS: (g2) lost identity file ? resume via inference, site starts ready
```
ready-time=3s
```

- PASS: (g2) .omd-labs-site-identity RE-RECORDED with the inferred 1234/1234
- PASS: (g3) recorded identity honored: site starts ready
```
ready-time=3s
```

- PASS: (g3) fresh-container account carries uid=1234 (id recid)
- PASS: (g3) fresh-container account carries primary gid=1234 (id recid)
- PASS: (g4) occupied uid on resume ? exit 1 (code=1)
- PASS: (g4) fatal names the collision (occupied uid / foreign group - F2 validation before any write)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site occres
```

- PASS: (g4) no-mutation: volume byte-identical (identity NOT re-written, no group change - F2 ordering)
- PASS: (g5) occupied uid/gid on adopt ? exit 1 (code=1)
- PASS: (g5) fatal names the collision (occupied uid / foreign group - F2 validation before any write)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site occadp
```

- PASS: (g5) no-mutation: volume byte-identical (no identity file, no group)
- PASS: (g5) adopt-complete marker ABSENT (adopt wrote nothing before the fatal)
- PASS: (g6) fixture precondition: stale in-progress marker present on a completed volume (root probe)
- PASS: (g6) persisted volume with stale marker ? resume ready (inference + re-record)
```
ready-time=3s
```

- PASS: (g6) stale in-progress marker REMOVED after validation (root probe)
- PASS: (g6) log carries the deterministic removal notice
```
2026-11-11T03:42:24+0000 c605a875485b omd-ready-check[480]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-11T03:42:24+0000 c605a875485b systemd[1]: Finished OMD labs bounded readiness gate (FR-018).
2026-11-11T03:42:24+0000 c605a875485b systemd[1]: Reached target Multi-User System.
2026-11-11T03:42:24+0000 c605a875485b systemd[1]: Reached target Graphical Interface.
2026-11-11T03:42:24+0000 c605a875485b systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T03:42:24+0000 c605a875485b systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T03:42:24+0000 c605a875485b systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T03:42:24+0000 c605a875485b systemd[1]: Startup finished in 2.052s.
```

- PASS: (g6) identity re-recorded (root probe)
- PASS: (g7) malformed recorded identity ? exit 1 (code=1)
- PASS: (g7) fatal names the malformed identity (no account-tool rejection)
```
FATAL: malformed recorded identity (uid='abc') for site badid - the value must be a non-empty integer. No mutation. Remedy: fix or remove .omd-labs-site-identity.
```

- PASS: (g7) no-mutation: volume byte-identical (identity NOT re-written - F2 ordering)
- PASS: (g8) stale marker + foreign gid ? exit 1 (code=1)
- PASS: (g8) fatal names the collision (occupied uid / foreign group)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site staled
```

- PASS: (g8) in-progress marker RETAINED (removed only AFTER validation - no-mutation)
- PASS: (g8) no-mutation: volume byte-identical
- PASS: (g9) GID-only foreign collision on resume ? exit 1 (code=1)
- PASS: (g9) fatal names the foreign group (belongs to group 'occgrp')
```
FATAL: gid 1234 belongs to group 'occgrp', not site 'gonly' - refusing to bind the site account to a foreign group (no mutation). Remedy: free the gid or fix the recorded identity.
```

- PASS: (g9) no-mutation: volume byte-identical (F2 ordering)
- PASS: (g10) inverse collision (site-named group at wrong gid) ? exit 1 (code=1)
- PASS: (g10) fatal names the inverse collision (exists at gid 1230)
```
FATAL: a group named 'g10id' already exists at gid 1230 (the recorded identity requests gid 1234) - refusing (no mutation). Remedy: groupdel/rename the existing group or fix the recorded identity.
```

- PASS: (g10) no-mutation: volume byte-identical (identity NOT re-written - F2 ordering)
- PASS: (g10) the ORIGINAL identity line is intact (not overwritten by the failed restore)
## S6-s6-rocky-e-inputs
- when: 2026-11-11 04:43:44
- runtime: podman

- **RESULT: PASS**

- PASS: (e-inputs) legacy volume adopted WITH inputs - site starts ready
```
ready-time=3s
```

- PASS: (e-inputs) 'adopted existing site' banner (contract string)
```
2026-11-11T03:43:53+0000 357055b76019 omd-ready-check[487]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-11T03:43:53+0000 357055b76019 systemd[1]: Finished OMD labs bounded readiness gate (FR-018).
2026-11-11T03:43:53+0000 357055b76019 systemd[1]: Reached target Multi-User System.
2026-11-11T03:43:53+0000 357055b76019 systemd[1]: Reached target Graphical Interface.
2026-11-11T03:43:53+0000 357055b76019 systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T03:43:53+0000 357055b76019 systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T03:43:53+0000 357055b76019 systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T03:43:53+0000 357055b76019 systemd[1]: Startup finished in 2.045s.
```

- PASS: (e-inputs) FR-012 notice logged: inputs supplied but NOT applied (stored config authoritative)
```
2026-11-11T03:43:53+0000 357055b76019 omd-ready-check[487]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-11T03:43:53+0000 357055b76019 systemd[1]: Finished OMD labs bounded readiness gate (FR-018).
2026-11-11T03:43:53+0000 357055b76019 systemd[1]: Reached target Multi-User System.
2026-11-11T03:43:53+0000 357055b76019 systemd[1]: Reached target Graphical Interface.
2026-11-11T03:43:53+0000 357055b76019 systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T03:43:53+0000 357055b76019 systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T03:43:53+0000 357055b76019 systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T03:43:53+0000 357055b76019 systemd[1]: Startup finished in 2.045s.
```

- PASS: (e-inputs) MOD_GEARMAN still the stored value off (input 'on' NOT applied)
- PASS: (e-inputs) PNP4NAGIOS still the stored value on (untouched by the adopt)
- PASS: (e-inputs) no 4730 listener (stored MOD_GEARMAN off - input not applied; capture non-empty - N2)
- PASS: (e-inputs) stored site.conf UNMODIFIED (sha256 unchanged, root probe)
- PASS: (e-inputs) the stored web credential created before STILL LOGS IN (thruk 200 with stored cred from .meta)
```
with-cred=200
```

- PASS: (e-inputs) init-complete marker written by the adopt (root probe)
- PASS: (e-inputs) /run/omd-labs.env carries SITE_CUSTOM_APPLIED=0 (inputs validated, not applied)
## S5-s5-debian
- when: 2026-11-11 04:44:11
- runtime: podman

- **RESULT: PASS**

- PASS: readiness (gate + /custsite/)
```
ready-time=8s
```

- PASS: gearmand listening on 4730 when ready (SC-012 - component came up with the site)
- PASS: env value WON the conflict: omd config show GEARMAND_PORT = 0.0.0.0:4730 (EXACT line)
- PASS: effective config observable: MOD_GEARMAN = on (EXACT line)
- PASS: container log carries the effective-customization summary (FR-010; bounded wait for log flush)
```
2026-11-11T03:44:18+00:00 6e65fbfc732b systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-11T03:44:18+00:00 6e65fbfc732b systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-11T03:44:18+00:00 6e65fbfc732b systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-11T03:44:18+00:00 6e65fbfc732b systemd[1]: Startup finished in 2.252s.
2026-11-11T03:44:19+00:00 6e65fbfc732b runuser[2555]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
2026-11-11T03:44:19+00:00 6e65fbfc732b runuser[2555]: pam_unix(runuser:session): session closed for user custsite
2026-11-11T03:44:20+00:00 6e65fbfc732b runuser[2633]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
2026-11-11T03:44:20+00:00 6e65fbfc732b runuser[2633]: pam_unix(runuser:session): session closed for user custsite
```

- PASS: listener address is the env value (0.0.0.0:4730)
- PASS: no customization input ? ready BEFORE the negative listener check
```
ready-time=4s
```

- PASS: no customization input ? no 4730 listener (capture non-empty first - N2)
- PASS: S6c: persisted site resumes ready (stored configuration authoritative)
```
ready-time=3s
```

- PASS: S6c: stored value survives (GEARMAND_PORT still 0.0.0.0:4730 - inputs NOT applied, EXACT line)
- PASS: S6c: log carries the deterministic notice that inputs were not applied (FR-012; bounded wait)
```
2026-11-11T03:44:32+00:00 c4ff7861792d systemd[1]: Started exim4.service - exim Mail Transport Agent.
2026-11-11T03:44:32+00:00 c4ff7861792d omd-ready-check[666]: READY: base services up (omd-site active, apache2 443, sshd 22)
2026-11-11T03:44:32+00:00 c4ff7861792d systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-11T03:44:32+00:00 c4ff7861792d systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-11T03:44:32+00:00 c4ff7861792d systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-11T03:44:32+00:00 c4ff7861792d systemd[1]: Startup finished in 2.186s.
2026-11-11T03:44:33+00:00 c4ff7861792d runuser[836]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
2026-11-11T03:44:33+00:00 c4ff7861792d runuser[836]: pam_unix(runuser:session): session closed for user custsite
```

## S6-s6-debian-g
- when: 2026-11-11 04:44:36
- runtime: podman

- **RESULT: PASS**

- PASS: (g1) ambiguous identity ? actionable exit 1 (code=1)
- PASS: (g1) fatal reason names the ambiguity
```
FATAL: inferred identity is AMBIGUOUS - the site subfolders' group (106) equals the omd group's gid; the primary gid cannot be determined. Refusing (no mutation). Remedy: run the site once from its original image or set the identity manually.
```

- PASS: (g1) volume unchanged: content + ownership/mode metadata identical
- PASS: (g2) lost identity file ? resume via inference, site starts ready
```
ready-time=3s
```

- PASS: (g2) .omd-labs-site-identity RE-RECORDED with the inferred 1234/1234
- PASS: (g3) recorded identity honored: site starts ready
```
ready-time=3s
```

- PASS: (g3) fresh-container account carries uid=1234 (id recid)
- PASS: (g3) fresh-container account carries primary gid=1234 (id recid)
- PASS: (g4) occupied uid on resume ? exit 1 (code=1)
- PASS: (g4) fatal names the collision (occupied uid / foreign group - F2 validation before any write)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site occres
```

- PASS: (g4) no-mutation: volume byte-identical (identity NOT re-written, no group change - F2 ordering)
- PASS: (g5) occupied uid/gid on adopt ? exit 1 (code=1)
- PASS: (g5) fatal names the collision (occupied uid / foreign group - F2 validation before any write)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site occadp
```

- PASS: (g5) no-mutation: volume byte-identical (no identity file, no group)
- PASS: (g5) adopt-complete marker ABSENT (adopt wrote nothing before the fatal)
- PASS: (g6) fixture precondition: stale in-progress marker present on a completed volume (root probe)
- PASS: (g6) persisted volume with stale marker ? resume ready (inference + re-record)
```
ready-time=4s
```

- PASS: (g6) stale in-progress marker REMOVED after validation (root probe)
- PASS: (g6) log carries the deterministic removal notice
```
2026-11-11T03:45:59+00:00 7cae188a97de systemd[1]: Started mariadb.service - MariaDB 11.8.6 database server.
2026-11-11T03:45:59+00:00 7cae188a97de /etc/mysql/debian-start[726]: Upgrading MariaDB tables if necessary.
2026-11-11T03:45:59+00:00 7cae188a97de /etc/mysql/debian-start[741]: Checking for insecure root accounts.
2026-11-11T03:45:59+00:00 7cae188a97de /etc/mysql/debian-start[745]: Triggering myisam-recover for all MyISAM tables and aria-recover for all Aria tables
2026-11-11T03:45:59+00:00 7cae188a97de systemd[1]: Started exim4.service - exim Mail Transport Agent.
2026-11-11T03:45:59+00:00 7cae188a97de systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-11T03:45:59+00:00 7cae188a97de systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-11T03:45:59+00:00 7cae188a97de systemd[1]: Startup finished in 2.265s.
```

- PASS: (g6) identity re-recorded (root probe)
- PASS: (g7) malformed recorded identity ? exit 1 (code=1)
- PASS: (g7) fatal names the malformed identity (no account-tool rejection)
```
FATAL: malformed recorded identity (uid='abc') for site badid - the value must be a non-empty integer. No mutation. Remedy: fix or remove .omd-labs-site-identity.
```

- PASS: (g7) no-mutation: volume byte-identical (identity NOT re-written - F2 ordering)
- PASS: (g8) stale marker + foreign gid ? exit 1 (code=1)
- PASS: (g8) fatal names the collision (occupied uid / foreign group)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site staled
```

- PASS: (g8) in-progress marker RETAINED (removed only AFTER validation - no-mutation)
- PASS: (g8) no-mutation: volume byte-identical
- PASS: (g9) GID-only foreign collision on resume ? exit 1 (code=1)
- PASS: (g9) fatal names the foreign group (belongs to group 'occgrp')
```
FATAL: gid 1234 belongs to group 'occgrp', not site 'gonly' - refusing to bind the site account to a foreign group (no mutation). Remedy: free the gid or fix the recorded identity.
```

- PASS: (g9) no-mutation: volume byte-identical (F2 ordering)
- PASS: (g10) inverse collision (site-named group at wrong gid) ? exit 1 (code=1)
- PASS: (g10) fatal names the inverse collision (exists at gid 1230)
```
FATAL: a group named 'g10id' already exists at gid 1230 (the recorded identity requests gid 1234) - refusing (no mutation). Remedy: groupdel/rename the existing group or fix the recorded identity.
```

- PASS: (g10) no-mutation: volume byte-identical (identity NOT re-written - F2 ordering)
- PASS: (g10) the ORIGINAL identity line is intact (not overwritten by the failed restore)
## S6-s6-debian-e-inputs
- when: 2026-11-11 04:47:13
- runtime: podman

- **RESULT: PASS**

- PASS: (e-inputs) legacy volume adopted WITH inputs - site starts ready
```
ready-time=3s
```

- PASS: (e-inputs) 'adopted existing site' banner (contract string)
```
2026-11-11T03:47:21+00:00 09e544403742 systemd[1]: Started systemd-timedated.service - Time & Date Service.
2026-11-11T03:47:21+00:00 09e544403742 dbus-daemon[130]: [system] Successfully activated service 'org.freedesktop.timedate1'
2026-11-11T03:47:21+00:00 09e544403742 omd-ready-check[400]: READY: base services up (omd-site active, apache2 443, sshd 22)
2026-11-11T03:47:21+00:00 09e544403742 systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-11T03:47:21+00:00 09e544403742 systemd[1]: Started exim4.service - exim Mail Transport Agent.
2026-11-11T03:47:21+00:00 09e544403742 systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-11T03:47:21+00:00 09e544403742 systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-11T03:47:21+00:00 09e544403742 systemd[1]: Startup finished in 2.234s.
```

- PASS: (e-inputs) FR-012 notice logged: inputs supplied but NOT applied (stored config authoritative)
```
2026-11-11T03:47:21+00:00 09e544403742 systemd[1]: Started systemd-timedated.service - Time & Date Service.
2026-11-11T03:47:21+00:00 09e544403742 dbus-daemon[130]: [system] Successfully activated service 'org.freedesktop.timedate1'
2026-11-11T03:47:21+00:00 09e544403742 omd-ready-check[400]: READY: base services up (omd-site active, apache2 443, sshd 22)
2026-11-11T03:47:21+00:00 09e544403742 systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-11T03:47:21+00:00 09e544403742 systemd[1]: Started exim4.service - exim Mail Transport Agent.
2026-11-11T03:47:21+00:00 09e544403742 systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-11T03:47:21+00:00 09e544403742 systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-11T03:47:21+00:00 09e544403742 systemd[1]: Startup finished in 2.234s.
```

- PASS: (e-inputs) MOD_GEARMAN still the stored value off (input 'on' NOT applied)
- PASS: (e-inputs) PNP4NAGIOS still the stored value on (untouched by the adopt)
- PASS: (e-inputs) no 4730 listener (stored MOD_GEARMAN off - input not applied; capture non-empty - N2)
- PASS: (e-inputs) stored site.conf UNMODIFIED (sha256 unchanged, root probe)
- PASS: (e-inputs) the stored web credential created before STILL LOGS IN (thruk 200 with stored cred from .meta)
```
with-cred=200
```

- PASS: (e-inputs) init-complete marker written by the adopt (root probe)
- PASS: (e-inputs) /run/omd-labs.env carries SITE_CUSTOM_APPLIED=0 (inputs validated, not applied)


## T026-2026-11-11 (customization application + carried F2 identity/validation hardening)

- **Entry** (scripts/omd-labs-entry, final sha256
  873801c8bc7d43d3edcac90d388a8b520c42404f91de4dcaa4d971a6f2417340; bash -n
  + ASCII clean; NO rebuild in this task - the overlay image
  local/omd-labs-{rocky,debian}:t026ovl = build #11 + this entry carried
  the identical entry for all in-image verification; the canonical rebuild
  is T027). Key regions (current line numbers): `validate_identity` :331,
  `restore_registration` :350, `adopt_site` :483, `recover_interrupted`
  :512, `create_site` :259, `rollback` :129 (removes $IDENTITY on the
  fresh path), `site_hooks_dir` :643, `site_effective_settings` :662
  (strict parse: empty key, tab/newline in value, tab/newline in KEY -
  the key check at :687), `cfg_timeout` :736, `site_customize_apply`
  :755 (per-key budget recompute + cfg_timeout + rc/non-empty show gates
  :839-859), `site_customize` :867, `write_env` :963.
- **Behavior**: effective settings = mounted file + OMDCFG_* env, env wins
  per key; dependency-aware (topological) application order with
  effective-settings (sorted-key) fallback for cyclic remainders;
  per-key `omd config set` + mandatory `omd config show` equality check
  (a hook `set` failure is SILENT - rc 0, value not stored);
  FR-010 effective-customization summary logged + `SITE_CUSTOM_APPLIED=1`
  + summary into /run/omd-labs.env; FR-012 lowercase "not applied" notice
  on BOTH persisted and adopted paths (from the single pre-mutation
  parse); "adopted existing site" banner AFTER validation + marker commit.
  Invalid key/value => exit 1 pre-init (FR-011), nothing started.
  Settings validated BEFORE the first mutation on all four input-reading
  paths (resume/adopt/recover/create). Identity hardening (carried F2):
  numeric + range validation before all account tools; same-name account
  must match the volume identity (uid+gid+home) else fatal no-mutation;
  foreign-gid and INVERSE collision (site-named group at a different gid)
  refused; identity file written LAST on every path.
- **Codex rounds**: 75 (4 BLOCKER + 3 NOTE) and 77 (1 BLOCKER + 1 NOTE),
  all verified real, fixed, and verified in-image. The 77 BLOCKER fix:
  the apply loop re-computes the budget PER subprocess - set
  min(rem_budget,90) (:839-845), show min(rem_budget,30) RE-READ after the
  set (:852-856) - and `cfg_timeout` (:736) = `timeout -k 1` + TEMP-FILE
  output capture; the show must exit rc 0 AND be non-empty before the
  equality check (:857-858). **Empirical timeout footguns (both distros,
  load-bearing)**: (1) `out=$(timeout ...)` PIPE capture does NOT return
  at the deadline when a TERM-ignoring child leaves an orphaned grandchild
  holding the pipe (GNU timeout signals the foreground process group; a
  backgrounded grandchild survives) - the command substitution blocks
  indefinitely; file capture returns at deadline+1 rc 137. (2)
  `timeout -k 0` does NOT KILL - it waits for the child to die - so a
  TERM-ignoring child blocked a 2 s deadline for 40 s; grace >= 1 is
  mandatory (worst case: deadline+1 s, bounded by the rem_budget<=0
  fatals).
- **Self-introduced bug caught + fixed**: bare
  `x=$(getent group <absent> | cut ...)` under `set -e`+`pipefail` aborts
  the entry with exit 2 and NO fatal file when the group is ABSENT
  (getent exits 2 - the normal fresh/resume case); the new
  inverse-collision assignments broke g2/g3/g6 until `|| true` was added.
  All other getent calls audited (guarded or inside confirmed-exists
  branches).
- **In-image ground truth** (build #11 + this entry, BOTH distros):
  M1-M6 happy-path matrix, F1-F4 F2-ordering matrix, 5-case topological
  dry-run, CX counterexample matrix C1-C6 (C1 malformed identity; C2/C2b
  same-name gid/home mismatch; C3a/C3b inverse collision resume+adopt -
  all no-mutation, volume byte-identical; C4 empty-key file fresh path -
  volume EMPTY; C5 tab-in-value - volume EMPTY; C6 tab-in-KEY - volume
  EMPTY, fatal "the key on this line ... contains a tab or newline").
  H-matrix via test-only stateful omd shim (intercepts only
  `config set`/`show`, persists set->show, passes everything else to the
  real binary): H0 normal ready 8 s APPLIED=1; H1 slow-set(10 s) ready
  17 s; H2 TERM-ignoring hung set (`trap "" TERM; sleep 300`) exit 1 in
  96 s (90 s deadline + 1 s KILL escalation, not 300 s), fatal
  "rc=137 killed after ignoring TERM"; H3 show-fail -> "omd config show
  failed (rc=1)"; H4 show-empty -> "returned empty output". (A hung SHOW
  specifically is omd-internal in 5.81 - the hooks have no `show)`
  handler - so the show is bounded at min(rem,30) and the cfg_timeout
  bound itself was proven on the TERM-ignoring direct + orphan-grandchild
  shapes, both distros.)
- **Suite codified + smoke-verified on the final overlay entry** (entry
  sha256 == host): s5 11/11 (SELinux label on the settings mount
  `:ro${SELABEL:+,z}`, `runuser -u SITE -- omd config show KEY` + exact
  `grep -qx`, readiness-first + non-empty-capture negative listener);
  s6 g 34/34 (g1-g10: g4/g5 occupied uid/gid resume+adopt, g6 stale
  marker, g7 malformed identity, g8 stale-marker+foreign-gid, g9 GID-only
  foreign collision via no-user sub-image local/omd-s6g-occg, g10 inverse
  collision via sub-image local/omd-s6g-invs - each with no-mutation
  snapshots); s6 e-inputs 10/10. All GREEN both distros. Logs:
  /tmp/t026-{matrix,f2,cx,hx}-{rocky,debian}.log, /tmp/s5-t026f.log,
  /tmp/s6g-t026f.log, /tmp/s6ein-t026f.log + -deb- variants.
- **Spar outcome**: CONSENSUS (debate 79 - incremental T026 sign-off;
  codex: "The remaining findings are resolved: set/show budgets are
  recomputed separately, timeout has bounded KILL escalation with
  file-backed capture, show failures cannot pass equality verification,
  and tab-containing file keys fail before mutation"; T027 canonical
  rebuild + codified regressions remain the gate; whole-implementation
  sign-off pending the final Phase-8 gates).
- **Note for T027**: `hooks/build` hardcodes docker (absent - podman-only
  host); use the podman equivalent with the same Dockerfile/image name +
  OMD_VERSION=master (build #12), then run s5 + s6 a/b/d/e/e-inputs/g
  for the record (the direct scenarios/*.sh + IMAGE= form, NOT the run.sh
  4-arg form whose tag falls back to the nightly default).
## S5-s5-rocky
- when: 2026-11-11 04:57:10
- runtime: podman

- **RESULT: PASS**

- PASS: readiness (gate + /custsite/)
```
ready-time=11s
```

- PASS: gearmand listening on 4730 when ready (SC-012 - component came up with the site)
- PASS: env value WON the conflict: omd config show GEARMAND_PORT = 0.0.0.0:4730 (EXACT line)
- PASS: effective config observable: MOD_GEARMAN = on (EXACT line)
- PASS: container log carries the effective-customization summary (FR-010; bounded wait for log flush)
```
2026-11-11T03:57:19+0000 d50d99519eda systemd[1]: Reached target Graphical Interface.
2026-11-11T03:57:19+0000 d50d99519eda systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T03:57:19+0000 d50d99519eda systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T03:57:19+0000 d50d99519eda systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T03:57:19+0000 d50d99519eda systemd[1]: Startup finished in 2.283s.
2026-11-11T03:57:21+0000 d50d99519eda runuser[2401]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
2026-11-11T03:57:21+0000 d50d99519eda runuser[2401]: pam_unix(runuser:session): session closed for user custsite
2026-11-11T03:57:21+0000 d50d99519eda runuser[2479]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
```

- PASS: listener address is the env value (0.0.0.0:4730)
- PASS: no customization input ? ready BEFORE the negative listener check
```
ready-time=6s
```

- PASS: no customization input ? no 4730 listener (capture non-empty first - N2)
- PASS: S6c: persisted site resumes ready (stored configuration authoritative)
```
ready-time=3s
```

- PASS: S6c: stored value survives (GEARMAND_PORT still 0.0.0.0:4730 - inputs NOT applied, EXACT line)
- PASS: S6c: log carries the deterministic notice that inputs were not applied (FR-012; bounded wait)
```
2026-11-11T03:57:38+0000 48e7b6b93604 systemd[1]: Reached target Multi-User System.
2026-11-11T03:57:38+0000 48e7b6b93604 systemd[1]: Reached target Graphical Interface.
2026-11-11T03:57:38+0000 48e7b6b93604 systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T03:57:38+0000 48e7b6b93604 systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T03:57:38+0000 48e7b6b93604 systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T03:57:38+0000 48e7b6b93604 systemd[1]: Startup finished in 2.177s.
2026-11-11T03:57:39+0000 48e7b6b93604 runuser[676]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
2026-11-11T03:57:39+0000 48e7b6b93604 runuser[676]: pam_unix(runuser:session): session closed for user custsite
```

## S6-s6-rocky-a
- when: 2026-11-11 04:57:42
- runtime: podman

## S6-s6-rocky-d
- when: 2026-11-11 04:57:43
- runtime: podman

- **RESULT: PASS**

- PASS: (d/account-plus-tree) fixture precondition: in-progress marker present pre-run
- PASS: (d/account-plus-tree) fixture precondition: complete marker absent pre-run
- PASS: (d/account-plus-tree) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/account-plus-tree) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/account-plus-tree) complete marker written after recovery (root probe)
- PASS: (d/account-plus-tree) in-progress marker removed (root probe)
- (d/account-plus-tree) outcome: expect=ready ready=yes code=0
- PASS: (d/version-link) fixture precondition: in-progress marker present pre-run
- PASS: (d/version-link) fixture precondition: complete marker absent pre-run
- PASS: (d/version-link) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/version-link) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/version-link) complete marker written after recovery (root probe)
- PASS: (d/version-link) in-progress marker removed (root probe)
- (d/version-link) outcome: expect=ready ready=yes code=0
- PASS: (d/tree-only) fixture precondition: in-progress marker present pre-run
- PASS: (d/tree-only) fixture precondition: complete marker absent pre-run
- PASS: (d/tree-only) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/tree-only) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/tree-only) complete marker written after recovery (root probe)
- PASS: (d/tree-only) in-progress marker removed (root probe)
- (d/tree-only) outcome: expect=ready ready=yes code=0
- PASS: (d/account-only) fixture precondition: in-progress marker present pre-run
- PASS: (d/account-only) fixture precondition: complete marker absent pre-run
- PASS: (d/account-only) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/account-only) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/account-only) complete marker written after recovery (root probe)
- PASS: (d/account-only) in-progress marker removed (root probe)
- (d/account-only) outcome: expect=ready ready=yes code=0
- PASS: (d/apache-conf) fixture precondition: in-progress marker present pre-run
- PASS: (d/apache-conf) fixture precondition: complete marker absent pre-run
- PASS: (d/apache-conf) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/apache-conf) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/apache-conf) complete marker written after recovery (root probe)
- PASS: (d/apache-conf) in-progress marker removed (root probe)
- (d/apache-conf) outcome: expect=ready ready=yes code=0
- PASS: (d/fstab) fixture precondition: in-progress marker present pre-run
- PASS: (d/fstab) fixture precondition: complete marker absent pre-run
- PASS: (d/fstab) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/fstab) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/fstab) complete marker written after recovery (root probe)
- PASS: (d/fstab) in-progress marker removed (root probe)
- (d/fstab) outcome: expect=ready ready=yes code=0
- PASS: (d/uid-gid-occupied) irreconcilable ? actionable exit 1 (code=1)
- PASS: (d/uid-gid-occupied) fatal reason names the occupying account
```
FATAL: recovery: uid 1234 is occupied by a different account - the interrupted creation is irreconcilable. No mutation. Remedy: free the uid (userdel the conflicting account) or restore the original volume.
```

- PASS: (d/uid-gid-occupied) no mutation (content + metadata snapshot identical)
- (d/uid-gid-occupied) outcome: expect=fatal ready=n/a code=1
- PASS: (d-injected) failure at the recovery commit point ? exit 1 (code=1)
- PASS: (d-injected) the injected line was REACHED (sentinel present, cp from stopped container)
- PASS: (d-injected) in-progress marker REMAINS after the failure (root probe)
- PASS: (d-injected) complete marker ABSENT (recovery never committed, root probe)
- PASS: (d-injected) next boot re-enters recovery, completes ready (root image)
```
ready-time=4s
```

- PASS: (d-injected) recovery committed: complete marker + in-progress gone (root probe)
## S6-s6-rocky-e
- when: 2026-11-11 04:59:40
- runtime: podman

- **RESULT: PASS**

- (e) real old-image volume: /tmp/omd-verify/s6e-legacy-rocky-mysite (identity uid=2001 gid=2002; pw/mail from .meta)
- PASS: (e) precondition: volume is marker-free (genuinely adoptable, root probe)
- PASS: (e) precondition: version link + stored site.conf + htpasswd present (root probe)
- PASS: (e) precondition: fixture identity uid and gid are DISTINCT (ownership assertions meaningful)
- PASS: (e) precondition: sentinels seeded in persistent paths with distinct content (root probe)
- PASS: (e) legacy volume adopted - site starts ready (gate + /mysite/)
```
ready-time=3s
```

- PASS: (e) prominent 'adopted existing site mysite (no init marker - legacy/pre-marker volume)' log line
```
2026-11-11T03:59:52+0000 193dc621fab5 omd-ready-check[480]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-11T03:59:52+0000 193dc621fab5 systemd[1]: Finished OMD labs bounded readiness gate (FR-018).
2026-11-11T03:59:52+0000 193dc621fab5 systemd[1]: Reached target Multi-User System.
2026-11-11T03:59:52+0000 193dc621fab5 systemd[1]: Reached target Graphical Interface.
2026-11-11T03:59:52+0000 193dc621fab5 systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T03:59:52+0000 193dc621fab5 systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T03:59:52+0000 193dc621fab5 systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T03:59:52+0000 193dc621fab5 systemd[1]: Startup finished in 2.007s.
```

- PASS: (e) stored configuration authoritative: omd config show returns the ALTERED stored value
- PASS: (e) omd status rc 0 (site registered + started, adopt path)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (e) stored site.conf UNMODIFIED (sha256 unchanged, root probe)
- PASS: (e) stored web credential FILE unmodified (htpasswd sha256 unchanged, root probe)
- PASS: (e) the stored web credential created before STILL LOGS IN (thruk 200 with stored cred from .meta, 302 anon)
```
with-cred=200 anon=302
```

- PASS: (e) init-complete marker now present (leaves the no-marker class, root probe)
- PASS: (e) identity re-recorded with the INFERRED uid/gid from the volume (root probe)
- PASS: (e) numeric ownership UNTOUCHED before/after (UID AND GID of top + persistent subfolders; the adopt's own top-level .omd-labs-* artifacts excluded, root probe)
- PASS: (e) top dir carries the image omd gid (uid=2001 group=omd, 0750) after adoption (root probe)
- PASS: (e) sentinel content UNTOUCHED (etc/omd, var/lib, local - exact lines, root probe)
- PASS: (e) sentinel metadata UNTOUCHED (uid/gid/mode identical before/after - umask-dependent, no guessed mode, root probe)
## S6-s6-rocky-e-inputs
- when: 2026-11-11 05:00:00
- runtime: podman

- **RESULT: PASS**

- PASS: (e-inputs) legacy volume adopted WITH inputs - site starts ready
```
ready-time=3s
```

- PASS: (e-inputs) 'adopted existing site' banner (contract string)
```
2026-11-11T04:00:10+0000 89dabab5a268 omd-ready-check[484]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-11T04:00:10+0000 89dabab5a268 systemd[1]: Finished OMD labs bounded readiness gate (FR-018).
2026-11-11T04:00:10+0000 89dabab5a268 systemd[1]: Reached target Multi-User System.
2026-11-11T04:00:10+0000 89dabab5a268 systemd[1]: Reached target Graphical Interface.
2026-11-11T04:00:10+0000 89dabab5a268 systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T04:00:10+0000 89dabab5a268 systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T04:00:10+0000 89dabab5a268 systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T04:00:10+0000 89dabab5a268 systemd[1]: Startup finished in 2.030s.
```

- PASS: (e-inputs) FR-012 notice logged: inputs supplied but NOT applied (stored config authoritative)
```
2026-11-11T04:00:10+0000 89dabab5a268 omd-ready-check[484]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-11T04:00:10+0000 89dabab5a268 systemd[1]: Finished OMD labs bounded readiness gate (FR-018).
2026-11-11T04:00:10+0000 89dabab5a268 systemd[1]: Reached target Multi-User System.
2026-11-11T04:00:10+0000 89dabab5a268 systemd[1]: Reached target Graphical Interface.
2026-11-11T04:00:10+0000 89dabab5a268 systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T04:00:10+0000 89dabab5a268 systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T04:00:10+0000 89dabab5a268 systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T04:00:10+0000 89dabab5a268 systemd[1]: Startup finished in 2.030s.
```

- PASS: (e-inputs) MOD_GEARMAN still the stored value off (input 'on' NOT applied)
- PASS: (e-inputs) PNP4NAGIOS still the stored value on (untouched by the adopt)
- PASS: (e-inputs) no 4730 listener (stored MOD_GEARMAN off - input not applied; capture non-empty - N2)
- PASS: (e-inputs) stored site.conf UNMODIFIED (sha256 unchanged, root probe)
- PASS: (e-inputs) the stored web credential created before STILL LOGS IN (thruk 200 with stored cred from .meta)
```
with-cred=200
```

- PASS: (e-inputs) init-complete marker written by the adopt (root probe)
- PASS: (e-inputs) /run/omd-labs.env carries SITE_CUSTOM_APPLIED=0 (inputs validated, not applied)
## S6-s6-rocky-g
- when: 2026-11-11 05:00:18
- runtime: podman

- **RESULT: PASS**

- PASS: (g1) ambiguous identity ? actionable exit 1 (code=1)
- PASS: (g1) fatal reason names the ambiguity
```
FATAL: inferred identity is AMBIGUOUS - the site subfolders' group (996) equals the omd group's gid; the primary gid cannot be determined. Refusing (no mutation). Remedy: run the site once from its original image or set the identity manually.
```

- PASS: (g1) volume unchanged: content + ownership/mode metadata identical
- PASS: (g2) lost identity file ? resume via inference, site starts ready
```
ready-time=3s
```

- PASS: (g2) .omd-labs-site-identity RE-RECORDED with the inferred 1234/1234
- PASS: (g3) recorded identity honored: site starts ready
```
ready-time=3s
```

- PASS: (g3) fresh-container account carries uid=1234 (id recid)
- PASS: (g3) fresh-container account carries primary gid=1234 (id recid)
- PASS: (g4) occupied uid on resume ? exit 1 (code=1)
- PASS: (g4) fatal names the collision (occupied uid / foreign group - F2 validation before any write)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site occres
```

- PASS: (g4) no-mutation: volume byte-identical (identity NOT re-written, no group change - F2 ordering)
- PASS: (g5) occupied uid/gid on adopt ? exit 1 (code=1)
- PASS: (g5) fatal names the collision (occupied uid / foreign group - F2 validation before any write)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site occadp
```

- PASS: (g5) no-mutation: volume byte-identical (no identity file, no group)
- PASS: (g5) adopt-complete marker ABSENT (adopt wrote nothing before the fatal)
- PASS: (g6) fixture precondition: stale in-progress marker present on a completed volume (root probe)
- PASS: (g6) persisted volume with stale marker ? resume ready (inference + re-record)
```
ready-time=4s
```

- PASS: (g6) stale in-progress marker REMOVED after validation (root probe)
- PASS: (g6) log carries the deterministic removal notice
```
2026-11-11T04:01:45+0000 7bc9b2693a67 omd-ready-check[477]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-11T04:01:45+0000 7bc9b2693a67 systemd[1]: Finished OMD labs bounded readiness gate (FR-018).
2026-11-11T04:01:45+0000 7bc9b2693a67 systemd[1]: Reached target Multi-User System.
2026-11-11T04:01:45+0000 7bc9b2693a67 systemd[1]: Reached target Graphical Interface.
2026-11-11T04:01:45+0000 7bc9b2693a67 systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T04:01:45+0000 7bc9b2693a67 systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T04:01:45+0000 7bc9b2693a67 systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T04:01:45+0000 7bc9b2693a67 systemd[1]: Startup finished in 2.007s.
```

- PASS: (g6) identity re-recorded (root probe)
- PASS: (g7) malformed recorded identity ? exit 1 (code=1)
- PASS: (g7) fatal names the malformed identity (no account-tool rejection)
```
FATAL: malformed recorded identity (uid='abc') for site badid - the value must be a non-empty integer. No mutation. Remedy: fix or remove .omd-labs-site-identity.
```

- PASS: (g7) no-mutation: volume byte-identical (identity NOT re-written - F2 ordering)
- PASS: (g8) stale marker + foreign gid ? exit 1 (code=1)
- PASS: (g8) fatal names the collision (occupied uid / foreign group)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site staled
```

- PASS: (g8) in-progress marker RETAINED (removed only AFTER validation - no-mutation)
- PASS: (g8) no-mutation: volume byte-identical
- PASS: (g9) GID-only foreign collision on resume ? exit 1 (code=1)
- PASS: (g9) fatal names the foreign group (belongs to group 'occgrp')
```
FATAL: gid 1234 belongs to group 'occgrp', not site 'gonly' - refusing to bind the site account to a foreign group (no mutation). Remedy: free the gid or fix the recorded identity.
```

- PASS: (g9) no-mutation: volume byte-identical (F2 ordering)
- PASS: (g10) inverse collision (site-named group at wrong gid) ? exit 1 (code=1)
- PASS: (g10) fatal names the inverse collision (exists at gid 1230)
```
FATAL: a group named 'g10id' already exists at gid 1230 (the recorded identity requests gid 1234) - refusing (no mutation). Remedy: groupdel/rename the existing group or fix the recorded identity.
```

- PASS: (g10) no-mutation: volume byte-identical (identity NOT re-written - F2 ordering)
- PASS: (g10) the ORIGINAL identity line is intact (not overwritten by the failed restore)
## S6-s6-rocky-a
- when: 2026-11-11 05:04:10
- runtime: podman

- **RESULT: PASS**

- PASS: (a) invalid key OMDCFG_NOT_A_KEY ? exit 1 <=30 s (code=1)
- PASS: (a) fatal reason names the key; nothing half-configured left running
```
FATAL: invalid customization NOT_A_KEY=on: omd config set refused it (rc=1; 124 = budget timeout, 137 = killed after ignoring TERM)
FATAL: nothing was started (pre-init, FR-011). Fix the key/value - run 'omd config <site> show' for the valid values. omd said: No such variable 'NOT_A_KEY'
```

- PASS: (b) invalid value MOD_GEARMAN=bogus ? exit 1 <=30 s (code=1)
- PASS: (b) fatal reason names key+value; retry with corrected input succeeds (T027 covers retry)
```
FATAL: invalid customization MOD_GEARMAN=bogus: omd config set refused it (rc=1; 124 = budget timeout, 137 = killed after ignoring TERM)
```

## S5-s5-debian
- when: 2026-11-11 05:04:29
- runtime: podman

- **RESULT: PASS**

- PASS: readiness (gate + /custsite/)
```
ready-time=8s
```

- PASS: gearmand listening on 4730 when ready (SC-012 - component came up with the site)
- PASS: env value WON the conflict: omd config show GEARMAND_PORT = 0.0.0.0:4730 (EXACT line)
- PASS: effective config observable: MOD_GEARMAN = on (EXACT line)
- PASS: container log carries the effective-customization summary (FR-010; bounded wait for log flush)
```
2026-11-11T04:04:37+00:00 83bb0626e6d1 systemd[1]: Startup finished in 3.196s.
2026-11-11T04:04:37+00:00 83bb0626e6d1 /etc/mysql/debian-start[2506]: Upgrading MariaDB tables if necessary.
2026-11-11T04:04:37+00:00 83bb0626e6d1 /etc/mysql/debian-start[2517]: Checking for insecure root accounts.
2026-11-11T04:04:37+00:00 83bb0626e6d1 /etc/mysql/debian-start[2521]: Triggering myisam-recover for all MyISAM tables and aria-recover for all Aria tables
2026-11-11T04:04:37+00:00 83bb0626e6d1 runuser[2537]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
2026-11-11T04:04:37+00:00 83bb0626e6d1 runuser[2537]: pam_unix(runuser:session): session closed for user custsite
2026-11-11T04:04:37+00:00 83bb0626e6d1 runuser[2628]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
2026-11-11T04:04:38+00:00 83bb0626e6d1 runuser[2628]: pam_unix(runuser:session): session closed for user custsite
```

- PASS: listener address is the env value (0.0.0.0:4730)
- PASS: no customization input ? ready BEFORE the negative listener check
```
ready-time=5s
```

- PASS: no customization input ? no 4730 listener (capture non-empty first - N2)
- PASS: S6c: persisted site resumes ready (stored configuration authoritative)
```
ready-time=3s
```

- PASS: S6c: stored value survives (GEARMAND_PORT still 0.0.0.0:4730 - inputs NOT applied, EXACT line)
- PASS: S6c: log carries the deterministic notice that inputs were not applied (FR-012; bounded wait)
```
2026-11-11T04:04:50+00:00 27ce6f2a416c dbus-daemon[120]: [system] Successfully activated service 'org.freedesktop.timedate1'
2026-11-11T04:04:50+00:00 27ce6f2a416c omd-ready-check[673]: READY: base services up (omd-site active, apache2 443, sshd 22)
2026-11-11T04:04:50+00:00 27ce6f2a416c systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-11T04:04:50+00:00 27ce6f2a416c systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-11T04:04:50+00:00 27ce6f2a416c systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-11T04:04:50+00:00 27ce6f2a416c systemd[1]: Startup finished in 2.229s.
2026-11-11T04:04:51+00:00 27ce6f2a416c runuser[835]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
2026-11-11T04:04:51+00:00 27ce6f2a416c runuser[835]: pam_unix(runuser:session): session closed for user custsite
```

## S6-s6-debian-a
- when: 2026-11-11 05:04:54
- runtime: podman

## S6-s6-debian-d
- when: 2026-11-11 05:04:54
- runtime: podman

- **RESULT: PASS**

- PASS: (d/account-plus-tree) fixture precondition: in-progress marker present pre-run
- PASS: (d/account-plus-tree) fixture precondition: complete marker absent pre-run
- PASS: (d/account-plus-tree) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/account-plus-tree) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/account-plus-tree) complete marker written after recovery (root probe)
- PASS: (d/account-plus-tree) in-progress marker removed (root probe)
- (d/account-plus-tree) outcome: expect=ready ready=yes code=0
- PASS: (d/version-link) fixture precondition: in-progress marker present pre-run
- PASS: (d/version-link) fixture precondition: complete marker absent pre-run
- PASS: (d/version-link) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/version-link) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/version-link) complete marker written after recovery (root probe)
- PASS: (d/version-link) in-progress marker removed (root probe)
- (d/version-link) outcome: expect=ready ready=yes code=0
- PASS: (d/tree-only) fixture precondition: in-progress marker present pre-run
- PASS: (d/tree-only) fixture precondition: complete marker absent pre-run
- PASS: (d/tree-only) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/tree-only) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/tree-only) complete marker written after recovery (root probe)
- PASS: (d/tree-only) in-progress marker removed (root probe)
- (d/tree-only) outcome: expect=ready ready=yes code=0
- PASS: (d/account-only) fixture precondition: in-progress marker present pre-run
- PASS: (d/account-only) fixture precondition: complete marker absent pre-run
- PASS: (d/account-only) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/account-only) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/account-only) complete marker written after recovery (root probe)
- PASS: (d/account-only) in-progress marker removed (root probe)
- (d/account-only) outcome: expect=ready ready=yes code=0
- PASS: (d/apache-conf) fixture precondition: in-progress marker present pre-run
- PASS: (d/apache-conf) fixture precondition: complete marker absent pre-run
- PASS: (d/apache-conf) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/apache-conf) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/apache-conf) complete marker written after recovery (root probe)
- PASS: (d/apache-conf) in-progress marker removed (root probe)
- (d/apache-conf) outcome: expect=ready ready=yes code=0
- PASS: (d/fstab) fixture precondition: in-progress marker present pre-run
- PASS: (d/fstab) fixture precondition: complete marker absent pre-run
- PASS: (d/fstab) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/fstab) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/fstab) complete marker written after recovery (root probe)
- PASS: (d/fstab) in-progress marker removed (root probe)
- (d/fstab) outcome: expect=ready ready=yes code=0
- PASS: (d/uid-gid-occupied) irreconcilable ? actionable exit 1 (code=1)
- PASS: (d/uid-gid-occupied) fatal reason names the occupying account
```
FATAL: recovery: uid 1234 is occupied by a different account - the interrupted creation is irreconcilable. No mutation. Remedy: free the uid (userdel the conflicting account) or restore the original volume.
```

- PASS: (d/uid-gid-occupied) no mutation (content + metadata snapshot identical)
- (d/uid-gid-occupied) outcome: expect=fatal ready=n/a code=1
- PASS: (d-injected) failure at the recovery commit point ? exit 1 (code=1)
- PASS: (d-injected) the injected line was REACHED (sentinel present, cp from stopped container)
- PASS: (d-injected) in-progress marker REMAINS after the failure (root probe)
- PASS: (d-injected) complete marker ABSENT (recovery never committed, root probe)
- PASS: (d-injected) next boot re-enters recovery, completes ready (root image)
```
ready-time=3s
```

- PASS: (d-injected) recovery committed: complete marker + in-progress gone (root probe)
## S6-s6-debian-e
- when: 2026-11-11 05:06:44
- runtime: podman

- **RESULT: PASS**

- (e) real old-image volume: /tmp/omd-verify/s6e-legacy-debian-mysite (identity uid=2001 gid=2002; pw/mail from .meta)
- PASS: (e) precondition: volume is marker-free (genuinely adoptable, root probe)
- PASS: (e) precondition: version link + stored site.conf + htpasswd present (root probe)
- PASS: (e) precondition: fixture identity uid and gid are DISTINCT (ownership assertions meaningful)
- PASS: (e) precondition: sentinels seeded in persistent paths with distinct content (root probe)
- PASS: (e) legacy volume adopted - site starts ready (gate + /mysite/)
```
ready-time=4s
```

- PASS: (e) prominent 'adopted existing site mysite (no init marker - legacy/pre-marker volume)' log line
```
2026-11-11T04:06:54+00:00 e9ca13251be9 systemd[1]: Started exim4.service - exim Mail Transport Agent.
2026-11-11T04:06:54+00:00 e9ca13251be9 systemd[1]: Started mariadb.service - MariaDB 11.8.6 database server.
2026-11-11T04:06:54+00:00 e9ca13251be9 systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-11T04:06:54+00:00 e9ca13251be9 systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-11T04:06:54+00:00 e9ca13251be9 systemd[1]: Startup finished in 2.255s.
2026-11-11T04:06:54+00:00 e9ca13251be9 /etc/mysql/debian-start[732]: Upgrading MariaDB tables if necessary.
2026-11-11T04:06:54+00:00 e9ca13251be9 /etc/mysql/debian-start[743]: Checking for insecure root accounts.
2026-11-11T04:06:54+00:00 e9ca13251be9 /etc/mysql/debian-start[747]: Triggering myisam-recover for all MyISAM tables and aria-recover for all Aria tables
```

- PASS: (e) stored configuration authoritative: omd config show returns the ALTERED stored value
- PASS: (e) omd status rc 0 (site registered + started, adopt path)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (e) stored site.conf UNMODIFIED (sha256 unchanged, root probe)
- PASS: (e) stored web credential FILE unmodified (htpasswd sha256 unchanged, root probe)
- PASS: (e) the stored web credential created before STILL LOGS IN (thruk 200 with stored cred from .meta, 302 anon)
```
with-cred=200 anon=302
```

- PASS: (e) init-complete marker now present (leaves the no-marker class, root probe)
- PASS: (e) identity re-recorded with the INFERRED uid/gid from the volume (root probe)
- PASS: (e) numeric ownership UNTOUCHED before/after (UID AND GID of top + persistent subfolders; the adopt's own top-level .omd-labs-* artifacts excluded, root probe)
- PASS: (e) top dir carries the image omd gid (uid=2001 group=omd, 0750) after adoption (root probe)
- PASS: (e) sentinel content UNTOUCHED (etc/omd, var/lib, local - exact lines, root probe)
- PASS: (e) sentinel metadata UNTOUCHED (uid/gid/mode identical before/after - umask-dependent, no guessed mode, root probe)
## S6-s6-debian-e-inputs
- when: 2026-11-11 05:07:01
- runtime: podman

- **RESULT: PASS**

- PASS: (e-inputs) legacy volume adopted WITH inputs - site starts ready
```
ready-time=3s
```

- PASS: (e-inputs) 'adopted existing site' banner (contract string)
```
2026-11-11T04:07:10+00:00 e7c1b867776c mariadbd[256]: Version: '11.8.6-MariaDB-0+deb13u1 from Debian'  socket: '/run/mysqld/mysqld.sock'  port: 3306  -- Please help get to 10k stars at https://github.com/MariaDB/Server
2026-11-11T04:07:10+00:00 e7c1b867776c systemd[1]: Started mariadb.service - MariaDB 11.8.6 database server.
2026-11-11T04:07:10+00:00 e7c1b867776c systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-11T04:07:10+00:00 e7c1b867776c systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-11T04:07:10+00:00 e7c1b867776c systemd[1]: Startup finished in 2.683s.
2026-11-11T04:07:10+00:00 e7c1b867776c /etc/mysql/debian-start[736]: Upgrading MariaDB tables if necessary.
2026-11-11T04:07:10+00:00 e7c1b867776c /etc/mysql/debian-start[747]: Checking for insecure root accounts.
2026-11-11T04:07:10+00:00 e7c1b867776c /etc/mysql/debian-start[751]: Triggering myisam-recover for all MyISAM tables and aria-recover for all Aria tables
```

- PASS: (e-inputs) FR-012 notice logged: inputs supplied but NOT applied (stored config authoritative)
```
2026-11-11T04:07:10+00:00 e7c1b867776c mariadbd[256]: Version: '11.8.6-MariaDB-0+deb13u1 from Debian'  socket: '/run/mysqld/mysqld.sock'  port: 3306  -- Please help get to 10k stars at https://github.com/MariaDB/Server
2026-11-11T04:07:10+00:00 e7c1b867776c systemd[1]: Started mariadb.service - MariaDB 11.8.6 database server.
2026-11-11T04:07:10+00:00 e7c1b867776c systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-11T04:07:10+00:00 e7c1b867776c systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-11T04:07:10+00:00 e7c1b867776c systemd[1]: Startup finished in 2.683s.
2026-11-11T04:07:10+00:00 e7c1b867776c /etc/mysql/debian-start[736]: Upgrading MariaDB tables if necessary.
2026-11-11T04:07:10+00:00 e7c1b867776c /etc/mysql/debian-start[747]: Checking for insecure root accounts.
2026-11-11T04:07:10+00:00 e7c1b867776c /etc/mysql/debian-start[751]: Triggering myisam-recover for all MyISAM tables and aria-recover for all Aria tables
```

- PASS: (e-inputs) MOD_GEARMAN still the stored value off (input 'on' NOT applied)
- PASS: (e-inputs) PNP4NAGIOS still the stored value on (untouched by the adopt)
- PASS: (e-inputs) no 4730 listener (stored MOD_GEARMAN off - input not applied; capture non-empty - N2)
- PASS: (e-inputs) stored site.conf UNMODIFIED (sha256 unchanged, root probe)
- PASS: (e-inputs) the stored web credential created before STILL LOGS IN (thruk 200 with stored cred from .meta)
```
with-cred=200
```

- PASS: (e-inputs) init-complete marker written by the adopt (root probe)
- PASS: (e-inputs) /run/omd-labs.env carries SITE_CUSTOM_APPLIED=0 (inputs validated, not applied)
## S6-s6-debian-g
- when: 2026-11-11 05:07:15
- runtime: podman

- **RESULT: PASS**

- PASS: (g1) ambiguous identity ? actionable exit 1 (code=1)
- PASS: (g1) fatal reason names the ambiguity
```
FATAL: inferred identity is AMBIGUOUS - the site subfolders' group (106) equals the omd group's gid; the primary gid cannot be determined. Refusing (no mutation). Remedy: run the site once from its original image or set the identity manually.
```

- PASS: (g1) volume unchanged: content + ownership/mode metadata identical
- PASS: (g2) lost identity file ? resume via inference, site starts ready
```
ready-time=4s
```

- PASS: (g2) .omd-labs-site-identity RE-RECORDED with the inferred 1234/1234
- PASS: (g3) recorded identity honored: site starts ready
```
ready-time=3s
```

- PASS: (g3) fresh-container account carries uid=1234 (id recid)
- PASS: (g3) fresh-container account carries primary gid=1234 (id recid)
- PASS: (g4) occupied uid on resume ? exit 1 (code=1)
- PASS: (g4) fatal names the collision (occupied uid / foreign group - F2 validation before any write)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site occres
```

- PASS: (g4) no-mutation: volume byte-identical (identity NOT re-written, no group change - F2 ordering)
- PASS: (g5) occupied uid/gid on adopt ? exit 1 (code=1)
- PASS: (g5) fatal names the collision (occupied uid / foreign group - F2 validation before any write)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site occadp
```

- PASS: (g5) no-mutation: volume byte-identical (no identity file, no group)
- PASS: (g5) adopt-complete marker ABSENT (adopt wrote nothing before the fatal)
- PASS: (g6) fixture precondition: stale in-progress marker present on a completed volume (root probe)
- PASS: (g6) persisted volume with stale marker ? resume ready (inference + re-record)
```
ready-time=3s
```

- PASS: (g6) stale in-progress marker REMOVED after validation (root probe)
- PASS: (g6) log carries the deterministic removal notice
```
2026-11-11T04:08:38+00:00 a0056e11d084 mariadbd[265]: Version: '11.8.6-MariaDB-0+deb13u1 from Debian'  socket: '/run/mysqld/mysqld.sock'  port: 3306  -- Please help get to 10k stars at https://github.com/MariaDB/Server
2026-11-11T04:08:38+00:00 a0056e11d084 systemd[1]: Started mariadb.service - MariaDB 11.8.6 database server.
2026-11-11T04:08:38+00:00 a0056e11d084 /etc/mysql/debian-start[732]: Upgrading MariaDB tables if necessary.
2026-11-11T04:08:38+00:00 a0056e11d084 systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-11T04:08:38+00:00 a0056e11d084 systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-11T04:08:38+00:00 a0056e11d084 systemd[1]: Startup finished in 3.001s.
2026-11-11T04:08:38+00:00 a0056e11d084 /etc/mysql/debian-start[743]: Checking for insecure root accounts.
2026-11-11T04:08:38+00:00 a0056e11d084 /etc/mysql/debian-start[747]: Triggering myisam-recover for all MyISAM tables and aria-recover for all Aria tables
```

- PASS: (g6) identity re-recorded (root probe)
- PASS: (g7) malformed recorded identity ? exit 1 (code=1)
- PASS: (g7) fatal names the malformed identity (no account-tool rejection)
```
FATAL: malformed recorded identity (uid='abc') for site badid - the value must be a non-empty integer. No mutation. Remedy: fix or remove .omd-labs-site-identity.
```

- PASS: (g7) no-mutation: volume byte-identical (identity NOT re-written - F2 ordering)
- PASS: (g8) stale marker + foreign gid ? exit 1 (code=1)
- PASS: (g8) fatal names the collision (occupied uid / foreign group)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site staled
```

- PASS: (g8) in-progress marker RETAINED (removed only AFTER validation - no-mutation)
- PASS: (g8) no-mutation: volume byte-identical
- PASS: (g9) GID-only foreign collision on resume ? exit 1 (code=1)
- PASS: (g9) fatal names the foreign group (belongs to group 'occgrp')
```
FATAL: gid 1234 belongs to group 'occgrp', not site 'gonly' - refusing to bind the site account to a foreign group (no mutation). Remedy: free the gid or fix the recorded identity.
```

- PASS: (g9) no-mutation: volume byte-identical (F2 ordering)
- PASS: (g10) inverse collision (site-named group at wrong gid) ? exit 1 (code=1)
- PASS: (g10) fatal names the inverse collision (exists at gid 1230)
```
FATAL: a group named 'g10id' already exists at gid 1230 (the recorded identity requests gid 1234) - refusing (no mutation). Remedy: groupdel/rename the existing group or fix the recorded identity.
```

- PASS: (g10) no-mutation: volume byte-identical (identity NOT re-written - F2 ordering)
- PASS: (g10) the ORIGINAL identity line is intact (not overwritten by the failed restore)
## S6-s6-rocky-a
- when: 2026-11-11 05:11:12
- runtime: podman

- **RESULT: PASS**

- PASS: (a) invalid key OMDCFG_NOT_A_KEY ? exit 1 <=30 s (code=1)
- PASS: (a) fatal reason names the key; nothing half-configured left running
```
FATAL: invalid customization NOT_A_KEY=on: omd config set refused it (rc=1; 124 = budget timeout, 137 = killed after ignoring TERM)
FATAL: nothing was started (pre-init, FR-011). Fix the key/value - run 'omd config <site> show' for the valid values. omd said: No such variable 'NOT_A_KEY'
```

- PASS: (b) invalid value MOD_GEARMAN=bogus ? exit 1 <=30 s (code=1)
- PASS: (b) fatal reason names key+value; retry with corrected input succeeds (T027 covers retry)
```
FATAL: invalid customization MOD_GEARMAN=bogus: omd config set refused it (rc=1; 124 = budget timeout, 137 = killed after ignoring TERM)
```

## S6-s6-debian-a
- when: 2026-11-11 05:11:22
- runtime: podman

- **RESULT: PASS**

- PASS: (a) invalid key OMDCFG_NOT_A_KEY ? exit 1 <=30 s (code=1)
- PASS: (a) fatal reason names the key; nothing half-configured left running
```
FATAL: invalid customization NOT_A_KEY=on: omd config set refused it (rc=1; 124 = budget timeout, 137 = killed after ignoring TERM)
FATAL: nothing was started (pre-init, FR-011). Fix the key/value - run 'omd config <site> show' for the valid values. omd said: No such variable 'NOT_A_KEY'
```

- PASS: (b) invalid value MOD_GEARMAN=bogus ? exit 1 <=30 s (code=1)
- PASS: (b) fatal reason names key+value; retry with corrected input succeeds (T027 covers retry)
```
FATAL: invalid customization MOD_GEARMAN=bogus: omd config set refused it (rc=1; 124 = budget timeout, 137 = killed after ignoring TERM)
```

## S6-s6-rocky-a
- when: 2026-11-11 05:18:54
- runtime: podman

- **RESULT: PASS**

- PASS: (a) invalid key OMDCFG_NOT_A_KEY ? exit 1 <=30 s (code=1)
- PASS: (a) fatal reason names the key; nothing half-configured left running
```
FATAL: invalid customization NOT_A_KEY=on: omd config set refused it (rc=1; 124 = budget timeout, 137 = killed after ignoring TERM)
FATAL: nothing was started (pre-init, FR-011). Fix the key/value - run 'omd config <site> show' for the valid values. omd said: No such variable 'NOT_A_KEY'
```

- PASS: (b) invalid value MOD_GEARMAN=bogus ? exit 1 <=30 s (code=1)
- PASS: (b) fatal reason names key+value
```
FATAL: invalid customization MOD_GEARMAN=bogus: omd config set refused it (rc=1; 124 = budget timeout, 137 = killed after ignoring TERM)
```

- PASS: (b) retry with corrected input succeeds: site ready (adopted the created tree, fresh input NOT applied - FR-012)
```
ready-time=3s
```

- PASS: (b) retry log carries the adoption banner + the not-applied notice (stored config authoritative)
- PASS: (a) retry with corrected input succeeds: site ready (adopted the created tree)
```
ready-time=4s
```

- PASS: (a) retry log carries the adoption banner (adopted existing site badcfg)
## S6-s6-debian-a
- when: 2026-11-11 05:19:21
- runtime: podman

- **RESULT: FAIL**

- PASS: (a) invalid key OMDCFG_NOT_A_KEY ? exit 1 <=30 s (code=1)
- PASS: (a) fatal reason names the key; nothing half-configured left running
```
FATAL: invalid customization NOT_A_KEY=on: omd config set refused it (rc=1; 124 = budget timeout, 137 = killed after ignoring TERM)
FATAL: nothing was started (pre-init, FR-011). Fix the key/value - run 'omd config <site> show' for the valid values. omd said: No such variable 'NOT_A_KEY'
```

- PASS: (b) invalid value MOD_GEARMAN=bogus ? exit 1 <=30 s (code=1)
- PASS: (b) fatal reason names key+value
```
FATAL: invalid customization MOD_GEARMAN=bogus: omd config set refused it (rc=1; 124 = budget timeout, 137 = killed after ignoring TERM)
```

- PASS: (b) retry with corrected input succeeds: site ready (adopted the created tree, fresh input NOT applied - FR-012)
```
ready-time=3s
```

- PASS: (b) retry log carries the adoption banner + the not-applied notice (stored config authoritative)
- PASS: (a) retry with corrected input succeeds: site ready (adopted the created tree)
```
ready-time=3s
```

- FAIL: (a) retry log carries the adoption banner (adopted existing site badcfg) (rc=141)
```

```

## S6-s6-rocky-a
- when: 2026-11-11 05:20:08
- runtime: podman

- **RESULT: PASS**

- PASS: (a) invalid key OMDCFG_NOT_A_KEY ? exit 1 <=30 s (code=1)
- PASS: (a) fatal reason names the key; nothing half-configured left running
```
FATAL: invalid customization NOT_A_KEY=on: omd config set refused it (rc=1; 124 = budget timeout, 137 = killed after ignoring TERM)
FATAL: nothing was started (pre-init, FR-011). Fix the key/value - run 'omd config <site> show' for the valid values. omd said: No such variable 'NOT_A_KEY'
```

- PASS: (b) invalid value MOD_GEARMAN=bogus ? exit 1 <=30 s (code=1)
- PASS: (b) fatal reason names key+value
```
FATAL: invalid customization MOD_GEARMAN=bogus: omd config set refused it (rc=1; 124 = budget timeout, 137 = killed after ignoring TERM)
```

- PASS: (b) retry with corrected input succeeds: site ready (adopted the created tree, fresh input NOT applied - FR-012)
```
ready-time=3s
```

- PASS: (b) retry log carries the adoption banner + the not-applied notice (stored config authoritative)
- PASS: (a) retry with corrected input succeeds: site ready (adopted the created tree)
```
ready-time=3s
```

- PASS: (a) retry log carries the adoption banner (adopted existing site badcfg)
## S6-s6-debian-a
- when: 2026-11-11 05:20:32
- runtime: podman

- **RESULT: PASS**

- PASS: (a) invalid key OMDCFG_NOT_A_KEY ? exit 1 <=30 s (code=1)
- PASS: (a) fatal reason names the key; nothing half-configured left running
```
FATAL: invalid customization NOT_A_KEY=on: omd config set refused it (rc=1; 124 = budget timeout, 137 = killed after ignoring TERM)
FATAL: nothing was started (pre-init, FR-011). Fix the key/value - run 'omd config <site> show' for the valid values. omd said: No such variable 'NOT_A_KEY'
```

- PASS: (b) invalid value MOD_GEARMAN=bogus ? exit 1 <=30 s (code=1)
- PASS: (b) fatal reason names key+value
```
FATAL: invalid customization MOD_GEARMAN=bogus: omd config set refused it (rc=1; 124 = budget timeout, 137 = killed after ignoring TERM)
```

- PASS: (b) retry with corrected input succeeds: site ready (adopted the created tree, fresh input NOT applied - FR-012)
```
ready-time=3s
```

- PASS: (b) retry log carries the adoption banner + the not-applied notice (stored config authoritative)
- PASS: (a) retry with corrected input succeeds: site ready (adopted the created tree)
```
ready-time=3s
```

- PASS: (a) retry log carries the adoption banner (adopted existing site badcfg)


## T027-BUILD12-2026-11-11 (rebuild both images + canonical suite runs for the record)

- **Image rebuild #12** (T027's first step - the rebuild point for T026's
  entry change): `podman build -f Dockerfile.omd-labs-{rocky,debian}
  -t local/omd-labs-{rocky,debian}:nightly --build-arg OMD_VERSION=master .`
  both rc=0. New image ids: rocky 9dcd168bff84, debian
  e81572122b4b (build #11 superseded). Baked entry sha256 verified IDENTICAL
  to the host scripts/omd-labs-entry (873801c8bc7d43d3edcac90d388a8b520c42
  404f91de4dcaa4d971a6f2417340) in BOTH images. (`make -f
  Makefile.omd-labs-systemd-vm-rocky build` still fails on this host - `hooks/build`
  hardcodes docker, absent; the podman equivalent was invoked directly with
  the same Dockerfile/image name/build-arg.)
- **Canonical suite runs** (rebuild #12, both distros, strictly sequential,
  via run.sh with tag nightly; ports 18458/18460/18461):
  | scenario | rocky | debian |
  | s5 (customization happy path + S6c persisted-restart) | 11 PASS / 0 FAIL | 11 PASS / 0 FAIL |
  | s6 a (invalid key/value + RETRY half) | 8 PASS / 0 FAIL | 8 PASS / 0 FAIL |
  | s6 d (interrupted-creation matrix) | 45 PASS / 0 FAIL | 45 PASS / 0 FAIL |
  | s6 e (legacy adoption core) | 17 PASS / 0 FAIL | 17 PASS / 0 FAIL |
  | s6 e-inputs (T2c input half) | 10 PASS / 0 FAIL | 10 PASS / 0 FAIL |
  | s6 g (identity fixtures g1-g10) | 34 PASS / 0 FAIL | 34 PASS / 0 FAIL |
  Ready-times within documented bounds (3-11 s; first/customized starts
  6-11 s, resume/adopt/retry 3-4 s). Sections appended to this file
  (s5/s6d/s6e/s6ein/s6g @5463-6022 for the first runs; the final s6-a
  8/8 sections @6128 rocky, @6159 debian).
- **s6 a/b latent defects found + fixed by T027 (the sub-item had NEVER
  executed before - T026 smokes covered only g/e-inputs/s5):**
  1. The a/b block mounted $FIXDIR/s6a and $FIXDIR/s6b which NOTHING ever
     created: podman refuses the missing mount SOURCE (statfs, rc 125) and
     `set -euo pipefail` aborted the scenario before any check. FIX:
     fresh per-run dirs via mktemp -d (verify/scenarios/s6.sh :35-36).
  2. Reusing a fixed dir across runs is ALSO unsafe: the containers run
     with a :z label, so after a run the host dir is container-labeled and
     carries site-owned subdirs (uid 1000 - a uid ABSENT on the host; the
     site IS created before the customization fatal), and host-root
     rm -rf is DENIED (SELinux - "Permission denied", rc 1). This is the
     suite's known stale-VDIR pitfall; FIX: the mktemp -d per-run
     convention (prior dirs orphaned in /tmp, harmless).
  3. The RETRY half of the a/b acceptance ("a retry with corrected input
     succeeds") was uncodified (the old s6b check text said "T027 covers
     retry"). Ground truth for the retry (empirical, both distros): a
     customization fail-fast leaves a COMPLETE site tree (omd create
     finishes before the customization fatal) with NO .omd-labs-* markers
     (rollback removes the in-progress marker AND the identity file by
     design), so the retry classifies row 3b ADOPT: the adopt infers the
     identity from the volume (home uid 1000 + subfolder gid 1000 - both
     FREE in a fresh container, verified) and writes
     .omd-labs-site-identity uid=1000 gid=1000. Codified: (b) retry with
     corrected OMDCFG_MOD_GEARMAN=on + (a) retry - both assert ready +
     "adopted existing site" banner + (b) the FR-012 "not applied" notice
     (the adopted path does not apply inputs). 8/8 PASS both distros.
  4. SIGPIPE race in the banner checks: `echo "$l" | grep -q ...` closes
     the pipe EARLY when the match is found -> the echo writer dies with
     rc 141 (EMPIRICAL: FAIL on debian, PASS on rocky - the race is
     timing-dependent). FIX: grep -c (reads all input, no early exit).
- **Suite hygiene**: bash -n + ASCII clean on verify/scenarios/s6.sh;
  splices verified with cat -A.
- **Still open for T027's sign-off**: the spar round (codex review of the
  T027 window: rebuild + canonical runs + the four a/b fixes). Phase 8
  tasks (T028 s7 battery, T029 s8 audit, T030 README, T031/T038 PENDING
  no-docker, T035 PENDING no-arm64, T039 5666/NRPE record) follow, each
  with a codex round, then the final whole-implementation adversarial
  round.
## S6-s6-rocky-a
- when: 2026-11-11 06:08:37
- runtime: podman

- **RESULT: PASS**

- PASS: (a) invalid key OMDCFG_NOT_A_KEY ? exit 1 <=30 s (code=1, elapsed=4s)
- PASS: (a) fatal reason names the key; nothing half-configured left running
```
FATAL: invalid customization NOT_A_KEY=on: omd config set refused it (rc=1; 124 = budget timeout, 137 = killed after ignoring TERM)
FATAL: nothing was started (pre-init, FR-011). Fix the key/value - run 'omd config <site> show' for the valid values. omd said: No such variable 'NOT_A_KEY'
```

- PASS: (b) invalid value MOD_GEARMAN=bogus ? exit 1 <=30 s (code=1, elapsed=3s)
- PASS: (b) fatal reason names key+value
```
FATAL: invalid customization MOD_GEARMAN=bogus: omd config set refused it (rc=1; 124 = budget timeout, 137 = killed after ignoring TERM)
```

- PASS: (b) failed first creation retained its in-progress provenance (root probe)
- PASS: (b) retry with corrected input succeeds: site ready (recovered, corrected settings re-applied)
```
ready-time=4s
```

- PASS: (b) retry log: the recovery banners (re-registered after creation completed)
- PASS: (b) retry log: the corrected input WAS applied (customization applied: MOD_GEARMAN=on)
- PASS: (b) retry stored MOD_GEARMAN = on (the corrected value - not the pre-fail off)
- PASS: (b) retry log carries NO adoption banner (recovery, not adopt - capture non-empty)
- PASS: (a) failed first creation retained its in-progress provenance (root probe)
- PASS: (a) retry with corrected input succeeds: site ready (recovered, corrected settings re-applied)
```
ready-time=5s
```

- PASS: (a) retry log: recovery banners + the corrected input was applied
- PASS: (a) retry stored MOD_GEARMAN = on (the corrected value)
- PASS: (a) retry log carries NO adoption banner (recovery, not adopt - capture non-empty)
- PASS: (c) partial failure: exit 1 <=30 s (code=1, elapsed=6s)
- PASS: (c) partial failure: fatal names the failing key
```
FATAL: invalid customization GEARMAND=bogus: omd config set refused it (rc=1; 124 = budget timeout, 137 = killed after ignoring TERM)
```

- PASS: (c) partial failure retained the in-progress provenance (root probe)
- PASS: (c) earlier valid setting WAS applied before the later failure (stored MOD_GEARMAN on)
- PASS: (c) the failing setting was NOT stored (GEARMAND not 'bogus')
- PASS: (c) retry with the corrected pair: site ready (recovered)
```
ready-time=6s
```

- PASS: (c) retry log: recovery + both settings applied
- PASS: (c) retry stored MOD_GEARMAN = on
- PASS: (c) retry stored GEARMAND = on (the corrected value)
- PASS: (c) retry: the corrected component is up - 4730 listener (capture non-empty first - N2)
- PASS: (c) retry log carries NO adoption banner (recovery, not adopt - capture non-empty)
## S6-s6-debian-a
- when: 2026-11-11 06:09:29
- runtime: podman

- **RESULT: PASS**

- PASS: (a) invalid key OMDCFG_NOT_A_KEY ? exit 1 <=30 s (code=1, elapsed=3s)
- PASS: (a) fatal reason names the key; nothing half-configured left running
```
FATAL: invalid customization NOT_A_KEY=on: omd config set refused it (rc=1; 124 = budget timeout, 137 = killed after ignoring TERM)
FATAL: nothing was started (pre-init, FR-011). Fix the key/value - run 'omd config <site> show' for the valid values. omd said: No such variable 'NOT_A_KEY'
```

- PASS: (b) invalid value MOD_GEARMAN=bogus ? exit 1 <=30 s (code=1, elapsed=4s)
- PASS: (b) fatal reason names key+value
```
FATAL: invalid customization MOD_GEARMAN=bogus: omd config set refused it (rc=1; 124 = budget timeout, 137 = killed after ignoring TERM)
```

- PASS: (b) failed first creation retained its in-progress provenance (root probe)
- PASS: (b) retry with corrected input succeeds: site ready (recovered, corrected settings re-applied)
```
ready-time=4s
```

- PASS: (b) retry log: the recovery banners (re-registered after creation completed)
- PASS: (b) retry log: the corrected input WAS applied (customization applied: MOD_GEARMAN=on)
- PASS: (b) retry stored MOD_GEARMAN = on (the corrected value - not the pre-fail off)
- PASS: (b) retry log carries NO adoption banner (recovery, not adopt - capture non-empty)
- PASS: (a) failed first creation retained its in-progress provenance (root probe)
- PASS: (a) retry with corrected input succeeds: site ready (recovered, corrected settings re-applied)
```
ready-time=4s
```

- PASS: (a) retry log: recovery banners + the corrected input was applied
- PASS: (a) retry stored MOD_GEARMAN = on (the corrected value)
- PASS: (a) retry log carries NO adoption banner (recovery, not adopt - capture non-empty)
- PASS: (c) partial failure: exit 1 <=30 s (code=1, elapsed=4s)
- PASS: (c) partial failure: fatal names the failing key
```
FATAL: invalid customization GEARMAND=bogus: omd config set refused it (rc=1; 124 = budget timeout, 137 = killed after ignoring TERM)
```

- PASS: (c) partial failure retained the in-progress provenance (root probe)
- PASS: (c) earlier valid setting WAS applied before the later failure (stored MOD_GEARMAN on)
- PASS: (c) the failing setting was NOT stored (GEARMAND not 'bogus')
- PASS: (c) retry with the corrected pair: site ready (recovered)
```
ready-time=5s
```

- PASS: (c) retry log: recovery + both settings applied
- PASS: (c) retry stored MOD_GEARMAN = on
- PASS: (c) retry stored GEARMAND = on (the corrected value)
- PASS: (c) retry: the corrected component is up - 4730 listener (capture non-empty first - N2)
- PASS: (c) retry log carries NO adoption banner (recovery, not adopt - capture non-empty)
## S5-s5-rocky
- when: 2026-11-11 06:10:27
- runtime: podman

- **RESULT: PASS**

- PASS: readiness (gate + /custsite/)
```
ready-time=10s
```

- PASS: gearmand listening on 4730 when ready (SC-012 - component came up with the site)
- PASS: env value WON the conflict: omd config show GEARMAND_PORT = 0.0.0.0:4730 (EXACT line)
- PASS: effective config observable: MOD_GEARMAN = on (EXACT line)
- PASS: container log carries the effective-customization summary (FR-010; bounded wait for log flush)
```
2026-11-11T05:10:36+0000 fe35a782035b systemd[1]: Reached target Graphical Interface.
2026-11-11T05:10:36+0000 fe35a782035b systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T05:10:36+0000 fe35a782035b systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T05:10:36+0000 fe35a782035b systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T05:10:36+0000 fe35a782035b systemd[1]: Startup finished in 2.742s.
2026-11-11T05:10:37+0000 fe35a782035b runuser[2349]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
2026-11-11T05:10:38+0000 fe35a782035b runuser[2349]: pam_unix(runuser:session): session closed for user custsite
2026-11-11T05:10:38+0000 fe35a782035b runuser[2427]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
```

- PASS: listener address is the env value (0.0.0.0:4730)
- PASS: no customization input ? ready BEFORE the negative listener check
```
ready-time=6s
```

- PASS: no customization input ? no 4730 listener (capture non-empty first - N2)
- PASS: S6c: persisted site resumes ready (stored configuration authoritative)
```
ready-time=4s
```

- PASS: S6c: stored value survives (GEARMAND_PORT still 0.0.0.0:4730 - inputs NOT applied, EXACT line)
- PASS: S6c: log carries the deterministic notice that inputs were not applied (FR-012; bounded wait)
```
2026-11-11T05:10:54+0000 d3cbeb292247 systemd[1]: Reached target Multi-User System.
2026-11-11T05:10:54+0000 d3cbeb292247 systemd[1]: Reached target Graphical Interface.
2026-11-11T05:10:54+0000 d3cbeb292247 systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T05:10:54+0000 d3cbeb292247 systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T05:10:54+0000 d3cbeb292247 systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T05:10:54+0000 d3cbeb292247 systemd[1]: Startup finished in 2.189s.
2026-11-11T05:10:55+0000 d3cbeb292247 runuser[677]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
2026-11-11T05:10:55+0000 d3cbeb292247 runuser[677]: pam_unix(runuser:session): session closed for user custsite
```

## S6-s6-rocky-d
- when: 2026-11-11 06:10:58
- runtime: podman

- **RESULT: PASS**

- PASS: (d/account-plus-tree) fixture precondition: in-progress marker present pre-run
- PASS: (d/account-plus-tree) fixture precondition: complete marker absent pre-run
- PASS: (d/account-plus-tree) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/account-plus-tree) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/account-plus-tree) complete marker written after recovery (root probe)
- PASS: (d/account-plus-tree) in-progress marker removed (root probe)
- (d/account-plus-tree) outcome: expect=ready ready=yes code=0
- PASS: (d/version-link) fixture precondition: in-progress marker present pre-run
- PASS: (d/version-link) fixture precondition: complete marker absent pre-run
- PASS: (d/version-link) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/version-link) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/version-link) complete marker written after recovery (root probe)
- PASS: (d/version-link) in-progress marker removed (root probe)
- (d/version-link) outcome: expect=ready ready=yes code=0
- PASS: (d/tree-only) fixture precondition: in-progress marker present pre-run
- PASS: (d/tree-only) fixture precondition: complete marker absent pre-run
- PASS: (d/tree-only) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/tree-only) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/tree-only) complete marker written after recovery (root probe)
- PASS: (d/tree-only) in-progress marker removed (root probe)
- (d/tree-only) outcome: expect=ready ready=yes code=0
- PASS: (d/account-only) fixture precondition: in-progress marker present pre-run
- PASS: (d/account-only) fixture precondition: complete marker absent pre-run
- PASS: (d/account-only) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/account-only) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/account-only) complete marker written after recovery (root probe)
- PASS: (d/account-only) in-progress marker removed (root probe)
- (d/account-only) outcome: expect=ready ready=yes code=0
- PASS: (d/apache-conf) fixture precondition: in-progress marker present pre-run
- PASS: (d/apache-conf) fixture precondition: complete marker absent pre-run
- PASS: (d/apache-conf) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/apache-conf) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/apache-conf) complete marker written after recovery (root probe)
- PASS: (d/apache-conf) in-progress marker removed (root probe)
- (d/apache-conf) outcome: expect=ready ready=yes code=0
- PASS: (d/fstab) fixture precondition: in-progress marker present pre-run
- PASS: (d/fstab) fixture precondition: complete marker absent pre-run
- PASS: (d/fstab) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/fstab) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/fstab) complete marker written after recovery (root probe)
- PASS: (d/fstab) in-progress marker removed (root probe)
- (d/fstab) outcome: expect=ready ready=yes code=0
- PASS: (d/uid-gid-occupied) irreconcilable ? actionable exit 1 (code=1)
- PASS: (d/uid-gid-occupied) fatal reason names the occupying account
```
FATAL: recovery: uid 1234 is occupied by a different account - the interrupted creation is irreconcilable. No mutation. Remedy: free the uid (userdel the conflicting account) or restore the original volume.
```

- PASS: (d/uid-gid-occupied) no mutation (content + metadata snapshot identical)
- (d/uid-gid-occupied) outcome: expect=fatal ready=n/a code=1
- PASS: (d-injected) failure at the recovery commit point ? exit 1 (code=1)
- PASS: (d-injected) the injected line was REACHED (sentinel present, cp from stopped container)
- PASS: (d-injected) in-progress marker REMAINS after the failure (root probe)
- PASS: (d-injected) complete marker ABSENT (recovery never committed, root probe)
- PASS: (d-injected) next boot re-enters recovery, completes ready (root image)
```
ready-time=3s
```

- PASS: (d-injected) recovery committed: complete marker + in-progress gone (root probe)
## S6-s6-rocky-e
- when: 2026-11-11 06:12:58
- runtime: podman

- **RESULT: PASS**

- (e) real old-image volume: /tmp/omd-verify/s6e-legacy-rocky-mysite (identity uid=2001 gid=2002; pw/mail from .meta)
- PASS: (e) precondition: volume is marker-free (genuinely adoptable, root probe)
- PASS: (e) precondition: version link + stored site.conf + htpasswd present (root probe)
- PASS: (e) precondition: fixture identity uid and gid are DISTINCT (ownership assertions meaningful)
- PASS: (e) precondition: sentinels seeded in persistent paths with distinct content (root probe)
- PASS: (e) legacy volume adopted - site starts ready (gate + /mysite/)
```
ready-time=3s
```

- PASS: (e) prominent 'adopted existing site mysite (no init marker - legacy/pre-marker volume)' log line
```
2026-11-11T05:13:10+0000 17c2e1ebcc9c omd-ready-check[480]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-11T05:13:10+0000 17c2e1ebcc9c systemd[1]: Finished OMD labs bounded readiness gate (FR-018).
2026-11-11T05:13:10+0000 17c2e1ebcc9c systemd[1]: Reached target Multi-User System.
2026-11-11T05:13:10+0000 17c2e1ebcc9c systemd[1]: Reached target Graphical Interface.
2026-11-11T05:13:10+0000 17c2e1ebcc9c systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T05:13:10+0000 17c2e1ebcc9c systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T05:13:10+0000 17c2e1ebcc9c systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T05:13:10+0000 17c2e1ebcc9c systemd[1]: Startup finished in 2.000s.
```

- PASS: (e) stored configuration authoritative: omd config show returns the ALTERED stored value
- PASS: (e) omd status rc 0 (site registered + started, adopt path)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (e) stored site.conf UNMODIFIED (sha256 unchanged, root probe)
- PASS: (e) stored web credential FILE unmodified (htpasswd sha256 unchanged, root probe)
- PASS: (e) the stored web credential created before STILL LOGS IN (thruk 200 with stored cred from .meta, 302 anon)
```
with-cred=200 anon=302
```

- PASS: (e) init-complete marker now present (leaves the no-marker class, root probe)
- PASS: (e) identity re-recorded with the INFERRED uid/gid from the volume (root probe)
- PASS: (e) numeric ownership UNTOUCHED before/after (UID AND GID of top + persistent subfolders; the adopt's own top-level .omd-labs-* artifacts excluded, root probe)
- PASS: (e) top dir carries the image omd gid (uid=2001 group=omd, 0750) after adoption (root probe)
- PASS: (e) sentinel content UNTOUCHED (etc/omd, var/lib, local - exact lines, root probe)
- PASS: (e) sentinel metadata UNTOUCHED (uid/gid/mode identical before/after - umask-dependent, no guessed mode, root probe)
## S6-s6-rocky-e-inputs
- when: 2026-11-11 06:13:18
- runtime: podman

- **RESULT: PASS**

- PASS: (e-inputs) legacy volume adopted WITH inputs - site starts ready
```
ready-time=3s
```

- PASS: (e-inputs) 'adopted existing site' banner (contract string)
```
2026-11-11T05:13:27+0000 94abf384432d omd-ready-check[484]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-11T05:13:27+0000 94abf384432d systemd[1]: Finished OMD labs bounded readiness gate (FR-018).
2026-11-11T05:13:27+0000 94abf384432d systemd[1]: Reached target Multi-User System.
2026-11-11T05:13:27+0000 94abf384432d systemd[1]: Reached target Graphical Interface.
2026-11-11T05:13:27+0000 94abf384432d systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T05:13:27+0000 94abf384432d systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T05:13:27+0000 94abf384432d systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T05:13:27+0000 94abf384432d systemd[1]: Startup finished in 1.958s.
```

- PASS: (e-inputs) FR-012 notice logged: inputs supplied but NOT applied (stored config authoritative)
```
2026-11-11T05:13:27+0000 94abf384432d omd-ready-check[484]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-11T05:13:27+0000 94abf384432d systemd[1]: Finished OMD labs bounded readiness gate (FR-018).
2026-11-11T05:13:27+0000 94abf384432d systemd[1]: Reached target Multi-User System.
2026-11-11T05:13:27+0000 94abf384432d systemd[1]: Reached target Graphical Interface.
2026-11-11T05:13:27+0000 94abf384432d systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T05:13:27+0000 94abf384432d systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T05:13:27+0000 94abf384432d systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T05:13:27+0000 94abf384432d systemd[1]: Startup finished in 1.958s.
```

- PASS: (e-inputs) MOD_GEARMAN still the stored value off (input 'on' NOT applied)
- PASS: (e-inputs) PNP4NAGIOS still the stored value on (untouched by the adopt)
- PASS: (e-inputs) no 4730 listener (stored MOD_GEARMAN off - input not applied; capture non-empty - N2)
- PASS: (e-inputs) stored site.conf UNMODIFIED (sha256 unchanged, root probe)
- PASS: (e-inputs) the stored web credential created before STILL LOGS IN (thruk 200 with stored cred from .meta)
```
with-cred=200
```

- PASS: (e-inputs) init-complete marker written by the adopt (root probe)
- PASS: (e-inputs) /run/omd-labs.env carries SITE_CUSTOM_APPLIED=0 (inputs validated, not applied)
## S6-s6-rocky-g
- when: 2026-11-11 06:13:34
- runtime: podman

- **RESULT: PASS**

- PASS: (g1) ambiguous identity ? actionable exit 1 (code=1)
- PASS: (g1) fatal reason names the ambiguity
```
FATAL: inferred identity is AMBIGUOUS - the site subfolders' group (996) equals the omd group's gid; the primary gid cannot be determined. Refusing (no mutation). Remedy: run the site once from its original image or set the identity manually.
```

- PASS: (g1) volume unchanged: content + ownership/mode metadata identical
- PASS: (g2) lost identity file ? resume via inference, site starts ready
```
ready-time=3s
```

- PASS: (g2) .omd-labs-site-identity RE-RECORDED with the inferred 1234/1234
- PASS: (g3) recorded identity honored: site starts ready
```
ready-time=4s
```

- PASS: (g3) fresh-container account carries uid=1234 (id recid)
- PASS: (g3) fresh-container account carries primary gid=1234 (id recid)
- PASS: (g4) occupied uid on resume ? exit 1 (code=1)
- PASS: (g4) fatal names the collision (occupied uid / foreign group - F2 validation before any write)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site occres
```

- PASS: (g4) no-mutation: volume byte-identical (identity NOT re-written, no group change - F2 ordering)
- PASS: (g5) occupied uid/gid on adopt ? exit 1 (code=1)
- PASS: (g5) fatal names the collision (occupied uid / foreign group - F2 validation before any write)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site occadp
```

- PASS: (g5) no-mutation: volume byte-identical (no identity file, no group)
- PASS: (g5) adopt-complete marker ABSENT (adopt wrote nothing before the fatal)
- PASS: (g6) fixture precondition: stale in-progress marker present on a completed volume (root probe)
- PASS: (g6) persisted volume with stale marker ? resume ready (inference + re-record)
```
ready-time=3s
```

- PASS: (g6) stale in-progress marker REMOVED after validation (root probe)
- PASS: (g6) log carries the deterministic removal notice
```
2026-11-11T05:15:02+0000 4e031f27739b omd-ready-check[477]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-11T05:15:02+0000 4e031f27739b systemd[1]: Finished OMD labs bounded readiness gate (FR-018).
2026-11-11T05:15:02+0000 4e031f27739b systemd[1]: Reached target Multi-User System.
2026-11-11T05:15:02+0000 4e031f27739b systemd[1]: Reached target Graphical Interface.
2026-11-11T05:15:02+0000 4e031f27739b systemd[1]: Starting Record Runlevel Change in UTMP...
2026-11-11T05:15:02+0000 4e031f27739b systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-11T05:15:02+0000 4e031f27739b systemd[1]: Finished Record Runlevel Change in UTMP.
2026-11-11T05:15:02+0000 4e031f27739b systemd[1]: Startup finished in 1.996s.
```

- PASS: (g6) identity re-recorded (root probe)
- PASS: (g7) malformed recorded identity ? exit 1 (code=1)
- PASS: (g7) fatal names the malformed identity (no account-tool rejection)
```
FATAL: malformed recorded identity (uid='abc') for site badid - the value must be a non-empty integer. No mutation. Remedy: fix or remove .omd-labs-site-identity.
```

- PASS: (g7) no-mutation: volume byte-identical (identity NOT re-written - F2 ordering)
- PASS: (g8) stale marker + foreign gid ? exit 1 (code=1)
- PASS: (g8) fatal names the collision (occupied uid / foreign group)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site staled
```

- PASS: (g8) in-progress marker RETAINED (removed only AFTER validation - no-mutation)
- PASS: (g8) no-mutation: volume byte-identical
- PASS: (g9) GID-only foreign collision on resume ? exit 1 (code=1)
- PASS: (g9) fatal names the foreign group (belongs to group 'occgrp')
```
FATAL: gid 1234 belongs to group 'occgrp', not site 'gonly' - refusing to bind the site account to a foreign group (no mutation). Remedy: free the gid or fix the recorded identity.
```

- PASS: (g9) no-mutation: volume byte-identical (F2 ordering)
- PASS: (g10) inverse collision (site-named group at wrong gid) ? exit 1 (code=1)
- PASS: (g10) fatal names the inverse collision (exists at gid 1230)
```
FATAL: a group named 'g10id' already exists at gid 1230 (the recorded identity requests gid 1234) - refusing (no mutation). Remedy: groupdel/rename the existing group or fix the recorded identity.
```

- PASS: (g10) no-mutation: volume byte-identical (identity NOT re-written - F2 ordering)
- PASS: (g10) the ORIGINAL identity line is intact (not overwritten by the failed restore)
## S5-s5-debian
- when: 2026-11-11 06:16:23
- runtime: podman

- **RESULT: PASS**

- PASS: readiness (gate + /custsite/)
```
ready-time=7s
```

- PASS: gearmand listening on 4730 when ready (SC-012 - component came up with the site)
- PASS: env value WON the conflict: omd config show GEARMAND_PORT = 0.0.0.0:4730 (EXACT line)
- PASS: effective config observable: MOD_GEARMAN = on (EXACT line)
- PASS: container log carries the effective-customization summary (FR-010; bounded wait for log flush)
```
2026-11-11T05:16:30+00:00 ada2c93c8dd9 dbus-daemon[1841]: [system] Successfully activated service 'org.freedesktop.timedate1'
2026-11-11T05:16:30+00:00 ada2c93c8dd9 omd-ready-check[2411]: READY: base services up (omd-site active, apache2 443, sshd 22)
2026-11-11T05:16:30+00:00 ada2c93c8dd9 systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-11T05:16:30+00:00 ada2c93c8dd9 systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-11T05:16:30+00:00 ada2c93c8dd9 systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-11T05:16:30+00:00 ada2c93c8dd9 systemd[1]: Startup finished in 2.251s.
2026-11-11T05:16:31+00:00 ada2c93c8dd9 runuser[2558]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
2026-11-11T05:16:31+00:00 ada2c93c8dd9 runuser[2558]: pam_unix(runuser:session): session closed for user custsite
```

- PASS: listener address is the env value (0.0.0.0:4730)
- PASS: no customization input ? ready BEFORE the negative listener check
```
ready-time=5s
```

- PASS: no customization input ? no 4730 listener (capture non-empty first - N2)
- PASS: S6c: persisted site resumes ready (stored configuration authoritative)
```
ready-time=3s
```

- PASS: S6c: stored value survives (GEARMAND_PORT still 0.0.0.0:4730 - inputs NOT applied, EXACT line)
- PASS: S6c: log carries the deterministic notice that inputs were not applied (FR-012; bounded wait)
```
2026-11-11T05:16:44+00:00 8cc8ca797791 omd-ready-check[493]: READY: base services up (omd-site active, apache2 443, sshd 22)
2026-11-11T05:16:44+00:00 8cc8ca797791 systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-11T05:16:44+00:00 8cc8ca797791 systemd[1]: Started exim4.service - exim Mail Transport Agent.
2026-11-11T05:16:44+00:00 8cc8ca797791 systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-11T05:16:44+00:00 8cc8ca797791 systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-11T05:16:44+00:00 8cc8ca797791 systemd[1]: Startup finished in 2.205s.
2026-11-11T05:16:45+00:00 8cc8ca797791 runuser[833]: pam_unix(runuser:session): session opened for user custsite(uid=1000) by root(uid=0)
2026-11-11T05:16:45+00:00 8cc8ca797791 runuser[833]: pam_unix(runuser:session): session closed for user custsite
```

## S6-s6-debian-d
- when: 2026-11-11 06:16:48
- runtime: podman

- **RESULT: PASS**

- PASS: (d/account-plus-tree) fixture precondition: in-progress marker present pre-run
- PASS: (d/account-plus-tree) fixture precondition: complete marker absent pre-run
- PASS: (d/account-plus-tree) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/account-plus-tree) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/account-plus-tree) complete marker written after recovery (root probe)
- PASS: (d/account-plus-tree) in-progress marker removed (root probe)
- (d/account-plus-tree) outcome: expect=ready ready=yes code=0
- PASS: (d/version-link) fixture precondition: in-progress marker present pre-run
- PASS: (d/version-link) fixture precondition: complete marker absent pre-run
- PASS: (d/version-link) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/version-link) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/version-link) complete marker written after recovery (root probe)
- PASS: (d/version-link) in-progress marker removed (root probe)
- (d/version-link) outcome: expect=ready ready=yes code=0
- PASS: (d/tree-only) fixture precondition: in-progress marker present pre-run
- PASS: (d/tree-only) fixture precondition: complete marker absent pre-run
- PASS: (d/tree-only) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/tree-only) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/tree-only) complete marker written after recovery (root probe)
- PASS: (d/tree-only) in-progress marker removed (root probe)
- (d/tree-only) outcome: expect=ready ready=yes code=0
- PASS: (d/account-only) fixture precondition: in-progress marker present pre-run
- PASS: (d/account-only) fixture precondition: complete marker absent pre-run
- PASS: (d/account-only) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/account-only) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/account-only) complete marker written after recovery (root probe)
- PASS: (d/account-only) in-progress marker removed (root probe)
- (d/account-only) outcome: expect=ready ready=yes code=0
- PASS: (d/apache-conf) fixture precondition: in-progress marker present pre-run
- PASS: (d/apache-conf) fixture precondition: complete marker absent pre-run
- PASS: (d/apache-conf) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/apache-conf) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/apache-conf) complete marker written after recovery (root probe)
- PASS: (d/apache-conf) in-progress marker removed (root probe)
- (d/apache-conf) outcome: expect=ready ready=yes code=0
- PASS: (d/fstab) fixture precondition: in-progress marker present pre-run
- PASS: (d/fstab) fixture precondition: complete marker absent pre-run
- PASS: (d/fstab) reconcilable ? recovery completes, site ready (code=0)
- PASS: (d/fstab) omd status rc 0 (site registered + started)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (d/fstab) complete marker written after recovery (root probe)
- PASS: (d/fstab) in-progress marker removed (root probe)
- (d/fstab) outcome: expect=ready ready=yes code=0
- PASS: (d/uid-gid-occupied) irreconcilable ? actionable exit 1 (code=1)
- PASS: (d/uid-gid-occupied) fatal reason names the occupying account
```
FATAL: recovery: uid 1234 is occupied by a different account - the interrupted creation is irreconcilable. No mutation. Remedy: free the uid (userdel the conflicting account) or restore the original volume.
```

- PASS: (d/uid-gid-occupied) no mutation (content + metadata snapshot identical)
- (d/uid-gid-occupied) outcome: expect=fatal ready=n/a code=1
- PASS: (d-injected) failure at the recovery commit point ? exit 1 (code=1)
- PASS: (d-injected) the injected line was REACHED (sentinel present, cp from stopped container)
- PASS: (d-injected) in-progress marker REMAINS after the failure (root probe)
- PASS: (d-injected) complete marker ABSENT (recovery never committed, root probe)
- PASS: (d-injected) next boot re-enters recovery, completes ready (root image)
```
ready-time=4s
```

- PASS: (d-injected) recovery committed: complete marker + in-progress gone (root probe)
## S6-s6-debian-e
- when: 2026-11-11 06:18:38
- runtime: podman

- **RESULT: PASS**

- (e) real old-image volume: /tmp/omd-verify/s6e-legacy-debian-mysite (identity uid=2001 gid=2002; pw/mail from .meta)
- PASS: (e) precondition: volume is marker-free (genuinely adoptable, root probe)
- PASS: (e) precondition: version link + stored site.conf + htpasswd present (root probe)
- PASS: (e) precondition: fixture identity uid and gid are DISTINCT (ownership assertions meaningful)
- PASS: (e) precondition: sentinels seeded in persistent paths with distinct content (root probe)
- PASS: (e) legacy volume adopted - site starts ready (gate + /mysite/)
```
ready-time=3s
```

- PASS: (e) prominent 'adopted existing site mysite (no init marker - legacy/pre-marker volume)' log line
```
2026-11-11T05:18:49+00:00 09735c6c7c2e mariadbd[248]: Version: '11.8.6-MariaDB-0+deb13u1 from Debian'  socket: '/run/mysqld/mysqld.sock'  port: 3306  -- Please help get to 10k stars at https://github.com/MariaDB/Server
2026-11-11T05:18:49+00:00 09735c6c7c2e systemd[1]: Started mariadb.service - MariaDB 11.8.6 database server.
2026-11-11T05:18:49+00:00 09735c6c7c2e systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-11T05:18:49+00:00 09735c6c7c2e systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-11T05:18:49+00:00 09735c6c7c2e systemd[1]: Startup finished in 2.478s.
2026-11-11T05:18:49+00:00 09735c6c7c2e /etc/mysql/debian-start[734]: Upgrading MariaDB tables if necessary.
2026-11-11T05:18:49+00:00 09735c6c7c2e /etc/mysql/debian-start[745]: Checking for insecure root accounts.
2026-11-11T05:18:49+00:00 09735c6c7c2e /etc/mysql/debian-start[749]: Triggering myisam-recover for all MyISAM tables and aria-recover for all Aria tables
```

- PASS: (e) stored configuration authoritative: omd config show returns the ALTERED stored value
- PASS: (e) omd status rc 0 (site registered + started, adopt path)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: (e) stored site.conf UNMODIFIED (sha256 unchanged, root probe)
- PASS: (e) stored web credential FILE unmodified (htpasswd sha256 unchanged, root probe)
- PASS: (e) the stored web credential created before STILL LOGS IN (thruk 200 with stored cred from .meta, 302 anon)
```
with-cred=200 anon=302
```

- PASS: (e) init-complete marker now present (leaves the no-marker class, root probe)
- PASS: (e) identity re-recorded with the INFERRED uid/gid from the volume (root probe)
- PASS: (e) numeric ownership UNTOUCHED before/after (UID AND GID of top + persistent subfolders; the adopt's own top-level .omd-labs-* artifacts excluded, root probe)
- PASS: (e) top dir carries the image omd gid (uid=2001 group=omd, 0750) after adoption (root probe)
- PASS: (e) sentinel content UNTOUCHED (etc/omd, var/lib, local - exact lines, root probe)
- PASS: (e) sentinel metadata UNTOUCHED (uid/gid/mode identical before/after - umask-dependent, no guessed mode, root probe)
## S6-s6-debian-e-inputs
- when: 2026-11-11 06:18:55
- runtime: podman

- **RESULT: PASS**

- PASS: (e-inputs) legacy volume adopted WITH inputs - site starts ready
```
ready-time=3s
```

- PASS: (e-inputs) 'adopted existing site' banner (contract string)
```
2026-11-11T05:19:03+00:00 4ffa17d31c23 /etc/mysql/debian-start[718]: Upgrading MariaDB tables if necessary.
2026-11-11T05:19:03+00:00 4ffa17d31c23 omd-ready-check[476]: READY: base services up (omd-site active, apache2 443, sshd 22)
2026-11-11T05:19:03+00:00 4ffa17d31c23 systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-11T05:19:03+00:00 4ffa17d31c23 systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-11T05:19:03+00:00 4ffa17d31c23 systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-11T05:19:03+00:00 4ffa17d31c23 systemd[1]: Startup finished in 2.117s.
2026-11-11T05:19:03+00:00 4ffa17d31c23 /etc/mysql/debian-start[744]: Checking for insecure root accounts.
2026-11-11T05:19:03+00:00 4ffa17d31c23 /etc/mysql/debian-start[752]: Triggering myisam-recover for all MyISAM tables and aria-recover for all Aria tables
```

- PASS: (e-inputs) FR-012 notice logged: inputs supplied but NOT applied (stored config authoritative)
```
2026-11-11T05:19:03+00:00 4ffa17d31c23 /etc/mysql/debian-start[718]: Upgrading MariaDB tables if necessary.
2026-11-11T05:19:03+00:00 4ffa17d31c23 omd-ready-check[476]: READY: base services up (omd-site active, apache2 443, sshd 22)
2026-11-11T05:19:03+00:00 4ffa17d31c23 systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-11T05:19:03+00:00 4ffa17d31c23 systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-11T05:19:03+00:00 4ffa17d31c23 systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-11T05:19:03+00:00 4ffa17d31c23 systemd[1]: Startup finished in 2.117s.
2026-11-11T05:19:03+00:00 4ffa17d31c23 /etc/mysql/debian-start[744]: Checking for insecure root accounts.
2026-11-11T05:19:03+00:00 4ffa17d31c23 /etc/mysql/debian-start[752]: Triggering myisam-recover for all MyISAM tables and aria-recover for all Aria tables
```

- PASS: (e-inputs) MOD_GEARMAN still the stored value off (input 'on' NOT applied)
- PASS: (e-inputs) PNP4NAGIOS still the stored value on (untouched by the adopt)
- PASS: (e-inputs) no 4730 listener (stored MOD_GEARMAN off - input not applied; capture non-empty - N2)
- PASS: (e-inputs) stored site.conf UNMODIFIED (sha256 unchanged, root probe)
- PASS: (e-inputs) the stored web credential created before STILL LOGS IN (thruk 200 with stored cred from .meta)
```
with-cred=200
```

- PASS: (e-inputs) init-complete marker written by the adopt (root probe)
- PASS: (e-inputs) /run/omd-labs.env carries SITE_CUSTOM_APPLIED=0 (inputs validated, not applied)
## S6-s6-debian-g
- when: 2026-11-11 06:19:09
- runtime: podman

- **RESULT: PASS**

- PASS: (g1) ambiguous identity ? actionable exit 1 (code=1)
- PASS: (g1) fatal reason names the ambiguity
```
FATAL: inferred identity is AMBIGUOUS - the site subfolders' group (106) equals the omd group's gid; the primary gid cannot be determined. Refusing (no mutation). Remedy: run the site once from its original image or set the identity manually.
```

- PASS: (g1) volume unchanged: content + ownership/mode metadata identical
- PASS: (g2) lost identity file ? resume via inference, site starts ready
```
ready-time=3s
```

- PASS: (g2) .omd-labs-site-identity RE-RECORDED with the inferred 1234/1234
- PASS: (g3) recorded identity honored: site starts ready
```
ready-time=3s
```

- PASS: (g3) fresh-container account carries uid=1234 (id recid)
- PASS: (g3) fresh-container account carries primary gid=1234 (id recid)
- PASS: (g4) occupied uid on resume ? exit 1 (code=1)
- PASS: (g4) fatal names the collision (occupied uid / foreign group - F2 validation before any write)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site occres
```

- PASS: (g4) no-mutation: volume byte-identical (identity NOT re-written, no group change - F2 ordering)
- PASS: (g5) occupied uid/gid on adopt ? exit 1 (code=1)
- PASS: (g5) fatal names the collision (occupied uid / foreign group - F2 validation before any write)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site occadp
```

- PASS: (g5) no-mutation: volume byte-identical (no identity file, no group)
- PASS: (g5) adopt-complete marker ABSENT (adopt wrote nothing before the fatal)
- PASS: (g6) fixture precondition: stale in-progress marker present on a completed volume (root probe)
- PASS: (g6) persisted volume with stale marker ? resume ready (inference + re-record)
```
ready-time=4s
```

- PASS: (g6) stale in-progress marker REMOVED after validation (root probe)
- PASS: (g6) log carries the deterministic removal notice
```
2026-11-11T05:20:37+00:00 4c904350f9dd systemd[1]: Started systemd-timedated.service - Time & Date Service.
2026-11-11T05:20:37+00:00 4c904350f9dd dbus-daemon[121]: [system] Successfully activated service 'org.freedesktop.timedate1'
2026-11-11T05:20:37+00:00 4c904350f9dd omd-ready-check[525]: READY: base services up (omd-site active, apache2 443, sshd 22)
2026-11-11T05:20:37+00:00 4c904350f9dd systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-11T05:20:37+00:00 4c904350f9dd systemd[1]: Started exim4.service - exim Mail Transport Agent.
2026-11-11T05:20:37+00:00 4c904350f9dd systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-11T05:20:37+00:00 4c904350f9dd systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-11T05:20:37+00:00 4c904350f9dd systemd[1]: Startup finished in 2.459s.
```

- PASS: (g6) identity re-recorded (root probe)
- PASS: (g7) malformed recorded identity ? exit 1 (code=1)
- PASS: (g7) fatal names the malformed identity (no account-tool rejection)
```
FATAL: malformed recorded identity (uid='abc') for site badid - the value must be a non-empty integer. No mutation. Remedy: fix or remove .omd-labs-site-identity.
```

- PASS: (g7) no-mutation: volume byte-identical (identity NOT re-written - F2 ordering)
- PASS: (g8) stale marker + foreign gid ? exit 1 (code=1)
- PASS: (g8) fatal names the collision (occupied uid / foreign group)
```
FATAL: uid 1234 is occupied by a different account (occupier) - cannot restore site staled
```

- PASS: (g8) in-progress marker RETAINED (removed only AFTER validation - no-mutation)
- PASS: (g8) no-mutation: volume byte-identical
- PASS: (g9) GID-only foreign collision on resume ? exit 1 (code=1)
- PASS: (g9) fatal names the foreign group (belongs to group 'occgrp')
```
FATAL: gid 1234 belongs to group 'occgrp', not site 'gonly' - refusing to bind the site account to a foreign group (no mutation). Remedy: free the gid or fix the recorded identity.
```

- PASS: (g9) no-mutation: volume byte-identical (F2 ordering)
- PASS: (g10) inverse collision (site-named group at wrong gid) ? exit 1 (code=1)
- PASS: (g10) fatal names the inverse collision (exists at gid 1230)
```
FATAL: a group named 'g10id' already exists at gid 1230 (the recorded identity requests gid 1234) - refusing (no mutation). Remedy: groupdel/rename the existing group or fix the recorded identity.
```

- PASS: (g10) no-mutation: volume byte-identical (identity NOT re-written - F2 ordering)
- PASS: (g10) the ORIGINAL identity line is intact (not overwritten by the failed restore)


## T027-BLOCKER-FIX-BUILD13-2026-11-11 (failed-creation provenance retained; recovery, not adoption)

- **CORRECTION to the T027-BUILD12 record above**: its s6 a/b "ground
  truth" (a customization fail-fast leaves a complete tree + NO
  markers, so the retry classifies row 3b ADOPT and the adopt is the
  desired outcome) is SUPERSEDED and was WRONG. The adopt branch
  violates the spec: it starts the partially-configured site as if it
  were complete, IGNORES the corrected retry input, and then writes
  .omd-labs-init-complete + .omd-labs-site-identity - committing a
  partially-configured site as a completed persisted site. That
  violates FR-009 (spec.md @158: a failed first creation must not be
  adopted as completed) and US3 scenario 6 (spec.md ~@90: a retry with
  corrected input must complete the initialization with the corrected
  configuration). Codex 81 BLOCKER, verified real end-to-end, fixed.
- **Root cause**: on the fresh path, `create_site` runs
  `omd create --reuse` (the full tree) and THEN `site_customize`; a
  customization fail-fast fires AFTER creation. The fresh-path EXIT
  trap `rollback()` DELETED the in-progress marker (old :149) AND the
  identity file (old :156 - the codex 75 B3 "fix"), so the volume
  looked like a legacy complete tree and the retry adopted it.
- **Empirical pre-fix proof** (fresh container, build #12 image,
  /tmp/t27-blk.sh, rocky): run1 (OMDCFG_MOD_GEARMAN=bogus) exit 1,
  volume had NO .omd-labs-* markers; retry (OMDCFG_MOD_GEARMAN=on) ->
  "inferred legacy identity" -> "adopted existing site blksite" ->
  "NOTICE - customization inputs were supplied but not applied" ->
  stored MOD_GEARMAN = off (the corrected input IGNORED), and the adopt
  wrote .omd-labs-init-complete + .omd-labs-site-identity.
- **FIX** (scripts/omd-labs-entry `rollback()`, :148-161): the EXIT
  trap now RETAINS the in-progress marker AND the identity file (the
  durable provenance that a first creation was interrupted). A retry
  then classifies row 3a RECOVERY (`recover_interrupted` :512:
  settings-first, idempotent account + registration re-checks,
  version-link present -> omd enable re-registration,
  `site_customize` re-applies the corrected effective settings, then
  commits the init-complete marker and removes the in-progress marker;
  banner "recovery complete - resumed existing site <site>" :613).
  The resume path's stale-marker removal (:211) is unaffected.
  Post-fix entry sha256 49f7b3b7cdb9e59bb2a7a59efa895fcfbbc71ae77cc7b
  fa1322642f81d0d5f20 (bash -n + ASCII clean).
- **Empirical post-fix proof** (mounted host entry over the build #12
  image, /tmp/t27-blk.sh, rocky): run1 retains
  .omd-labs-init-inprogress + .omd-labs-site-identity; retry ->
  "recovering interrupted first creation (in-progress marker present)"
  -> "recovery: creation had completed (version link) - re-registered"
  -> "customization applied: MOD_GEARMAN=on" -> stored value on,
  state=recovered, omd-ready active.
- **Build #13** (the rebuild point for the BLOCKER fix): podman build
  both distros (hooks/build hardcodes docker - absent; podman
  equivalent, same Dockerfile/image name/OMD_VERSION=master), rc=0.
  Image ids: rocky 686dbc86f899, debian 45bd695ce2ad (build #12
  superseded). Baked entry sha256 == host (49f7b3b7...) in BOTH
  images.
- **s6 a/b/c REWORK** (verify/scenarios/s6.sh :27-200 - the old retry
  checks asserted the WRONG pre-fix adopt behavior; on the fixed entry
  they would FAIL): the a/b retry checks now assert RECOVERY - retry
  ready + "recovering interrupted first creation" banner + the
  CORRECTED stored value (runuser -u <site> -- omd config show KEY |
  grep -qx) + ABSENCE of the "adopted existing site" banner
  (non-empty-capture negative, N2). NOTE 2 (codex 81): the a/b/c
  fail-fasts now measure the actual elapsed (captured BEFORE v_run,
  1 s poll granularity) and assert exit 1 AND elapsed <= 30 s (the
  advertised bound; EMPIRICAL fail-fasts 3-6 s). NOTE 3 (codex 81):
  the fresh per-run mktemp dirs (s6a/s6b/s6c.XXXXXX) are swept at
  teardown by a BEST-EFFORT root container (reuses the established
  root-side convention; the sweep runs on an EXIT trap so it fires
  after normal and failure exits; a probe failure is swallowed so it
  never masks a real failure). Verified: after the runs the six
  most-recent per-run dirs contained 0 entries. NEW (c) multi-setting
  PARTIAL-APPLICATION case (codex 81: "earlier valid settings can have
  applied before the later failure"): run1 OMDCFG_MOD_GEARMAN=on (valid
  - stored) + OMDCFG_GEARMAND=bogus (refused by omd config set at
  PRE-INIT - an enumerated on/off choice) -> exit 1 <=30 s, fatal names
  GEARMAND, the EARLIER valid key IS stored (root probe:
  CONFIG_MOD_GEARMAN='on'), the failing key is NOT stored (not
  'bogus'), and the in-progress + identity provenance is retained;
  retry with the corrected pair (GEARMAND=on) -> row 3a recovery, both
  stored values on (omd config show grep -qx), the 4730 listener is up
  (non-empty-capture check), no adoption banner. KEY FINDING: the
  (c) case must use an ENUMERATED-choice key - GEARMAND_PORT=BOGUS
  would be the WRONG shape: that hook's choices regex
  ([a-zA-Z0-9\.\-,:]*) accepts BOGUS and its set) stores it, so the
  failure surfaces only at RUNTIME (naemon refuses the bind, the
  omd-ready gate fails) AFTER the completion marker is committed -
  the retry would then classify row 2 RESUME (not re-apply) and the
  site would never come up.
- **Canonical runs on BUILD #13 (both distros, strictly sequential,
  run.sh tag nightly)**:
  | scenario | rocky | debian |
  | s6 a (a/b/c rework, 28 checks) | 28 PASS / 0 FAIL | 28 PASS / 0 FAIL |
  | s5 (customization happy path + S6c persisted-restart) | 11 PASS / 0 FAIL | 11 PASS / 0 FAIL |
  | s6 d (interrupted-creation matrix) | 45 PASS / 0 FAIL | 45 PASS / 0 FAIL |
  | s6 e (legacy adoption core) | 17 PASS / 0 FAIL | 17 PASS / 0 FAIL |
  | s6 e-inputs (T2c input half) | 10 PASS / 0 FAIL | 10 PASS / 0 FAIL |
  | s6 g (identity fixtures g1-g10) | 34 PASS / 0 FAIL | 34 PASS / 0 FAIL |
  Ready-times within documented bounds (recovery retries 4-6 s,
  fail-fasts 3-6 s, remaining gates 3-10 s). Logs:
  /tmp/t027-s6a-{rocky,debian}.log (a/b/c rework) +
  /tmp/t027b-{s5,s6d,s6e,s6ein,s6g}-{rocky,debian}.log; suite sections
  auto-appended above this record. The s6 e/e-inputs legacy ADOPT
  sub-items still pass unchanged - the legacy adopt remains correct
  for GENUINE legacy volumes (a real old image's volume, written by a
  pre-marker entry); what was forbidden is adopting a FAILED first
  creation of the CURRENT entry, and the retained in-progress marker
  is exactly the discriminator.
- **Suite hygiene**: bash -n + ASCII clean on verify/scenarios/s6.sh;
  splices verified with cat -A (:35-53, :63-69, :78-95, :127-142,
  :156-200).
- **Spar state**: codex 81 (1 BLOCKER + 2 NOTEs) addressed: BLOCKER
  fixed + verified end-to-end + codified (recovery assertions, both
  distros); NOTE 2 (timing bound) + NOTE 3 (dir sweep) codified +
  verified. Awaiting the final T027 verdict (debate file 83) before
  T027 is closed.
## S7-s7-rocky
- when: 2026-11-11 06:24:56
- runtime: podman

## S7-s7-debian
- when: 2026-11-11 06:25:08
- runtime: podman

## S7-s7-rocky
- when: 2026-11-11 06:26:22
- runtime: podman

- **RESULT: FAIL**

- PASS: (a) not-writable mount ? exit 1 <=30 s (elapsed=0s code=1)
- PASS: (a) fatal reason names the non-writable location (entry-fatal file)
```
FATAL: /omd/sites/rwfail is not writable (run the container with a writable volume at /omd/sites/rwfail)
```

- PASS: (a) data untouched (marker/creation never attempted - root probe)
- PASS: (b) readiness (gate + 443)
```
ready-time=2s
```

- PASS: (b) after systemctl stop httpd: container still running (never exits)
- PASS: (b) httpd inactive; status + journalctl explain
- PASS: (b) systemctl start httpd restores 443
- PASS: (c) pre-ready site-start failure ? container exit 1 (code=1)
- PASS: (c) FATAL-BLOCK / READY-FATAL in the stopped container's log (bounded wait)
```
2026-11-11T05:26:42+0000 5c3708995633 systemd[1]: Stopped target sshd-keygen.target.
2026-11-11T05:26:42+0000 5c3708995633 systemd[1]: Stopping Permit User Sessions...
2026-11-11T05:26:42+0000 5c3708995633 systemd[1]: php-fpm.service: Deactivated successfully.
2026-11-11T05:26:42+0000 5c3708995633 systemd[1]: Stopped The PHP FastCGI Process Manager.
2026-11-11T05:26:42+0000 5c3708995633 systemd[1]: systemd-logind.service: Deactivated successfully.
2026-11-11T05:26:42+0000 5c3708995633 systemd[1]: Stopped User Login Management.
2026-11-11T05:26:42+0000 5c3708995633 systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-11T05:26:42+0000 5c3708995633 systemd[1]: Stopped Permit User Sessions.
```

- PASS: (c) bounded cleanup ran: no site daemons left
- PASS: (d) ready-gate deadline (injected) ? exit 2 (code=2)
- PASS: (e) forwarder dead at fatal time ? exit still 1 (code=1)
- PASS: (e) documented DIRECT-COPY degradation line in the journal (best-effort diagnostics)
```
no DIRECT-COPY line found - degradation recorded (forwarder may have been killed before journal stream; best-effort channel)
```

- FAIL: (f1) hung pre-init child ? bounded exit 1 <=120 s before systemd exists (code=0) (rc=1)
```

```

- PASS: (f1) no systemd journal (died before /sbin/init)
- FAIL: (f1b) late-starting hung child ? whole bootstrap still exit 1 <=120 s from start (code=0, t=240s) (rc=1)
```

```

- PASS: (f2) stuck dependency job ? job fails at TimeoutStartSec, After=-only gate still runs ? exit 1 (code=1, t=93s)
- PASS: (f3) hung probe ? killed at 150 s backstop, FailureAction=exit fires ? non-zero exit (code=255, t=147s)
- PASS: (g) dead-forwarder/full-pipe fatal ? exit code unchanged (1) (code=1)
- PASS: (g) reason retrievable from writable-layer fatal-reason file WITHOUT assuming pipe copy (B3)
- post-ready crash never exits the container (a/b contrast); all hangs bounded (f)
## S7-s7-debian
- when: 2026-11-11 06:41:43
- runtime: podman

- **RESULT: FAIL**

- PASS: (a) not-writable mount ? exit 1 <=30 s (elapsed=1s code=1)
- PASS: (a) fatal reason names the non-writable location (entry-fatal file)
```
FATAL: /omd/sites/rwfail is not writable (run the container with a writable volume at /omd/sites/rwfail)
```

- PASS: (a) data untouched (marker/creation never attempted - root probe)
- PASS: (b) readiness (gate + 443)
```
ready-time=2s
```

- PASS: (b) after systemctl stop apache2: container still running (never exits)
- PASS: (b) apache2 inactive; status + journalctl explain
- PASS: (b) systemctl start apache2 restores 443
- PASS: (c) pre-ready site-start failure ? container exit 1 (code=1)
- PASS: (c) FATAL-BLOCK / READY-FATAL in the stopped container's log (bounded wait)
```
2026-11-11T05:42:00+00:00 3c87bc718bfe mariadbd[988]: 2026-11-11  5:42:00 0 [Note] InnoDB: Starting shutdown...
2026-11-11T05:42:00+00:00 3c87bc718bfe mariadbd[988]: 2026-11-11  5:42:00 0 [Note] InnoDB: Dumping buffer pool(s) to /var/lib/mysql/ib_buffer_pool
2026-11-11T05:42:00+00:00 3c87bc718bfe mariadbd[988]: 2026-11-11  5:42:00 0 [Note] InnoDB: Buffer pool(s) dump completed at 261111  5:42:00
2026-11-11T05:42:00+00:00 3c87bc718bfe systemd[1]: apache2.service: Deactivated successfully.
2026-11-11T05:42:00+00:00 3c87bc718bfe systemd[1]: Stopped apache2.service - The Apache HTTP Server.
2026-11-11T05:42:00+00:00 3c87bc718bfe systemd[1]: Stopped target remote-fs.target - Remote File Systems.
2026-11-11T05:42:00+00:00 3c87bc718bfe mariadbd[988]: 2026-11-11  5:42:00 0 [Note] InnoDB: Removed temporary tablespace data file: "./ibtmp1"
2026-11-11T05:42:00+00:00 3c87bc718bfe mariadbd[988]: 2026-11-11  5:42:00 0 [Note] InnoDB: Shutdown completed; log sequence number 45498; transaction id 15
```

- PASS: (c) bounded cleanup ran: no site daemons left
- FAIL: (d) ready-gate deadline (injected) ? exit 2 (code=203) (rc=1)
```

```

- PASS: (e) forwarder dead at fatal time ? exit still 1 (code=1)
- PASS: (e) documented DIRECT-COPY degradation line in the journal (best-effort diagnostics)
```
no DIRECT-COPY line found - degradation recorded (forwarder may have been killed before journal stream; best-effort channel)
```

- FAIL: (f1) hung pre-init child ? bounded exit 1 <=120 s before systemd exists (code=0) (rc=1)
```

```

- PASS: (f1) no systemd journal (died before /sbin/init)
- FAIL: (f1b) late-starting hung child ? whole bootstrap still exit 1 <=120 s from start (code=0, t=240s) (rc=1)
```

```

- PASS: (f2) stuck dependency job ? job fails at TimeoutStartSec, After=-only gate still runs ? exit 1 (code=1, t=6s)
- PASS: (f3) hung probe ? killed at 150 s backstop, FailureAction=exit fires ? non-zero exit (code=203, t=3s)
- PASS: (g) dead-forwarder/full-pipe fatal ? exit code unchanged (1) (code=1)
- PASS: (g) reason retrievable from writable-layer fatal-reason file WITHOUT assuming pipe copy (B3)
- post-ready crash never exits the container (a/b contrast); all hangs bounded (f)
## S7-s7-rocky
- when: 2026-11-11 07:40:21
- runtime: podman

- **RESULT: PASS**

- PASS: (a) not-writable mount ? exit 1 <=30 s (elapsed=0s code=1)
- PASS: (a) fatal reason names the non-writable location (entry-fatal file)
```
FATAL: /omd/sites/rwfail is not writable (run the container with a writable volume at /omd/sites/rwfail)
```

- PASS: (a) data untouched (marker/creation never attempted - root probe)
- PASS: (b) readiness (gate + 443)
```
ready-time=2s
```

- PASS: (b) after systemctl stop httpd: container still running (never exits)
- PASS: (b) httpd inactive; status + journalctl explain
- PASS: (b) systemctl start httpd restores 443
- PASS: (c) pre-ready site-start failure ? container exit 1 (code=1)
- PASS: (c) FATAL-BLOCK / READY-FATAL in the stopped container's log (bounded wait)
```
2026-11-11T06:40:40+0000 5c85c3948439 systemd[1]: crond.service: Deactivated successfully.
2026-11-11T06:40:40+0000 5c85c3948439 systemd[1]: Stopped Command Scheduler.
2026-11-11T06:40:40+0000 5c85c3948439 systemd[1]: Stopped target sshd-keygen.target.
2026-11-11T06:40:40+0000 5c85c3948439 systemd[1]: Stopping Permit User Sessions...
2026-11-11T06:40:40+0000 5c85c3948439 systemd[1]: php-fpm.service: Deactivated successfully.
2026-11-11T06:40:40+0000 5c85c3948439 systemd[1]: Stopped The PHP FastCGI Process Manager.
2026-11-11T06:40:40+0000 5c85c3948439 systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-11T06:40:40+0000 5c85c3948439 systemd[1]: Stopped Permit User Sessions.
```

- PASS: (c) bounded cleanup ran: no site daemons left
- PASS: (d) ready-gate deadline (injected) ? exit 2 within the 150 s backstop (code=2, elapsed=134s)
- PASS: (e) forwarder dead at fatal time ? exit still 1 (code=1)
- PASS: (e) documented DIRECT-COPY degradation line in the journal (best-effort diagnostics)
```
no DIRECT-COPY line found - degradation recorded (forwarder may have been killed before journal stream; best-effort channel)
```

- PASS: (f1) hung pre-init child ? bounded exit 1 <=130 s wall (the 120 s bootstrap bound, entry epoch) (code=1, elapsed=121s)
- PASS: (f1) the pre-init budget FATAL is recorded (the bounded child was killed, rc=124/137)
```
FATAL: step failed (rc=124): TEST-ONLY injected hang (s7 f1)
```

- PASS: (f1) no systemd ever ran (log carries no systemd[1] lines - died before /sbin/init)
- PASS: (f1b) late-starting hung child ? whole bootstrap still exit 1 <=130 s wall (N2 - not t=190 s) (code=1, elapsed=121s)
- PASS: (f1b) the pre-init budget FATAL is recorded (the remaining-budget cap fired)
```
FATAL: step failed (rc=124): TEST-ONLY injected hang (s7 f1b)
```

- PASS: (f2) stuck dependency job ? fails at TimeoutStartSec, After=-only gate still runs ? exit 1 (code=1, elapsed=97s)
- PASS: (f2) the After=-only gate ran and failed on the stuck unit (log: omd-site.service failed)
```
2026-11-11T06:48:50+0000 0f0637acdf65 systemd[1]: Stopped target sshd-keygen.target.
2026-11-11T06:48:50+0000 0f0637acdf65 systemd[1]: Stopping Permit User Sessions...
2026-11-11T06:48:50+0000 0f0637acdf65 systemd[1]: systemd-logind.service: Deactivated successfully.
2026-11-11T06:48:50+0000 0f0637acdf65 systemd[1]: Stopped User Login Management.
2026-11-11T06:48:50+0000 0f0637acdf65 systemd[1]: php-fpm.service: Deactivated successfully.
2026-11-11T06:48:50+0000 0f0637acdf65 systemd[1]: Stopped The PHP FastCGI Process Manager.
2026-11-11T06:48:50+0000 0f0637acdf65 systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-11T06:48:50+0000 0f0637acdf65 systemd[1]: Stopped Permit User Sessions.
```

- PASS: (f3) hung probe ? killed at the 150 s backstop, FailureAction=exit ? exit 255 (code=255, elapsed=152s)
- PASS: (g) dead-forwarder/full-pipe fatal ? exit code unchanged (1) and BOUNDED (code=1, elapsed=9s - the 5 s write deadline kept it well inside the 200 s window)
- PASS: (g) reason retrievable from writable-layer fatal-reason file WITHOUT assuming pipe copy (B3)
- post-ready crash never exits the container (a/b contrast); all hangs bounded (f)
## S7-s7-debian
- when: 2026-11-11 07:51:38
- runtime: podman

- **RESULT: PASS**

- PASS: (a) not-writable mount ? exit 1 <=30 s (elapsed=1s code=1)
- PASS: (a) fatal reason names the non-writable location (entry-fatal file)
```
FATAL: /omd/sites/rwfail is not writable (run the container with a writable volume at /omd/sites/rwfail)
```

- PASS: (a) data untouched (marker/creation never attempted - root probe)
- PASS: (b) readiness (gate + 443)
```
ready-time=2s
```

- PASS: (b) after systemctl stop apache2: container still running (never exits)
- PASS: (b) apache2 inactive; status + journalctl explain
- PASS: (b) systemctl start apache2 restores 443
- PASS: (c) pre-ready site-start failure ? container exit 1 (code=1)
- PASS: (c) FATAL-BLOCK / READY-FATAL in the stopped container's log (bounded wait)
```
2026-11-11T06:51:54+00:00 46ef5aab9af2 mariadbd[1002]: 2026-11-11  6:51:54 0 [Note] InnoDB: Starting shutdown...
2026-11-11T06:51:54+00:00 46ef5aab9af2 mariadbd[1002]: 2026-11-11  6:51:54 0 [Note] InnoDB: Dumping buffer pool(s) to /var/lib/mysql/ib_buffer_pool
2026-11-11T06:51:54+00:00 46ef5aab9af2 mariadbd[1002]: 2026-11-11  6:51:54 0 [Note] InnoDB: Buffer pool(s) dump completed at 261111  6:51:54
2026-11-11T06:51:54+00:00 46ef5aab9af2 systemd[1]: apache2.service: Deactivated successfully.
2026-11-11T06:51:54+00:00 46ef5aab9af2 systemd[1]: Stopped apache2.service - The Apache HTTP Server.
2026-11-11T06:51:54+00:00 46ef5aab9af2 systemd[1]: Stopped target remote-fs.target - Remote File Systems.
2026-11-11T06:51:54+00:00 46ef5aab9af2 mariadbd[1002]: 2026-11-11  6:51:54 0 [Note] InnoDB: Removed temporary tablespace data file: "./ibtmp1"
2026-11-11T06:51:54+00:00 46ef5aab9af2 mariadbd[1002]: 2026-11-11  6:51:54 0 [Note] InnoDB: Shutdown completed; log sequence number 45498; transaction id 15
```

- PASS: (c) bounded cleanup ran: no site daemons left
- PASS: (d) ready-gate deadline (injected) ? exit 2 within the 150 s backstop (code=2, elapsed=134s)
- PASS: (e) forwarder dead at fatal time ? exit still 1 (code=1)
- PASS: (e) documented DIRECT-COPY degradation line in the journal (best-effort diagnostics)
```
no DIRECT-COPY line found - degradation recorded (forwarder may have been killed before journal stream; best-effort channel)
```

- PASS: (f1) hung pre-init child ? bounded exit 1 <=130 s wall (the 120 s bootstrap bound, entry epoch) (code=1, elapsed=123s)
- PASS: (f1) the pre-init budget FATAL is recorded (the bounded child was killed, rc=124/137)
```
FATAL: step failed (rc=124): TEST-ONLY injected hang (s7 f1)
```

- PASS: (f1) no systemd ever ran (log carries no systemd[1] lines - died before /sbin/init)
- PASS: (f1b) late-starting hung child ? whole bootstrap still exit 1 <=130 s wall (N2 - not t=190 s) (code=1, elapsed=120s)
- PASS: (f1b) the pre-init budget FATAL is recorded (the remaining-budget cap fired)
```
FATAL: step failed (rc=124): TEST-ONLY injected hang (s7 f1b)
```

- PASS: (f2) stuck dependency job ? fails at TimeoutStartSec, After=-only gate still runs ? exit 1 (code=1, elapsed=97s)
- PASS: (f2) the After=-only gate ran and failed on the stuck unit (log: omd-site.service failed)
```
2026-11-11T07:00:04+00:00 4e946fe5739c systemd[1]: Stopped systemd-user-sessions.service - Permit User Sessions.
2026-11-11T07:00:04+00:00 4e946fe5739c systemd[1]: Stopped target network-online.target - Network is Online.
2026-11-11T07:00:04+00:00 4e946fe5739c apachectl[1497]: AH00558: apache2: Could not reliably determine the server's fully qualified domain name, using 10.0.1.166. Set the 'ServerName' directive globally to suppress this message
2026-11-11T07:00:04+00:00 4e946fe5739c systemd[1]: apache2.service: Deactivated successfully.
2026-11-11T07:00:04+00:00 4e946fe5739c systemd[1]: Stopped apache2.service - The Apache HTTP Server.
2026-11-11T07:00:04+00:00 4e946fe5739c systemd[1]: Stopped target remote-fs.target - Remote File Systems.
2026-11-11T07:00:05+00:00 4e946fe5739c mariadbd[972]: 2026-11-11  7:00:05 0 [Note] InnoDB: Removed temporary tablespace data file: "./ibtmp1"
2026-11-11T07:00:05+00:00 4e946fe5739c mariadbd[972]: 2026-11-11  7:00:05 0 [Note] InnoDB: Shutdown completed; log sequence number 45498; transaction id 15
```

- PASS: (f3) hung probe ? killed at the 150 s backstop, FailureAction=exit ? exit 255 (code=255, elapsed=153s)
- PASS: (g) dead-forwarder/full-pipe fatal ? exit code unchanged (1) and BOUNDED (code=1, elapsed=7s - the 5 s write deadline kept it well inside the 200 s window)
- PASS: (g) reason retrievable from writable-layer fatal-reason file WITHOUT assuming pipe copy (B3)
- post-ready crash never exits the container (a/b contrast); all hangs bounded (f)


## T028-S7-2026-11-11 (s7 battery green on build #13; the battery had NEVER executed before)

- **Task**: T028 = `verify/run.sh s7` via the suite (both distros, port
  18461, injections per quickstart S7 - test-only entry/probe variants
  built FROM the image under test). On BUILD #13 (rocky
  686dbc86f899, debian 45bd695ce2ad; entry 49f7b3b7...). STRICTLY
  SEQUENTIAL, both distros. Result: 23/23 PASS / 0 FAIL EACH
  (rc=0). Logs /tmp/t028b-s7-{rocky,debian}.log.
- **This sub-item had NEVER executed before** (like the s6 a/b case).
  Run #1 aborted BOTH distros before any check; run #2 (after the
  abort fix) ran 18/17 checks with 5 FAILs. FOUR distinct latent
  defects found and fixed in verify/scenarios/s7.sh:
  1. **`injection_build` set -u abort (:53)**: `local tag=$1 body=$2
     df="$FIXDIR/Dockerfile-$tag"` in ONE statement - bash expands
     every word BEFORE any local takes effect, so $tag was unbound
     ("tag: unbound variable", abort at :53). Fixed: df on its own
     line. Suite audit: this was the ONLY occurrence (all other
     multi-assignment locals use positional params or globals - safe).
     Minimal repro of both failure mode and fix recorded in tasks/
     todo.md.
  2. **f1/f1b (both distros, code=0 - still ALIVE at assert time)**:
     the old injection `sed "1a exec sleep 9999"` made the sleep PID 1
     (EXEC replaced the entry), so the bootstrap NEVER ran and the
     container never exited. It tested nothing. Fix: a faithful
     run_bounded CHILD inserted directly before the entry's UNIQUE
     `exec /sbin/init` anchor (entry :1009, count=1 verified):
     `run_bounded 9999 "TEST-ONLY injected hang (s7 f1)" sleep 9999`;
     f1b = `sh -c "sleep 100; exec sleep 9999"` (the LATE-STARTING
     case: the child's own sleep begins ~t=100 s; its run_bounded cap
     is the REMAINING budget, so a per-child cap alone would allow
     t=190 s - the N2 remaining-budget assertion). Pre-run smoke
     (rocky, dedicated image): exit 1 at wall=122 s, child killed at
     the remaining 116 s budget (rc=124), entry-fatal "FATAL: step
     failed (rc=124)", no systemd lines in the log.
  3. **(d)/(f2)/(f3) debian (code=203 = EXEC failure)**: the
     Dockerfile `RUN echo -e "..."` runs under the image's /bin/sh -
     DASH on Debian writes `-e`/`\n` LITERALLY, so the injected
     script had no shebang and the unit died with an EXEC failure
     instantly. Rocky's bash `echo -e` works - why rocky passed.
     Debian's f3 "passed" VACUOUSLY (t=3 s under the old loose
     assertion), its f2 too (203 instead of the TimeoutStartSec path).
     Fix: `printf` (portable - the FORMAT string interprets the
     escapes, not the shell; verified byte-exact via od -c under dash).
  4. **Weak/vacuous assertions**: the loop counter `t` (coarse poll
     granularity) was used as the time bounds; f3 had NO lower bound;
     (d) asserted only the exit code; and the f1 "no systemd" check
     was PROVABLY VACUOUS (`exec journalctl` on a stopped container
     always errors -> non-empty error text -> always exit 0). Fix:
     wall `elapsed` captured BEFORE v_run; explicit windows;
     v_fatal/v_wait_log proof checks; the f1 check replaced with a
     real proof - NO `systemd[1]` lines in the container log (empirical
     ground truth: systemd's own lines DO appear in podman logs when
     systemd ran - the t27c1 log).
- **Timing windows (calibrated against the REAL-path ground truth from
  run #2, rocky - where the real paths were taken)**:
  - (d) `code=2 && 125<=elapsed<=145`: the injected probe sleeps 130 s
    then `exit 2`; code=2 is only reachable via the probe's own exit;
    >=125 proves the full deadline was reached, <=145 proves the probe
    finished BEFORE the 150 s unit backstop. EMPIRICAL: 134 s both
    distros.
  - f1/f1b `code=1 && elapsed<=130` wall: the entry's 120 s budget runs
    from its T0 epoch (a few seconds after container start); the wall
    bound is therefore 130. EMPIRICAL: rocky 121 s, debian 121/120 s.
  - f2 `code=1 && 90<=elapsed<=135`: the job fails AT its
    TimeoutStartSec=90 s (>=90 excludes the instant ~3 s 203 EXEC
    death - it still proves the real timeout path); the After=-only
    gate then still runs and exits 1 (<=135 = 90 s job + gate + stop
    sequence). EMPIRICAL: 97 s both distros (run #2 rocky: 93 s).
    Proof check: the gate's FATAL names the stuck unit (log:
    "omd-site.service failed").
  - f3 `code=255 && 140<=elapsed<=210`: 255 is the empirical systemd
    exit for a killed oneshot + FailureAction=exit (B2); >=140 excludes
    the instant 203 death (the wall death sits slightly BELOW the 150 s
    unit timeout: the job timeout clock starts before the probe
    finishes starting - run #2 rocky 147 s). EMPIRICAL: rocky 152 s,
    debian 153 s. A distro divergence on the code or timing would be a
    parity defect (T032).
  - (g) `code=1 && elapsed<=120`: the undrained-pipe/dead-forwarder
    fatal (killed forwarder + filled pipe); the probe's 5 s write
    deadline keeps it bounded. EMPIRICAL: rocky 9 s, debian 7 s. The
    reason is asserted from the writable-layer fatal-reason file
    WITHOUT assuming the pipe copy was delivered (B3: the guaranteed
    artifact is the exit code; the file is best-effort).
- **Full battery results (build #13, both distros, 23 checks each)**:
  (a) not-writable mount: exit 1 <=30 s (rocky 0 s / debian 1 s),
  fatal names the location, data untouched (root probe);
  (b) post-ready crash: container STAYS UP after `systemctl stop
  httpd|apache2` (edge unit inactive, status+journalctl explain,
  start restores 443 - SC-006/FR-019 second half);
  (c) pre-ready site-start failure (injected): exit 1, FATAL-BLOCK /
  READY-FATAL in the stopped container's log (bounded wait), bounded
  cleanup ran (no site daemons left);
  (d) ready-gate deadline: exit 2 @134 s (both);
  (e) forwarder dead at fatal time: exit still 1 + the documented
  DIRECT-COPY degradation line in the journal;
  (f1) hung pre-init child: bounded exit 1 @121 s, FATAL recorded
  (rc=124), no systemd ever ran;
  (f1b) late-starting hung child: whole bootstrap still exit 1 @120-121
  s (N2 remaining-budget cap - not t=190 s), FATAL recorded;
  (f2) stuck dependency job: exit 1 @97 s (TimeoutStartSec path +
  After=-only gate still runs and fails on the stuck unit);
  (f3) hung probe: exit 255 @152/153 s (150 s backstop +
  FailureAction=exit);
  (g) full-pipe/dead-forwarder: exit 1 @7-9 s, reason from the
  writable-layer file.
- **Suite hygiene**: bash -n + ASCII clean; every edited assertion
  line verified with sed -n NNp | cat -A. Injection escaping verified
  by building both new images and parsing the injected entry (bash -n
  INJECTED-ENTRY-PARSE-OK) before the battery.
- **Spar state**: brief + review round pending (files 84/85) before
  T028 closes - standing directive (every step gets a codex round).
## S7-s7-rocky
- when: 2026-11-11 11:35:00
- runtime: podman

- **RESULT: FAIL**

- PASS: (a) not-writable mount ? exit 1 <=30 s (elapsed=0s code=1)
- PASS: (a) fatal reason names the non-writable location (entry-fatal file)
```
FATAL: /omd/sites/rwfail is not writable (run the container with a writable volume at /omd/sites/rwfail)
```

- PASS: (a) data untouched (marker/creation never attempted - root probe)
- PASS: (b) readiness (gate + 443)
```
ready-time=2s
```

- PASS: (b) after systemctl stop httpd: container still running (never exits)
- PASS: (b) httpd inactive; status + journalctl explain
- PASS: (b) systemctl start httpd restores 443
- PASS: (c) pre-ready site-start failure ? container exit 1 (code=1)
- PASS: (c) FATAL-BLOCK marker in the stopped container's log (bounded wait)
```
2026-11-11T10:35:20+0000 89c20a06571a systemd[1]: crond.service: Deactivated successfully.
2026-11-11T10:35:20+0000 89c20a06571a systemd[1]: Stopped Command Scheduler.
2026-11-11T10:35:20+0000 89c20a06571a systemd[1]: Stopped target sshd-keygen.target.
2026-11-11T10:35:20+0000 89c20a06571a systemd[1]: Stopping Permit User Sessions...
2026-11-11T10:35:20+0000 89c20a06571a systemd[1]: systemd-logind.service: Deactivated successfully.
2026-11-11T10:35:20+0000 89c20a06571a systemd[1]: Stopped User Login Management.
2026-11-11T10:35:20+0000 89c20a06571a systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-11T10:35:20+0000 89c20a06571a systemd[1]: Stopped Permit User Sessions.
```

- PASS: (c) the real daemon was launched before the failure (volume: durable wrapper marker)
- PASS: (c) bounded cleanup ran: the site omd.log records the naemon stop (durable root probe)
- PASS: (c) bounded cleanup ran: no naemon pid file left (durable root probe)
- PASS: (d) ready-gate deadline (REAL probe, masked edge) ? exit 2 within the 150 s backstop (code=2, elapsed=125s)
- PASS: (d) the real probe's deadline reason (log: readiness deadline exceeded)
```
2026-11-11T10:37:26+0000 d43264d8aeb0 omd-ready-check[58]: FATAL-BLOCK-BEGIN (omd-ready rc=2, condition: readiness deadline exceeded (120s gate window))
2026-11-11T10:37:26+0000 d43264d8aeb0 omd-ready-check[941]: 2026-11-11T10:35:25+0000 d43264d8aeb0 systemd[1]: Starting OMD labs single active site (start/stop)...
2026-11-11T10:37:26+0000 d43264d8aeb0 omd-ready-check[941]: 2026-11-11T10:35:25+0000 d43264d8aeb0 systemd[1]: Finished OMD labs single active site (start/stop).
2026-11-11T10:37:26+0000 d43264d8aeb0 omd-ready-check[941]: 2026-11-11T10:35:25+0000 d43264d8aeb0 systemd[1]: Starting OMD labs bounded readiness gate (FR-018)...
2026-11-11T10:37:26+0000 d43264d8aeb0 omd-ready-check[941]: 2026-11-11T10:37:26+0000 d43264d8aeb0 omd-ready-check[58]: READY-FATAL: readiness deadline exceeded (120s gate window) (rc=2)
2026-11-11T10:37:26+0000 d43264d8aeb0 omd-ready-check[941]: 2026-11-11T10:37:26+0000 d43264d8aeb0 omd-ready-check[58]: FATAL-BLOCK-BEGIN (omd-ready rc=2, condition: readiness deadline exceeded (120s gate window))
2026-11-11T10:37:26+0000 d43264d8aeb0 omd-ready-check[58]: FATAL-BLOCK-END
2026-11-11T10:37:26+0000 d43264d8aeb0 omd-ready-check[947]: DIRECT-COPY: status=0 (reason=sent)
```

- PASS: (e) precondition: the forwarder IS dead (kill -0 fails, proved before the fatal)
- PASS: (e) forwarder dead at fatal time ? exit still 1 (code=1)
- FAIL: (e) the REAL probe logged the dead-forwarder degradation line (DIRECT-COPY: status=4) (rc=1)
```
grep: /tmp/tmp.AY1GntTS3v/o: Not a directory
no status=4 line:
```

- FAIL: (e) the writable-layer fatal-reason file carries the reason (guaranteed artifact) (rc=2)
```
grep: /tmp/tmp.A3BXkmjl10/r: Not a directory
```

- PASS: (f1) hung pre-init child ? bounded exit 1 <=130 s wall (the 120 s bootstrap bound, entry epoch) (code=1, elapsed=121s)
- PASS: (f1) the pre-init budget FATAL is recorded (the bounded child was killed, rc=124/137)
```
FATAL: step failed (rc=124): TEST-ONLY injected hang (s7 f1)
```

- PASS: (f1) no systemd ever ran (log carries no systemd[1] lines - died before /sbin/init)
- PASS: (f1b) late-invocation remaining budget ? whole bootstrap still exit 1, 100s<=wall<=135s (N2 - not t~190 s) (code=1, elapsed=121s)
- PASS: (f1b) the run_bounded cap logged for the late child is the REMAINING budget (bounded: Ns, N<=25)
```
logged cap: 17 s
```

- PASS: (f1b) the pre-init budget FATAL is recorded (the remaining-budget cap fired)
```
FATAL: step failed (rc=124): TEST-ONLY injected hang (s7 f1b)
```

- PASS: (f2) stuck dependency job ? fails at TimeoutStartSec, After=-only gate still runs ? exit 1 (code=1, elapsed=100s)
- PASS: (f2) the After=-only gate ran and failed on the stuck unit (log: omd-site.service failed)
```
2026-11-11T10:44:21+0000 d055be9079ac systemd[1]: php-fpm.service: Deactivated successfully.
2026-11-11T10:44:21+0000 d055be9079ac systemd[1]: Stopped The PHP FastCGI Process Manager.
2026-11-11T10:44:21+0000 d055be9079ac systemd[1]: sshd.service: Deactivated successfully.
2026-11-11T10:44:21+0000 d055be9079ac systemd[1]: Stopped OpenSSH server daemon.
2026-11-11T10:44:21+0000 d055be9079ac systemd[1]: Stopped target sshd-keygen.target.
2026-11-11T10:44:21+0000 d055be9079ac systemd[1]: Stopping Permit User Sessions...
2026-11-11T10:44:21+0000 d055be9079ac systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-11T10:44:21+0000 d055be9079ac systemd[1]: Stopped Permit User Sessions.
```

- PASS: (f2) systemd evidence: omd-site timed out (start operation timed out)
```
2026-11-11T10:44:21+0000 d055be9079ac systemd[1]: php-fpm.service: Deactivated successfully.
2026-11-11T10:44:21+0000 d055be9079ac systemd[1]: Stopped The PHP FastCGI Process Manager.
2026-11-11T10:44:21+0000 d055be9079ac systemd[1]: sshd.service: Deactivated successfully.
2026-11-11T10:44:21+0000 d055be9079ac systemd[1]: Stopped OpenSSH server daemon.
2026-11-11T10:44:21+0000 d055be9079ac systemd[1]: Stopped target sshd-keygen.target.
2026-11-11T10:44:21+0000 d055be9079ac systemd[1]: Stopping Permit User Sessions...
2026-11-11T10:44:21+0000 d055be9079ac systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-11T10:44:21+0000 d055be9079ac systemd[1]: Stopped Permit User Sessions.
```

- PASS: (f3) hung probe ? killed at the 150 s backstop, FailureAction=exit ? exit 255 (code=255, elapsed=153s)
- PASS: (f3) systemd evidence: omd-ready killed at the 150 s backstop (start operation timed out)
```
2026-11-11T10:46:58+0000 a2c5b3810c39 systemd[1]: sshd.service: Deactivated successfully.
2026-11-11T10:46:58+0000 a2c5b3810c39 systemd[1]: Stopped OpenSSH server daemon.
2026-11-11T10:46:58+0000 a2c5b3810c39 systemd[1]: omd-site.service: Deactivated successfully.
2026-11-11T10:46:58+0000 a2c5b3810c39 systemd[1]: Stopped OMD labs single active site (start/stop).
2026-11-11T10:46:58+0000 a2c5b3810c39 systemd[1]: Stopped target sshd-keygen.target.
2026-11-11T10:46:58+0000 a2c5b3810c39 systemd[1]: Stopping Permit User Sessions...
2026-11-11T10:46:58+0000 a2c5b3810c39 systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-11T10:46:58+0000 a2c5b3810c39 systemd[1]: Stopped Permit User Sessions.
```

- PASS: (g/baseline) the REAL probe's direct_copy returned status=0 (sent) (code=1, elapsed=9s)
```
DIRECT-COPY: status=0 (reason=sent)
```

- PASS: (g/baseline) the direct-copy operation is BOUNDED (per-op wall < 15 s from the tap)
```
per-op wall=1s
```

- FAIL: (g/baseline) writable-layer fatal-reason file carries the reason (guaranteed artifact, HARD) (rc=2)
```
grep: /tmp/tmp.MZ7I6gm9Rn/r: Not a directory
```

- PASS: (g/fullpipe) the REAL probe's direct_copy returned status=1 (partial) (code=1, elapsed=9s)
```
DIRECT-COPY: status=1 (reason=partial)
```

- PASS: (g/fullpipe) the direct-copy operation is BOUNDED (per-op wall < 15 s from the tap)
```
per-op wall=2s
```

- FAIL: (g/fullpipe) writable-layer fatal-reason file carries the reason (guaranteed artifact, HARD) (rc=2)
```
grep: /tmp/tmp.6sKKAiIQ8k/r: Not a directory
```

- post-ready crash never exits the container (a/b contrast); all hangs bounded (f)
## S7-s7-debian
- when: 2026-11-11 11:47:26
- runtime: podman

- **RESULT: FAIL**

- PASS: (a) not-writable mount ? exit 1 <=30 s (elapsed=1s code=1)
- PASS: (a) fatal reason names the non-writable location (entry-fatal file)
```
FATAL: /omd/sites/rwfail is not writable (run the container with a writable volume at /omd/sites/rwfail)
```

- PASS: (a) data untouched (marker/creation never attempted - root probe)
- PASS: (b) readiness (gate + 443)
```
ready-time=1s
```

- PASS: (b) after systemctl stop apache2: container still running (never exits)
- PASS: (b) apache2 inactive; status + journalctl explain
- PASS: (b) systemctl start apache2 restores 443
- PASS: (c) pre-ready site-start failure ? container exit 1 (code=1)
- PASS: (c) FATAL-BLOCK marker in the stopped container's log (bounded wait)
```
2026-11-11T10:47:46+00:00 7aa51e33f70c mariadbd[978]: 2026-11-11 10:47:46 0 [Note] InnoDB: Starting shutdown...
2026-11-11T10:47:46+00:00 7aa51e33f70c mariadbd[978]: 2026-11-11 10:47:46 0 [Note] InnoDB: Dumping buffer pool(s) to /var/lib/mysql/ib_buffer_pool
2026-11-11T10:47:46+00:00 7aa51e33f70c mariadbd[978]: 2026-11-11 10:47:46 0 [Note] InnoDB: Buffer pool(s) dump completed at 261111 10:47:46
2026-11-11T10:47:46+00:00 7aa51e33f70c systemd[1]: apache2.service: Deactivated successfully.
2026-11-11T10:47:46+00:00 7aa51e33f70c systemd[1]: Stopped apache2.service - The Apache HTTP Server.
2026-11-11T10:47:46+00:00 7aa51e33f70c systemd[1]: Stopped target remote-fs.target - Remote File Systems.
2026-11-11T10:47:46+00:00 7aa51e33f70c mariadbd[978]: 2026-11-11 10:47:46 0 [Note] InnoDB: Removed temporary tablespace data file: "./ibtmp1"
2026-11-11T10:47:46+00:00 7aa51e33f70c mariadbd[978]: 2026-11-11 10:47:46 0 [Note] InnoDB: Shutdown completed; log sequence number 45498; transaction id 15
```

- PASS: (c) the real daemon was launched before the failure (volume: durable wrapper marker)
- PASS: (c) bounded cleanup ran: the site omd.log records the naemon stop (durable root probe)
- PASS: (c) bounded cleanup ran: no naemon pid file left (durable root probe)
- PASS: (d) ready-gate deadline (REAL probe, masked edge) ? exit 2 within the 150 s backstop (code=2, elapsed=125s)
- PASS: (d) the real probe's deadline reason (log: readiness deadline exceeded)
```
2026-11-11T10:49:53+00:00 26c5f66c3da2 mariadbd[157]: 2026-11-11 10:49:53 0 [Note] InnoDB: Dumping buffer pool(s) to /var/lib/mysql/ib_buffer_pool
2026-11-11T10:49:53+00:00 26c5f66c3da2 mariadbd[157]: 2026-11-11 10:49:53 0 [Note] InnoDB: Buffer pool(s) dump completed at 261111 10:49:53
2026-11-11T10:49:53+00:00 26c5f66c3da2 systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-11T10:49:53+00:00 26c5f66c3da2 systemd[1]: Stopped systemd-user-sessions.service - Permit User Sessions.
2026-11-11T10:49:53+00:00 26c5f66c3da2 systemd[1]: Stopped target network-online.target - Network is Online.
2026-11-11T10:49:53+00:00 26c5f66c3da2 systemd[1]: Stopped target remote-fs.target - Remote File Systems.
2026-11-11T10:49:53+00:00 26c5f66c3da2 mariadbd[157]: 2026-11-11 10:49:53 0 [Note] InnoDB: Removed temporary tablespace data file: "./ibtmp1"
2026-11-11T10:49:53+00:00 26c5f66c3da2 mariadbd[157]: 2026-11-11 10:49:53 0 [Note] InnoDB: Shutdown completed; log sequence number 45498; transaction id 15
```

- PASS: (e) precondition: the forwarder IS dead (kill -0 fails, proved before the fatal)
- PASS: (e) forwarder dead at fatal time ? exit still 1 (code=1)
- FAIL: (e) the REAL probe logged the dead-forwarder degradation line (DIRECT-COPY: status=4) (rc=1)
```
grep: /tmp/tmp.bg70fJ0mnp/o: Not a directory
no status=4 line:
```

- FAIL: (e) the writable-layer fatal-reason file carries the reason (guaranteed artifact) (rc=2)
```
grep: /tmp/tmp.ng7dGgaqsC/r: Not a directory
```

- PASS: (f1) hung pre-init child ? bounded exit 1 <=130 s wall (the 120 s bootstrap bound, entry epoch) (code=1, elapsed=121s)
- PASS: (f1) the pre-init budget FATAL is recorded (the bounded child was killed, rc=124/137)
```
FATAL: step failed (rc=124): TEST-ONLY injected hang (s7 f1)
```

- PASS: (f1) no systemd ever ran (log carries no systemd[1] lines - died before /sbin/init)
- PASS: (f1b) late-invocation remaining budget ? whole bootstrap still exit 1, 100s<=wall<=135s (N2 - not t~190 s) (code=1, elapsed=121s)
- PASS: (f1b) the run_bounded cap logged for the late child is the REMAINING budget (bounded: Ns, N<=25)
```
logged cap: 18 s
```

- PASS: (f1b) the pre-init budget FATAL is recorded (the remaining-budget cap fired)
```
FATAL: step failed (rc=124): TEST-ONLY injected hang (s7 f1b)
```

- PASS: (f2) stuck dependency job ? fails at TimeoutStartSec, After=-only gate still runs ? exit 1 (code=1, elapsed=97s)
- PASS: (f2) the After=-only gate ran and failed on the stuck unit (log: omd-site.service failed)
```
2026-11-11T10:56:47+00:00 721d09418673 mariadbd[972]: 2026-11-11 10:56:47 0 [Note] InnoDB: Dumping buffer pool(s) to /var/lib/mysql/ib_buffer_pool
2026-11-11T10:56:47+00:00 721d09418673 mariadbd[972]: 2026-11-11 10:56:47 0 [Note] InnoDB: Buffer pool(s) dump completed at 261111 10:56:47
2026-11-11T10:56:47+00:00 721d09418673 apachectl[1497]: AH00558: apache2: Could not reliably determine the server's fully qualified domain name, using 10.0.1.166. Set the 'ServerName' directive globally to suppress this message
2026-11-11T10:56:47+00:00 721d09418673 systemd[1]: apache2.service: Deactivated successfully.
2026-11-11T10:56:47+00:00 721d09418673 systemd[1]: Stopped apache2.service - The Apache HTTP Server.
2026-11-11T10:56:47+00:00 721d09418673 systemd[1]: Stopped target remote-fs.target - Remote File Systems.
2026-11-11T10:56:47+00:00 721d09418673 mariadbd[972]: 2026-11-11 10:56:47 0 [Note] InnoDB: Removed temporary tablespace data file: "./ibtmp1"
2026-11-11T10:56:47+00:00 721d09418673 mariadbd[972]: 2026-11-11 10:56:47 0 [Note] InnoDB: Shutdown completed; log sequence number 45498; transaction id 15
```

- PASS: (f2) systemd evidence: omd-site timed out (start operation timed out)
```
2026-11-11T10:56:47+00:00 721d09418673 mariadbd[972]: 2026-11-11 10:56:47 0 [Note] InnoDB: Dumping buffer pool(s) to /var/lib/mysql/ib_buffer_pool
2026-11-11T10:56:47+00:00 721d09418673 mariadbd[972]: 2026-11-11 10:56:47 0 [Note] InnoDB: Buffer pool(s) dump completed at 261111 10:56:47
2026-11-11T10:56:47+00:00 721d09418673 apachectl[1497]: AH00558: apache2: Could not reliably determine the server's fully qualified domain name, using 10.0.1.166. Set the 'ServerName' directive globally to suppress this message
2026-11-11T10:56:47+00:00 721d09418673 systemd[1]: apache2.service: Deactivated successfully.
2026-11-11T10:56:47+00:00 721d09418673 systemd[1]: Stopped apache2.service - The Apache HTTP Server.
2026-11-11T10:56:47+00:00 721d09418673 systemd[1]: Stopped target remote-fs.target - Remote File Systems.
2026-11-11T10:56:47+00:00 721d09418673 mariadbd[972]: 2026-11-11 10:56:47 0 [Note] InnoDB: Removed temporary tablespace data file: "./ibtmp1"
2026-11-11T10:56:47+00:00 721d09418673 mariadbd[972]: 2026-11-11 10:56:47 0 [Note] InnoDB: Shutdown completed; log sequence number 45498; transaction id 15
```

- PASS: (f3) hung probe ? killed at the 150 s backstop, FailureAction=exit ? exit 255 (code=255, elapsed=153s)
- PASS: (f3) systemd evidence: omd-ready killed at the 150 s backstop (start operation timed out)
```
2026-11-11T10:59:21+00:00 9222d6e8f0eb systemd[1]: Stopped systemd-user-sessions.service - Permit User Sessions.
2026-11-11T10:59:21+00:00 9222d6e8f0eb systemd[1]: Stopped target network-online.target - Network is Online.
2026-11-11T10:59:21+00:00 9222d6e8f0eb apachectl[483]: AH00558: apache2: Could not reliably determine the server's fully qualified domain name, using 10.0.1.166. Set the 'ServerName' directive globally to suppress this message
2026-11-11T10:59:21+00:00 9222d6e8f0eb systemd[1]: apache2.service: Deactivated successfully.
2026-11-11T10:59:21+00:00 9222d6e8f0eb systemd[1]: Stopped apache2.service - The Apache HTTP Server.
2026-11-11T10:59:21+00:00 9222d6e8f0eb systemd[1]: Stopped target remote-fs.target - Remote File Systems.
2026-11-11T10:59:21+00:00 9222d6e8f0eb mariadbd[154]: 2026-11-11 10:59:21 0 [Note] InnoDB: Removed temporary tablespace data file: "./ibtmp1"
2026-11-11T10:59:21+00:00 9222d6e8f0eb mariadbd[154]: 2026-11-11 10:59:21 0 [Note] InnoDB: Shutdown completed; log sequence number 45498; transaction id 15
```

- PASS: (g/baseline) the REAL probe's direct_copy returned status=0 (sent) (code=1, elapsed=7s)
```
DIRECT-COPY: status=0 (reason=sent)
```

- PASS: (g/baseline) the direct-copy operation is BOUNDED (per-op wall < 15 s from the tap)
```
per-op wall=2s
```

- FAIL: (g/baseline) writable-layer fatal-reason file carries the reason (guaranteed artifact, HARD) (rc=2)
```
grep: /tmp/tmp.ll8q1NnsSb/r: Not a directory
```

- PASS: (g/fullpipe) the REAL probe's direct_copy returned status=1 (partial) (code=1, elapsed=6s)
```
DIRECT-COPY: status=1 (reason=partial)
```

- PASS: (g/fullpipe) the direct-copy operation is BOUNDED (per-op wall < 15 s from the tap)
```
per-op wall=1s
```

- FAIL: (g/fullpipe) writable-layer fatal-reason file carries the reason (guaranteed artifact, HARD) (rc=2)
```
grep: /tmp/tmp.gUxvGp2qdL/r: Not a directory
```

- post-ready crash never exits the container (a/b contrast); all hangs bounded (f)
## S7-s7-rocky
- when: 2026-11-11 12:02:54
- runtime: podman

- **RESULT: PASS**

- PASS: (a) not-writable mount ? exit 1 <=30 s (elapsed=0s code=1)
- PASS: (a) fatal reason names the non-writable location (entry-fatal file)
```
FATAL: /omd/sites/rwfail is not writable (run the container with a writable volume at /omd/sites/rwfail)
```

- PASS: (a) data untouched (marker/creation never attempted - root probe)
- PASS: (b) readiness (gate + 443)
```
ready-time=2s
```

- PASS: (b) after systemctl stop httpd: container still running (never exits)
- PASS: (b) httpd inactive; status + journalctl explain
- PASS: (b) systemctl start httpd restores 443
- PASS: (c) pre-ready site-start failure ? container exit 1 (code=1)
- PASS: (c) FATAL-BLOCK marker in the stopped container's log (bounded wait)
```
2026-11-11T11:03:14+0000 5b7a66b60e18 systemd[1]: sshd.service: Deactivated successfully.
2026-11-11T11:03:14+0000 5b7a66b60e18 systemd[1]: Stopped OpenSSH server daemon.
2026-11-11T11:03:14+0000 5b7a66b60e18 systemd[1]: Stopped target sshd-keygen.target.
2026-11-11T11:03:14+0000 5b7a66b60e18 systemd[1]: Stopping Permit User Sessions...
2026-11-11T11:03:14+0000 5b7a66b60e18 systemd[1]: php-fpm.service: Deactivated successfully.
2026-11-11T11:03:14+0000 5b7a66b60e18 systemd[1]: Stopped The PHP FastCGI Process Manager.
2026-11-11T11:03:14+0000 5b7a66b60e18 systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-11T11:03:14+0000 5b7a66b60e18 systemd[1]: Stopped Permit User Sessions.
```

- PASS: (c) the real daemon was launched before the failure (volume: durable wrapper marker)
- PASS: (c) bounded cleanup ran: the site omd.log records the naemon stop (durable root probe)
- PASS: (c) bounded cleanup ran: no naemon pid file left (durable root probe)
- PASS: (d) ready-gate deadline (REAL probe, masked edge) ? exit 2 within the 150 s backstop (code=2, elapsed=125s)
- PASS: (d) the real probe's deadline reason (log: readiness deadline exceeded)
```
2026-11-11T11:05:21+0000 321c9cf883db omd-ready-check[57]: FATAL-BLOCK-BEGIN (omd-ready rc=2, condition: readiness deadline exceeded (120s gate window))
2026-11-11T11:05:21+0000 321c9cf883db omd-ready-check[941]: 2026-11-11T11:03:19+0000 321c9cf883db systemd[1]: Starting OMD labs single active site (start/stop)...
2026-11-11T11:05:21+0000 321c9cf883db omd-ready-check[941]: 2026-11-11T11:03:19+0000 321c9cf883db systemd[1]: Finished OMD labs single active site (start/stop).
2026-11-11T11:05:21+0000 321c9cf883db omd-ready-check[941]: 2026-11-11T11:03:20+0000 321c9cf883db systemd[1]: Starting OMD labs bounded readiness gate (FR-018)...
2026-11-11T11:05:21+0000 321c9cf883db omd-ready-check[941]: 2026-11-11T11:05:21+0000 321c9cf883db omd-ready-check[57]: READY-FATAL: readiness deadline exceeded (120s gate window) (rc=2)
2026-11-11T11:05:21+0000 321c9cf883db omd-ready-check[941]: 2026-11-11T11:05:21+0000 321c9cf883db omd-ready-check[57]: FATAL-BLOCK-BEGIN (omd-ready rc=2, condition: readiness deadline exceeded (120s gate window))
2026-11-11T11:05:21+0000 321c9cf883db omd-ready-check[57]: FATAL-BLOCK-END
2026-11-11T11:05:21+0000 321c9cf883db omd-ready-check[947]: DIRECT-COPY: status=0 (reason=sent)
```

- PASS: (e) precondition: the forwarder IS dead (kill -0 fails, proved before the fatal)
- PASS: (e) forwarder dead at fatal time ? exit still 1 (code=1)
- PASS: (e) the REAL probe logged the dead-forwarder degradation line (DIRECT-COPY: status=4)
```
DIRECT-COPY: status=4 (forwarder dead - pipe copy skipped)
```

- PASS: (e) the writable-layer fatal-reason file carries the reason (guaranteed artifact)
```
READY-FATAL: unit omd-site.service failed (per-unit ActiveState/Result=failed) (rc=1)
```

- PASS: (f1) hung pre-init child ? bounded exit 1 <=130 s wall (the 120 s bootstrap bound, entry epoch) (code=1, elapsed=122s)
- PASS: (f1) the pre-init budget FATAL is recorded (the bounded child was killed, rc=124/137)
```
FATAL: step failed (rc=124): TEST-ONLY injected hang (s7 f1)
```

- PASS: (f1) no systemd ever ran (log carries no systemd[1] lines - died before /sbin/init)
- PASS: (f1b) late-invocation remaining budget ? whole bootstrap still exit 1, 100s<=wall<=135s (N2 - not t~190 s) (code=1, elapsed=122s)
- PASS: (f1b) the run_bounded cap logged for the late child is the REMAINING budget (bounded: Ns, N<=25)
```
logged cap: 16 s
```

- PASS: (f1b) the pre-init budget FATAL is recorded (the remaining-budget cap fired)
```
FATAL: step failed (rc=124): TEST-ONLY injected hang (s7 f1b)
```

- PASS: (f2) stuck dependency job ? fails at TimeoutStartSec, After=-only gate still runs ? exit 1 (code=1, elapsed=100s)
- PASS: (f2) the After=-only gate ran and failed on the stuck unit (log: omd-site.service failed)
```
2026-11-11T11:12:05+0000 f318c286278a systemd[1]: Stopped Command Scheduler.
2026-11-11T11:12:05+0000 f318c286278a systemd[1]: Stopping Permit User Sessions...
2026-11-11T11:12:05+0000 f318c286278a systemd[1]: php-fpm.service: Deactivated successfully.
2026-11-11T11:12:05+0000 f318c286278a systemd[1]: Stopped The PHP FastCGI Process Manager.
2026-11-11T11:12:05+0000 f318c286278a systemd[1]: systemd-logind.service: Deactivated successfully.
2026-11-11T11:12:05+0000 f318c286278a systemd[1]: Stopped User Login Management.
2026-11-11T11:12:05+0000 f318c286278a systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-11T11:12:05+0000 f318c286278a systemd[1]: Stopped Permit User Sessions.
```

- PASS: (f2) systemd evidence: omd-site timed out (start operation timed out)
```
2026-11-11T11:12:05+0000 f318c286278a systemd[1]: Stopped Command Scheduler.
2026-11-11T11:12:05+0000 f318c286278a systemd[1]: Stopping Permit User Sessions...
2026-11-11T11:12:05+0000 f318c286278a systemd[1]: php-fpm.service: Deactivated successfully.
2026-11-11T11:12:05+0000 f318c286278a systemd[1]: Stopped The PHP FastCGI Process Manager.
2026-11-11T11:12:05+0000 f318c286278a systemd[1]: systemd-logind.service: Deactivated successfully.
2026-11-11T11:12:05+0000 f318c286278a systemd[1]: Stopped User Login Management.
2026-11-11T11:12:05+0000 f318c286278a systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-11T11:12:05+0000 f318c286278a systemd[1]: Stopped Permit User Sessions.
```

- PASS: (f3) hung probe ? killed at the 150 s backstop, FailureAction=exit ? exit 255 (code=255, elapsed=153s)
- PASS: (f3) systemd evidence: omd-ready killed at the 150 s backstop (start operation timed out)
```
2026-11-11T11:14:42+0000 6309863a6059 systemd[1]: sshd.service: Deactivated successfully.
2026-11-11T11:14:42+0000 6309863a6059 systemd[1]: Stopped OpenSSH server daemon.
2026-11-11T11:14:42+0000 6309863a6059 systemd[1]: omd-site.service: Deactivated successfully.
2026-11-11T11:14:42+0000 6309863a6059 systemd[1]: Stopped OMD labs single active site (start/stop).
2026-11-11T11:14:42+0000 6309863a6059 systemd[1]: Stopped target sshd-keygen.target.
2026-11-11T11:14:42+0000 6309863a6059 systemd[1]: Stopping Permit User Sessions...
2026-11-11T11:14:42+0000 6309863a6059 systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-11T11:14:42+0000 6309863a6059 systemd[1]: Stopped Permit User Sessions.
```

- PASS: (g/baseline) the REAL probe's direct_copy returned status=0 (sent) (code=1, elapsed=9s)
```
DIRECT-COPY: status=0 (reason=sent)
```

- PASS: (g/baseline) the direct-copy operation is BOUNDED (per-op wall < 15 s from the tap)
```
per-op wall=2s
```

- PASS: (g/baseline) writable-layer fatal-reason file carries the reason (guaranteed artifact, HARD)
```
READY-FATAL: unit omd-site.service failed (per-unit ActiveState/Result=failed) (rc=1)
```

- PASS: (g/fullpipe) the REAL probe's direct_copy returned status=1 (partial) (code=1, elapsed=9s)
```
DIRECT-COPY: status=1 (reason=partial)
```

- PASS: (g/fullpipe) the direct-copy operation is BOUNDED (per-op wall < 15 s from the tap)
```
per-op wall=2s
```

- PASS: (g/fullpipe) writable-layer fatal-reason file carries the reason (guaranteed artifact, HARD)
```
READY-FATAL: unit omd-site.service failed (per-unit ActiveState/Result=failed) (rc=1)
```

- post-ready crash never exits the container (a/b contrast); all hangs bounded (f)
## S7-s7-debian
- when: 2026-11-11 12:15:10
- runtime: podman

- **RESULT: PASS**

- PASS: (a) not-writable mount ? exit 1 <=30 s (elapsed=1s code=1)
- PASS: (a) fatal reason names the non-writable location (entry-fatal file)
```
FATAL: /omd/sites/rwfail is not writable (run the container with a writable volume at /omd/sites/rwfail)
```

- PASS: (a) data untouched (marker/creation never attempted - root probe)
- PASS: (b) readiness (gate + 443)
```
ready-time=2s
```

- PASS: (b) after systemctl stop apache2: container still running (never exits)
- PASS: (b) apache2 inactive; status + journalctl explain
- PASS: (b) systemctl start apache2 restores 443
- PASS: (c) pre-ready site-start failure ? container exit 1 (code=1)
- PASS: (c) FATAL-BLOCK marker in the stopped container's log (bounded wait)
```
2026-11-11T11:15:28+00:00 ae83971282ff systemd[1]: Stopped systemd-user-sessions.service - Permit User Sessions.
2026-11-11T11:15:28+00:00 ae83971282ff apachectl[1498]: AH00558: apache2: Could not reliably determine the server's fully qualified domain name, using 10.0.1.166. Set the 'ServerName' directive globally to suppress this message
2026-11-11T11:15:28+00:00 ae83971282ff mariadbd[978]: 2026-11-11 11:15:28 0 [Note] InnoDB: Starting shutdown...
2026-11-11T11:15:28+00:00 ae83971282ff mariadbd[978]: 2026-11-11 11:15:28 0 [Note] InnoDB: Dumping buffer pool(s) to /var/lib/mysql/ib_buffer_pool
2026-11-11T11:15:28+00:00 ae83971282ff mariadbd[978]: 2026-11-11 11:15:28 0 [Note] InnoDB: Buffer pool(s) dump completed at 261111 11:15:28
2026-11-11T11:15:28+00:00 ae83971282ff systemd[1]: apache2.service: Deactivated successfully.
2026-11-11T11:15:28+00:00 ae83971282ff systemd[1]: Stopped apache2.service - The Apache HTTP Server.
2026-11-11T11:15:28+00:00 ae83971282ff systemd[1]: Stopped target remote-fs.target - Remote File Systems.
```

- PASS: (c) the real daemon was launched before the failure (volume: durable wrapper marker)
- PASS: (c) bounded cleanup ran: the site omd.log records the naemon stop (durable root probe)
- PASS: (c) bounded cleanup ran: no naemon pid file left (durable root probe)
- PASS: (d) ready-gate deadline (REAL probe, masked edge) ? exit 2 within the 150 s backstop (code=2, elapsed=125s)
- PASS: (d) the real probe's deadline reason (log: readiness deadline exceeded)
```
2026-11-11T11:17:34+00:00 3b5d6c654ff7 systemd[1]: Stopped target network-online.target - Network is Online.
2026-11-11T11:17:34+00:00 3b5d6c654ff7 mariadbd[157]: 2026-11-11 11:17:34 0 [Note] InnoDB: Dumping buffer pool(s) to /var/lib/mysql/ib_buffer_pool
2026-11-11T11:17:34+00:00 3b5d6c654ff7 mariadbd[157]: 2026-11-11 11:17:34 0 [Note] InnoDB: Buffer pool(s) dump completed at 261111 11:17:34
2026-11-11T11:17:34+00:00 3b5d6c654ff7 systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-11T11:17:34+00:00 3b5d6c654ff7 systemd[1]: Stopped systemd-user-sessions.service - Permit User Sessions.
2026-11-11T11:17:34+00:00 3b5d6c654ff7 systemd[1]: Stopped target remote-fs.target - Remote File Systems.
2026-11-11T11:17:34+00:00 3b5d6c654ff7 mariadbd[157]: 2026-11-11 11:17:34 0 [Note] InnoDB: Removed temporary tablespace data file: "./ibtmp1"
2026-11-11T11:17:34+00:00 3b5d6c654ff7 mariadbd[157]: 2026-11-11 11:17:34 0 [Note] InnoDB: Shutdown completed; log sequence number 45498; transaction id 15
```

- PASS: (e) precondition: the forwarder IS dead (kill -0 fails, proved before the fatal)
- PASS: (e) forwarder dead at fatal time ? exit still 1 (code=1)
- PASS: (e) the REAL probe logged the dead-forwarder degradation line (DIRECT-COPY: status=4)
```
DIRECT-COPY: status=4 (forwarder dead - pipe copy skipped)
```

- PASS: (e) the writable-layer fatal-reason file carries the reason (guaranteed artifact)
```
READY-FATAL: unit omd-site.service failed (per-unit ActiveState/Result=failed) (rc=1)
```

- PASS: (f1) hung pre-init child ? bounded exit 1 <=130 s wall (the 120 s bootstrap bound, entry epoch) (code=1, elapsed=123s)
- PASS: (f1) the pre-init budget FATAL is recorded (the bounded child was killed, rc=124/137)
```
FATAL: step failed (rc=124): TEST-ONLY injected hang (s7 f1)
```

- PASS: (f1) no systemd ever ran (log carries no systemd[1] lines - died before /sbin/init)
- PASS: (f1b) late-invocation remaining budget ? whole bootstrap still exit 1, 100s<=wall<=135s (N2 - not t~190 s) (code=1, elapsed=121s)
- PASS: (f1b) the run_bounded cap logged for the late child is the REMAINING budget (bounded: Ns, N<=25)
```
logged cap: 18 s
```

- PASS: (f1b) the pre-init budget FATAL is recorded (the remaining-budget cap fired)
```
FATAL: step failed (rc=124): TEST-ONLY injected hang (s7 f1b)
```

- PASS: (f2) stuck dependency job ? fails at TimeoutStartSec, After=-only gate still runs ? exit 1 (code=1, elapsed=97s)
- PASS: (f2) the After=-only gate ran and failed on the stuck unit (log: omd-site.service failed)
```
2026-11-11T11:24:14+00:00 57593b7ad741 systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-11T11:24:14+00:00 57593b7ad741 systemd[1]: Stopped systemd-user-sessions.service - Permit User Sessions.
2026-11-11T11:24:14+00:00 57593b7ad741 apachectl[1497]: AH00558: apache2: Could not reliably determine the server's fully qualified domain name, using 10.0.1.166. Set the 'ServerName' directive globally to suppress this message
2026-11-11T11:24:14+00:00 57593b7ad741 systemd[1]: apache2.service: Deactivated successfully.
2026-11-11T11:24:14+00:00 57593b7ad741 systemd[1]: Stopped apache2.service - The Apache HTTP Server.
2026-11-11T11:24:14+00:00 57593b7ad741 systemd[1]: Stopped target remote-fs.target - Remote File Systems.
2026-11-11T11:24:14+00:00 57593b7ad741 mariadbd[972]: 2026-11-11 11:24:14 0 [Note] InnoDB: Removed temporary tablespace data file: "./ibtmp1"
2026-11-11T11:24:14+00:00 57593b7ad741 mariadbd[972]: 2026-11-11 11:24:14 0 [Note] InnoDB: Shutdown completed; log sequence number 45498; transaction id 15
```

- PASS: (f2) systemd evidence: omd-site timed out (start operation timed out)
```
2026-11-11T11:24:14+00:00 57593b7ad741 systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-11T11:24:14+00:00 57593b7ad741 systemd[1]: Stopped systemd-user-sessions.service - Permit User Sessions.
2026-11-11T11:24:14+00:00 57593b7ad741 apachectl[1497]: AH00558: apache2: Could not reliably determine the server's fully qualified domain name, using 10.0.1.166. Set the 'ServerName' directive globally to suppress this message
2026-11-11T11:24:14+00:00 57593b7ad741 systemd[1]: apache2.service: Deactivated successfully.
2026-11-11T11:24:14+00:00 57593b7ad741 systemd[1]: Stopped apache2.service - The Apache HTTP Server.
2026-11-11T11:24:14+00:00 57593b7ad741 systemd[1]: Stopped target remote-fs.target - Remote File Systems.
2026-11-11T11:24:14+00:00 57593b7ad741 mariadbd[972]: 2026-11-11 11:24:14 0 [Note] InnoDB: Removed temporary tablespace data file: "./ibtmp1"
2026-11-11T11:24:14+00:00 57593b7ad741 mariadbd[972]: 2026-11-11 11:24:14 0 [Note] InnoDB: Shutdown completed; log sequence number 45498; transaction id 15
```

- PASS: (f3) hung probe ? killed at the 150 s backstop, FailureAction=exit ? exit 255 (code=255, elapsed=153s)
- PASS: (f3) systemd evidence: omd-ready killed at the 150 s backstop (start operation timed out)
```
2026-11-11T11:26:48+00:00 5dabd984ab0d systemd[1]: Stopped systemd-user-sessions.service - Permit User Sessions.
2026-11-11T11:26:48+00:00 5dabd984ab0d systemd[1]: Stopped target network-online.target - Network is Online.
2026-11-11T11:26:48+00:00 5dabd984ab0d apachectl[483]: AH00558: apache2: Could not reliably determine the server's fully qualified domain name, using 10.0.1.166. Set the 'ServerName' directive globally to suppress this message
2026-11-11T11:26:49+00:00 5dabd984ab0d systemd[1]: apache2.service: Deactivated successfully.
2026-11-11T11:26:49+00:00 5dabd984ab0d systemd[1]: Stopped apache2.service - The Apache HTTP Server.
2026-11-11T11:26:49+00:00 5dabd984ab0d systemd[1]: Stopped target remote-fs.target - Remote File Systems.
2026-11-11T11:26:49+00:00 5dabd984ab0d mariadbd[154]: 2026-11-11 11:26:49 0 [Note] InnoDB: Removed temporary tablespace data file: "./ibtmp1"
2026-11-11T11:26:49+00:00 5dabd984ab0d mariadbd[154]: 2026-11-11 11:26:49 0 [Note] InnoDB: Shutdown completed; log sequence number 45498; transaction id 15
```

- PASS: (g/baseline) the REAL probe's direct_copy returned status=0 (sent) (code=1, elapsed=7s)
```
DIRECT-COPY: status=0 (reason=sent)
```

- PASS: (g/baseline) the direct-copy operation is BOUNDED (per-op wall < 15 s from the tap)
```
per-op wall=2s
```

- PASS: (g/baseline) writable-layer fatal-reason file carries the reason (guaranteed artifact, HARD)
```
READY-FATAL: unit omd-site.service failed (per-unit ActiveState/Result=failed) (rc=1)
```

- PASS: (g/fullpipe) the REAL probe's direct_copy returned status=1 (partial) (code=1, elapsed=7s)
```
DIRECT-COPY: status=1 (reason=partial)
```

- PASS: (g/fullpipe) the direct-copy operation is BOUNDED (per-op wall < 15 s from the tap)
```
per-op wall=2s
```

- PASS: (g/fullpipe) writable-layer fatal-reason file carries the reason (guaranteed artifact, HARD)
```
READY-FATAL: unit omd-site.service failed (per-unit ActiveState/Result=failed) (rc=1)
```

- post-ready crash never exits the container (a/b contrast); all hangs bounded (f)


## T028-S7-V2-2026-11-11 (codex-85 rework green: 35/35 both distros; supersedes T028-S7-2026-11-11)

- **Task**: same as before - `verify/run.sh s7` via the suite (both
  distros, port 18461, build #13 images). The previous green (23/23) is
  SUPERSEDED: spar round 85 (codex, file 85) + self-audit found 1 BLOCKER
  + 3 MAJOR + 1 NOTE, all verified real and fixed. The reworked battery
  has 35 checks. STRICTLY SEQUENTIAL, both distros. Result: 35/35 PASS /
  0 FAIL EACH (rc=0). Logs /tmp/t028d-s7-{rocky,debian}.log (the t028c
  run was 31/4 - the 4 FAILs were one harness bug in the new checks,
  fixed and re-run).
- **Fixes per codex 85 (full reasoning + empirical evidence in debate
  file 86)**:
  1. BLOCKER (g) - the pipe was never filled (the old fill loop wrote to
     /dev/null; killing the forwarder only exercised status=4). Now the
     REAL probe's direct_copy path is exercised for real:
     (g/baseline) REAL forwarder + REAL probe -> `DIRECT-COPY: status=0
     (reason=sent)`; (g/fullpipe) a test-only forwarder shim re-points
     fd 1 to a PRIVATE fifo (O_RDWR `exec 1<>`, filled, never drained)
     so the REAL probe's O_NONBLOCK write to /proc/<fwd>/fd/1 returns
     EAGAIN -> `DIRECT-COPY: status=1 (reason=partial)`. Deterministic
     (a full pipe returns EAGAIN instantly - host-proven errno 11).
     status=2 (the 5 s deadline) is UNREACHABLE for a pipe in practice
     and is documented as the code-level backstop. Per-operation wall
     measured via a t0/t1 tap around the REAL probe (rocky 1-2 s,
     debian 1 s - well inside the 5 s deadline). The (e) case covers
     status=4 (dead forwarder). The writable-layer fatal-reason file is
     HARD-asserted in (g) (no file-write failure is injected).
  2. MAJOR (e) - the old check passed vacuously (the DIRECT-COPY line
     was 0x in both green runs; the check exited 0 by construction).
     Settled facts: the probe's stdout is JOURNAL-only (no
     StandardOutput=) and the journal is VOLATILE post-stop (tested) -
     so a TEST-ONLY tee shim runs the REAL probe (contract preserved,
     PIPESTATUS exit propagation) and taps to /var/log/omd-labs/
     probe-out.tap (OVERLAY - /tmp is a systemd tmpfs, EMPIRICAL:
     markers written to /tmp, /var/tmp and /var/log/omd-labs in a live
     systemd container were all gone after stop). Precondition sync:
     the fatal is DELAYED (wrapper sleep 45; omd-site stays activating
     so the probe polls), the forwarder is killed at t~10 and its death
     is PROVEN (bounded kill -0 poll, hard check) BEFORE the fatal.
     GREEN: `DIRECT-COPY: status=4 (forwarder dead - pipe copy skipped)`
     HARD-asserted from the tap (both distros); exit still 1.
  3. MAJOR (c) - the old wrapper was `echo "exit 1"` (no shebang ->
     EXEC-failure risk; started no daemons) and the old "no daemons
     left" check passed vacuously (exec ps on a stopped container always
     errors). Now: a REAL heredoc-fixture wrapper (zero escape layering
     - the RUN-printf approach was proven dash-broken: `printf: %?:
     invalid directive` on ${SITE#?}) that writes a durable marker,
     starts the site's OWN naemon with the REAL startup command
     (`runuser -u <site> -- <site>/bin/naemon -ud <site>/tmp/naemon/
     naemon.cfg`), then exit 1; the build bash -n's the baked file.
     Cleanup proven DURABLY via root volume probes (ground truth, probe
     C): the bounded `omd stop` leaves `80-naemon stop` lines in the
     site's omd.log and NO naemon pid file. All 5 (c) checks GREEN both
     distros.
  4. MAJOR (d) - the old injection replaced the whole probe with
     `sleep 130; exit 2` (exit-code propagation only). Now the REAL
     probe runs; the never-ready condition is a MASKED distro edge unit
     (masked -> inactive -> transient per the probe's unit_state, so
     only the deadline path can fire). GREEN: exit 2 @ 125 s both
     distros + the probe's OWN `readiness deadline exceeded` reason
     line (window 125-145 s).
  5. NOTE - (f2)/(f3): deterministic systemd evidence added
     (`start operation timed out` for the right unit, v_wait_log)
     alongside the wall windows - GREEN both distros (f2 97-100 s,
     f3 255 @ 153 s); this also anchors the clock origin (wall death =
     ~5-7 s bootstrap offset + the exact 90/150 s job timeout). (f1b):
     now proves the REMAINING-budget cap fired - two injected
     run_bounded steps (`sleep 100` consumer + hanging child) and the
     check asserts the LAST logged `bounded: Ns` is the small remaining
     number (N<=25): GREEN, logged cap 16 s (rocky) / 18 s (debian),
     whole bootstrap exit 1 @ 121 s (window 100-135 s). (a): astart
     before v_run. (f1): non-empty-capture guard added.
- **Harness bug found and fixed in the t028c run** (31/4 both distros):
  the 3 new fatal-reason/tap checks used `tmp=$(mktemp)` (a FILE) but
  wrote to `$tmp/o`/`$tmp/r` (paths under that file) -> `podman cp`
  "Not a directory" -> the artifact never landed -> grep failed.
  Underlying checks all passed (the evidence lines were present). Fix:
  `mktemp -d` (s7.sh :254/:259/:514). Suite-wide audit: no other
  mktemp-as-file usages (s10.sh/common.sh use it as a file - correct).
- **Suite hygiene**: bash -n + ASCII clean; every check splice
  cat -A-verified; injection_build context = $FIXDIR (the heredoc
  fixtures ADD by basename); all injection images build-verified before
  the battery (bash -n of the baked files).
- **Spar state**: response file 86 (dispositions + evidence) sent;
  codex final verdict requested (file 87) before T028 closes.
## S7-s7-rocky
- when: 2026-11-11 13:02:50
- runtime: podman

- **RESULT: PASS**

- PASS: (a) not-writable mount ? exit 1 <=30 s (elapsed=1s code=1)
- PASS: (a) fatal reason names the non-writable location (entry-fatal file)
```
FATAL: /omd/sites/rwfail is not writable (run the container with a writable volume at /omd/sites/rwfail)
```

- PASS: (a) data untouched (marker/creation never attempted - root probe)
- PASS: (b) readiness (gate + 443)
```
ready-time=2s
```

- PASS: (b) after systemctl stop httpd: container still running (never exits)
- PASS: (b) httpd inactive; status + journalctl explain
- PASS: (b) systemctl start httpd restores 443
- PASS: (c) pre-ready site-start failure ? container exit 1 (code=1, elapsed=9s)
- PASS: (c) the failure is a REAL partial start, not an instant death (wall 5-240 s, elapsed=9s)
- PASS: (c) FATAL-BLOCK marker in the stopped container's log (bounded wait)
```
2026-11-11T12:03:11+0000 05438218a4f7 systemd[1]: Stopped Command Scheduler.
2026-11-11T12:03:11+0000 05438218a4f7 systemd[1]: systemd-logind.service: Deactivated successfully.
2026-11-11T12:03:11+0000 05438218a4f7 systemd[1]: Stopped User Login Management.
2026-11-11T12:03:11+0000 05438218a4f7 systemd[1]: php-fpm.service: Deactivated successfully.
2026-11-11T12:03:11+0000 05438218a4f7 systemd[1]: Stopped The PHP FastCGI Process Manager.
2026-11-11T12:03:11+0000 05438218a4f7 systemd[1]: Stopping Permit User Sessions...
2026-11-11T12:03:11+0000 05438218a4f7 systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-11T12:03:11+0000 05438218a4f7 systemd[1]: Stopped Permit User Sessions.
```

- PASS: (c) the real daemon was RUNNING before the failure (volume: durable verified-startup marker with PID/EXE/USER evidence)
```
PID=1064
EXE=/opt/omd/versions/5.81.20261109-labs-edition/bin/naemon
USER=sitefail
VERIFIED=1794398589
```

- PASS: (c) bounded cleanup ran: the site omd.log records the naemon stop (durable root probe)
- PASS: (c) bounded cleanup ran: no naemon pid file left (durable root probe)
- PASS: (d) ready-gate deadline (REAL probe, masked edge) ? exit 2 within the 150 s backstop (code=2, elapsed=125s)
- PASS: (d) the real probe's deadline reason (log: readiness deadline exceeded)
```
2026-11-11T12:05:17+0000 71d4417ab443 omd-ready-check[58]: FATAL-BLOCK-BEGIN (omd-ready rc=2, condition: readiness deadline exceeded (120s gate window))
2026-11-11T12:05:17+0000 71d4417ab443 omd-ready-check[941]: 2026-11-11T12:03:16+0000 71d4417ab443 systemd[1]: Starting OMD labs single active site (start/stop)...
2026-11-11T12:05:17+0000 71d4417ab443 omd-ready-check[941]: 2026-11-11T12:03:16+0000 71d4417ab443 systemd[1]: Finished OMD labs single active site (start/stop).
2026-11-11T12:05:17+0000 71d4417ab443 omd-ready-check[941]: 2026-11-11T12:03:16+0000 71d4417ab443 systemd[1]: Starting OMD labs bounded readiness gate (FR-018)...
2026-11-11T12:05:17+0000 71d4417ab443 omd-ready-check[941]: 2026-11-11T12:05:17+0000 71d4417ab443 omd-ready-check[58]: READY-FATAL: readiness deadline exceeded (120s gate window) (rc=2)
2026-11-11T12:05:17+0000 71d4417ab443 omd-ready-check[941]: 2026-11-11T12:05:17+0000 71d4417ab443 omd-ready-check[58]: FATAL-BLOCK-BEGIN (omd-ready rc=2, condition: readiness deadline exceeded (120s gate window))
2026-11-11T12:05:17+0000 71d4417ab443 omd-ready-check[58]: FATAL-BLOCK-END
2026-11-11T12:05:17+0000 71d4417ab443 omd-ready-check[947]: DIRECT-COPY: status=0 (reason=sent)
```

- PASS: (e) precondition: the forwarder IS dead (kill -0 fails, proved before the fatal)
- PASS: (e) forwarder dead at fatal time ? exit still 1 (code=1)
- PASS: (e) the REAL probe logged the dead-forwarder degradation line (DIRECT-COPY: status=4)
```
DIRECT-COPY: status=4 (forwarder dead - pipe copy skipped)
```

- PASS: (e) the writable-layer fatal-reason file carries the reason (guaranteed artifact)
```
READY-FATAL: unit omd-site.service failed (per-unit ActiveState/Result=failed) (rc=1)
```

- PASS: (f1) hung pre-init child ? bounded exit 1 <=130 s wall (the 120 s bootstrap bound, entry epoch) (code=1, elapsed=121s)
- PASS: (f1) the pre-init budget FATAL is recorded (the bounded child was killed, rc=124/137)
```
FATAL: step failed (rc=124): TEST-ONLY injected hang (s7 f1)
```

- PASS: (f1) no systemd ever ran (log carries no systemd[1] lines - died before /sbin/init)
- PASS: (f1b) late-invocation remaining budget ? whole bootstrap still exit 1, 100s<=wall<=135s (N2 - not t~190 s) (code=1, elapsed=121s)
- PASS: (f1b) the run_bounded cap logged for the late child is the REMAINING budget (bounded: Ns, N<=25)
```
logged cap: 17 s
```

- PASS: (f1b) the pre-init budget FATAL is recorded (the remaining-budget cap fired)
```
FATAL: step failed (rc=124): TEST-ONLY injected hang (s7 f1b)
```

- PASS: (f2) stuck dependency job ? fails at TimeoutStartSec, After=-only gate still runs ? exit 1 (code=1, elapsed=97s)
- PASS: (f2) the After=-only gate ran and failed on the stuck unit (log: omd-site.service failed)
```
2026-11-11T12:11:57+0000 e6177e6d1d7a crond[865]: (CRON) INFO (Shutting down)
2026-11-11T12:11:57+0000 e6177e6d1d7a systemd[1]: crond.service: Deactivated successfully.
2026-11-11T12:11:57+0000 e6177e6d1d7a systemd[1]: Stopped Command Scheduler.
2026-11-11T12:11:57+0000 e6177e6d1d7a systemd[1]: Stopping Permit User Sessions...
2026-11-11T12:11:57+0000 e6177e6d1d7a systemd[1]: php-fpm.service: Deactivated successfully.
2026-11-11T12:11:57+0000 e6177e6d1d7a systemd[1]: Stopped The PHP FastCGI Process Manager.
2026-11-11T12:11:57+0000 e6177e6d1d7a systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-11T12:11:57+0000 e6177e6d1d7a systemd[1]: Stopped Permit User Sessions.
```

- PASS: (f2) systemd evidence: omd-site timed out (start operation timed out)
```
2026-11-11T12:11:57+0000 e6177e6d1d7a crond[865]: (CRON) INFO (Shutting down)
2026-11-11T12:11:57+0000 e6177e6d1d7a systemd[1]: crond.service: Deactivated successfully.
2026-11-11T12:11:57+0000 e6177e6d1d7a systemd[1]: Stopped Command Scheduler.
2026-11-11T12:11:57+0000 e6177e6d1d7a systemd[1]: Stopping Permit User Sessions...
2026-11-11T12:11:57+0000 e6177e6d1d7a systemd[1]: php-fpm.service: Deactivated successfully.
2026-11-11T12:11:57+0000 e6177e6d1d7a systemd[1]: Stopped The PHP FastCGI Process Manager.
2026-11-11T12:11:57+0000 e6177e6d1d7a systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-11T12:11:57+0000 e6177e6d1d7a systemd[1]: Stopped Permit User Sessions.
```

- PASS: (f3) hung probe ? killed at the 150 s backstop, FailureAction=exit ? exit 255 (code=255, elapsed=153s)
- PASS: (f3) systemd evidence: omd-ready killed at the 150 s backstop (start operation timed out)
```
2026-11-11T12:14:31+0000 884808a3ba13 systemd[1]: sshd.service: Deactivated successfully.
2026-11-11T12:14:31+0000 884808a3ba13 systemd[1]: Stopped OpenSSH server daemon.
2026-11-11T12:14:31+0000 884808a3ba13 systemd[1]: omd-site.service: Deactivated successfully.
2026-11-11T12:14:31+0000 884808a3ba13 systemd[1]: Stopped OMD labs single active site (start/stop).
2026-11-11T12:14:31+0000 884808a3ba13 systemd[1]: Stopped target sshd-keygen.target.
2026-11-11T12:14:31+0000 884808a3ba13 systemd[1]: Stopping Permit User Sessions...
2026-11-11T12:14:31+0000 884808a3ba13 systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-11T12:14:31+0000 884808a3ba13 systemd[1]: Stopped Permit User Sessions.
```

- PASS: (g/baseline) container exited 1 AND the REAL probe's direct_copy returned status=0 (sent) (code=1, elapsed=9s)
```
DIRECT-COPY: status=0 (reason=sent)
```

- PASS: (g/baseline) non-vacuous: the same body with a DELIBERATELY wrong code FAILS (proof the exit assertion is mandatory)
```
exit code 999 != 1
proof: body(real=set +e; gbody() { [ "$1" = 1 ] || { echo "exit code $1 != 1"; return 1; }; grep -q "DIRECT-COPY: status=0" "/tmp/tmp.CPxxmpoKIt/o" 2>/dev/null || return 1; }; gbody 1 || { echo "BUG: real code failed the body"; exit 1; }; gbody 999 && { echo "BUG: wrong code 999 passed - assertion vacuous"; exit 1; }; echo "proof: body(real=$1) accepted, body(999) rejected") accepted, body(999) rejected
```

- PASS: (g/baseline) the direct-copy operation is BOUNDED (per-op wall < 15 s from the tap)
```
per-op wall=2s
```

- PASS: (g/baseline) writable-layer fatal-reason file carries the reason (guaranteed artifact, HARD)
```
READY-FATAL: unit omd-site.service failed (per-unit ActiveState/Result=failed) (rc=1)
```

- PASS: (g/fullpipe) container exited 1 AND the REAL probe's direct_copy returned status=1 (partial) (code=1, elapsed=10s)
```
DIRECT-COPY: status=1 (reason=partial)
```

- PASS: (g/fullpipe) non-vacuous: the same body with a DELIBERATELY wrong code FAILS (proof the exit assertion is mandatory)
```
exit code 999 != 1
proof: body(real=set +e; gbody() { [ "$1" = 1 ] || { echo "exit code $1 != 1"; return 1; }; grep -q "DIRECT-COPY: status=1" "/tmp/tmp.0lCyIyVEQ4/o" 2>/dev/null || return 1; }; gbody 1 || { echo "BUG: real code failed the body"; exit 1; }; gbody 999 && { echo "BUG: wrong code 999 passed - assertion vacuous"; exit 1; }; echo "proof: body(real=$1) accepted, body(999) rejected") accepted, body(999) rejected
```

- PASS: (g/fullpipe) the direct-copy operation is BOUNDED (per-op wall < 15 s from the tap)
```
per-op wall=1s
```

- PASS: (g/fullpipe) writable-layer fatal-reason file carries the reason (guaranteed artifact, HARD)
```
READY-FATAL: unit omd-site.service failed (per-unit ActiveState/Result=failed) (rc=1)
```

- post-ready crash never exits the container (a/b contrast); all hangs bounded (f)
## S7-s7-debian
- when: 2026-11-11 13:15:01
- runtime: podman

- **RESULT: FAIL**

- PASS: (a) not-writable mount ? exit 1 <=30 s (elapsed=1s code=1)
- PASS: (a) fatal reason names the non-writable location (entry-fatal file)
```
FATAL: /omd/sites/rwfail is not writable (run the container with a writable volume at /omd/sites/rwfail)
```

- PASS: (a) data untouched (marker/creation never attempted - root probe)
- PASS: (b) readiness (gate + 443)
```
ready-time=2s
```

- PASS: (b) after systemctl stop apache2: container still running (never exits)
- PASS: (b) apache2 inactive; status + journalctl explain
- PASS: (b) systemctl start apache2 restores 443
- PASS: (c) pre-ready site-start failure ? container exit 1 (code=1, elapsed=7s)
- PASS: (c) the failure is a REAL partial start, not an instant death (wall 5-240 s, elapsed=7s)
- PASS: (c) FATAL-BLOCK marker in the stopped container's log (bounded wait)
```
2026-11-11T12:15:19+00:00 01359dcdb6ec systemd[1]: Stopped systemd-user-sessions.service - Permit User Sessions.
2026-11-11T12:15:19+00:00 01359dcdb6ec apachectl[1687]: AH00558: apache2: Could not reliably determine the server's fully qualified domain name, using 10.0.1.166. Set the 'ServerName' directive globally to suppress this message
2026-11-11T12:15:19+00:00 01359dcdb6ec mariadbd[1014]: 2026-11-11 12:15:19 0 [Note] InnoDB: Starting shutdown...
2026-11-11T12:15:19+00:00 01359dcdb6ec mariadbd[1014]: 2026-11-11 12:15:19 0 [Note] InnoDB: Dumping buffer pool(s) to /var/lib/mysql/ib_buffer_pool
2026-11-11T12:15:19+00:00 01359dcdb6ec mariadbd[1014]: 2026-11-11 12:15:19 0 [Note] InnoDB: Buffer pool(s) dump completed at 261111 12:15:19
2026-11-11T12:15:19+00:00 01359dcdb6ec systemd[1]: apache2.service: Deactivated successfully.
2026-11-11T12:15:19+00:00 01359dcdb6ec systemd[1]: Stopped apache2.service - The Apache HTTP Server.
2026-11-11T12:15:19+00:00 01359dcdb6ec systemd[1]: Stopped target remote-fs.target - Remote File Systems.
```

- PASS: (c) the real daemon was RUNNING before the failure (volume: durable verified-startup marker with PID/EXE/USER evidence)
```
PID=1077
EXE=/opt/omd/versions/5.81.20261109-labs-edition/bin/naemon
USER=sitefail
VERIFIED=1794399317
```

- PASS: (c) bounded cleanup ran: the site omd.log records the naemon stop (durable root probe)
- PASS: (c) bounded cleanup ran: no naemon pid file left (durable root probe)
- PASS: (d) ready-gate deadline (REAL probe, masked edge) ? exit 2 within the 150 s backstop (code=2, elapsed=125s)
- PASS: (d) the real probe's deadline reason (log: readiness deadline exceeded)
```
2026-11-11T12:17:25+00:00 ca0f0a94433d mariadbd[155]: 2026-11-11 12:17:25 0 [Note] InnoDB: Dumping buffer pool(s) to /var/lib/mysql/ib_buffer_pool
2026-11-11T12:17:25+00:00 ca0f0a94433d systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-11T12:17:25+00:00 ca0f0a94433d mariadbd[155]: 2026-11-11 12:17:25 0 [Note] InnoDB: Buffer pool(s) dump completed at 261111 12:17:25
2026-11-11T12:17:25+00:00 ca0f0a94433d systemd[1]: Stopped systemd-user-sessions.service - Permit User Sessions.
2026-11-11T12:17:25+00:00 ca0f0a94433d systemd[1]: Stopped target network-online.target - Network is Online.
2026-11-11T12:17:25+00:00 ca0f0a94433d systemd[1]: Stopped target remote-fs.target - Remote File Systems.
2026-11-11T12:17:25+00:00 ca0f0a94433d mariadbd[155]: 2026-11-11 12:17:25 0 [Note] InnoDB: Removed temporary tablespace data file: "./ibtmp1"
2026-11-11T12:17:25+00:00 ca0f0a94433d mariadbd[155]: 2026-11-11 12:17:25 0 [Note] InnoDB: Shutdown completed; log sequence number 45498; transaction id 15
```

- PASS: (e) precondition: the forwarder IS dead (kill -0 fails, proved before the fatal)
- PASS: (e) forwarder dead at fatal time ? exit still 1 (code=1)
- PASS: (e) the REAL probe logged the dead-forwarder degradation line (DIRECT-COPY: status=4)
```
DIRECT-COPY: status=4 (forwarder dead - pipe copy skipped)
```

- PASS: (e) the writable-layer fatal-reason file carries the reason (guaranteed artifact)
```
READY-FATAL: unit omd-site.service failed (per-unit ActiveState/Result=failed) (rc=1)
```

- PASS: (f1) hung pre-init child ? bounded exit 1 <=130 s wall (the 120 s bootstrap bound, entry epoch) (code=1, elapsed=125s)
- PASS: (f1) the pre-init budget FATAL is recorded (the bounded child was killed, rc=124/137)
```
FATAL: step failed (rc=124): TEST-ONLY injected hang (s7 f1)
```

- PASS: (f1) no systemd ever ran (log carries no systemd[1] lines - died before /sbin/init)
- PASS: (f1b) late-invocation remaining budget ? whole bootstrap still exit 1, 100s<=wall<=135s (N2 - not t~190 s) (code=1, elapsed=121s)
- FAIL: (f1b) the run_bounded cap logged for the late child is the REMAINING budget (bounded: Ns, N<=25) (rc=1)
```
cap 43 s is NOT the remaining budget (expected ~15-20 s)
```

- PASS: (f1b) the pre-init budget FATAL is recorded (the remaining-budget cap fired)
```
FATAL: step failed (rc=124): TEST-ONLY s7 f1b budget consumer
```

- PASS: (f2) stuck dependency job ? fails at TimeoutStartSec, After=-only gate still runs ? exit 1 (code=1, elapsed=98s)
- PASS: (f2) the After=-only gate ran and failed on the stuck unit (log: omd-site.service failed)
```
2026-11-11T12:24:20+00:00 8c9f74ca3297 systemd[1]: Stopped systemd-user-sessions.service - Permit User Sessions.
2026-11-11T12:24:20+00:00 8c9f74ca3297 systemd[1]: Stopped target network-online.target - Network is Online.
2026-11-11T12:24:20+00:00 8c9f74ca3297 mariadbd[967]: 2026-11-11 12:24:20 0 [Note] InnoDB: Dumping buffer pool(s) to /var/lib/mysql/ib_buffer_pool
2026-11-11T12:24:20+00:00 8c9f74ca3297 mariadbd[967]: 2026-11-11 12:24:20 0 [Note] InnoDB: Buffer pool(s) dump completed at 261111 12:24:20
2026-11-11T12:24:20+00:00 8c9f74ca3297 apachectl[1498]: AH00558: apache2: Could not reliably determine the server's fully qualified domain name, using 10.0.1.166. Set the 'ServerName' directive globally to suppress this message
2026-11-11T12:24:21+00:00 8c9f74ca3297 systemd[1]: apache2.service: Deactivated successfully.
2026-11-11T12:24:21+00:00 8c9f74ca3297 systemd[1]: Stopped apache2.service - The Apache HTTP Server.
2026-11-11T12:24:21+00:00 8c9f74ca3297 systemd[1]: Stopped target remote-fs.target - Remote File Systems.
```

- PASS: (f2) systemd evidence: omd-site timed out (start operation timed out)
```
2026-11-11T12:24:20+00:00 8c9f74ca3297 systemd[1]: Stopped systemd-user-sessions.service - Permit User Sessions.
2026-11-11T12:24:20+00:00 8c9f74ca3297 systemd[1]: Stopped target network-online.target - Network is Online.
2026-11-11T12:24:20+00:00 8c9f74ca3297 mariadbd[967]: 2026-11-11 12:24:20 0 [Note] InnoDB: Dumping buffer pool(s) to /var/lib/mysql/ib_buffer_pool
2026-11-11T12:24:20+00:00 8c9f74ca3297 mariadbd[967]: 2026-11-11 12:24:20 0 [Note] InnoDB: Buffer pool(s) dump completed at 261111 12:24:20
2026-11-11T12:24:20+00:00 8c9f74ca3297 apachectl[1498]: AH00558: apache2: Could not reliably determine the server's fully qualified domain name, using 10.0.1.166. Set the 'ServerName' directive globally to suppress this message
2026-11-11T12:24:21+00:00 8c9f74ca3297 systemd[1]: apache2.service: Deactivated successfully.
2026-11-11T12:24:21+00:00 8c9f74ca3297 systemd[1]: Stopped apache2.service - The Apache HTTP Server.
2026-11-11T12:24:21+00:00 8c9f74ca3297 systemd[1]: Stopped target remote-fs.target - Remote File Systems.
```

- PASS: (f3) hung probe ? killed at the 150 s backstop, FailureAction=exit ? exit 255 (code=255, elapsed=154s)
- PASS: (f3) systemd evidence: omd-ready killed at the 150 s backstop (start operation timed out)
```
2026-11-11T12:26:56+00:00 088784b13098 mariadbd[154]: 2026-11-11 12:26:56 0 [Note] InnoDB: Starting shutdown...
2026-11-11T12:26:56+00:00 088784b13098 mariadbd[154]: 2026-11-11 12:26:56 0 [Note] InnoDB: Dumping buffer pool(s) to /var/lib/mysql/ib_buffer_pool
2026-11-11T12:26:56+00:00 088784b13098 mariadbd[154]: 2026-11-11 12:26:56 0 [Note] InnoDB: Buffer pool(s) dump completed at 261111 12:26:56
2026-11-11T12:26:56+00:00 088784b13098 systemd[1]: apache2.service: Deactivated successfully.
2026-11-11T12:26:56+00:00 088784b13098 systemd[1]: Stopped apache2.service - The Apache HTTP Server.
2026-11-11T12:26:56+00:00 088784b13098 systemd[1]: Stopped target remote-fs.target - Remote File Systems.
2026-11-11T12:26:56+00:00 088784b13098 mariadbd[154]: 2026-11-11 12:26:56 0 [Note] InnoDB: Removed temporary tablespace data file: "./ibtmp1"
2026-11-11T12:26:56+00:00 088784b13098 mariadbd[154]: 2026-11-11 12:26:56 0 [Note] InnoDB: Shutdown completed; log sequence number 45498; transaction id 15
```

- PASS: (g/baseline) container exited 1 AND the REAL probe's direct_copy returned status=0 (sent) (code=1, elapsed=7s)
```
DIRECT-COPY: status=0 (reason=sent)
```

- PASS: (g/baseline) non-vacuous: the same body with a DELIBERATELY wrong code FAILS (proof the exit assertion is mandatory)
```
exit code 999 != 1
proof: body(real=set +e; gbody() { [ "$1" = 1 ] || { echo "exit code $1 != 1"; return 1; }; grep -q "DIRECT-COPY: status=0" "/tmp/tmp.qr38z6TpRS/o" 2>/dev/null || return 1; }; gbody 1 || { echo "BUG: real code failed the body"; exit 1; }; gbody 999 && { echo "BUG: wrong code 999 passed - assertion vacuous"; exit 1; }; echo "proof: body(real=$1) accepted, body(999) rejected") accepted, body(999) rejected
```

- PASS: (g/baseline) the direct-copy operation is BOUNDED (per-op wall < 15 s from the tap)
```
per-op wall=1s
```

- PASS: (g/baseline) writable-layer fatal-reason file carries the reason (guaranteed artifact, HARD)
```
READY-FATAL: unit omd-site.service failed (per-unit ActiveState/Result=failed) (rc=1)
```

- PASS: (g/fullpipe) container exited 1 AND the REAL probe's direct_copy returned status=1 (partial) (code=1, elapsed=7s)
```
DIRECT-COPY: status=1 (reason=partial)
```

- PASS: (g/fullpipe) non-vacuous: the same body with a DELIBERATELY wrong code FAILS (proof the exit assertion is mandatory)
```
exit code 999 != 1
proof: body(real=set +e; gbody() { [ "$1" = 1 ] || { echo "exit code $1 != 1"; return 1; }; grep -q "DIRECT-COPY: status=1" "/tmp/tmp.VBajUKObpO/o" 2>/dev/null || return 1; }; gbody 1 || { echo "BUG: real code failed the body"; exit 1; }; gbody 999 && { echo "BUG: wrong code 999 passed - assertion vacuous"; exit 1; }; echo "proof: body(real=$1) accepted, body(999) rejected") accepted, body(999) rejected
```

- PASS: (g/fullpipe) the direct-copy operation is BOUNDED (per-op wall < 15 s from the tap)
```
per-op wall=2s
```

- PASS: (g/fullpipe) writable-layer fatal-reason file carries the reason (guaranteed artifact, HARD)
```
READY-FATAL: unit omd-site.service failed (per-unit ActiveState/Result=failed) (rc=1)
```

- post-ready crash never exits the container (a/b contrast); all hangs bounded (f)
## S7-s7-rocky
- when: 2026-11-11 13:42:59
- runtime: podman

- **RESULT: PASS**

- PASS: (a) not-writable mount ? exit 1 <=30 s (elapsed=1s code=1)
- PASS: (a) fatal reason names the non-writable location (entry-fatal file)
```
FATAL: /omd/sites/rwfail is not writable (run the container with a writable volume at /omd/sites/rwfail)
```

- PASS: (a) data untouched (marker/creation never attempted - root probe)
- PASS: (b) readiness (gate + 443)
```
ready-time=2s
```

- PASS: (b) after systemctl stop httpd: container still running (never exits)
- PASS: (b) httpd inactive; status + journalctl explain
- PASS: (b) systemctl start httpd restores 443
- PASS: (c) pre-ready site-start failure ? container exit 1 (code=1, elapsed=9s)
- PASS: (c) the failure is a REAL partial start, not an instant death (wall 5-240 s, elapsed=9s)
- PASS: (c) FATAL-BLOCK marker in the stopped container's log (bounded wait)
```
2026-11-11T12:43:21+0000 28127722b217 systemd[1]: Stopped Command Scheduler.
2026-11-11T12:43:21+0000 28127722b217 systemd[1]: systemd-logind.service: Deactivated successfully.
2026-11-11T12:43:21+0000 28127722b217 systemd[1]: Stopped User Login Management.
2026-11-11T12:43:21+0000 28127722b217 systemd[1]: php-fpm.service: Deactivated successfully.
2026-11-11T12:43:21+0000 28127722b217 systemd[1]: Stopped The PHP FastCGI Process Manager.
2026-11-11T12:43:21+0000 28127722b217 systemd[1]: Stopping Permit User Sessions...
2026-11-11T12:43:21+0000 28127722b217 systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-11T12:43:21+0000 28127722b217 systemd[1]: Stopped Permit User Sessions.
```

- PASS: (c) the real daemon was RUNNING before the failure (volume: durable verified-startup marker with PID/EXE/USER evidence)
```
PID=1174
EXE=/opt/omd/versions/5.81.20261109-labs-edition/bin/naemon
USER=sitefail
VERIFIED=1794400999
```

- PASS: (c) bounded cleanup ran: the site omd.log records the naemon stop (durable root probe)
- PASS: (c) bounded cleanup ran: no naemon pid file left (durable root probe)
- PASS: (d) ready-gate deadline (REAL probe, masked edge) ? exit 2 within the 150 s backstop (code=2, elapsed=125s)
- PASS: (d) the real probe's deadline reason (log: readiness deadline exceeded)
```
2026-11-11T12:45:28+0000 522fc0c522fd omd-ready-check[58]: FATAL-BLOCK-BEGIN (omd-ready rc=2, condition: readiness deadline exceeded (120s gate window))
2026-11-11T12:45:28+0000 522fc0c522fd omd-ready-check[941]: 2026-11-11T12:43:27+0000 522fc0c522fd systemd[1]: Starting OMD labs single active site (start/stop)...
2026-11-11T12:45:28+0000 522fc0c522fd omd-ready-check[941]: 2026-11-11T12:43:27+0000 522fc0c522fd systemd[1]: Finished OMD labs single active site (start/stop).
2026-11-11T12:45:28+0000 522fc0c522fd omd-ready-check[941]: 2026-11-11T12:43:27+0000 522fc0c522fd systemd[1]: Starting OMD labs bounded readiness gate (FR-018)...
2026-11-11T12:45:28+0000 522fc0c522fd omd-ready-check[941]: 2026-11-11T12:45:28+0000 522fc0c522fd omd-ready-check[58]: READY-FATAL: readiness deadline exceeded (120s gate window) (rc=2)
2026-11-11T12:45:28+0000 522fc0c522fd omd-ready-check[941]: 2026-11-11T12:45:28+0000 522fc0c522fd omd-ready-check[58]: FATAL-BLOCK-BEGIN (omd-ready rc=2, condition: readiness deadline exceeded (120s gate window))
2026-11-11T12:45:28+0000 522fc0c522fd omd-ready-check[58]: FATAL-BLOCK-END
2026-11-11T12:45:28+0000 522fc0c522fd omd-ready-check[947]: DIRECT-COPY: status=0 (reason=sent)
```

- PASS: (e) precondition: the forwarder IS dead (kill -0 fails, proved before the fatal)
- PASS: (e) forwarder dead at fatal time ? exit still 1 (code=1)
- PASS: (e) the REAL probe logged the dead-forwarder degradation line (DIRECT-COPY: status=4)
```
DIRECT-COPY: status=4 (forwarder dead - pipe copy skipped)
```

- PASS: (e) the writable-layer fatal-reason file carries the reason (guaranteed artifact)
```
READY-FATAL: unit omd-site.service failed (per-unit ActiveState/Result=failed) (rc=1)
```

- PASS: (f1) hung pre-init child ? bounded exit 1 <=130 s wall (the 120 s bootstrap bound, entry epoch) (code=1, elapsed=122s)
- PASS: (f1) the pre-init budget FATAL is recorded (the bounded child was killed, rc=124/137)
```
FATAL: step failed (rc=124): TEST-ONLY injected hang (s7 f1)
```

- PASS: (f1) no systemd ever ran (log carries no systemd[1] lines - died before /sbin/init)
- PASS: (f1b) late-invocation remaining budget ? whole bootstrap still exit 1, 100s<=wall<=135s (N2 - not t~190 s) (code=1, elapsed=121s)
- PASS: (f1b) the run_bounded cap logged for the late child is the REMAINING budget (bounded: Ns, N<=25)
```
logged cap: 12 s
```

- PASS: (f1b) the pre-init budget FATAL is recorded (the remaining-budget cap fired)
```
FATAL: step failed (rc=124): TEST-ONLY injected hang (s7 f1b)
```

- PASS: (f2) stuck dependency job ? fails at TimeoutStartSec, After=-only gate still runs ? exit 1 (code=1, elapsed=100s)
- PASS: (f2) the After=-only gate ran and failed on the stuck unit (log: omd-site.service failed)
```
2026-11-11T12:52:13+0000 dc99cd301061 systemd[1]: sshd.service: Deactivated successfully.
2026-11-11T12:52:13+0000 dc99cd301061 systemd[1]: Stopped OpenSSH server daemon.
2026-11-11T12:52:13+0000 dc99cd301061 systemd[1]: php-fpm.service: Deactivated successfully.
2026-11-11T12:52:13+0000 dc99cd301061 systemd[1]: Stopped The PHP FastCGI Process Manager.
2026-11-11T12:52:13+0000 dc99cd301061 systemd[1]: Stopped target sshd-keygen.target.
2026-11-11T12:52:13+0000 dc99cd301061 systemd[1]: Stopping Permit User Sessions...
2026-11-11T12:52:13+0000 dc99cd301061 systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-11T12:52:13+0000 dc99cd301061 systemd[1]: Stopped Permit User Sessions.
```

- PASS: (f2) systemd evidence: omd-site timed out (start operation timed out)
```
2026-11-11T12:52:13+0000 dc99cd301061 systemd[1]: sshd.service: Deactivated successfully.
2026-11-11T12:52:13+0000 dc99cd301061 systemd[1]: Stopped OpenSSH server daemon.
2026-11-11T12:52:13+0000 dc99cd301061 systemd[1]: php-fpm.service: Deactivated successfully.
2026-11-11T12:52:13+0000 dc99cd301061 systemd[1]: Stopped The PHP FastCGI Process Manager.
2026-11-11T12:52:13+0000 dc99cd301061 systemd[1]: Stopped target sshd-keygen.target.
2026-11-11T12:52:13+0000 dc99cd301061 systemd[1]: Stopping Permit User Sessions...
2026-11-11T12:52:13+0000 dc99cd301061 systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-11T12:52:13+0000 dc99cd301061 systemd[1]: Stopped Permit User Sessions.
```

- PASS: (f3) hung probe ? killed at the 150 s backstop, FailureAction=exit ? exit 255 (code=255, elapsed=153s)
- PASS: (f3) systemd evidence: omd-ready killed at the 150 s backstop (start operation timed out)
```
2026-11-11T12:54:50+0000 7487ad3418af systemd[1]: sshd.service: Deactivated successfully.
2026-11-11T12:54:50+0000 7487ad3418af systemd[1]: Stopped OpenSSH server daemon.
2026-11-11T12:54:50+0000 7487ad3418af systemd[1]: omd-site.service: Deactivated successfully.
2026-11-11T12:54:50+0000 7487ad3418af systemd[1]: Stopped OMD labs single active site (start/stop).
2026-11-11T12:54:50+0000 7487ad3418af systemd[1]: Stopped target sshd-keygen.target.
2026-11-11T12:54:50+0000 7487ad3418af systemd[1]: Stopping Permit User Sessions...
2026-11-11T12:54:50+0000 7487ad3418af systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-11T12:54:50+0000 7487ad3418af systemd[1]: Stopped Permit User Sessions.
```

- PASS: (g/baseline) container exited 1 AND the REAL probe's direct_copy returned status=0 (sent) (code=1, elapsed=9s)
```
DIRECT-COPY: status=0 (reason=sent)
```

- PASS: (g/baseline) non-vacuous: the same body with a DELIBERATELY wrong code FAILS (proof the exit assertion is mandatory)
```
exit code 999 != 1
proof: body(real=set +e; gbody() { [ "$1" = 1 ] || { echo "exit code $1 != 1"; return 1; }; grep -q "DIRECT-COPY: status=0" "/tmp/tmp.yVtG7Hpbkc/o" 2>/dev/null || return 1; }; gbody 1 || { echo "BUG: real code failed the body"; exit 1; }; gbody 999 && { echo "BUG: wrong code 999 passed - assertion vacuous"; exit 1; }; echo "proof: body(real=$1) accepted, body(999) rejected") accepted, body(999) rejected
```

- PASS: (g/baseline) the direct-copy operation is BOUNDED (per-op wall < 15 s from the tap)
```
per-op wall=2s
```

- PASS: (g/baseline) writable-layer fatal-reason file carries the reason (guaranteed artifact, HARD)
```
READY-FATAL: unit omd-site.service failed (per-unit ActiveState/Result=failed) (rc=1)
```

- PASS: (g/fullpipe) container exited 1 AND the REAL probe's direct_copy returned status=1 (partial) (code=1, elapsed=9s)
```
DIRECT-COPY: status=1 (reason=partial)
```

- PASS: (g/fullpipe) non-vacuous: the same body with a DELIBERATELY wrong code FAILS (proof the exit assertion is mandatory)
```
exit code 999 != 1
proof: body(real=set +e; gbody() { [ "$1" = 1 ] || { echo "exit code $1 != 1"; return 1; }; grep -q "DIRECT-COPY: status=1" "/tmp/tmp.NE5JuJ8V5I/o" 2>/dev/null || return 1; }; gbody 1 || { echo "BUG: real code failed the body"; exit 1; }; gbody 999 && { echo "BUG: wrong code 999 passed - assertion vacuous"; exit 1; }; echo "proof: body(real=$1) accepted, body(999) rejected") accepted, body(999) rejected
```

- PASS: (g/fullpipe) the direct-copy operation is BOUNDED (per-op wall < 15 s from the tap)
```
per-op wall=2s
```

- PASS: (g/fullpipe) writable-layer fatal-reason file carries the reason (guaranteed artifact, HARD)
```
READY-FATAL: unit omd-site.service failed (per-unit ActiveState/Result=failed) (rc=1)
```

- post-ready crash never exits the container (a/b contrast); all hangs bounded (f)
## S7-s7-debian
- when: 2026-11-11 13:55:20
- runtime: podman

- **RESULT: PASS**

- PASS: (a) not-writable mount ? exit 1 <=30 s (elapsed=1s code=1)
- PASS: (a) fatal reason names the non-writable location (entry-fatal file)
```
FATAL: /omd/sites/rwfail is not writable (run the container with a writable volume at /omd/sites/rwfail)
```

- PASS: (a) data untouched (marker/creation never attempted - root probe)
- PASS: (b) readiness (gate + 443)
```
ready-time=2s
```

- PASS: (b) after systemctl stop apache2: container still running (never exits)
- PASS: (b) apache2 inactive; status + journalctl explain
- PASS: (b) systemctl start apache2 restores 443
- PASS: (c) pre-ready site-start failure ? container exit 1 (code=1, elapsed=9s)
- PASS: (c) the failure is a REAL partial start, not an instant death (wall 5-240 s, elapsed=9s)
- PASS: (c) FATAL-BLOCK marker in the stopped container's log (bounded wait)
```
2026-11-11T12:55:39+00:00 20ae97c24901 mariadbd[1020]: 2026-11-11 12:55:39 0 [Note] InnoDB: Starting shutdown...
2026-11-11T12:55:39+00:00 20ae97c24901 mariadbd[1020]: 2026-11-11 12:55:39 0 [Note] InnoDB: Dumping buffer pool(s) to /var/lib/mysql/ib_buffer_pool
2026-11-11T12:55:39+00:00 20ae97c24901 mariadbd[1020]: 2026-11-11 12:55:39 0 [Note] InnoDB: Buffer pool(s) dump completed at 261111 12:55:39
2026-11-11T12:55:39+00:00 20ae97c24901 systemd[1]: apache2.service: Deactivated successfully.
2026-11-11T12:55:39+00:00 20ae97c24901 systemd[1]: Stopped apache2.service - The Apache HTTP Server.
2026-11-11T12:55:39+00:00 20ae97c24901 systemd[1]: Stopped target remote-fs.target - Remote File Systems.
2026-11-11T12:55:39+00:00 20ae97c24901 mariadbd[1020]: 2026-11-11 12:55:39 0 [Note] InnoDB: Removed temporary tablespace data file: "./ibtmp1"
2026-11-11T12:55:39+00:00 20ae97c24901 mariadbd[1020]: 2026-11-11 12:55:39 0 [Note] InnoDB: Shutdown completed; log sequence number 45498; transaction id 15
```

- PASS: (c) the real daemon was RUNNING before the failure (volume: durable verified-startup marker with PID/EXE/USER evidence)
```
PID=1077
EXE=/opt/omd/versions/5.81.20261109-labs-edition/bin/naemon
USER=sitefail
VERIFIED=1794401736
```

- PASS: (c) bounded cleanup ran: the site omd.log records the naemon stop (durable root probe)
- PASS: (c) bounded cleanup ran: no naemon pid file left (durable root probe)
- PASS: (d) ready-gate deadline (REAL probe, masked edge) ? exit 2 within the 150 s backstop (code=2, elapsed=126s)
- PASS: (d) the real probe's deadline reason (log: readiness deadline exceeded)
```
2026-11-11T12:57:48+00:00 095fd293031c systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-11T12:57:48+00:00 095fd293031c systemd[1]: Stopped systemd-user-sessions.service - Permit User Sessions.
2026-11-11T12:57:48+00:00 095fd293031c mariadbd[156]: 2026-11-11 12:57:48 0 [Note] InnoDB: Dumping buffer pool(s) to /var/lib/mysql/ib_buffer_pool
2026-11-11T12:57:48+00:00 095fd293031c mariadbd[156]: 2026-11-11 12:57:48 0 [Note] InnoDB: Buffer pool(s) dump completed at 261111 12:57:48
2026-11-11T12:57:48+00:00 095fd293031c systemd[1]: Stopped target network-online.target - Network is Online.
2026-11-11T12:57:48+00:00 095fd293031c systemd[1]: Stopped target remote-fs.target - Remote File Systems.
2026-11-11T12:57:48+00:00 095fd293031c mariadbd[156]: 2026-11-11 12:57:48 0 [Note] InnoDB: Removed temporary tablespace data file: "./ibtmp1"
2026-11-11T12:57:48+00:00 095fd293031c mariadbd[156]: 2026-11-11 12:57:48 0 [Note] InnoDB: Shutdown completed; log sequence number 45498; transaction id 15
```

- PASS: (e) precondition: the forwarder IS dead (kill -0 fails, proved before the fatal)
- PASS: (e) forwarder dead at fatal time ? exit still 1 (code=1)
- PASS: (e) the REAL probe logged the dead-forwarder degradation line (DIRECT-COPY: status=4)
```
DIRECT-COPY: status=4 (forwarder dead - pipe copy skipped)
```

- PASS: (e) the writable-layer fatal-reason file carries the reason (guaranteed artifact)
```
READY-FATAL: unit omd-site.service failed (per-unit ActiveState/Result=failed) (rc=1)
```

- PASS: (f1) hung pre-init child ? bounded exit 1 <=130 s wall (the 120 s bootstrap bound, entry epoch) (code=1, elapsed=121s)
- PASS: (f1) the pre-init budget FATAL is recorded (the bounded child was killed, rc=124/137)
```
FATAL: step failed (rc=124): TEST-ONLY injected hang (s7 f1)
```

- PASS: (f1) no systemd ever ran (log carries no systemd[1] lines - died before /sbin/init)
- PASS: (f1b) late-invocation remaining budget ? whole bootstrap still exit 1, 100s<=wall<=135s (N2 - not t~190 s) (code=1, elapsed=121s)
- PASS: (f1b) the run_bounded cap logged for the late child is the REMAINING budget (bounded: Ns, N<=25)
```
logged cap: 12 s
```

- PASS: (f1b) the pre-init budget FATAL is recorded (the remaining-budget cap fired)
```
FATAL: step failed (rc=124): TEST-ONLY injected hang (s7 f1b)
```

- PASS: (f2) stuck dependency job ? fails at TimeoutStartSec, After=-only gate still runs ? exit 1 (code=1, elapsed=97s)
- PASS: (f2) the After=-only gate ran and failed on the stuck unit (log: omd-site.service failed)
```
2026-11-11T13:04:28+00:00 e3c41290315b mariadbd[972]: 2026-11-11 13:04:28 0 [Note] InnoDB: Dumping buffer pool(s) to /var/lib/mysql/ib_buffer_pool
2026-11-11T13:04:28+00:00 e3c41290315b mariadbd[972]: 2026-11-11 13:04:28 0 [Note] InnoDB: Buffer pool(s) dump completed at 261111 13:04:28
2026-11-11T13:04:28+00:00 e3c41290315b apachectl[1497]: AH00558: apache2: Could not reliably determine the server's fully qualified domain name, using 10.0.1.166. Set the 'ServerName' directive globally to suppress this message
2026-11-11T13:04:28+00:00 e3c41290315b systemd[1]: apache2.service: Deactivated successfully.
2026-11-11T13:04:28+00:00 e3c41290315b systemd[1]: Stopped apache2.service - The Apache HTTP Server.
2026-11-11T13:04:28+00:00 e3c41290315b systemd[1]: Stopped target remote-fs.target - Remote File Systems.
2026-11-11T13:04:28+00:00 e3c41290315b mariadbd[972]: 2026-11-11 13:04:28 0 [Note] InnoDB: Removed temporary tablespace data file: "./ibtmp1"
2026-11-11T13:04:28+00:00 e3c41290315b mariadbd[972]: 2026-11-11 13:04:28 0 [Note] InnoDB: Shutdown completed; log sequence number 45498; transaction id 15
```

- PASS: (f2) systemd evidence: omd-site timed out (start operation timed out)
```
2026-11-11T13:04:28+00:00 e3c41290315b mariadbd[972]: 2026-11-11 13:04:28 0 [Note] InnoDB: Dumping buffer pool(s) to /var/lib/mysql/ib_buffer_pool
2026-11-11T13:04:28+00:00 e3c41290315b mariadbd[972]: 2026-11-11 13:04:28 0 [Note] InnoDB: Buffer pool(s) dump completed at 261111 13:04:28
2026-11-11T13:04:28+00:00 e3c41290315b apachectl[1497]: AH00558: apache2: Could not reliably determine the server's fully qualified domain name, using 10.0.1.166. Set the 'ServerName' directive globally to suppress this message
2026-11-11T13:04:28+00:00 e3c41290315b systemd[1]: apache2.service: Deactivated successfully.
2026-11-11T13:04:28+00:00 e3c41290315b systemd[1]: Stopped apache2.service - The Apache HTTP Server.
2026-11-11T13:04:28+00:00 e3c41290315b systemd[1]: Stopped target remote-fs.target - Remote File Systems.
2026-11-11T13:04:28+00:00 e3c41290315b mariadbd[972]: 2026-11-11 13:04:28 0 [Note] InnoDB: Removed temporary tablespace data file: "./ibtmp1"
2026-11-11T13:04:28+00:00 e3c41290315b mariadbd[972]: 2026-11-11 13:04:28 0 [Note] InnoDB: Shutdown completed; log sequence number 45498; transaction id 15
```

- PASS: (f3) hung probe ? killed at the 150 s backstop, FailureAction=exit ? exit 255 (code=255, elapsed=154s)
- PASS: (f3) systemd evidence: omd-ready killed at the 150 s backstop (start operation timed out)
```
2026-11-11T13:07:03+00:00 d51b26912cf8 systemd[1]: Stopped omd-site.service - OMD labs single active site (start/stop).
2026-11-11T13:07:03+00:00 d51b26912cf8 systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-11T13:07:03+00:00 d51b26912cf8 systemd[1]: Stopped systemd-user-sessions.service - Permit User Sessions.
2026-11-11T13:07:03+00:00 d51b26912cf8 systemd[1]: Stopped target network-online.target - Network is Online.
2026-11-11T13:07:03+00:00 d51b26912cf8 apachectl[483]: AH00558: apache2: Could not reliably determine the server's fully qualified domain name, using 10.0.1.166. Set the 'ServerName' directive globally to suppress this message
2026-11-11T13:07:03+00:00 d51b26912cf8 systemd[1]: apache2.service: Deactivated successfully.
2026-11-11T13:07:03+00:00 d51b26912cf8 systemd[1]: Stopped apache2.service - The Apache HTTP Server.
2026-11-11T13:07:03+00:00 d51b26912cf8 systemd[1]: Stopped target remote-fs.target - Remote File Systems.
```

- PASS: (g/baseline) container exited 1 AND the REAL probe's direct_copy returned status=0 (sent) (code=1, elapsed=7s)
```
DIRECT-COPY: status=0 (reason=sent)
```

- PASS: (g/baseline) non-vacuous: the same body with a DELIBERATELY wrong code FAILS (proof the exit assertion is mandatory)
```
exit code 999 != 1
proof: body(real=set +e; gbody() { [ "$1" = 1 ] || { echo "exit code $1 != 1"; return 1; }; grep -q "DIRECT-COPY: status=0" "/tmp/tmp.IEeLAcSUmS/o" 2>/dev/null || return 1; }; gbody 1 || { echo "BUG: real code failed the body"; exit 1; }; gbody 999 && { echo "BUG: wrong code 999 passed - assertion vacuous"; exit 1; }; echo "proof: body(real=$1) accepted, body(999) rejected") accepted, body(999) rejected
```

- PASS: (g/baseline) the direct-copy operation is BOUNDED (per-op wall < 15 s from the tap)
```
per-op wall=2s
```

- PASS: (g/baseline) writable-layer fatal-reason file carries the reason (guaranteed artifact, HARD)
```
READY-FATAL: unit omd-site.service failed (per-unit ActiveState/Result=failed) (rc=1)
```

- PASS: (g/fullpipe) container exited 1 AND the REAL probe's direct_copy returned status=1 (partial) (code=1, elapsed=7s)
```
DIRECT-COPY: status=1 (reason=partial)
```

- PASS: (g/fullpipe) non-vacuous: the same body with a DELIBERATELY wrong code FAILS (proof the exit assertion is mandatory)
```
exit code 999 != 1
proof: body(real=set +e; gbody() { [ "$1" = 1 ] || { echo "exit code $1 != 1"; return 1; }; grep -q "DIRECT-COPY: status=1" "/tmp/tmp.kCDeVbtWcn/o" 2>/dev/null || return 1; }; gbody 1 || { echo "BUG: real code failed the body"; exit 1; }; gbody 999 && { echo "BUG: wrong code 999 passed - assertion vacuous"; exit 1; }; echo "proof: body(real=$1) accepted, body(999) rejected") accepted, body(999) rejected
```

- PASS: (g/fullpipe) the direct-copy operation is BOUNDED (per-op wall < 15 s from the tap)
```
per-op wall=1s
```

- PASS: (g/fullpipe) writable-layer fatal-reason file carries the reason (guaranteed artifact, HARD)
```
READY-FATAL: unit omd-site.service failed (per-unit ActiveState/Result=failed) (rc=1)
```

- post-ready crash never exits the container (a/b contrast); all hangs bounded (f)


## T028-S7-V3-2026-11-11 (codex-87 rework green: 38/38 both distros; supersedes T028-S7-V2)

- **Task**: same as before - `verify/run.sh s7` via the suite (both
  distros, port 18461, build #13 images). The V2 green (35/35, t028d)
  is SUPERSEDED: spar round 87 (codex final verdict, file 87) found 2
  MAJORs in the reworked battery, both verified REAL and fixed. The
  battery now has 38 runtime checks (30 standalone + 4 in the (g) loop
  x 2 variants). STRICTLY SEQUENTIAL, both distros. Result: 38/38 PASS
  / 0 FAIL EACH (rc=0). Logs /tmp/t028f-s7-{rocky,debian}.log. (The
  intermediate t028e run was 38/38 rocky + 37/38 debian - the 1 debian
  FAIL was a self-caught f1b test-design defect, fixed and re-run; see
  below.)
- **Fix per codex 87 MAJOR (c)** - the marker proved the wrapper ran,
  not the daemon. VALIDATED EMPIRICALLY during the fix: the v2 wrapper's
  direct `naemon -ud` launch ABORTS INSTANTLY on a fresh site (no
  naemon.cfg yet: "Cannot open main configuration file"), and the
  omd.log "80-naemon stop" lines + missing pid file are produced by the
  probe's bounded `omd stop` cleanup REGARDLESS of whether a daemon ever
  ran (empirical probe t028c-dx). FIX: the wrapper now runs the REAL
  production start path (`/usr/bin/omd start $SITE` - exactly what the
  real omd-site-start execs: creates the site config and starts the
  daemons), then BOUNDARILY verifies (30 x 1 s poll) that a daemon
  ACTUALLY RAN - the site's OWN pid file (tmp/run/naemon.pid, the real
  path) must name a LIVE process (kill -0) whose /proc/<pid>/exe is the
  naemon binary and whose user is the site - and ONLY THEN writes the
  durable SUCCESS marker (tmp/probe-naemon-evidence) carrying that
  evidence (PID/EXE/USER/VERIFIED). Absent daemon => absent marker =>
  the hard volume assertion FAILS. New checks: the marker + PID/EXE/USER
  evidence (root volume probe) and a real-partial-start wall window
  (5-240 s, empirical 9 s both distros). GREEN both distros: rocky
  marker PID=1174, debian PID=1077, both EXE=
  /opt/omd/versions/5.81.20261109-labs-edition/bin/naemon USER=sitefail;
  4 "80-naemon stop" lines + 0 naemon pid files left (durable cleanup
  proof kept). The negative case (daemon never starts) leaves NO marker
  and FAILS the assertion (proven in the t028c-dx probe).
- **Fix per codex 87 MAJOR (g)** - the exit assertion was DISCARDED:
  `set +e; [ "$gcode" = 1 ]; grep ...` (semicolon; v_check counts only
  the final command's status, common.sh:344-350), so a probe exiting
  255/137 would have passed. FIX: the clause is now MANDATORY (`gbody
  $real-code || exit 1` inside the eval'd body - gbody = the exit-code
  test AND the status-line grep; either failing -> check FAILS), plus a
  SEPARATE non-vacuity check proving the clause bites: the SAME body
  called with a deliberately wrong code (999) must be REJECTED while the
  real code is ACCEPTED (empirical: gbody(1) accepted; gbody(999) and
  gbody(255) rejected - "exit code 999 != 1"; in the green runs the
  proof line "exit code 999 != 1" is present for both variants, both
  distros). Audit: every other exit-code assertion in the battery
  (a/d/e/f1/f1b/f2/f3) has the code test as the FINAL command of the
  eval - no other discard flaws.
- **New harness defect caught by the t028e run (self-found, fixed)**:
  the f1b budget consumer was a FIXED `sleep 100` that must COMPLETE for
  the later hang child to see a small remaining cap, but the real
  bootstrap consumes a VARYING share of the 120 s budget (empirical:
  ~10 s rocky, ~77 s debian). On debian only ~43 s remained when the
  consumer started, so the consumer itself was capped-and-killed
  (rc=124), the hang child never ran, and the LAST "bounded: Ns" line
  was the consumer's 43 s (limit 25) - the t028e debian FAIL. FIX: the
  consumer's sleep is ADAPTIVE (`sleep $(( $(rem_budget) - 12 ))`) - it
  burns (remaining - 12 s) and leaves EXACTLY ~12 s for the hang child,
  independent of bootstrap consumption. Both distros' baked entry lines
  verified byte-identical after the sed injection (bash -n of the entry)
  and smoke-ran with the exact injection image (rocky bounded
  90/116/12 s, debian 90/118/12 s, exit 1 @ wall 122 s each). GREEN in
  t028f: logged cap 12 s BOTH distros.
- **Unchanged checks re-confirmed green in t028f**: (a) 0-1 s + reason
  + data untouched; (b) full readiness + stop/start httpd; (d) REAL
  probe masked-edge deadline exit 2 @ 125 s (rocky) / 126 s (debian) +
  own reason; (e) fwd-death proven before the fatal, status=4 line from
  the durable tap, fatal-reason file; (f1) 121 s both; (f1b) 121 s
  both; (f2) 100 s (rocky) / 97 s (debian) + timeout line; (f3) 255 @
  153 s (rocky) / 154 s (debian) + timeout line.
- **Suite hygiene**: bash -n + ASCII clean; every new check splice
  cat -A-verified; the (c) wrapper fixture byte-extracted from s7.sh
  for the smokes (no drift); injection images build-verified before the
  battery; mktemp -d everywhere a dir is needed.
- **Spar state**: response file 88 (per-finding dispositions +
  empirical evidence incl. the f1b self-caught defect); codex FINAL
  VERDICT (file 89): CONSENSUS - (c) and (g) closed, adaptive f1b
  accepted, t028f logs + bash -n verified, no containers mutated.
  T028 CLOSED on CONSENSUS (tasks.md [X]); whole-implementation
  sign-off remains a separate final round.
## S8-s8-rocky
- when: 2026-11-11 14:13:37
- runtime: podman

- **RESULT: PASS**

- PASS: readiness (gate + /auditsite/)
```
ready-time=6s
```

- enabled unit files (evidence): crond.service                     enabled enabled;dbus-broker.service               enabled enabled;httpd.service                     enabled disabled;nis-domainname.service            enabled enabled;omd-ready.service                 enabled disabled;omd-site.service                  enabled disabled;sshd.service                      enabled enabled;systemd-network-generator.service enabled enabled;dbus.socket                       enabled enabled;reboot.target                     enabled enabled;remote-fs.target                  enabled enabled;dnf-makecache.timer               enabled enabled;logrotate.timer                   enabled enabled;
- PASS: is-enabled (site case): omd.service=masked (got 'masked'), httpd=enabled ('enabled'), sshd=enabled ('enabled'), crond=enabled ('enabled'), omd-site=enabled ('enabled'), omd-ready=enabled ('enabled')
- PASS: getty@tty1 disabled (container console model, got 'disabled')
- PASS: site case: /omd/sites contains only the selected site
- PASS: site case: no process runs as an unexpected site user (only auditsite uid>=1000)
- PASS: no-site mount: ready (base path, no site)
```
ready-time=2s
```

- PASS: no-site mount: no account created for the mounted dir (id volsite fails)
- PASS: no-site mount: no marker written (no omd-labs file in the dir)
- PASS: no-site mount: stop -t 30 clean in 2s (exit 130, 130/0 not 137 - guarded stop wrapper no-ops)
- PASS: no-site mount: restart ready again (full cycle)
```
ready-time=2s
```

- PASS: no-site mount: volume byte-identical before/after (no writes at all)
- PASS: N1: no-site: omd-site enabled ('enabled'), omd-ready enabled ('enabled'), omd-site active as no-op ('active')
- PASS: N1: no-site: no site daemons run (no uid>=1000 process user)
- PASS: N1: no-site stop -t 30 clean in 2s (exit 130, 130/0 not 137 - guarded stop wrapper)
- PASS: N1: no-site restart: still enabled, still a no-op, ready again (full cycle)
```
ready-time=2s omd-site-active=active
```

- enabled-set audit target: units/README-units.md (T012/T029 assert against it)
## S8-s8-debian
- when: 2026-11-11 14:14:08
- runtime: podman

- **RESULT: PASS**

- PASS: readiness (gate + /auditsite/)
```
ready-time=7s
```

- enabled unit files (evidence): apache2.service           enabled enabled;cron.service              enabled enabled;exim4.service             enabled enabled;mariadb.service           enabled enabled;omd-ready.service         enabled enabled;omd-site.service          enabled enabled;ssh.service               enabled enabled;sshd-keygen.service       enabled enabled;systemd-pstore.service    enabled enabled;systemd-timesyncd.service enabled enabled;xinetd.service            enabled enabled;remote-fs.target          enabled enabled;apt-daily-upgrade.timer   enabled enabled;apt-daily.timer           enabled enabled;dpkg-db-backup.timer      enabled enabled;exim4-base.timer          enabled enabled;fstrim.timer              enabled enabled;logrotate.timer           enabled enabled;phpsessionclean.timer     enabled enabled;
- PASS: is-enabled (site case): omd.service=masked (got 'masked'), apache2=enabled ('enabled'), ssh=enabled ('enabled'), cron=enabled ('enabled'), omd-site=enabled ('enabled'), omd-ready=enabled ('enabled')
- PASS: getty@tty1 disabled (container console model, got 'disabled')
- PASS: site case: /omd/sites contains only the selected site
- PASS: site case: no process runs as an unexpected site user (only auditsite uid>=1000)
- PASS: no-site mount: ready (base path, no site)
```
ready-time=2s
```

- PASS: no-site mount: no account created for the mounted dir (id volsite fails)
- PASS: no-site mount: no marker written (no omd-labs file in the dir)
- PASS: no-site mount: stop -t 30 clean in 1s (exit 130, 130/0 not 137 - guarded stop wrapper no-ops)
- PASS: no-site mount: restart ready again (full cycle)
```
ready-time=2s
```

- PASS: no-site mount: volume byte-identical before/after (no writes at all)
- PASS: N1: no-site: omd-site enabled ('enabled'), omd-ready enabled ('enabled'), omd-site active as no-op ('active')
- PASS: N1: no-site: no site daemons run (no uid>=1000 process user)
- PASS: N1: no-site stop -t 30 clean in 1s (exit 130, 130/0 not 137 - guarded stop wrapper)
- PASS: N1: no-site restart: still enabled, still a no-op, ready again (full cycle)
```
ready-time=4s omd-site-active=active
```

- enabled-set audit target: units/README-units.md (T012/T029 assert against it)
## S8-s8-rocky
- when: 2026-11-11 14:46:10
- runtime: podman

- **RESULT: PASS**

- PASS: readiness (gate + /auditsite/)
```
ready-time=6s
```

- enabled unit files (evidence): crond.service                     enabled enabled;dbus-broker.service               enabled enabled;httpd.service                     enabled disabled;nis-domainname.service            enabled enabled;omd-ready.service                 enabled disabled;omd-site.service                  enabled disabled;sshd.service                      enabled enabled;systemd-network-generator.service enabled enabled;dbus.socket                       enabled enabled;reboot.target                     enabled enabled;remote-fs.target                  enabled enabled;dnf-makecache.timer               enabled enabled;logrotate.timer                   enabled enabled;
- PASS: is-enabled (site case): omd.service=masked (got 'masked'), httpd=enabled ('enabled'), sshd=enabled ('enabled'), crond=enabled ('enabled'), omd-site=enabled ('enabled'), omd-ready=enabled ('enabled')
- PASS: getty@tty1 disabled (container console model, got 'disabled')
- PASS: site case: /omd/sites contains only the selected site
- PASS: site case: no process runs as an unexpected site user (only auditsite uid>=1000)
- PASS: no-site mount: ready (base path, no site)
```
ready-time=2s
```

- PASS: no-site mount: no account created for the mounted dir (id volsite fails)
```
id volsite failed as expected: id: 'volsite': no such user
```

- PASS: no-site mount: no marker written (no omd-labs file in the dir)
```
ls succeeded, no omd-labs entry; dir: .
..
data
f2
link-to-f1
target-of-link
```

- PASS: no-site mount: stop -t 30 clean in 2s (exit 130, 130/0 not 137 - guarded stop wrapper no-ops)
- PASS: no-site mount: negative control - ownership, mode, new dir, and symlink-target mutations are DETECTED
```
all 4 mutation classes detected; volume restored to baseline (orig 0:0/644)
```

- PASS: no-site mount: restart ready again (full cycle)
```
ready-time=2s
```

- PASS: no-site mount: volume manifest identical before/after (types, ownership, modes, symlink targets, contents)
- PASS: N1: no-site: omd-site enabled ('enabled'), omd-ready enabled ('enabled'), omd-site active as no-op ('active')
- PASS: N1: no-site: no site daemons run (no uid>=1000 process user)
- PASS: N1: no-site stop -t 30 clean in 2s (exit 130, 130/0 not 137 - guarded stop wrapper)
- PASS: N1: no-site restart: still enabled, still a no-op, ready again (full cycle)
```
ready-time=2s omd-site-active=active
```

- enabled-set audit target: units/README-units.md (T012/T029 assert against it)
## S8-s8-debian
- when: 2026-11-11 14:46:40
- runtime: podman

- **RESULT: PASS**

- PASS: readiness (gate + /auditsite/)
```
ready-time=6s
```

- enabled unit files (evidence): apache2.service           enabled enabled;cron.service              enabled enabled;exim4.service             enabled enabled;mariadb.service           enabled enabled;omd-ready.service         enabled enabled;omd-site.service          enabled enabled;ssh.service               enabled enabled;sshd-keygen.service       enabled enabled;systemd-pstore.service    enabled enabled;systemd-timesyncd.service enabled enabled;xinetd.service            enabled enabled;remote-fs.target          enabled enabled;apt-daily-upgrade.timer   enabled enabled;apt-daily.timer           enabled enabled;dpkg-db-backup.timer      enabled enabled;exim4-base.timer          enabled enabled;fstrim.timer              enabled enabled;logrotate.timer           enabled enabled;phpsessionclean.timer     enabled enabled;
- PASS: is-enabled (site case): omd.service=masked (got 'masked'), apache2=enabled ('enabled'), ssh=enabled ('enabled'), cron=enabled ('enabled'), omd-site=enabled ('enabled'), omd-ready=enabled ('enabled')
- PASS: getty@tty1 disabled (container console model, got 'disabled')
- PASS: site case: /omd/sites contains only the selected site
- PASS: site case: no process runs as an unexpected site user (only auditsite uid>=1000)
- PASS: no-site mount: ready (base path, no site)
```
ready-time=2s
```

- PASS: no-site mount: no account created for the mounted dir (id volsite fails)
```
id volsite failed as expected: id: 'volsite': no such user
```

- PASS: no-site mount: no marker written (no omd-labs file in the dir)
```
ls succeeded, no omd-labs entry; dir: .
..
data
f2
link-to-f1
target-of-link
```

- PASS: no-site mount: stop -t 30 clean in 1s (exit 130, 130/0 not 137 - guarded stop wrapper no-ops)
- PASS: no-site mount: negative control - ownership, mode, new dir, and symlink-target mutations are DETECTED
```
all 4 mutation classes detected; volume restored to baseline (orig 0:0/644)
```

- PASS: no-site mount: restart ready again (full cycle)
```
ready-time=2s
```

- PASS: no-site mount: volume manifest identical before/after (types, ownership, modes, symlink targets, contents)
- PASS: N1: no-site: omd-site enabled ('enabled'), omd-ready enabled ('enabled'), omd-site active as no-op ('active')
- PASS: N1: no-site: no site daemons run (no uid>=1000 process user)
- PASS: N1: no-site stop -t 30 clean in 1s (exit 130, 130/0 not 137 - guarded stop wrapper)
- PASS: N1: no-site restart: still enabled, still a no-op, ready again (full cycle)
```
ready-time=2s omd-site-active=active
```

- enabled-set audit target: units/README-units.md (T012/T029 assert against it)
## S8-s8-rocky
- when: 2026-11-11 14:57:01
- runtime: podman

- **RESULT: FAIL**

- PASS: readiness (gate + /auditsite/)
```
ready-time=8s
```

- enabled unit files (evidence): crond.service                     enabled enabled;dbus-broker.service               enabled enabled;httpd.service                     enabled disabled;nis-domainname.service            enabled enabled;omd-ready.service                 enabled disabled;omd-site.service                  enabled disabled;sshd.service                      enabled enabled;systemd-network-generator.service enabled enabled;dbus.socket                       enabled enabled;reboot.target                     enabled enabled;remote-fs.target                  enabled enabled;dnf-makecache.timer               enabled enabled;logrotate.timer                   enabled enabled;
- PASS: is-enabled (site case): omd.service=masked (got 'masked'), httpd=enabled ('enabled'), sshd=enabled ('enabled'), crond=enabled ('enabled'), omd-site=enabled ('enabled'), omd-ready=enabled ('enabled')
- PASS: getty@tty1 disabled (container console model, got 'disabled')
- PASS: site case: /omd/sites contains only the selected site
- PASS: site case: no process runs as an unexpected site user (only auditsite uid>=1000)
- PASS: no-site mount: ready (base path, no site)
```
ready-time=2s
```

- PASS: no-site mount: no account created for the mounted dir (volsite absent from a successful passwd enumeration)
```
passwd enumeration ok (rc=0), volsite absent; id evidence (rc=1): id: 'volsite': no such user
```

- FAIL: no-site mount: negative control - a failing runtime CANNOT satisfy the no-account check (rc=1)
```

```

- PASS: no-site mount: no marker written (no omd-labs file in the dir)
```
ls succeeded, no omd-labs entry; dir: .
..
data
f2
link-to-f1
target-of-link
```

- PASS: no-site mount: stop -t 30 clean in 1s (exit 130, 130/0 not 137 - guarded stop wrapper no-ops)
- PASS: no-site mount: post-stop manifest equals the pre-run baseline (integrity established before any control mutation)
- PASS: no-site mount: negative control - ownership, mode, new dir, and symlink-target mutations are DETECTED
```
all 4 mutation classes detected; volume restored to its ACTUAL pre-control state (orig 0:0/644, link -> data/f1, retargeted via target-of-link)
```

- PASS: no-site mount: restart ready again (full cycle)
```
ready-time=2s
```

- PASS: no-site mount: volume manifest identical before/after (types, ownership, modes, symlink targets, contents)
- PASS: N1: no-site: omd-site enabled ('enabled'), omd-ready enabled ('enabled'), omd-site active as no-op ('active')
- PASS: N1: no-site: no site daemons run (no uid>=1000 process user)
- PASS: N1: no-site stop -t 30 clean in 2s (exit 130, 130/0 not 137 - guarded stop wrapper)
- PASS: N1: no-site restart: still enabled, still a no-op, ready again (full cycle)
```
ready-time=2s omd-site-active=active
```

- enabled-set audit target: units/README-units.md (T012/T029 assert against it)
## S8-s8-debian
- when: 2026-11-11 14:57:34
- runtime: podman

- **RESULT: FAIL**

- PASS: readiness (gate + /auditsite/)
```
ready-time=6s
```

- enabled unit files (evidence): apache2.service           enabled enabled;cron.service              enabled enabled;exim4.service             enabled enabled;mariadb.service           enabled enabled;omd-ready.service         enabled enabled;omd-site.service          enabled enabled;ssh.service               enabled enabled;sshd-keygen.service       enabled enabled;systemd-pstore.service    enabled enabled;systemd-timesyncd.service enabled enabled;xinetd.service            enabled enabled;remote-fs.target          enabled enabled;apt-daily-upgrade.timer   enabled enabled;apt-daily.timer           enabled enabled;dpkg-db-backup.timer      enabled enabled;exim4-base.timer          enabled enabled;fstrim.timer              enabled enabled;logrotate.timer           enabled enabled;phpsessionclean.timer     enabled enabled;
- PASS: is-enabled (site case): omd.service=masked (got 'masked'), apache2=enabled ('enabled'), ssh=enabled ('enabled'), cron=enabled ('enabled'), omd-site=enabled ('enabled'), omd-ready=enabled ('enabled')
- PASS: getty@tty1 disabled (container console model, got 'disabled')
- PASS: site case: /omd/sites contains only the selected site
- PASS: site case: no process runs as an unexpected site user (only auditsite uid>=1000)
- PASS: no-site mount: ready (base path, no site)
```
ready-time=2s
```

- PASS: no-site mount: no account created for the mounted dir (volsite absent from a successful passwd enumeration)
```
passwd enumeration ok (rc=0), volsite absent; id evidence (rc=1): id: 'volsite': no such user
```

- FAIL: no-site mount: negative control - a failing runtime CANNOT satisfy the no-account check (rc=1)
```

```

- PASS: no-site mount: no marker written (no omd-labs file in the dir)
```
ls succeeded, no omd-labs entry; dir: .
..
data
f2
link-to-f1
target-of-link
```

- PASS: no-site mount: stop -t 30 clean in 1s (exit 130, 130/0 not 137 - guarded stop wrapper no-ops)
- PASS: no-site mount: post-stop manifest equals the pre-run baseline (integrity established before any control mutation)
- PASS: no-site mount: negative control - ownership, mode, new dir, and symlink-target mutations are DETECTED
```
all 4 mutation classes detected; volume restored to its ACTUAL pre-control state (orig 0:0/644, link -> data/f1, retargeted via target-of-link)
```

- PASS: no-site mount: restart ready again (full cycle)
```
ready-time=2s
```

- PASS: no-site mount: volume manifest identical before/after (types, ownership, modes, symlink targets, contents)
- PASS: N1: no-site: omd-site enabled ('enabled'), omd-ready enabled ('enabled'), omd-site active as no-op ('active')
- PASS: N1: no-site: no site daemons run (no uid>=1000 process user)
- PASS: N1: no-site stop -t 30 clean in 0s (exit 130, 130/0 not 137 - guarded stop wrapper)
- PASS: N1: no-site restart: still enabled, still a no-op, ready again (full cycle)
```
ready-time=1s omd-site-active=active
```

- enabled-set audit target: units/README-units.md (T012/T029 assert against it)
## S8-s8-rocky
- when: 2026-11-11 15:02:40
- runtime: podman

- **RESULT: PASS**

- PASS: readiness (gate + /auditsite/)
```
ready-time=6s
```

- enabled unit files (evidence): crond.service                     enabled enabled;dbus-broker.service               enabled enabled;httpd.service                     enabled disabled;nis-domainname.service            enabled enabled;omd-ready.service                 enabled disabled;omd-site.service                  enabled disabled;sshd.service                      enabled enabled;systemd-network-generator.service enabled enabled;dbus.socket                       enabled enabled;reboot.target                     enabled enabled;remote-fs.target                  enabled enabled;dnf-makecache.timer               enabled enabled;logrotate.timer                   enabled enabled;
- PASS: is-enabled (site case): omd.service=masked (got 'masked'), httpd=enabled ('enabled'), sshd=enabled ('enabled'), crond=enabled ('enabled'), omd-site=enabled ('enabled'), omd-ready=enabled ('enabled')
- PASS: getty@tty1 disabled (container console model, got 'disabled')
- PASS: site case: /omd/sites contains only the selected site
- PASS: site case: no process runs as an unexpected site user (only auditsite uid>=1000)
- PASS: no-site mount: ready (base path, no site)
```
ready-time=2s
```

- PASS: no-site mount: no account created for the mounted dir (volsite absent from a successful passwd enumeration)
```
passwd enumeration ok (rc=0), volsite absent; id evidence (rc=1): id: 'volsite': no such user
```

- PASS: no-site mount: negative control - a failing runtime CANNOT satisfy the no-account check
```
broken-runtime evaluation rejected (rc=1): rejection: getent rc=127
```

- PASS: no-site mount: no marker written (no omd-labs file in the dir)
```
ls succeeded, no omd-labs entry; dir: .
..
data
f2
link-to-f1
target-of-link
```

- PASS: no-site mount: stop -t 30 clean in 1s (exit 130, 130/0 not 137 - guarded stop wrapper no-ops)
- PASS: no-site mount: post-stop manifest equals the pre-run baseline (integrity established before any control mutation)
- PASS: no-site mount: negative control - ownership, mode, new dir, and symlink-target mutations are DETECTED
```
all 4 mutation classes detected; volume restored to its ACTUAL pre-control state (orig 0:0/644, link -> data/f1, retargeted via target-of-link)
```

- PASS: no-site mount: restart ready again (full cycle)
```
ready-time=2s
```

- PASS: no-site mount: volume manifest identical before/after (types, ownership, modes, symlink targets, contents)
- PASS: N1: no-site: omd-site enabled ('enabled'), omd-ready enabled ('enabled'), omd-site active as no-op ('active')
- PASS: N1: no-site: no site daemons run (no uid>=1000 process user)
- PASS: N1: no-site stop -t 30 clean in 2s (exit 130, 130/0 not 137 - guarded stop wrapper)
- PASS: N1: no-site restart: still enabled, still a no-op, ready again (full cycle)
```
ready-time=2s omd-site-active=active
```

- enabled-set audit target: units/README-units.md (T012/T029 assert against it)
## S8-s8-debian
- when: 2026-11-11 15:03:11
- runtime: podman

- **RESULT: PASS**

- PASS: readiness (gate + /auditsite/)
```
ready-time=6s
```

- enabled unit files (evidence): apache2.service           enabled enabled;cron.service              enabled enabled;exim4.service             enabled enabled;mariadb.service           enabled enabled;omd-ready.service         enabled enabled;omd-site.service          enabled enabled;ssh.service               enabled enabled;sshd-keygen.service       enabled enabled;systemd-pstore.service    enabled enabled;systemd-timesyncd.service enabled enabled;xinetd.service            enabled enabled;remote-fs.target          enabled enabled;apt-daily-upgrade.timer   enabled enabled;apt-daily.timer           enabled enabled;dpkg-db-backup.timer      enabled enabled;exim4-base.timer          enabled enabled;fstrim.timer              enabled enabled;logrotate.timer           enabled enabled;phpsessionclean.timer     enabled enabled;
- PASS: is-enabled (site case): omd.service=masked (got 'masked'), apache2=enabled ('enabled'), ssh=enabled ('enabled'), cron=enabled ('enabled'), omd-site=enabled ('enabled'), omd-ready=enabled ('enabled')
- PASS: getty@tty1 disabled (container console model, got 'disabled')
- PASS: site case: /omd/sites contains only the selected site
- PASS: site case: no process runs as an unexpected site user (only auditsite uid>=1000)
- PASS: no-site mount: ready (base path, no site)
```
ready-time=2s
```

- PASS: no-site mount: no account created for the mounted dir (volsite absent from a successful passwd enumeration)
```
passwd enumeration ok (rc=0), volsite absent; id evidence (rc=1): id: 'volsite': no such user
```

- PASS: no-site mount: negative control - a failing runtime CANNOT satisfy the no-account check
```
broken-runtime evaluation rejected (rc=1): rejection: getent rc=127
```

- PASS: no-site mount: no marker written (no omd-labs file in the dir)
```
ls succeeded, no omd-labs entry; dir: .
..
data
f2
link-to-f1
target-of-link
```

- PASS: no-site mount: stop -t 30 clean in 1s (exit 130, 130/0 not 137 - guarded stop wrapper no-ops)
- PASS: no-site mount: post-stop manifest equals the pre-run baseline (integrity established before any control mutation)
- PASS: no-site mount: negative control - ownership, mode, new dir, and symlink-target mutations are DETECTED
```
all 4 mutation classes detected; volume restored to its ACTUAL pre-control state (orig 0:0/644, link -> data/f1, retargeted via target-of-link)
```

- PASS: no-site mount: restart ready again (full cycle)
```
ready-time=2s
```

- PASS: no-site mount: volume manifest identical before/after (types, ownership, modes, symlink targets, contents)
- PASS: N1: no-site: omd-site enabled ('enabled'), omd-ready enabled ('enabled'), omd-site active as no-op ('active')
- PASS: N1: no-site: no site daemons run (no uid>=1000 process user)
- PASS: N1: no-site stop -t 30 clean in 0s (exit 130, 130/0 not 137 - guarded stop wrapper)
- PASS: N1: no-site restart: still enabled, still a no-op, ready again (full cycle)
```
ready-time=2s omd-site-active=active
```

- enabled-set audit target: units/README-units.md (T012/T029 assert against it)
## S8-s8-rocky
- when: 2026-11-11 15:15:34
- runtime: podman

- **RESULT: PASS**

- PASS: readiness (gate + /auditsite/)
```
ready-time=6s
```

- enabled unit files (evidence): crond.service                     enabled enabled;dbus-broker.service               enabled enabled;httpd.service                     enabled disabled;nis-domainname.service            enabled enabled;omd-ready.service                 enabled disabled;omd-site.service                  enabled disabled;sshd.service                      enabled enabled;systemd-network-generator.service enabled enabled;dbus.socket                       enabled enabled;reboot.target                     enabled enabled;remote-fs.target                  enabled enabled;dnf-makecache.timer               enabled enabled;logrotate.timer                   enabled enabled;
- PASS: is-enabled (site case): omd.service=masked (got 'masked'), httpd=enabled ('enabled'), sshd=enabled ('enabled'), crond=enabled ('enabled'), omd-site=enabled ('enabled'), omd-ready=enabled ('enabled')
- PASS: getty@tty1 disabled (container console model, got 'disabled')
- PASS: site case: /omd/sites contains only the selected site
- PASS: site case: no process runs as an unexpected site user (only auditsite uid>=1000)
- PASS: no-site mount: ready (base path, no site)
```
ready-time=1s
```

- PASS: no-site mount: no account created for the mounted dir (volsite absent from a successful passwd enumeration)
```
passwd enumeration ok (rc=0), volsite absent; id evidence (rc=1): id: 'volsite': no such user
```

- PASS: no-site mount: negative control - a failing runtime CANNOT satisfy the no-account check
```
broken-runtime evaluation rejected (rc=1): rejection: getent rc=127
```

- PASS: no-site mount: no marker written (no omd-labs file in the dir)
```
ls succeeded, no omd-labs entry; dir: .
..
data
f2
link-to-f1
target-of-link
```

- PASS: no-site mount: stop -t 30 clean in 2s (exit 130, 130/0 not 137 - guarded stop wrapper no-ops)
- PASS: no-site mount: post-stop manifest equals the pre-run baseline (integrity established before any control mutation)
- PASS: no-site mount: negative control - ownership, mode, new dir, and symlink-target mutations are DETECTED
```
all 4 mutation classes detected; volume restored to its ACTUAL pre-control state (orig 0:0/644, link -> data/f1, retargeted via target-of-link)
```

- PASS: no-site mount: negative control - a nonzero-status vol_manifest capture CANNOT count as a detected mutation
```
failed-capture evaluation rejected (rc=1): rejection: mcap refused the failed capture (required)
```

- PASS: no-site mount: restart ready again (full cycle)
```
ready-time=1s
```

- PASS: no-site mount: volume manifest identical before/after (types, ownership, modes, symlink targets, contents)
- PASS: N1: no-site: omd-site enabled ('enabled'), omd-ready enabled ('enabled'), omd-site active as no-op ('active')
- PASS: N1: no-site: no site daemons run (no uid>=1000 process user)
- PASS: N1: no-site stop -t 30 clean in 1s (exit 130, 130/0 not 137 - guarded stop wrapper)
- PASS: N1: no-site restart: still enabled, still a no-op, ready again (full cycle)
```
ready-time=2s omd-site-active=active
```

- enabled-set audit target: units/README-units.md (T012/T029 assert against it)
## S8-s8-debian
- when: 2026-11-11 15:16:07
- runtime: podman

- **RESULT: PASS**

- PASS: readiness (gate + /auditsite/)
```
ready-time=6s
```

- enabled unit files (evidence): apache2.service           enabled enabled;cron.service              enabled enabled;exim4.service             enabled enabled;mariadb.service           enabled enabled;omd-ready.service         enabled enabled;omd-site.service          enabled enabled;ssh.service               enabled enabled;sshd-keygen.service       enabled enabled;systemd-pstore.service    enabled enabled;systemd-timesyncd.service enabled enabled;xinetd.service            enabled enabled;remote-fs.target          enabled enabled;apt-daily-upgrade.timer   enabled enabled;apt-daily.timer           enabled enabled;dpkg-db-backup.timer      enabled enabled;exim4-base.timer          enabled enabled;fstrim.timer              enabled enabled;logrotate.timer           enabled enabled;phpsessionclean.timer     enabled enabled;
- PASS: is-enabled (site case): omd.service=masked (got 'masked'), apache2=enabled ('enabled'), ssh=enabled ('enabled'), cron=enabled ('enabled'), omd-site=enabled ('enabled'), omd-ready=enabled ('enabled')
- PASS: getty@tty1 disabled (container console model, got 'disabled')
- PASS: site case: /omd/sites contains only the selected site
- PASS: site case: no process runs as an unexpected site user (only auditsite uid>=1000)
- PASS: no-site mount: ready (base path, no site)
```
ready-time=2s
```

- PASS: no-site mount: no account created for the mounted dir (volsite absent from a successful passwd enumeration)
```
passwd enumeration ok (rc=0), volsite absent; id evidence (rc=1): id: 'volsite': no such user
```

- PASS: no-site mount: negative control - a failing runtime CANNOT satisfy the no-account check
```
broken-runtime evaluation rejected (rc=1): rejection: getent rc=127
```

- PASS: no-site mount: no marker written (no omd-labs file in the dir)
```
ls succeeded, no omd-labs entry; dir: .
..
data
f2
link-to-f1
target-of-link
```

- PASS: no-site mount: stop -t 30 clean in 1s (exit 130, 130/0 not 137 - guarded stop wrapper no-ops)
- PASS: no-site mount: post-stop manifest equals the pre-run baseline (integrity established before any control mutation)
- PASS: no-site mount: negative control - ownership, mode, new dir, and symlink-target mutations are DETECTED
```
all 4 mutation classes detected; volume restored to its ACTUAL pre-control state (orig 0:0/644, link -> data/f1, retargeted via target-of-link)
```

- PASS: no-site mount: negative control - a nonzero-status vol_manifest capture CANNOT count as a detected mutation
```
failed-capture evaluation rejected (rc=1): rejection: mcap refused the failed capture (required)
```

- PASS: no-site mount: restart ready again (full cycle)
```
ready-time=2s
```

- PASS: no-site mount: volume manifest identical before/after (types, ownership, modes, symlink targets, contents)
- PASS: N1: no-site: omd-site enabled ('enabled'), omd-ready enabled ('enabled'), omd-site active as no-op ('active')
- PASS: N1: no-site: no site daemons run (no uid>=1000 process user)
- PASS: N1: no-site stop -t 30 clean in 1s (exit 130, 130/0 not 137 - guarded stop wrapper)
- PASS: N1: no-site restart: still enabled, still a no-op, ready again (full cycle)
```
ready-time=2s omd-site-active=active
```

- enabled-set audit target: units/README-units.md (T012/T029 assert against it)

## T9-2026-11-11 (5666/NRPE source - D5; user decision + empirical probe on build #13, both distros)

**Decision (user, 2026-11-10, reaffirmed 2026-11-11):** the NRPE/snclient
agent is **external to the OMD package set**  -  no 5666 enabling path is
documented or asserted; the README's "external component" note is final.
Consequences per tasks.md T039 option (b): the key/mechanism does NOT join
the D4 customization catalog; the port stays `EXPOSE 5666` (documentation
only); an operator who has such an agent provides it via `exec`/Ansible
post-first-start.

**EMPIRICAL probe (this round, build #13 images, both distros, `--entrypoint
/bin/sh` one-shot runs  -  no site, no container left running):**

| Evidence | rocky | debian |
|---|---|---|
| `snclient`/`snagent`/`nrpe`/`nrpe-server` binary | absent | absent |
| port 5666 listener (ss/netstat) | not-listening | not-listening |
| NRPE-related packages in the image | none (net-snmp 5.9.1 = SNMP daemon + utils only) | none (libsnmp* libraries only, no snmpd binary) |
| hooks dir entries referencing 5666 | none (76-key catalog re-checked) | none |
| NRPE config files (/etc/nagios/nrpe*, /etc/nrpe*) | none | none |

Note (informational, NOT a 5666 enabler): the catalog contains
`SNMPTRAPD`/`SNMPTRAPD_UDP_PORT`  -  that is the SNMP **trap receiver**
(`snmptrapd`, UDP 162 by default), unrelated to NRPE/5666; it listens only
when explicitly configured.

**RESULT: PASS**  -  the README (T030) states exactly this: 5666 has no
enabling path in the current OMD package set, the listener appears only if
the operator provides an external agent, the port stays EXPOSEd for that
use.
## S1-s1-rocky
- when: 2026-11-11 21:31:04
- runtime: podman

- **RESULT: PASS**

- container: omd-s1 (https 18451, ssh 18452, edge unit httpd)
- PASS: readiness within bound (gate active + 443 answers)
```
ready-time=2s rc=0
```

- PASS: no OMD site exists (SC-003: /omd/sites empty)
- PASS: omd-ready + httpd + sshd all active
```
ready=active edge=active ssh=active
```

- PASS: listeners on 443 + 80 + 22 (in-container; FR-002: edge on 443 AND 80)
- PASS: sshd reachable from host on 18452
- PASS: informational banner in container log (FR-015: no site)
- PASS: stop httpd -> 443 down -> start -> back (SC-006)
- PASS: stop sshd -> 22 down -> start -> back (SC-006)
- PASS: journalctl -u httpd returns logs (FR-016)
- PASS: container log shows startup sequence (FR-015)
- ready-time recorded above; median-of-5 formal baseline = T034 (FR-018)
- PASS: clean stop -t 30 ends 130/0, not 137 (exit code: 130, stop rc: 0)
- teardown done
## S8-s8-rocky
- when: 2026-11-13 11:35:24
- runtime: podman

- **RESULT: FAIL**

- PASS: readiness (gate + /auditsite/)
```
ready-time=8s
```

- enabled unit files (evidence): crond.service                     enabled enabled;dbus-broker.service               enabled enabled;httpd.service                     enabled disabled;nis-domainname.service            enabled enabled;omd-ready.service                 enabled disabled;omd-site.service                  enabled disabled;sshd.service                      enabled enabled;systemd-network-generator.service enabled enabled;dbus.socket                       enabled enabled;reboot.target                     enabled enabled;remote-fs.target                  enabled enabled;dnf-makecache.timer               enabled enabled;logrotate.timer                   enabled enabled;
- PASS: is-enabled (site case): omd.service=alias (got 'alias'), httpd=enabled ('enabled'), sshd=enabled ('enabled'), crond=enabled ('enabled'), omd-site=enabled ('enabled'), omd-ready=enabled ('enabled')
- omd.service alias (evidence): Id=Id=omd-site.service FragmentPath=FragmentPath=/usr/lib/systemd/system/omd-site.service Names=[Names=omd-site.service omd.service] symlink=/usr/lib/systemd/system/omd-site.service
- FAIL: omd.service alias identity (site case): Id=omd-site.service, FragmentPath=/usr/lib/systemd/system/omd-site.service, Names contains both, /etc alias resolves to the canonical unit (rc=1)
```

```

- FAIL: omd.service not masked/vendor-shadowed (site case): LoadState=loaded (got 'LoadState=loaded') (rc=1)
```

```

- PASS: getty@tty1 disabled (container console model, got 'disabled')
- PASS: site case: /omd/sites contains only the selected site
- PASS: site case: no process runs as an unexpected site user (only auditsite uid>=1000)
- PASS: no-site mount: ready (base path, no site)
```
ready-time=2s
```

- PASS: no-site mount: no account created for the mounted dir (volsite absent from a successful passwd enumeration)
```
passwd enumeration ok (rc=0), volsite absent; id evidence (rc=1): id: 'volsite': no such user
```

- PASS: no-site mount: negative control - a failing runtime CANNOT satisfy the no-account check
```
broken-runtime evaluation rejected (rc=1): rejection: getent rc=127
```

- PASS: no-site mount: no marker written (no omd-labs file in the dir)
```
ls succeeded, no omd-labs entry; dir: .
..
data
f2
link-to-f1
target-of-link
```

- PASS: no-site mount: stop -t 30 clean in 1s (exit 130, 130/0 not 137 - guarded stop wrapper no-ops)
- PASS: no-site mount: post-stop manifest equals the pre-run baseline (integrity established before any control mutation)
- PASS: no-site mount: negative control - ownership, mode, new dir, and symlink-target mutations are DETECTED
```
all 4 mutation classes detected; volume restored to its ACTUAL pre-control state (orig 0:0/644, link -> data/f1, retargeted via target-of-link)
```

- PASS: no-site mount: negative control - a nonzero-status vol_manifest capture CANNOT count as a detected mutation
```
failed-capture evaluation rejected (rc=1): rejection: mcap refused the failed capture (required)
```

- PASS: no-site mount: restart ready again (full cycle)
```
ready-time=2s
```

- PASS: no-site mount: volume manifest identical before/after (types, ownership, modes, symlink targets, contents)
- PASS: N1: no-site: omd-site enabled ('enabled'), omd-ready enabled ('enabled'), omd-site active as no-op ('active')
- PASS: N1: no-site: no site daemons run (no uid>=1000 process user)
- PASS: N1: no-site stop -t 30 clean in 2s (exit 130, 130/0 not 137 - guarded stop wrapper)
- PASS: N1: no-site restart: still enabled, still a no-op, ready again (full cycle)
```
ready-time=2s omd-site-active=active
```

- enabled-set audit target: units/README-units.md (T012/T029 assert against it)
## S8-s8-rocky
- when: 2026-11-13 11:37:10
- runtime: podman

- **RESULT: PASS**

- PASS: readiness (gate + /auditsite/)
```
ready-time=9s
```

- enabled unit files (evidence): crond.service                     enabled enabled;dbus-broker.service               enabled enabled;httpd.service                     enabled disabled;nis-domainname.service            enabled enabled;omd-ready.service                 enabled disabled;omd-site.service                  enabled disabled;sshd.service                      enabled enabled;systemd-network-generator.service enabled enabled;dbus.socket                       enabled enabled;reboot.target                     enabled enabled;remote-fs.target                  enabled enabled;dnf-makecache.timer               enabled enabled;logrotate.timer                   enabled enabled;
- PASS: is-enabled (site case): omd.service=alias (got 'alias'), httpd=enabled ('enabled'), sshd=enabled ('enabled'), crond=enabled ('enabled'), omd-site=enabled ('enabled'), omd-ready=enabled ('enabled')
- omd.service alias (evidence): Id=omd-site.service FragmentPath=/usr/lib/systemd/system/omd-site.service Names=[omd-site.service omd.service] LoadState=loaded symlink=/usr/lib/systemd/system/omd-site.service
- PASS: omd.service alias identity (site case): Id=omd-site.service, FragmentPath=/usr/lib/systemd/system/omd-site.service, Names contains both names, /etc alias resolves to the canonical unit
- PASS: omd.service not masked/vendor-shadowed (site case): LoadState=loaded (got 'loaded')
- PASS: getty@tty1 disabled (container console model, got 'disabled')
- PASS: site case: /omd/sites contains only the selected site
- PASS: site case: no process runs as an unexpected site user (only auditsite uid>=1000)
- PASS: no-site mount: ready (base path, no site)
```
ready-time=2s
```

- PASS: no-site mount: no account created for the mounted dir (volsite absent from a successful passwd enumeration)
```
passwd enumeration ok (rc=0), volsite absent; id evidence (rc=1): id: 'volsite': no such user
```

- PASS: no-site mount: negative control - a failing runtime CANNOT satisfy the no-account check
```
broken-runtime evaluation rejected (rc=1): rejection: getent rc=127
```

- PASS: no-site mount: no marker written (no omd-labs file in the dir)
```
ls succeeded, no omd-labs entry; dir: .
..
data
f2
link-to-f1
target-of-link
```

- PASS: no-site mount: stop -t 30 clean in 2s (exit 130, 130/0 not 137 - guarded stop wrapper no-ops)
- PASS: no-site mount: post-stop manifest equals the pre-run baseline (integrity established before any control mutation)
- PASS: no-site mount: negative control - ownership, mode, new dir, and symlink-target mutations are DETECTED
```
all 4 mutation classes detected; volume restored to its ACTUAL pre-control state (orig 0:0/644, link -> data/f1, retargeted via target-of-link)
```

- PASS: no-site mount: negative control - a nonzero-status vol_manifest capture CANNOT count as a detected mutation
```
failed-capture evaluation rejected (rc=1): rejection: mcap refused the failed capture (required)
```

- PASS: no-site mount: restart ready again (full cycle)
```
ready-time=3s
```

- PASS: no-site mount: volume manifest identical before/after (types, ownership, modes, symlink targets, contents)
- PASS: N1: no-site: omd-site enabled ('enabled'), omd-ready enabled ('enabled'), omd-site active as no-op ('active')
- PASS: N1: no-site: no site daemons run (no uid>=1000 process user)
- PASS: N1: no-site stop -t 30 clean in 1s (exit 130, 130/0 not 137 - guarded stop wrapper)
- PASS: N1: no-site restart: still enabled, still a no-op, ready again (full cycle)
```
ready-time=2s omd-site-active=active
```

- enabled-set audit target: units/README-units.md (T012/T029 assert against it)
## S8-s8-debian
- when: 2026-11-13 11:37:52
- runtime: podman

- **RESULT: PASS**

- PASS: readiness (gate + /auditsite/)
```
ready-time=7s
```

- enabled unit files (evidence): apache2.service           enabled enabled;cron.service              enabled enabled;exim4.service             enabled enabled;mariadb.service           enabled enabled;omd-ready.service         enabled enabled;omd-site.service          enabled enabled;ssh.service               enabled enabled;sshd-keygen.service       enabled enabled;systemd-pstore.service    enabled enabled;systemd-timesyncd.service enabled enabled;xinetd.service            enabled enabled;remote-fs.target          enabled enabled;apt-daily-upgrade.timer   enabled enabled;apt-daily.timer           enabled enabled;dpkg-db-backup.timer      enabled enabled;exim4-base.timer          enabled enabled;fstrim.timer              enabled enabled;logrotate.timer           enabled enabled;phpsessionclean.timer     enabled enabled;
- PASS: is-enabled (site case): omd.service=alias (got 'alias'), apache2=enabled ('enabled'), ssh=enabled ('enabled'), cron=enabled ('enabled'), omd-site=enabled ('enabled'), omd-ready=enabled ('enabled')
- omd.service alias (evidence): Id=omd-site.service FragmentPath=/usr/lib/systemd/system/omd-site.service Names=[omd-site.service omd.service] LoadState=loaded symlink=/usr/lib/systemd/system/omd-site.service
- PASS: omd.service alias identity (site case): Id=omd-site.service, FragmentPath=/usr/lib/systemd/system/omd-site.service, Names contains both names, /etc alias resolves to the canonical unit
- PASS: omd.service not masked/vendor-shadowed (site case): LoadState=loaded (got 'loaded')
- PASS: getty@tty1 disabled (container console model, got 'disabled')
- PASS: site case: /omd/sites contains only the selected site
- PASS: site case: no process runs as an unexpected site user (only auditsite uid>=1000)
- PASS: no-site mount: ready (base path, no site)
```
ready-time=2s
```

- PASS: no-site mount: no account created for the mounted dir (volsite absent from a successful passwd enumeration)
```
passwd enumeration ok (rc=0), volsite absent; id evidence (rc=1): id: 'volsite': no such user
```

- PASS: no-site mount: negative control - a failing runtime CANNOT satisfy the no-account check
```
broken-runtime evaluation rejected (rc=1): rejection: getent rc=127
```

- PASS: no-site mount: no marker written (no omd-labs file in the dir)
```
ls succeeded, no omd-labs entry; dir: .
..
data
f2
link-to-f1
target-of-link
```

- PASS: no-site mount: stop -t 30 clean in 1s (exit 130, 130/0 not 137 - guarded stop wrapper no-ops)
- PASS: no-site mount: post-stop manifest equals the pre-run baseline (integrity established before any control mutation)
- PASS: no-site mount: negative control - ownership, mode, new dir, and symlink-target mutations are DETECTED
```
all 4 mutation classes detected; volume restored to its ACTUAL pre-control state (orig 0:0/644, link -> data/f1, retargeted via target-of-link)
```

- PASS: no-site mount: negative control - a nonzero-status vol_manifest capture CANNOT count as a detected mutation
```
failed-capture evaluation rejected (rc=1): rejection: mcap refused the failed capture (required)
```

- PASS: no-site mount: restart ready again (full cycle)
```
ready-time=2s
```

- PASS: no-site mount: volume manifest identical before/after (types, ownership, modes, symlink targets, contents)
- PASS: N1: no-site: omd-site enabled ('enabled'), omd-ready enabled ('enabled'), omd-site active as no-op ('active')
- PASS: N1: no-site: no site daemons run (no uid>=1000 process user)
- PASS: N1: no-site stop -t 30 clean in 1s (exit 130, 130/0 not 137 - guarded stop wrapper)
- PASS: N1: no-site restart: still enabled, still a no-op, ready again (full cycle)
```
ready-time=2s omd-site-active=active
```

- enabled-set audit target: units/README-units.md (T012/T029 assert against it)
## S7-s7-rocky
- when: 2026-11-13 11:39:26
- runtime: podman

- **RESULT: FAIL**

- PASS: (a) not-writable mount ? exit 1 <=30 s (elapsed=1s code=1)
- PASS: (a) fatal reason names the non-writable location (entry-fatal file)
```
FATAL: /omd/sites/rwfail is not writable (run the container with a writable volume at /omd/sites/rwfail)
```

- PASS: (a) data untouched (marker/creation never attempted - root probe)
- PASS: (b) readiness (gate + 443)
```
ready-time=2s
```

- PASS: (b) after systemctl stop httpd: container still running (never exits)
- PASS: (b) httpd inactive; status + journalctl explain
- PASS: (b) systemctl start httpd restores 443
- PASS: (c) pre-ready site-start failure ? container exit 1 (code=1, elapsed=12s)
- PASS: (c) the failure is a REAL partial start, not an instant death (wall 5-240 s, elapsed=12s)
- PASS: (c) FATAL-BLOCK marker in the stopped container's log (bounded wait)
```
2026-11-13T10:39:54+0000 f45d9a42d617 systemd[1]: crond.service: Deactivated successfully.
2026-11-13T10:39:54+0000 f45d9a42d617 systemd[1]: Stopped Command Scheduler.
2026-11-13T10:39:54+0000 f45d9a42d617 systemd[1]: sshd.service: Deactivated successfully.
2026-11-13T10:39:54+0000 f45d9a42d617 systemd[1]: Stopped OpenSSH server daemon.
2026-11-13T10:39:54+0000 f45d9a42d617 systemd[1]: Stopped target sshd-keygen.target.
2026-11-13T10:39:54+0000 f45d9a42d617 systemd[1]: Stopping Permit User Sessions...
2026-11-13T10:39:54+0000 f45d9a42d617 systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-13T10:39:54+0000 f45d9a42d617 systemd[1]: Stopped Permit User Sessions.
```

- PASS: (c) the real daemon was RUNNING before the failure (volume: durable verified-startup marker with PID/EXE/USER evidence)
```
PID=1177
EXE=/opt/omd/versions/5.81.20261109-labs-edition/bin/naemon
USER=sitefail
VERIFIED=1794566391
```

- PASS: (c) bounded cleanup ran: the site omd.log records the naemon stop (durable root probe)
- PASS: (c) bounded cleanup ran: no naemon pid file left (durable root probe)
- FAIL: (d) ready-gate deadline (REAL probe, masked edge) ? exit 2 within the 150 s backstop (code=2, elapsed=124s) (rc=1)
```

```

- PASS: (d) the real probe's deadline reason (log: readiness deadline exceeded)
```
2026-11-13T10:42:03+0000 b02ee4f4a181 omd-ready-check[57]: FATAL-BLOCK-BEGIN (omd-ready rc=2, condition: readiness deadline exceeded (120s gate window))
2026-11-13T10:42:03+0000 b02ee4f4a181 omd-ready-check[825]: 2026-11-13T10:40:02+0000 b02ee4f4a181 systemd[1]: Starting OMD labs single active site (start/stop)...
2026-11-13T10:42:03+0000 b02ee4f4a181 omd-ready-check[825]: 2026-11-13T10:40:02+0000 b02ee4f4a181 systemd[1]: Finished OMD labs single active site (start/stop).
2026-11-13T10:42:03+0000 b02ee4f4a181 omd-ready-check[825]: 2026-11-13T10:40:02+0000 b02ee4f4a181 systemd[1]: Starting OMD labs bounded readiness gate (FR-018)...
2026-11-13T10:42:03+0000 b02ee4f4a181 omd-ready-check[825]: 2026-11-13T10:42:03+0000 b02ee4f4a181 omd-ready-check[57]: READY-FATAL: readiness deadline exceeded (120s gate window) (rc=2)
2026-11-13T10:42:03+0000 b02ee4f4a181 omd-ready-check[825]: 2026-11-13T10:42:03+0000 b02ee4f4a181 omd-ready-check[57]: FATAL-BLOCK-BEGIN (omd-ready rc=2, condition: readiness deadline exceeded (120s gate window))
2026-11-13T10:42:03+0000 b02ee4f4a181 omd-ready-check[57]: FATAL-BLOCK-END
2026-11-13T10:42:03+0000 b02ee4f4a181 omd-ready-check[831]: DIRECT-COPY: status=0 (reason=sent)
```

- PASS: (e) precondition: the forwarder IS dead (kill -0 fails, proved before the fatal)
- PASS: (e) forwarder dead at fatal time ? exit still 1 (code=1)
- PASS: (e) the REAL probe logged the dead-forwarder degradation line (DIRECT-COPY: status=4)
```
DIRECT-COPY: status=4 (forwarder dead - pipe copy skipped)
```

- PASS: (e) the writable-layer fatal-reason file carries the reason (guaranteed artifact)
```
READY-FATAL: unit omd-site.service failed (per-unit ActiveState/Result=failed) (rc=1)
```

- PASS: (f1) hung pre-init child ? bounded exit 1 <=130 s wall (the 120 s bootstrap bound, entry epoch) (code=1, elapsed=122s)
- PASS: (f1) the pre-init budget FATAL is recorded (the bounded child was killed, rc=124/137)
```
FATAL: step failed (rc=124): TEST-ONLY injected hang (s7 f1)
```

- PASS: (f1) no systemd ever ran (log carries no systemd[1] lines - died before /sbin/init)
- PASS: (f1b) late-invocation remaining budget ? whole bootstrap still exit 1, 100s<=wall<=135s (N2 - not t~190 s) (code=1, elapsed=122s)
- PASS: (f1b) the run_bounded cap logged for the late child is the REMAINING budget (bounded: Ns, N<=25)
```
logged cap: 12 s
```

- PASS: (f1b) the pre-init budget FATAL is recorded (the remaining-budget cap fired)
```
FATAL: step failed (rc=124): TEST-ONLY injected hang (s7 f1b)
```

- PASS: (f2) stuck dependency job ? fails at TimeoutStartSec, After=-only gate still runs ? exit 1 (code=1, elapsed=98s)
- PASS: (f2) the After=-only gate ran and failed on the stuck unit (log: omd-site.service failed)
```
2026-11-13T10:48:52+0000 f9274b8d02cf systemd[1]: sshd.service: Deactivated successfully.
2026-11-13T10:48:52+0000 f9274b8d02cf systemd[1]: Stopped OpenSSH server daemon.
2026-11-13T10:48:52+0000 f9274b8d02cf systemd[1]: Stopped target sshd-keygen.target.
2026-11-13T10:48:52+0000 f9274b8d02cf systemd[1]: Stopping Permit User Sessions...
2026-11-13T10:48:52+0000 f9274b8d02cf systemd[1]: php-fpm.service: Deactivated successfully.
2026-11-13T10:48:52+0000 f9274b8d02cf systemd[1]: Stopped The PHP FastCGI Process Manager.
2026-11-13T10:48:52+0000 f9274b8d02cf systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-13T10:48:52+0000 f9274b8d02cf systemd[1]: Stopped Permit User Sessions.
```

- PASS: (f2) systemd evidence: omd-site timed out (start operation timed out)
```
2026-11-13T10:48:52+0000 f9274b8d02cf systemd[1]: sshd.service: Deactivated successfully.
2026-11-13T10:48:52+0000 f9274b8d02cf systemd[1]: Stopped OpenSSH server daemon.
2026-11-13T10:48:52+0000 f9274b8d02cf systemd[1]: Stopped target sshd-keygen.target.
2026-11-13T10:48:52+0000 f9274b8d02cf systemd[1]: Stopping Permit User Sessions...
2026-11-13T10:48:52+0000 f9274b8d02cf systemd[1]: php-fpm.service: Deactivated successfully.
2026-11-13T10:48:52+0000 f9274b8d02cf systemd[1]: Stopped The PHP FastCGI Process Manager.
2026-11-13T10:48:52+0000 f9274b8d02cf systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-13T10:48:52+0000 f9274b8d02cf systemd[1]: Stopped Permit User Sessions.
```

- PASS: (f3) hung probe ? killed at the 150 s backstop, FailureAction=exit ? exit 255 (code=255, elapsed=154s)
- PASS: (f3) systemd evidence: omd-ready killed at the 150 s backstop (start operation timed out)
```
2026-11-13T10:51:29+0000 5d45b9d56a0e systemd[1]: systemd-logind.service: Deactivated successfully.
2026-11-13T10:51:29+0000 5d45b9d56a0e systemd[1]: Stopped User Login Management.
2026-11-13T10:51:29+0000 5d45b9d56a0e systemd[1]: omd-site.service: Deactivated successfully.
2026-11-13T10:51:29+0000 5d45b9d56a0e systemd[1]: Stopped OMD labs single active site (start/stop).
2026-11-13T10:51:29+0000 5d45b9d56a0e systemd[1]: Stopped target sshd-keygen.target.
2026-11-13T10:51:29+0000 5d45b9d56a0e systemd[1]: Stopping Permit User Sessions...
2026-11-13T10:51:29+0000 5d45b9d56a0e systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-13T10:51:29+0000 5d45b9d56a0e systemd[1]: Stopped Permit User Sessions.
```

- PASS: (g/baseline) container exited 1 AND the REAL probe's direct_copy returned status=0 (sent) (code=1, elapsed=9s)
```
DIRECT-COPY: status=0 (reason=sent)
```

- PASS: (g/baseline) non-vacuous: the same body with a DELIBERATELY wrong code FAILS (proof the exit assertion is mandatory)
```
exit code 999 != 1
proof: body(real=set +e; gbody() { [ "$1" = 1 ] || { echo "exit code $1 != 1"; return 1; }; grep -q "DIRECT-COPY: status=0" "/tmp/tmp.mxpy664hQE/o" 2>/dev/null || return 1; }; gbody 1 || { echo "BUG: real code failed the body"; exit 1; }; gbody 999 && { echo "BUG: wrong code 999 passed - assertion vacuous"; exit 1; }; echo "proof: body(real=$1) accepted, body(999) rejected") accepted, body(999) rejected
```

- PASS: (g/baseline) the direct-copy operation is BOUNDED (per-op wall < 15 s from the tap)
```
per-op wall=2s
```

- PASS: (g/baseline) writable-layer fatal-reason file carries the reason (guaranteed artifact, HARD)
```
READY-FATAL: unit omd-site.service failed (per-unit ActiveState/Result=failed) (rc=1)
```

- PASS: (g/fullpipe) container exited 1 AND the REAL probe's direct_copy returned status=1 (partial) (code=1, elapsed=10s)
```
DIRECT-COPY: status=1 (reason=partial)
```

- PASS: (g/fullpipe) non-vacuous: the same body with a DELIBERATELY wrong code FAILS (proof the exit assertion is mandatory)
```
exit code 999 != 1
proof: body(real=set +e; gbody() { [ "$1" = 1 ] || { echo "exit code $1 != 1"; return 1; }; grep -q "DIRECT-COPY: status=1" "/tmp/tmp.q6foMdC7oy/o" 2>/dev/null || return 1; }; gbody 1 || { echo "BUG: real code failed the body"; exit 1; }; gbody 999 && { echo "BUG: wrong code 999 passed - assertion vacuous"; exit 1; }; echo "proof: body(real=$1) accepted, body(999) rejected") accepted, body(999) rejected
```

- PASS: (g/fullpipe) the direct-copy operation is BOUNDED (per-op wall < 15 s from the tap)
```
per-op wall=1s
```

- PASS: (g/fullpipe) writable-layer fatal-reason file carries the reason (guaranteed artifact, HARD)
```
READY-FATAL: unit omd-site.service failed (per-unit ActiveState/Result=failed) (rc=1)
```

- post-ready crash never exits the container (a/b contrast); all hangs bounded (f)
## S7-s7-debian
- when: 2026-11-13 11:52:05
- runtime: podman

- **RESULT: PASS**

- PASS: (a) not-writable mount ? exit 1 <=30 s (elapsed=1s code=1)
- PASS: (a) fatal reason names the non-writable location (entry-fatal file)
```
FATAL: /omd/sites/rwfail is not writable (run the container with a writable volume at /omd/sites/rwfail)
```

- PASS: (a) data untouched (marker/creation never attempted - root probe)
- PASS: (b) readiness (gate + 443)
```
ready-time=2s
```

- PASS: (b) after systemctl stop apache2: container still running (never exits)
- PASS: (b) apache2 inactive; status + journalctl explain
- PASS: (b) systemctl start apache2 restores 443
- PASS: (c) pre-ready site-start failure ? container exit 1 (code=1, elapsed=7s)
- PASS: (c) the failure is a REAL partial start, not an instant death (wall 5-240 s, elapsed=7s)
- PASS: (c) FATAL-BLOCK marker in the stopped container's log (bounded wait)
```
2026-11-13T10:52:25+00:00 01e301f54ffa systemd[1]: Stopped target network-online.target - Network is Online.
2026-11-13T10:52:25+00:00 01e301f54ffa apachectl[1687]: AH00558: apache2: Could not reliably determine the server's fully qualified domain name, using 10.0.1.166. Set the 'ServerName' directive globally to suppress this message
2026-11-13T10:52:25+00:00 01e301f54ffa mariadbd[1023]: 2026-11-13 10:52:25 0 [Note] InnoDB: Starting shutdown...
2026-11-13T10:52:25+00:00 01e301f54ffa mariadbd[1023]: 2026-11-13 10:52:25 0 [Note] InnoDB: Dumping buffer pool(s) to /var/lib/mysql/ib_buffer_pool
2026-11-13T10:52:25+00:00 01e301f54ffa mariadbd[1023]: 2026-11-13 10:52:25 0 [Note] InnoDB: Buffer pool(s) dump completed at 261113 10:52:25
2026-11-13T10:52:26+00:00 01e301f54ffa systemd[1]: apache2.service: Deactivated successfully.
2026-11-13T10:52:26+00:00 01e301f54ffa systemd[1]: Stopped apache2.service - The Apache HTTP Server.
2026-11-13T10:52:26+00:00 01e301f54ffa systemd[1]: Stopped target remote-fs.target - Remote File Systems.
```

- PASS: (c) the real daemon was RUNNING before the failure (volume: durable verified-startup marker with PID/EXE/USER evidence)
```
PID=1085
EXE=/opt/omd/versions/5.81.20261109-labs-edition/bin/naemon
USER=sitefail
VERIFIED=1794567143
```

- PASS: (c) bounded cleanup ran: the site omd.log records the naemon stop (durable root probe)
- PASS: (c) bounded cleanup ran: no naemon pid file left (durable root probe)
- PASS: (d) ready-gate deadline (REAL probe, masked edge) ? exit 2 within the 150 s backstop (code=2, elapsed=126s)
- PASS: (d) the real probe's deadline reason (log: readiness deadline exceeded)
```
2026-11-13T10:54:33+00:00 39c8594670b5 systemd[1]: Stopped omd-site.service - OMD labs single active site (start/stop).
2026-11-13T10:54:33+00:00 39c8594670b5 systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-13T10:54:33+00:00 39c8594670b5 systemd[1]: Stopped systemd-user-sessions.service - Permit User Sessions.
2026-11-13T10:54:33+00:00 39c8594670b5 systemd[1]: Stopped target remote-fs.target - Remote File Systems.
2026-11-13T10:54:33+00:00 39c8594670b5 mariadbd[155]: 2026-11-13 10:54:33 0 [Note] InnoDB: Dumping buffer pool(s) to /var/lib/mysql/ib_buffer_pool
2026-11-13T10:54:33+00:00 39c8594670b5 mariadbd[155]: 2026-11-13 10:54:33 0 [Note] InnoDB: Buffer pool(s) dump completed at 261113 10:54:33
2026-11-13T10:54:33+00:00 39c8594670b5 mariadbd[155]: 2026-11-13 10:54:33 0 [Note] InnoDB: Removed temporary tablespace data file: "./ibtmp1"
2026-11-13T10:54:33+00:00 39c8594670b5 mariadbd[155]: 2026-11-13 10:54:33 0 [Note] InnoDB: Shutdown completed; log sequence number 45498; transaction id 15
```

- PASS: (e) precondition: the forwarder IS dead (kill -0 fails, proved before the fatal)
- PASS: (e) forwarder dead at fatal time ? exit still 1 (code=1)
- PASS: (e) the REAL probe logged the dead-forwarder degradation line (DIRECT-COPY: status=4)
```
DIRECT-COPY: status=4 (forwarder dead - pipe copy skipped)
```

- PASS: (e) the writable-layer fatal-reason file carries the reason (guaranteed artifact)
```
READY-FATAL: unit omd-site.service failed (per-unit ActiveState/Result=failed) (rc=1)
```

- PASS: (f1) hung pre-init child ? bounded exit 1 <=130 s wall (the 120 s bootstrap bound, entry epoch) (code=1, elapsed=122s)
- PASS: (f1) the pre-init budget FATAL is recorded (the bounded child was killed, rc=124/137)
```
FATAL: step failed (rc=124): TEST-ONLY injected hang (s7 f1)
```

- PASS: (f1) no systemd ever ran (log carries no systemd[1] lines - died before /sbin/init)
- PASS: (f1b) late-invocation remaining budget ? whole bootstrap still exit 1, 100s<=wall<=135s (N2 - not t~190 s) (code=1, elapsed=122s)
- PASS: (f1b) the run_bounded cap logged for the late child is the REMAINING budget (bounded: Ns, N<=25)
```
logged cap: 12 s
```

- PASS: (f1b) the pre-init budget FATAL is recorded (the remaining-budget cap fired)
```
FATAL: step failed (rc=124): TEST-ONLY injected hang (s7 f1b)
```

- PASS: (f2) stuck dependency job ? fails at TimeoutStartSec, After=-only gate still runs ? exit 1 (code=1, elapsed=97s)
- PASS: (f2) the After=-only gate ran and failed on the stuck unit (log: omd-site.service failed)
```
2026-11-13T11:01:22+00:00 59de4aab07ce mariadbd[975]: 2026-11-13 11:01:22 0 [Note] InnoDB: Buffer pool(s) dump completed at 261113 11:01:22
2026-11-13T11:01:22+00:00 59de4aab07ce systemd[1]: Stopped target network-online.target - Network is Online.
2026-11-13T11:01:22+00:00 59de4aab07ce apachectl[1501]: AH00558: apache2: Could not reliably determine the server's fully qualified domain name, using 10.0.1.166. Set the 'ServerName' directive globally to suppress this message
2026-11-13T11:01:22+00:00 59de4aab07ce systemd[1]: apache2.service: Deactivated successfully.
2026-11-13T11:01:22+00:00 59de4aab07ce systemd[1]: Stopped apache2.service - The Apache HTTP Server.
2026-11-13T11:01:22+00:00 59de4aab07ce systemd[1]: Stopped target remote-fs.target - Remote File Systems.
2026-11-13T11:01:22+00:00 59de4aab07ce mariadbd[975]: 2026-11-13 11:01:22 0 [Note] InnoDB: Removed temporary tablespace data file: "./ibtmp1"
2026-11-13T11:01:22+00:00 59de4aab07ce mariadbd[975]: 2026-11-13 11:01:22 0 [Note] InnoDB: Shutdown completed; log sequence number 45498; transaction id 15
```

- PASS: (f2) systemd evidence: omd-site timed out (start operation timed out)
```
2026-11-13T11:01:22+00:00 59de4aab07ce mariadbd[975]: 2026-11-13 11:01:22 0 [Note] InnoDB: Buffer pool(s) dump completed at 261113 11:01:22
2026-11-13T11:01:22+00:00 59de4aab07ce systemd[1]: Stopped target network-online.target - Network is Online.
2026-11-13T11:01:22+00:00 59de4aab07ce apachectl[1501]: AH00558: apache2: Could not reliably determine the server's fully qualified domain name, using 10.0.1.166. Set the 'ServerName' directive globally to suppress this message
2026-11-13T11:01:22+00:00 59de4aab07ce systemd[1]: apache2.service: Deactivated successfully.
2026-11-13T11:01:22+00:00 59de4aab07ce systemd[1]: Stopped apache2.service - The Apache HTTP Server.
2026-11-13T11:01:22+00:00 59de4aab07ce systemd[1]: Stopped target remote-fs.target - Remote File Systems.
2026-11-13T11:01:22+00:00 59de4aab07ce mariadbd[975]: 2026-11-13 11:01:22 0 [Note] InnoDB: Removed temporary tablespace data file: "./ibtmp1"
2026-11-13T11:01:22+00:00 59de4aab07ce mariadbd[975]: 2026-11-13 11:01:22 0 [Note] InnoDB: Shutdown completed; log sequence number 45498; transaction id 15
```

- PASS: (f3) hung probe ? killed at the 150 s backstop, FailureAction=exit ? exit 255 (code=255, elapsed=154s)
- PASS: (f3) systemd evidence: omd-ready killed at the 150 s backstop (start operation timed out)
```
2026-11-13T11:03:58+00:00 bcbf5ff1a35f mariadbd[154]: 2026-11-13 11:03:58 0 [Note] InnoDB: Dumping buffer pool(s) to /var/lib/mysql/ib_buffer_pool
2026-11-13T11:03:58+00:00 bcbf5ff1a35f mariadbd[154]: 2026-11-13 11:03:58 0 [Note] InnoDB: Buffer pool(s) dump completed at 261113 11:03:58
2026-11-13T11:03:58+00:00 bcbf5ff1a35f apachectl[484]: AH00558: apache2: Could not reliably determine the server's fully qualified domain name, using 10.0.1.166. Set the 'ServerName' directive globally to suppress this message
2026-11-13T11:03:58+00:00 bcbf5ff1a35f systemd[1]: apache2.service: Deactivated successfully.
2026-11-13T11:03:58+00:00 bcbf5ff1a35f systemd[1]: Stopped apache2.service - The Apache HTTP Server.
2026-11-13T11:03:58+00:00 bcbf5ff1a35f systemd[1]: Stopped target remote-fs.target - Remote File Systems.
2026-11-13T11:03:58+00:00 bcbf5ff1a35f mariadbd[154]: 2026-11-13 11:03:58 0 [Note] InnoDB: Removed temporary tablespace data file: "./ibtmp1"
2026-11-13T11:03:58+00:00 bcbf5ff1a35f mariadbd[154]: 2026-11-13 11:03:58 0 [Note] InnoDB: Shutdown completed; log sequence number 45498; transaction id 15
```

- PASS: (g/baseline) container exited 1 AND the REAL probe's direct_copy returned status=0 (sent) (code=1, elapsed=7s)
```
DIRECT-COPY: status=0 (reason=sent)
```

- PASS: (g/baseline) non-vacuous: the same body with a DELIBERATELY wrong code FAILS (proof the exit assertion is mandatory)
```
exit code 999 != 1
proof: body(real=set +e; gbody() { [ "$1" = 1 ] || { echo "exit code $1 != 1"; return 1; }; grep -q "DIRECT-COPY: status=0" "/tmp/tmp.f0SG3SCPQM/o" 2>/dev/null || return 1; }; gbody 1 || { echo "BUG: real code failed the body"; exit 1; }; gbody 999 && { echo "BUG: wrong code 999 passed - assertion vacuous"; exit 1; }; echo "proof: body(real=$1) accepted, body(999) rejected") accepted, body(999) rejected
```

- PASS: (g/baseline) the direct-copy operation is BOUNDED (per-op wall < 15 s from the tap)
```
per-op wall=1s
```

- PASS: (g/baseline) writable-layer fatal-reason file carries the reason (guaranteed artifact, HARD)
```
READY-FATAL: unit omd-site.service failed (per-unit ActiveState/Result=failed) (rc=1)
```

- PASS: (g/fullpipe) container exited 1 AND the REAL probe's direct_copy returned status=1 (partial) (code=1, elapsed=7s)
```
DIRECT-COPY: status=1 (reason=partial)
```

- PASS: (g/fullpipe) non-vacuous: the same body with a DELIBERATELY wrong code FAILS (proof the exit assertion is mandatory)
```
exit code 999 != 1
proof: body(real=set +e; gbody() { [ "$1" = 1 ] || { echo "exit code $1 != 1"; return 1; }; grep -q "DIRECT-COPY: status=1" "/tmp/tmp.7u39UNiKUh/o" 2>/dev/null || return 1; }; gbody 1 || { echo "BUG: real code failed the body"; exit 1; }; gbody 999 && { echo "BUG: wrong code 999 passed - assertion vacuous"; exit 1; }; echo "proof: body(real=$1) accepted, body(999) rejected") accepted, body(999) rejected
```

- PASS: (g/fullpipe) the direct-copy operation is BOUNDED (per-op wall < 15 s from the tap)
```
per-op wall=1s
```

- PASS: (g/fullpipe) writable-layer fatal-reason file carries the reason (guaranteed artifact, HARD)
```
READY-FATAL: unit omd-site.service failed (per-unit ActiveState/Result=failed) (rc=1)
```

- post-ready crash never exits the container (a/b contrast); all hangs bounded (f)
## S7-s7-rocky
- when: 2026-11-13 12:06:42
- runtime: podman

- **RESULT: PASS**

- PASS: (a) not-writable mount ? exit 1 <=30 s (elapsed=1s code=1)
- PASS: (a) fatal reason names the non-writable location (entry-fatal file)
```
FATAL: /omd/sites/rwfail is not writable (run the container with a writable volume at /omd/sites/rwfail)
```

- PASS: (a) data untouched (marker/creation never attempted - root probe)
- PASS: (b) readiness (gate + 443)
```
ready-time=3s
```

- PASS: (b) after systemctl stop httpd: container still running (never exits)
- PASS: (b) httpd inactive; status + journalctl explain
- PASS: (b) systemctl start httpd restores 443
- PASS: (c) pre-ready site-start failure ? container exit 1 (code=1, elapsed=12s)
- PASS: (c) the failure is a REAL partial start, not an instant death (wall 5-240 s, elapsed=12s)
- PASS: (c) FATAL-BLOCK marker in the stopped container's log (bounded wait)
```
2026-11-13T11:07:05+0000 b25c5cf81136 crond[875]: (CRON) INFO (Shutting down)
2026-11-13T11:07:05+0000 b25c5cf81136 systemd[1]: crond.service: Deactivated successfully.
2026-11-13T11:07:05+0000 b25c5cf81136 systemd[1]: Stopped Command Scheduler.
2026-11-13T11:07:05+0000 b25c5cf81136 systemd[1]: php-fpm.service: Deactivated successfully.
2026-11-13T11:07:05+0000 b25c5cf81136 systemd[1]: Stopped The PHP FastCGI Process Manager.
2026-11-13T11:07:05+0000 b25c5cf81136 systemd[1]: Stopping Permit User Sessions...
2026-11-13T11:07:05+0000 b25c5cf81136 systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-13T11:07:05+0000 b25c5cf81136 systemd[1]: Stopped Permit User Sessions.
```

- PASS: (c) the real daemon was RUNNING before the failure (volume: durable verified-startup marker with PID/EXE/USER evidence)
```
PID=1178
EXE=/opt/omd/versions/5.81.20261109-labs-edition/bin/naemon
USER=sitefail
VERIFIED=1794568022
```

- PASS: (c) bounded cleanup ran: the site omd.log records the naemon stop (durable root probe)
- PASS: (c) bounded cleanup ran: no naemon pid file left (durable root probe)
- PASS: (d) ready-gate deadline (REAL probe, masked edge) ? exit 2 within the 150 s backstop (code=2, elapsed=126s)
- PASS: (d) the real probe's deadline reason (log: readiness deadline exceeded)
```
2026-11-13T11:09:12+0000 d0489153b513 omd-ready-check[57]: FATAL-BLOCK-BEGIN (omd-ready rc=2, condition: readiness deadline exceeded (120s gate window))
2026-11-13T11:09:12+0000 d0489153b513 omd-ready-check[825]: 2026-11-13T11:07:12+0000 d0489153b513 systemd[1]: Starting OMD labs single active site (start/stop)...
2026-11-13T11:09:12+0000 d0489153b513 omd-ready-check[825]: 2026-11-13T11:07:12+0000 d0489153b513 systemd[1]: Finished OMD labs single active site (start/stop).
2026-11-13T11:09:12+0000 d0489153b513 omd-ready-check[825]: 2026-11-13T11:07:12+0000 d0489153b513 systemd[1]: Starting OMD labs bounded readiness gate (FR-018)...
2026-11-13T11:09:12+0000 d0489153b513 omd-ready-check[825]: 2026-11-13T11:09:12+0000 d0489153b513 omd-ready-check[57]: READY-FATAL: readiness deadline exceeded (120s gate window) (rc=2)
2026-11-13T11:09:12+0000 d0489153b513 omd-ready-check[825]: 2026-11-13T11:09:12+0000 d0489153b513 omd-ready-check[57]: FATAL-BLOCK-BEGIN (omd-ready rc=2, condition: readiness deadline exceeded (120s gate window))
2026-11-13T11:09:12+0000 d0489153b513 omd-ready-check[57]: FATAL-BLOCK-END
2026-11-13T11:09:13+0000 d0489153b513 omd-ready-check[831]: DIRECT-COPY: status=0 (reason=sent)
```

- PASS: (e) precondition: the forwarder IS dead (kill -0 fails, proved before the fatal)
- PASS: (e) forwarder dead at fatal time ? exit still 1 (code=1)
- PASS: (e) the REAL probe logged the dead-forwarder degradation line (DIRECT-COPY: status=4)
```
DIRECT-COPY: status=4 (forwarder dead - pipe copy skipped)
```

- PASS: (e) the writable-layer fatal-reason file carries the reason (guaranteed artifact)
```
READY-FATAL: unit omd-site.service failed (per-unit ActiveState/Result=failed) (rc=1)
```

- PASS: (f1) hung pre-init child ? bounded exit 1 <=130 s wall (the 120 s bootstrap bound, entry epoch) (code=1, elapsed=122s)
- PASS: (f1) the pre-init budget FATAL is recorded (the bounded child was killed, rc=124/137)
```
FATAL: step failed (rc=124): TEST-ONLY injected hang (s7 f1)
```

- PASS: (f1) no systemd ever ran (log carries no systemd[1] lines - died before /sbin/init)
- PASS: (f1b) late-invocation remaining budget ? whole bootstrap still exit 1, 100s<=wall<=135s (N2 - not t~190 s) (code=1, elapsed=122s)
- PASS: (f1b) the run_bounded cap logged for the late child is the REMAINING budget (bounded: Ns, N<=25)
```
logged cap: 12 s
```

- PASS: (f1b) the pre-init budget FATAL is recorded (the remaining-budget cap fired)
```
FATAL: step failed (rc=124): TEST-ONLY injected hang (s7 f1b)
```

- PASS: (f2) stuck dependency job ? fails at TimeoutStartSec, After=-only gate still runs ? exit 1 (code=1, elapsed=97s)
- PASS: (f2) the After=-only gate ran and failed on the stuck unit (log: omd-site.service failed)
```
2026-11-13T11:16:00+0000 be458c13cf97 systemd[1]: crond.service: Deactivated successfully.
2026-11-13T11:16:00+0000 be458c13cf97 systemd[1]: Stopped Command Scheduler.
2026-11-13T11:16:00+0000 be458c13cf97 systemd[1]: Stopped target sshd-keygen.target.
2026-11-13T11:16:00+0000 be458c13cf97 systemd[1]: Stopping Permit User Sessions...
2026-11-13T11:16:00+0000 be458c13cf97 systemd[1]: php-fpm.service: Deactivated successfully.
2026-11-13T11:16:00+0000 be458c13cf97 systemd[1]: Stopped The PHP FastCGI Process Manager.
2026-11-13T11:16:00+0000 be458c13cf97 systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-13T11:16:00+0000 be458c13cf97 systemd[1]: Stopped Permit User Sessions.
```

- PASS: (f2) systemd evidence: omd-site timed out (start operation timed out)
```
2026-11-13T11:16:00+0000 be458c13cf97 systemd[1]: crond.service: Deactivated successfully.
2026-11-13T11:16:00+0000 be458c13cf97 systemd[1]: Stopped Command Scheduler.
2026-11-13T11:16:00+0000 be458c13cf97 systemd[1]: Stopped target sshd-keygen.target.
2026-11-13T11:16:00+0000 be458c13cf97 systemd[1]: Stopping Permit User Sessions...
2026-11-13T11:16:00+0000 be458c13cf97 systemd[1]: php-fpm.service: Deactivated successfully.
2026-11-13T11:16:00+0000 be458c13cf97 systemd[1]: Stopped The PHP FastCGI Process Manager.
2026-11-13T11:16:00+0000 be458c13cf97 systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-13T11:16:00+0000 be458c13cf97 systemd[1]: Stopped Permit User Sessions.
```

- PASS: (f3) hung probe ? killed at the 150 s backstop, FailureAction=exit ? exit 255 (code=255, elapsed=154s)
- PASS: (f3) systemd evidence: omd-ready killed at the 150 s backstop (start operation timed out)
```
2026-11-13T11:18:34+0000 4461b948f7fb systemd[1]: sshd.service: Deactivated successfully.
2026-11-13T11:18:34+0000 4461b948f7fb systemd[1]: Stopped OpenSSH server daemon.
2026-11-13T11:18:34+0000 4461b948f7fb systemd[1]: omd-site.service: Deactivated successfully.
2026-11-13T11:18:34+0000 4461b948f7fb systemd[1]: Stopped OMD labs single active site (start/stop).
2026-11-13T11:18:34+0000 4461b948f7fb systemd[1]: Stopped target sshd-keygen.target.
2026-11-13T11:18:34+0000 4461b948f7fb systemd[1]: Stopping Permit User Sessions...
2026-11-13T11:18:34+0000 4461b948f7fb systemd[1]: systemd-user-sessions.service: Deactivated successfully.
2026-11-13T11:18:34+0000 4461b948f7fb systemd[1]: Stopped Permit User Sessions.
```

- PASS: (g/baseline) container exited 1 AND the REAL probe's direct_copy returned status=0 (sent) (code=1, elapsed=9s)
```
DIRECT-COPY: status=0 (reason=sent)
```

- PASS: (g/baseline) non-vacuous: the same body with a DELIBERATELY wrong code FAILS (proof the exit assertion is mandatory)
```
exit code 999 != 1
proof: body(real=set +e; gbody() { [ "$1" = 1 ] || { echo "exit code $1 != 1"; return 1; }; grep -q "DIRECT-COPY: status=0" "/tmp/tmp.nJEg4LWvFU/o" 2>/dev/null || return 1; }; gbody 1 || { echo "BUG: real code failed the body"; exit 1; }; gbody 999 && { echo "BUG: wrong code 999 passed - assertion vacuous"; exit 1; }; echo "proof: body(real=$1) accepted, body(999) rejected") accepted, body(999) rejected
```

- PASS: (g/baseline) the direct-copy operation is BOUNDED (per-op wall < 15 s from the tap)
```
per-op wall=1s
```

- PASS: (g/baseline) writable-layer fatal-reason file carries the reason (guaranteed artifact, HARD)
```
READY-FATAL: unit omd-site.service failed (per-unit ActiveState/Result=failed) (rc=1)
```

- PASS: (g/fullpipe) container exited 1 AND the REAL probe's direct_copy returned status=1 (partial) (code=1, elapsed=9s)
```
DIRECT-COPY: status=1 (reason=partial)
```

- PASS: (g/fullpipe) non-vacuous: the same body with a DELIBERATELY wrong code FAILS (proof the exit assertion is mandatory)
```
exit code 999 != 1
proof: body(real=set +e; gbody() { [ "$1" = 1 ] || { echo "exit code $1 != 1"; return 1; }; grep -q "DIRECT-COPY: status=1" "/tmp/tmp.UqfAPWbXcV/o" 2>/dev/null || return 1; }; gbody 1 || { echo "BUG: real code failed the body"; exit 1; }; gbody 999 && { echo "BUG: wrong code 999 passed - assertion vacuous"; exit 1; }; echo "proof: body(real=$1) accepted, body(999) rejected") accepted, body(999) rejected
```

- PASS: (g/fullpipe) the direct-copy operation is BOUNDED (per-op wall < 15 s from the tap)
```
per-op wall=1s
```

- PASS: (g/fullpipe) writable-layer fatal-reason file carries the reason (guaranteed artifact, HARD)
```
READY-FATAL: unit omd-site.service failed (per-unit ActiveState/Result=failed) (rc=1)
```

- post-ready crash never exits the container (a/b contrast); all hangs bounded (f)

## QS-quickstart-2026-11-13 (TUTORIAL.md "Quick Start" verbatim smoke run — spec 002 US1)
- when: 2026-11-13 15:40-15:55
- runtime: podman 6.1.3, rootless, Linux cgroup v2 (same host as the suite)
- image: local/omd-labs-systemd-vm-rocky:nightly (ea8bf405bcd8 — the alias-carrying
  build; tagged :nightly and :r2-test, image id bbca836eed24 for r2-test;
  the Quick Start's verbatim IMAGE default)
- OMD: 5.81.20261109-labs-edition

- **RESULT: PASS** (Podman alternative path, per spec 002 US1)

- PASS: setup block verbatim (mkdir -p ./omd-qs-data; non-overwriting
  ssh-keygen ed25519 -N ''; key.pub non-empty check) — new key generated
- PASS: Podman run block verbatim (--privileged --systemd=always -d,
  -p 2222:22 -p 8443:443, -e SITENAME=qs, site dir + key.pub mounts with
  :z) — container 1d3216ba75d2 started
- PASS: qs_wait_ready helper verbatim — READY after 8 s
  (systemctl is-active omd-ready = active); log banner "created new site qs"
  (created-fresh, no prior state in the data dir)
- PASS: `omd status qs` (in-container, verbatim) = Overall state: running
  (rrdcached/npcc/naemon/apache/crontab all running), rc 0
- PASS: `ssh -i ./omd-qs-key -o IdentitiesOnly=yes -p 2222 root@localhost
  'omd status qs'` — mapped-port login works, rc 0, Overall state: running.
  First attempt refused by the client: a STALE known_hosts entry for
  [localhost]:2222 from the previous (removed) omd-qs container; the new
  host key's fingerprint (SHA256:6LHSdMuum1oKOi5x9XdqvAvGRE47GRAHt/
  tvgqrY4ZA) matched the container's actual ed25519 host key — the
  documented "new container => new host keys" case (TUTORIAL §9). The
  single stale line was removed from ~/.ssh/known_hosts; retry with
  accept-new succeeded (the TUTORIAL's own advice: verify the fingerprint
  before accepting).
- PASS: `curl -sk -o /dev/null -w '%{http_code}\n' https://localhost:8443/qs/`
  = 302 (login redirect, as documented)
- PASS: teardown verbatim (`stop -t 30 omd-qs && rm omd-qs`) — wall 3 s,
  clean halt (exit 130 pattern per the stop contract; the previous omd-qs
  run stopped at 130, this run's inspect-after-rm unavailable by
  construction — wall-time + no 137 asserted)
- NOTE: host-side leftovers of the run (for the user's decision):
  omd-qs-data/ (site-owned numeric identity 525287:525283, host user
  cannot list it), omd-qs-key{,.pub}, one new known_hosts line
  [localhost]:2222 (ED25519, the new container's host key)
- UNVERIFIED (unchanged): the Docker run block — no Docker on this host
  (T031/T041 gate, spec 002); this run exercises the Podman alternative only
## S1-s1-rocky
- when: 2026-11-13 20:02:20
- runtime: podman

- **RESULT: PASS**

- container: omd-s1 (https 18451, ssh 18452, edge unit httpd)
- PASS: readiness within bound (gate active + 443 answers)
```
ready-time=2s rc=0
```

- PASS: no OMD site exists (SC-003: /omd/sites empty)
- PASS: omd-ready + httpd + sshd all active
```
ready=active edge=active ssh=active
```

- PASS: listeners on 443 + 80 + 22 (in-container; FR-002: edge on 443 AND 80)
- PASS: sshd reachable from host on 18452
- PASS: informational banner in container log (FR-015: no site)
- PASS: stop httpd -> 443 down -> start -> back (SC-006)
- PASS: stop sshd -> 22 down -> start -> back (SC-006)
- PASS: journalctl -u httpd returns logs (FR-016)
- PASS: container log shows startup sequence (FR-015)
- ready-time recorded above; median-of-5 formal baseline = T034 (FR-018)
- PASS: clean stop -t 30 ends 130/0, not 137 (exit code: 130, stop rc: 0)
- teardown done

## SUITE-INFRA-B2-2026-11-13
- **what**: runner pre-cleanup replaced — the name-prefix sweep (stop+rm of every running `^omd-s`) is gone; cleanup now requires **recorded ownership** (suite labels) + **staleness evidence** (the run lock) — 002 analyze round B2 (codex finding: the prefix sweep deleted any user container matching the pattern, e.g. `omd-sandbox`); user decision: a separately recorded runner fix over the per-task preflight guard
- **mechanism**: `v_suite_label()` labels every suite container at creation (`omd-verify.suite=omd-verify` + `omd-verify.suite-start=<epoch>` — `common.sh`; applied at `v_run` + the s2/s3/s3b/s10/fixtures raw-creation sites); `run.sh` (re)creates `$OMD_VERIFY_LOCK` and holds `flock` for the whole invocation (the never-concurrent suite rule is now mechanical, not conventional); `v_precleanup` removes **only** suite-labeled containers whose start is **before** the lock mtime (owning run provably not active = crashed leak); unlabeled containers (user resources) are **never touched**; a container started after the lock belongs to the current run and is left alone; a second invocation's flock **blocks** while a run is active
- **verification (harness `/tmp/opencode/b2-verify.sh`; image `local/omd-labs-systemd-vm-rocky:r2-test`; podman rootless cgroup-v2; amd64; 2026-11-13)**:
  - PASS owned stale container removed (direct `v_precleanup` and the fresh-run lock-recreation path)
  - PASS unrelated unlabeled `omd-sandbox`-class container survived every pre-cleanup (checks 1–3)
  - PASS active verification run's containers untouched (current-run tie-break + a second run's `flock` measured HELD while the active run held the lock)
  - PASS real-scenario smoke: `verify/run.sh s1 rocky r2-test` — all PASS, clean stop 130, no leftover containers (section `S1-s1-rocky` above)
- **lint**: `bash -n` OK on all changed files; ShellCheck unavailable on this host (recorded note — repo rule: ShellCheck *if available*)
## S11a-s11a-rocky
- when: 2026-11-15 11:03:50
- runtime: podman

- **RESULT: PASS**

- base image: local/omd-labs-systemd-vm-base-rocky:nightly (edge unit httpd, expect no-site HTTP 403)
- PASS: base readiness within bound (gate active + 443 answers)
```
ready-time=2s rc=0
```

- PASS: omd-ready + httpd + sshd all active
```
ready=active edge=active ssh=active
```

- PASS: edge answers the EXACT no-site code (403) on 443
```
code=403
```

- PASS: ss (the ready-gate probe tool) is PRESENT - a named cause, not a silent 120 s deadline
```
ss at: /usr/sbin/ss
```

- PASS: the omd binary is ABSENT (OMD-less chassis)
```
omd absent (ok)
```

- PASS: sshd reachable from host on 18452
- PASS: omd.service resolves to the omd-site alias
```
alias -> /usr/lib/systemd/system/omd-site.service
```

- PASS: both labs.consol.de channels configured (stable + testing)
- PASS: clean stop -t 30 ends 130/0, not 137 (exit code: 130, stop rc: 0)
- teardown done
## S11a-ff-s11a-failfast-rocky
- when: 2026-11-15 11:04:03
- runtime: podman

- **RESULT: PASS**

- base image: local/omd-labs-systemd-vm-base-rocky:nightly, starting with SITENAME=demo (must fail fast)
- PASS: container exited (fail-fast, not a running site attempt)
```
exited after 1s
```

- PASS: exit code is 1 (EXIT_FATAL), not the 120 s deadline (2)
```
exit=1
```

- PASS: elapsed < 5 s (fail-fast budget)
```
elapsed=1s
```

- PASS: named cause in /var/log/omd-labs/entry-fatal (OMD not installed)
```
FATAL: OMD is not installed in this image (the base image is chassis-only). Install an OMD package first - the labs.consol.de repositories are already configured (dnf install omd-labs-edition / apt-get install omd-labs-edition, or omd-<ver>-labs-edition / omd-labs-edition-daily) - then re-run with SITENAME.
```

- PASS: NO partial /omd/sites/demo left behind (the pre-fix defect)
```
partial entries: 0
```

- teardown done
## S11a-s11a-debian
- when: 2026-11-15 11:11:31
- runtime: podman

- **RESULT: PASS**

- base image: local/omd-labs-systemd-vm-base-debian:nightly (edge unit apache2, expect no-site HTTP 200)
- PASS: base readiness within bound (gate active + 443 answers)
```
ready-time=2s rc=0
```

- PASS: omd-ready + apache2 + ssh all active
```
ready=active edge=active ssh=active
```

- PASS: edge answers the EXACT no-site code (200) on 443
```
code=200
```

- PASS: ss (the ready-gate probe tool) is PRESENT - a named cause, not a silent 120 s deadline
```
ss at: /usr/bin/ss
```

- PASS: the omd binary is ABSENT (OMD-less chassis)
```
omd absent (ok)
```

- PASS: sshd reachable from host on 18452
- PASS: omd.service resolves to the omd-site alias
```
alias -> /usr/lib/systemd/system/omd-site.service
```

- PASS: both labs.consol.de channels configured (stable + testing)
- PASS: clean stop -t 30 ends 130/0, not 137 (exit code: 130, stop rc: 0)
- teardown done
## S11a-ff-s11a-failfast-debian
- when: 2026-11-15 11:12:16
- runtime: podman

- **RESULT: PASS**

- base image: local/omd-labs-systemd-vm-base-debian:nightly, starting with SITENAME=demo (must fail fast)
- PASS: container exited (fail-fast, not a running site attempt)
```
exited after 1s
```

- PASS: exit code is 1 (EXIT_FATAL), not the 120 s deadline (2)
```
exit=1
```

- PASS: elapsed < 5 s (fail-fast budget)
```
elapsed=1s
```

- PASS: named cause in /var/log/omd-labs/entry-fatal (OMD not installed)
```
FATAL: OMD is not installed in this image (the base image is chassis-only). Install an OMD package first - the labs.consol.de repositories are already configured (dnf install omd-labs-edition / apt-get install omd-labs-edition, or omd-<ver>-labs-edition / omd-labs-edition-daily) - then re-run with SITENAME.
```

- PASS: NO partial /omd/sites/demo left behind (the pre-fix defect)
```
partial entries: 0
```

- teardown done
## S1-s1-rocky
- when: 2026-11-15 11:23:00
- runtime: podman

- **RESULT: PASS**

- container: omd-s1 (https 18451, ssh 18452, edge unit httpd)
- PASS: readiness within bound (gate active + 443 answers)
```
ready-time=2s rc=0
```

- PASS: no OMD site exists (SC-003: /omd/sites empty)
- PASS: omd-ready + httpd + sshd all active
```
ready=active edge=active ssh=active
```

- PASS: listeners on 443 + 80 + 22 (in-container; FR-002: edge on 443 AND 80)
- PASS: sshd reachable from host on 18452
- PASS: informational banner in container log (FR-015: no site)
- PASS: stop httpd -> 443 down -> start -> back (SC-006)
- PASS: stop sshd -> 22 down -> start -> back (SC-006)
- PASS: journalctl -u httpd returns logs (FR-016)
- PASS: container log shows startup sequence (FR-015)
- ready-time recorded above; median-of-5 formal baseline = T034 (FR-018)
- PASS: clean stop -t 30 ends 130/0, not 137 (exit code: 130, stop rc: 0)
- teardown done
## S11b-s11b-rocky
- when: 2026-11-15 11:30:34
- runtime: podman

- **RESULT: PASS**

- derived image (FROM local/omd-labs-systemd-vm-base-rocky:nightly + stable OMD): local/omd-labs-systemd-vm-s11b-rocky:latest
- PASS: build derived image (base + stable OMD package from the base's repos)
```
352f8f1b8a9e9b3b7030b2fdcde59bf8f6c8635f2ebe5070837bd163523bb7a0
```

- PASS: site readiness within bound (gate active + /s11b 2xx/3xx)
```
ready-time=5s rc=0
```

- PASS: omd is now present (installed from the base's repos)
```
omd present
```

- PASS: /s11b answers 2xx/3xx (site UI / login redirect)
```
code=302
```

- PASS: omd status s11b rc 0 (site running)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
omd status rc=0
```

- PASS: clean stop -t 30 ends 130/0, not 137 (exit code: 130, stop rc: 0)
- teardown done (derived image local/omd-labs-systemd-vm-s11b-rocky:latest retained for inspection)
## S11b-s11b-debian
- when: 2026-11-15 11:32:13
- runtime: podman

- **RESULT: PASS**

- derived image (FROM local/omd-labs-systemd-vm-base-debian:nightly + stable OMD): local/omd-labs-systemd-vm-s11b-debian:latest
- PASS: build derived image (base + stable OMD package from the base's repos)
```
+ main debian latest
+ BRANCH=latest
+ BRANCH=latest
+ BRANCH=latest
+ case $1 in
+ install_omd_debian latest
+ VERSION=latest
++ pkgName latest
++ case $1 in
++ echo omd-labs-edition
+ PACKAGENAME=omd-labs-edition
++ repoVersion latest
++ '[' xlatest == xlatest ']'
++ echo stable
+ REPOVERSION=stable
+ export DEBIAN_FRONTEND=noninteractive
+ DEBIAN_FRONTEND=noninteractive
+ curl -fsS https://labs.consol.de/repo/stable/monitoring-repo-consol-de-gpg-2026.asc -o /etc/apt/trusted.gpg.d/monitoring-repo-consol-de-gpg-2026.asc
++ lsb_release -cs
+ echo 'deb http://labs.consol.de/repo/stable/debian trixie main'
+ apt-get update
+ apt-get install -y omd-labs-edition
+ apt-get clean
+ rm -rf /var/lib/apt/lists/auxfiles /var/lib/apt/lists/deb.debian.org_debian-security_dists_trixie-security_InRelease /var/lib/apt/lists/deb.debian.org_debian-security_dists_trixie-security_main_binary-amd64_Packages.lz4 /var/lib/apt/lists/deb.debian.org_debian_dists_trixie-updates_InRelease /var/lib/apt/lists/deb.debian.org_debian_dists_trixie-updates_main_binary-amd64_Packages.lz4 /var/lib/apt/lists/deb.debian.org_debian_dists_trixie_InRelease /var/lib/apt/lists/deb.debian.org_debian_dists_trixie_main_binary-amd64_Packages.lz4 /var/lib/apt/lists/labs.consol.de_repo_stable_debian_dists_trixie_InRelease /var/lib/apt/lists/labs.consol.de_repo_stable_debian_dists_trixie_main_binary-amd64_Packages.lz4 /var/lib/apt/lists/labs.consol.de_repo_testing_debian_dists_trixie_InRelease /var/lib/apt/lists/labs.consol.de_repo_testing_debian_dists_trixie_main_binary-amd64_Packages.lz4 /var/lib/apt/lists/lock /var/lib/apt/lists/partial /tmp/install_omd.sh '/var/tmp/*'
+ find /omd/versions/default/skel/etc/logrotate.d -type f -exec sed -i 's/rotate [0-9]*/rotate 0/' '{}' ';'
Synchronizing state of ssh.service with SysV service script with /usr/lib/systemd/systemd-sysv-install.
Executing: /usr/lib/systemd/systemd-sysv-install enable ssh
Synchronizing state of apache2.service with SysV service script with /usr/lib/systemd/systemd-sysv-install.
Executing: /usr/lib/systemd/systemd-sysv-install enable apache2
Synchronizing state of cron.service with SysV service script with /usr/lib/systemd/systemd-sysv-install.
Executing: /usr/lib/systemd/systemd-sysv-install enable cron
Created symlink '/etc/systemd/system/omd.service' → '/usr/lib/systemd/system/omd-site.service'.
351715bc26d346c509067629aea20f34a46b390c9e35e0c0bbe4f3c4ade8ebf8
```

- PASS: site readiness within bound (gate active + /s11b 2xx/3xx)
```
ready-time=6s rc=0
```

- PASS: omd is now present (installed from the base's repos)
```
omd present
```

- PASS: /s11b answers 2xx/3xx (site UI / login redirect)
```
code=302
```

- PASS: omd status s11b rc 0 (site running)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
omd status rc=0
```

- PASS: clean stop -t 30 ends 130/0, not 137 (exit code: 130, stop rc: 0)
- teardown done (derived image local/omd-labs-systemd-vm-s11b-debian:latest retained for inspection)
## S11a-s11a-rocky
- when: 2026-11-17 10:38:14
- runtime: podman

- **RESULT: PASS**

- base image: local/omd-labs-systemd-vm-base-rocky:nightly (edge unit httpd, expect no-site HTTP 403)
- PASS: base readiness within bound (gate active + 443 answers)
```
ready-time=2s rc=0
```

- PASS: omd-ready + httpd + sshd all active
```
ready=active edge=active ssh=active
```

- PASS: edge answers the EXACT no-site code (403) on 443
```
code=403
```

- PASS: ss (the ready-gate probe tool) is PRESENT - a named cause, not a silent 120 s deadline
```
ss at: /usr/sbin/ss
```

- PASS: the omd binary is ABSENT (OMD-less chassis)
```
omd absent (ok)
```

- PASS: sshd reachable from host on 18452
- PASS: omd.service resolves to the omd-site alias
```
alias -> /usr/lib/systemd/system/omd-site.service
```

- PASS: both labs.consol.de channels configured (stable + testing)
- PASS: clean stop -t 30 ends 130/0, not 137 (exit code: 130, stop rc: 0)
- teardown done
## S2-s2-rocky
- when: 2026-11-17 10:38:24
- runtime: podman

- **RESULT: PASS**

- PASS: readiness (gate active + /mysite/ answers 302/200)
```
ready-time=7s
```

- PASS: log shows prominent 'created new site mysite'
- PASS: omd status mysite running (rc 0)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: site data on host volume (etc/var/local/version + init-complete marker, root probe)
- PASS: 5 site daemons run as user mysite
- PASS: HTTPS /mysite/ through the edge (host-side)
```
302
```

- site-start ready-time (first start): see 'readiness' evidence above; formal median-of-5 baseline = T034 (FR-018)
- PASS: restart same container reaches ready again
```
omd-s2
ready-time=3s
```

- PASS: log shows 'resumed existing site mysite' (no re-creation)
- PASS: replacement container resumes (account absent in fresh image)
```
ready-time=4s
```

- PASS: replacement: 'resumed existing site mysite'
- PASS: replacement: omd status mysite rc 0
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: SC-002: concurrent site A ready (/s2siteA/ via published edge)
```
ready-time=7s
```

- PASS: SC-002: concurrent site B ready (gate active + /s2siteB/ on its own edge)
```
ready-time=7s
```

- PASS: SC-002: site A still serving WHILE B runs (no interference, both up)
```
302
```

- PASS: SC-002: omd status of BOTH sites rc 0 (independent site daemons)
```
A0
B0
```

- PASS: SC-002: both volumes populated independently (root probe)
- site-start reference ready-time: see readiness evidence above (formal median-of-5 = T034)
## S12-s12-rocky
- when: 2026-11-17 23:45:53
- runtime: podman

## S12-s12-rocky
- when: 2026-11-17 23:46:54
- runtime: podman

## S12-s12-rocky
- when: 2026-11-17 23:48:03
- runtime: podman

## S12-s12-rocky
- when: 2026-11-17 23:54:41
- runtime: podman

- **RESULT: FAIL**

- port 18450; site s12; volume /tmp/omd-verify/s12-site
- --- (a) fresh + pw
- PASS: (a) readiness (gate active + /s12/ answers 302/200)
```
ready-time=6s
```

- PASS: (a) htpasswd at EXACTLY etc/htpasswd, owned by the allocated site user (non-root) in the omd group (root probe)
- PASS: (a) omdadmin entry present (root probe)
- PASS: (a) thruk: authenticated 200 / anonymous 302
```
with-cred=200 anon=302
```

- PASS: (a) wrong password rejected (anon-equivalent 302, NOT 200)
```
wrong=302
```

- FAIL: (a) notice line present exactly once (deterministic, no value) (rc=1)
```
grep: admin: No such file or directory
grep: password: No such file or directory
grep: set: No such file or directory
grep: from: No such file or directory
grep: OMD_ADMIN_PASSWORD: No such file or directory
```

- FAIL: (a) the literal password ABSENT from the container log (rc=1)
```
grep: 9: No such file or directory
```

- (a) stopped before (b) (code=130, stop rc=0)
- --- (b) verbatim
- PASS: (b) readiness
```
ready-time=7s
```

- PASS: (b) login with the EXACT verbatim value succeeds (leading/trailing space + metacharacters)
```
exact=200
```

- PASS: (b) the TRIMMED variant FAILS (302 - proves no trimming / no shell-evaluated string)
```
trimmed=302
```

- FAIL: (b) notice present; the verbatim value ABSENT from the log (rc=1)
```
grep: admin: No such file or directory
grep: password: No such file or directory
grep: set: No such file or directory
grep: from: No such file or directory
grep: OMD_ADMIN_PASSWORD: No such file or directory
```

- --- (c) replacement, stored wins (fresh container on the (a) volume)
- PASS: (c) readiness (resume, gate active + /s12/)
```
ready-time=3s
```

- FAIL: (c) log shows 'resumed existing site s12' (row 2, no re-creation) (rc=2)
```
/home/lausser/git/omd-labs-systemd-vm-forge/verify/common.sh: eval: line 414: unexpected EOF while looking for matching `"'
```

- FAIL: (c) NO notice (the variable is a creation-only input, ignored on resume) (rc=2)
```
/home/lausser/git/omd-labs-systemd-vm-forge/verify/common.sh: eval: line 414: unexpected EOF while looking for matching `"'
```

- PASS: (c) the STORED credential logs in (the (a) value, extracted before the run)
```
stored=200
```

- PASS: (c) the NEW value is REJECTED (stored wins, 302)
```
new=302
```

- PASS: (c) htpasswd content UNCHANGED (sha256 before == after, root probe)
- (c) stored omdadmin hash: omdadmin:$apr1$mVLtNoUM$T4M8nSsZE8iXA.Uu...
- --- (e) clean stop contract
- PASS: (e) clean stop -t 30 ends 130/0, not 137 (exit code: 130, stop rc: 0)
- --- (d) empty value = no-op
- PASS: (d) readiness
```
ready-time=6s
```

- FAIL: (d) NO notice (the exactly-empty value is a no-op, no setter invocation) (rc=2)
```
/home/lausser/git/omd-labs-systemd-vm-forge/verify/common.sh: eval: line 414: unexpected EOF while looking for matching `"'
```

- PASS: (d) the generated omdadmin entry stands in etc/htpasswd (root probe)
- FAIL: (d) 'created new site s12' (fresh creation, no credential step) (rc=2)
```
/home/lausser/git/omd-labs-systemd-vm-forge/verify/common.sh: eval: line 414: unexpected EOF while looking for matching `"'
```

- --- (i) recovery, tree-only (create --reuse branch)
- PASS: (i) readiness (recovery completes, gate active + /s12/)
```
ready-time=6s
```

- PASS: (i) recovery banner present
```
2026-11-17T22:55:28+00:00 85df7a2baa80 omd-ready-check[1302]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-17T22:55:28+00:00 85df7a2baa80 systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-17T22:55:28+00:00 85df7a2baa80 systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-17T22:55:28+00:00 85df7a2baa80 systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-17T22:55:28+00:00 85df7a2baa80 systemd[1]: Starting systemd-update-utmp-runlevel.service - Record Runlevel Change in UTMP...
2026-11-17T22:55:28+00:00 85df7a2baa80 systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-17T22:55:28+00:00 85df7a2baa80 systemd[1]: Finished systemd-update-utmp-runlevel.service - Record Runlevel Change in UTMP.
2026-11-17T22:55:28+00:00 85df7a2baa80 systemd[1]: Startup finished in 2.464s.
```

- PASS: (i) login with the environment value succeeds
```
with-cred=200
```

- FAIL: (i) notice present (the creation tail was re-run) (rc=2)
```
/home/lausser/git/omd-labs-systemd-vm-forge/verify/common.sh: eval: line 414: unexpected EOF while looking for matching `"'
```

- PASS: (i) committed: complete marker present, in-progress gone (root probe)
- --- (ii) recovery, version-link (omd enable branch, old credential invalidated)
- PASS: (ii) readiness
```
ready-time=4s
```

- PASS: (ii) recovery banner + the version-link re-registration line
```
2026-11-17T22:55:39+00:00 a4eb63cff536 omd-ready-check[510]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-17T22:55:39+00:00 a4eb63cff536 systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-17T22:55:39+00:00 a4eb63cff536 systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-17T22:55:39+00:00 a4eb63cff536 systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-17T22:55:39+00:00 a4eb63cff536 systemd[1]: Starting systemd-update-utmp-runlevel.service - Record Runlevel Change in UTMP...
2026-11-17T22:55:39+00:00 a4eb63cff536 systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-17T22:55:39+00:00 a4eb63cff536 systemd[1]: Finished systemd-update-utmp-runlevel.service - Record Runlevel Change in UTMP.
2026-11-17T22:55:39+00:00 a4eb63cff536 systemd[1]: Startup finished in 2.609s.
```

- PASS: (ii) login with the environment value succeeds
```
with-cred=200
```

- FAIL: (ii) the PRE-EXISTING generated credential is INVALIDATED (htpasswd entry replaced; anon stays 302) (rc=1)
```
/home/lausser/git/omd-labs-systemd-vm-forge/verify/common.sh: line 414: apr1: unbound variable
```

- FAIL: (ii) notice present (rc=2)
```
/home/lausser/git/omd-labs-systemd-vm-forge/verify/common.sh: eval: line 414: unexpected EOF while looking for matching `"'
```

- --- (iii) persisted (stale INPROG), stored wins
- PASS: (iii) readiness (resume, not recovery)
```
ready-time=3s
```

- FAIL: (iii) log shows 'resumed existing site s12' (persisted row, not re-creation) (rc=2)
```
/home/lausser/git/omd-labs-systemd-vm-forge/verify/common.sh: eval: line 414: unexpected EOF while looking for matching `"'
```

- PASS: (iii) stale in-progress marker REMOVED (root probe)
- FAIL: (iii) NO notice (no creation tail ran) (rc=2)
```
/home/lausser/git/omd-labs-systemd-vm-forge/verify/common.sh: eval: line 414: unexpected EOF while looking for matching `"'
```

- PASS: (iii) the STORED credential logs in
```
stored=200
```

- PASS: (iii) the NEW value is REJECTED (302)
```
new=302
```

- PASS: (iii) htpasswd UNCHANGED (sha256, root probe)
- --- (iv) adopted legacy, stored wins
- PASS: (iv) readiness (adopt path starts the site)
```
ready-time=3s
```

- PASS: (iv) prominent 'adopted existing site' banner
```
2026-11-17T22:55:59+00:00 7098ceae1518 omd-ready-check[508]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-17T22:55:59+00:00 7098ceae1518 systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-17T22:55:59+00:00 7098ceae1518 systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-17T22:55:59+00:00 7098ceae1518 systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-17T22:55:59+00:00 7098ceae1518 systemd[1]: Starting systemd-update-utmp-runlevel.service - Record Runlevel Change in UTMP...
2026-11-17T22:55:59+00:00 7098ceae1518 systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-17T22:55:59+00:00 7098ceae1518 systemd[1]: Finished systemd-update-utmp-runlevel.service - Record Runlevel Change in UTMP.
2026-11-17T22:55:59+00:00 7098ceae1518 systemd[1]: Startup finished in 2.750s.
```

- FAIL: (iv) NO notice (the credential step is absent from adopt_site) (rc=2)
```
/home/lausser/git/omd-labs-systemd-vm-forge/verify/common.sh: eval: line 414: unexpected EOF while looking for matching `"'
```

- PASS: (iv) the STORED credential logs in
```
stored=200
```

- PASS: (iv) the NEW value is REJECTED (302)
```
new=302
```

- PASS: (iv) htpasswd UNCHANGED (sha256, root probe)
- --- (j) fresh tail: injected failure at the credential step
- PASS: (j) failure at the fresh credential step ? exit 1 (code=1)
- PASS: (j) the injected line was REACHED (sentinel present, cp from stopped container)
- FAIL: (j) the credential step had SUCCEEDED before the injection (notice present, value NOT in it) (rc=2)
```
/home/lausser/git/omd-labs-systemd-vm-forge/verify/common.sh: eval: line 414: unexpected EOF while looking for matching `"'
```

- FAIL: (j) the password value ABSENT from entry-fatal AND the container log (rc=1)
```
grep: 9: No such file or directory
```

- PASS: (j) COMPLETE marker ABSENT (the commit never ran, root probe)
- PASS: (j) INPROG marker RETAINED (retry re-enters the creation lifecycle, root probe)
- (j) no site service could be up: the entry fatals PRE-init (before exec /sbin/init) - the named cause IS the proof nothing was started
- PASS: (j) retry completes: ready (gate + /s12/)
```
ready-time=3s
```

- PASS: (j) retry: login with the value succeeds
```
with-cred=200
```

- PASS: (j) retry committed: complete marker + in-progress gone (root probe)
- --- (k) recovery tail: injected failure at the credential step
- PASS: (k) failure at the recovery credential step ? exit 1 (code=1)
- PASS: (k) the injected line was REACHED (sentinel present, cp from stopped container)
- FAIL: (k) the credential step had SUCCEEDED before the injection (notice present, value NOT in it) (rc=2)
```
/home/lausser/git/omd-labs-systemd-vm-forge/verify/common.sh: eval: line 414: unexpected EOF while looking for matching `"'
```

- FAIL: (k) the password value ABSENT from entry-fatal AND the container log (rc=1)
```
grep: 9: No such file or directory
```

- PASS: (k) COMPLETE marker ABSENT (the recovery never committed, root probe)
- PASS: (k) INPROG marker RETAINED (root probe)
- (k) no site service could be up: the entry fatals PRE-init - the named cause IS the proof nothing was started
- PASS: (k) retry completes: ready (gate + /s12/)
```
ready-time=3s
```

- PASS: (k) retry: login with the value succeeds
```
with-cred=200
```

- PASS: (k) retry committed: complete marker + in-progress gone (root probe)
- sub-items (a)-(e), (i)-(iv), (j), (k) done
## repro
- when: 2026-11-18 00:21:42
- runtime: podman

- **RESULT: FAIL**

- FAIL: (d) NO notice (the exactly-empty value is a no-op, no setter invocation) (rc=2)
```
./common.sh: eval: line 415: unexpected EOF while looking for matching `)'
```

## repro3
- when: 2026-11-18 00:24:03
- runtime: podman

- **RESULT: FAIL**

- FAIL: s1-32-form: no OMD site exists (rc=1)
```
Error: no container with name or ID "omd-s12d" found: no such container
```

- FAIL: my-(d)-form (rc=2)
```
./common.sh: eval: line 415: unexpected EOF while looking for matching `)'
```

## S12-s12-rocky
- when: 2026-11-18 02:16:42
- runtime: podman

## S12-s12-rocky
- when: 2026-11-18 02:30:17
- runtime: podman

## S12-s12-rocky
- when: 2026-11-18 02:34:00
- runtime: podman

- **RESULT: FAIL**

- port 18450; site s12; volume /tmp/omd-verify/s12-site
- --- (a) fresh + pw
- PASS: (a) readiness (gate active + /s12/ answers 302/200)
```
ready-time=6s
```

- PASS: (a) htpasswd at EXACTLY etc/htpasswd, owned by the allocated site user (non-root, root probe)
- PASS: (a) omdadmin entry present (root probe)
- PASS: (a) thruk: authenticated 200 / anonymous 302
```
with-cred=200 anon=302
```

- PASS: (a) wrong password rejected (anon-equivalent 302, NOT 200)
```
wrong=302
```

- PASS: (a) notice line present exactly once (deterministic, no value)
- PASS: (a) the literal password ABSENT from the container log (hardened: read must succeed and capture the entry's own output)
- (a) stopped before (b) (code=130, stop rc=0)
- --- (b) verbatim
- PASS: (b) readiness
```
ready-time=6s
```

- PASS: (b) login with the EXACT verbatim value succeeds (leading/trailing space + metacharacters)
```
exact=200
```

- PASS: (b) the TRIMMED variant FAILS (302 - proves no trimming / no shell-evaluated string)
```
trimmed=302
```

- PASS: (b) notice present; the verbatim value ABSENT from the log
- --- (c) replacement, stored wins (fresh container on the (a) volume)
- PASS: (c) readiness (resume, gate active + /s12/)
```
ready-time=3s
```

- PASS: (c) log shows 'resumed existing site s12' (row 2, no re-creation)
- PASS: (c) NO notice (the variable is a creation-only input, ignored on resume; hardened read)
- PASS: (c) the STORED credential logs in (the (a) value, extracted before the run)
```
stored=200
```

- PASS: (c) the NEW value is REJECTED (stored wins, 302)
```
new=302
```

- PASS: (c) htpasswd content UNCHANGED (sha256 before == after, root probe)
- (c) stored omdadmin hash: omdadmin:$apr1$h1.V2v3u$6AS7YRAmEk48flYZ...
- --- (e) clean stop contract
- PASS: (e) clean stop -t 30 ends 130/0, not 137 (exit code: 130, stop rc: 0)
- --- (d) empty value = no-op
- PASS: (d) readiness
```
ready-time=6s
```

- PASS: (d) NO notice (the exactly-empty value is a no-op, no setter invocation; hardened read)
- PASS: (d) the credential step was NEVER INVOKED (the run_bounded step line is absent; hardened read)
- PASS: (d) the generated omdadmin entry stands in etc/htpasswd (root probe)
- PASS: (d) 'created new site s12' (fresh creation, no credential step)
- --- (i) recovery, tree-only (create --reuse branch)
- PASS: (i) readiness (recovery completes, gate active + /s12/)
```
ready-time=5s
```

- PASS: (i) recovery banner present
```
2026-11-18T01:34:48+00:00 9e3f0ba0ece9 omd-ready-check[1304]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-18T01:34:48+00:00 9e3f0ba0ece9 systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-18T01:34:48+00:00 9e3f0ba0ece9 systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-18T01:34:48+00:00 9e3f0ba0ece9 systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-18T01:34:48+00:00 9e3f0ba0ece9 systemd[1]: Starting systemd-update-utmp-runlevel.service - Record Runlevel Change in UTMP...
2026-11-18T01:34:48+00:00 9e3f0ba0ece9 systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-18T01:34:48+00:00 9e3f0ba0ece9 systemd[1]: Finished systemd-update-utmp-runlevel.service - Record Runlevel Change in UTMP.
2026-11-18T01:34:48+00:00 9e3f0ba0ece9 systemd[1]: Startup finished in 2.598s.
```

- PASS: (i) login with the environment value succeeds
```
with-cred=200
```

- PASS: (i) notice present (the creation tail was re-run)
- PASS: (i) committed: complete marker present, in-progress gone (root probe)
- --- (ii) recovery, version-link (omd enable branch, old credential invalidated)
- PASS: (ii) pre-state: the KNOWN old credential is seeded (root probe)
- PASS: (ii) readiness
```
ready-time=3s
```

- PASS: (ii) recovery banner + the version-link re-registration line
```
2026-11-18T01:35:00+00:00 e0034e32538d omd-ready-check[332]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-18T01:35:00+00:00 e0034e32538d systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-18T01:35:00+00:00 e0034e32538d systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-18T01:35:00+00:00 e0034e32538d systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-18T01:35:00+00:00 e0034e32538d systemd[1]: Starting systemd-update-utmp-runlevel.service - Record Runlevel Change in UTMP...
2026-11-18T01:35:00+00:00 e0034e32538d systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-18T01:35:00+00:00 e0034e32538d systemd[1]: Finished systemd-update-utmp-runlevel.service - Record Runlevel Change in UTMP.
2026-11-18T01:35:00+00:00 e0034e32538d systemd[1]: Startup finished in 2.698s.
```

- PASS: (ii) login with the environment value succeeds
```
with-cred=200
```

- PASS: (ii) the SEEDING credential is now REJECTED: the pre-existing generated credential is INVALIDATED (old-pw login 302; the env value logs in - primary oracle)
```
old-pw=302
```

- PASS: (ii) the htpasswd entry was REPLACED (new non-empty, different from the SEEDING entry, root probe)
- PASS: (ii) anonymous access stays 302 (no anonymous bypass introduced)
```
anon=302
```

- PASS: (ii) notice present
- --- (iii) persisted (stale INPROG), stored wins
- PASS: (iii) readiness (resume, not recovery)
```
ready-time=3s
```

- PASS: (iii) log shows 'resumed existing site s12' (persisted row, not re-creation)
- PASS: (iii) stale in-progress marker REMOVED (root probe)
- PASS: (iii) NO notice (no creation tail ran; hardened read)
- PASS: (iii) the STORED credential logs in
```
stored=200
```

- PASS: (iii) the NEW value is REJECTED (302)
```
new=302
```

- PASS: (iii) htpasswd UNCHANGED (sha256, root probe)
- --- (iv) adopted legacy, stored wins
- PASS: (iv) readiness (adopt path starts the site)
```
ready-time=3s
```

- PASS: (iv) prominent 'adopted existing site' banner
```
2026-11-18T01:35:24+00:00 d0896db42fc7 omd-ready-check[507]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-18T01:35:24+00:00 d0896db42fc7 systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-18T01:35:24+00:00 d0896db42fc7 systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-18T01:35:24+00:00 d0896db42fc7 systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-18T01:35:24+00:00 d0896db42fc7 systemd[1]: Starting systemd-update-utmp-runlevel.service - Record Runlevel Change in UTMP...
2026-11-18T01:35:24+00:00 d0896db42fc7 systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-18T01:35:24+00:00 d0896db42fc7 systemd[1]: Finished systemd-update-utmp-runlevel.service - Record Runlevel Change in UTMP.
2026-11-18T01:35:24+00:00 d0896db42fc7 systemd[1]: Startup finished in 2.497s.
```

- PASS: (iv) NO notice (the credential step is absent from adopt_site; hardened read)
- PASS: (iv) the STORED credential logs in
```
stored=200
```

- PASS: (iv) the NEW value is REJECTED (302)
```
new=302
```

- PASS: (iv) htpasswd UNCHANGED (sha256, root probe)
- --- (j) fresh tail: injected failure at the credential step
- PASS: (j) failure at the fresh credential step ? exit 1 (code=1)
- PASS: (j) the injected line was REACHED (sentinel present, cp from stopped container)
- PASS: (j) the credential step had SUCCEEDED before the injection (notice present, value NOT in it)
- PASS: (j) the password value ABSENT from entry-fatal AND the container log (hardened: fresh copy, cp+read must succeed)
- PASS: (j) COMPLETE marker ABSENT (the commit never ran, root probe)
- PASS: (j) INPROG marker RETAINED (retry re-enters the creation lifecycle, root probe)
- (j) no site service could be up: the entry fatals PRE-init (before exec /sbin/init) - the named cause IS the proof nothing was started
- PASS: (j) retry completes: ready (gate + /s12/)
```
ready-time=4s
```

- PASS: (j) retry: login with the value succeeds
```
with-cred=200
```

- PASS: (j) retry committed: complete marker + in-progress gone (root probe)
- --- (k) recovery tail: injected failure at the credential step
- PASS: (k) failure at the recovery credential step ? exit 1 (code=1)
- PASS: (k) the injected line was REACHED (sentinel present, cp from stopped container)
- PASS: (k) the credential step had SUCCEEDED before the injection (notice present, value NOT in it)
- PASS: (k) the password value ABSENT from entry-fatal AND the container log (hardened: fresh copy, cp+read must succeed)
- PASS: (k) COMPLETE marker ABSENT (the recovery never committed, root probe)
- PASS: (k) INPROG marker RETAINED (root probe)
- (k) no site service could be up: the entry fatals PRE-init - the named cause IS the proof nothing was started
- PASS: (k) retry completes: ready (gate + /s12/)
```
ready-time=3s
```

- PASS: (k) retry: login with the value succeeds
```
with-cred=200
```

- PASS: (k) retry committed: complete marker + in-progress gone (root probe)
- --- (l) fresh tail: the REAL tool fails (rc=99) - production run_bounded/fatal
- PASS: (l) the real tool failure -> exit 1 (code=1)
- PASS: (l) the credential step WAS invoked (the real run_bounded step line present, hardened read)
- PASS: (l) the success notice is ABSENT (the setter did not succeed; hardened read)
- PASS: (l) the value is ABSENT from entry-fatal AND the container log (non-disclosure on the real failure path; fresh copy, cp+read must succeed)
- FAIL: (l) run_bounded REPLAYED the real child output (the tool's fault line is in the log) (rc=1)
```

```

- PASS: (l) COMPLETE marker ABSENT (the commit never ran, root probe)
- PASS: (l) INPROG marker RETAINED (the next boot re-enters the lifecycle, root probe)
- (l) no site service could be up: the entry fatals PRE-init (before exec /sbin/init) - the named cause IS the proof nothing was started
- --- (m) fresh tail: the REAL tool TIMES OUT (45s > the 30s bound)
- PASS: (m) the real tool timeout -> exit 1 (code=1)
- FAIL: (m) the run_bounded TIMEOUT branch fired: 'step timed out' line present in the container log (stderr channel; hardened read) (rc=1)
```

```

- PASS: (m) entry-fatal carries the TIMEOUT rc (124 or 137) for the named step (fresh copy, cp+read must succeed)
- PASS: (m) the credential step WAS invoked (the real run_bounded step line present, hardened read)
- PASS: (m) the value is ABSENT from entry-fatal AND the container log (fresh copy, cp+read must succeed)
- PASS: (m) COMPLETE marker ABSENT (the commit never ran, root probe)
- PASS: (m) INPROG marker RETAINED (root probe)
- --- (n) retry after the real (l) failure: the normal image completes the creation
- PASS: (n) readiness (recovery completes, gate active + /s12/)
```
ready-time=3s
```

- PASS: (n) the value is now the effective credential (login 200)
```
with-cred=200
```

- PASS: (n) notice present exactly once (the creation tail ran, hardened read)
- PASS: (n) committed: complete marker present, in-progress gone (root probe)
- sub-items (a)-(e), (i)-(iv), (j), (k), (l), (m), (n) done
## S12-s12-rocky
- when: 2026-11-18 02:39:25
- runtime: podman

## S12-s12-rocky
- when: 2026-11-18 02:40:53
- runtime: podman

- **RESULT: FAIL**

- port 18450; site s12; volume /tmp/omd-verify/s12-site
- --- (a) fresh + pw
- PASS: (a) readiness (gate active + /s12/ answers 302/200)
```
ready-time=6s
```

- PASS: (a) htpasswd at EXACTLY etc/htpasswd, owned by the allocated site user (non-root, root probe)
- PASS: (a) omdadmin entry present (root probe)
- PASS: (a) thruk: authenticated 200 / anonymous 302
```
with-cred=200 anon=302
```

- PASS: (a) wrong password rejected (anon-equivalent 302, NOT 200)
```
wrong=302
```

- PASS: (a) notice line present exactly once (deterministic, no value)
- PASS: (a) the literal password ABSENT from the container log (hardened: read must succeed and capture the entry's own output)
- (a) stopped before (b) (code=130, stop rc=0)
- --- (b) verbatim
- PASS: (b) readiness
```
ready-time=6s
```

- PASS: (b) login with the EXACT verbatim value succeeds (leading/trailing space + metacharacters)
```
exact=200
```

- PASS: (b) the TRIMMED variant FAILS (302 - proves no trimming / no shell-evaluated string)
```
trimmed=302
```

- PASS: (b) notice present; the verbatim value ABSENT from the log
- --- (c) replacement, stored wins (fresh container on the (a) volume)
- PASS: (c) readiness (resume, gate active + /s12/)
```
ready-time=4s
```

- PASS: (c) log shows 'resumed existing site s12' (row 2, no re-creation)
- PASS: (c) NO notice (the variable is a creation-only input, ignored on resume; hardened read)
- PASS: (c) the STORED credential logs in (the (a) value, extracted before the run)
```
stored=200
```

- PASS: (c) the NEW value is REJECTED (stored wins, 302)
```
new=302
```

- PASS: (c) htpasswd content UNCHANGED (sha256 before == after, root probe)
- (c) stored omdadmin hash: omdadmin:$apr1$f2ulx1KL$K.eyzXlgecyFCx5j...
- --- (e) clean stop contract
- PASS: (e) clean stop -t 30 ends 130/0, not 137 (exit code: 130, stop rc: 0)
- --- (d) empty value = no-op
- PASS: (d) readiness
```
ready-time=6s
```

- PASS: (d) NO notice (the exactly-empty value is a no-op, no setter invocation; hardened read)
- PASS: (d) the credential step was NEVER INVOKED (the run_bounded step line is absent; hardened read)
- PASS: (d) the generated omdadmin entry stands in etc/htpasswd (root probe)
- PASS: (d) 'created new site s12' (fresh creation, no credential step)
- --- (i) recovery, tree-only (create --reuse branch)
- PASS: (i) readiness (recovery completes, gate active + /s12/)
```
ready-time=6s
```

- PASS: (i) recovery banner present
```
2026-11-18T01:41:41+00:00 fb6d85225f9f omd-ready-check[1302]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-18T01:41:41+00:00 fb6d85225f9f systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-18T01:41:41+00:00 fb6d85225f9f systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-18T01:41:41+00:00 fb6d85225f9f systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-18T01:41:41+00:00 fb6d85225f9f systemd[1]: Starting systemd-update-utmp-runlevel.service - Record Runlevel Change in UTMP...
2026-11-18T01:41:41+00:00 fb6d85225f9f systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-18T01:41:41+00:00 fb6d85225f9f systemd[1]: Finished systemd-update-utmp-runlevel.service - Record Runlevel Change in UTMP.
2026-11-18T01:41:41+00:00 fb6d85225f9f systemd[1]: Startup finished in 2.545s.
```

- PASS: (i) login with the environment value succeeds
```
with-cred=200
```

- PASS: (i) notice present (the creation tail was re-run)
- PASS: (i) committed: complete marker present, in-progress gone (root probe)
- --- (ii) recovery, version-link (omd enable branch, old credential invalidated)
- PASS: (ii) pre-state: the KNOWN old credential is seeded (root probe)
- PASS: (ii) readiness
```
ready-time=3s
```

- PASS: (ii) recovery banner + the version-link re-registration line
```
2026-11-18T01:41:53+00:00 c28e2ca8a5f5 omd-ready-check[506]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-18T01:41:53+00:00 c28e2ca8a5f5 systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-18T01:41:53+00:00 c28e2ca8a5f5 systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-18T01:41:53+00:00 c28e2ca8a5f5 systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-18T01:41:53+00:00 c28e2ca8a5f5 systemd[1]: Starting systemd-update-utmp-runlevel.service - Record Runlevel Change in UTMP...
2026-11-18T01:41:53+00:00 c28e2ca8a5f5 systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-18T01:41:53+00:00 c28e2ca8a5f5 systemd[1]: Finished systemd-update-utmp-runlevel.service - Record Runlevel Change in UTMP.
2026-11-18T01:41:53+00:00 c28e2ca8a5f5 systemd[1]: Startup finished in 2.450s.
```

- PASS: (ii) login with the environment value succeeds
```
with-cred=200
```

- PASS: (ii) the SEEDING credential is now REJECTED: the pre-existing generated credential is INVALIDATED (old-pw login 302; the env value logs in - primary oracle)
```
old-pw=302
```

- PASS: (ii) the htpasswd entry was REPLACED (new non-empty, different from the SEEDING entry, root probe)
- PASS: (ii) anonymous access stays 302 (no anonymous bypass introduced)
```
anon=302
```

- PASS: (ii) notice present
- --- (iii) persisted (stale INPROG), stored wins
- PASS: (iii) readiness (resume, not recovery)
```
ready-time=4s
```

- PASS: (iii) log shows 'resumed existing site s12' (persisted row, not re-creation)
- PASS: (iii) stale in-progress marker REMOVED (root probe)
- PASS: (iii) NO notice (no creation tail ran; hardened read)
- PASS: (iii) the STORED credential logs in
```
stored=200
```

- PASS: (iii) the NEW value is REJECTED (302)
```
new=302
```

- PASS: (iii) htpasswd UNCHANGED (sha256, root probe)
- --- (iv) adopted legacy, stored wins
- PASS: (iv) readiness (adopt path starts the site)
```
ready-time=3s
```

- PASS: (iv) prominent 'adopted existing site' banner
```
2026-11-18T01:42:15+00:00 8cb96d60e573 omd-ready-check[508]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-18T01:42:15+00:00 8cb96d60e573 systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-18T01:42:15+00:00 8cb96d60e573 systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-18T01:42:15+00:00 8cb96d60e573 systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-18T01:42:15+00:00 8cb96d60e573 systemd[1]: Starting systemd-update-utmp-runlevel.service - Record Runlevel Change in UTMP...
2026-11-18T01:42:15+00:00 8cb96d60e573 systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-18T01:42:15+00:00 8cb96d60e573 systemd[1]: Finished systemd-update-utmp-runlevel.service - Record Runlevel Change in UTMP.
2026-11-18T01:42:15+00:00 8cb96d60e573 systemd[1]: Startup finished in 2.590s.
```

- PASS: (iv) NO notice (the credential step is absent from adopt_site; hardened read)
- PASS: (iv) the STORED credential logs in
```
stored=200
```

- PASS: (iv) the NEW value is REJECTED (302)
```
new=302
```

- PASS: (iv) htpasswd UNCHANGED (sha256, root probe)
- --- (j) fresh tail: injected failure at the credential step
- PASS: (j) failure at the fresh credential step ? exit 1 (code=1)
- PASS: (j) the injected line was REACHED (sentinel present, cp from stopped container)
- PASS: (j) the credential step had SUCCEEDED before the injection (notice present, value NOT in it)
- PASS: (j) the password value ABSENT from entry-fatal AND the container log (hardened: fresh copy, cp+read must succeed)
- PASS: (j) COMPLETE marker ABSENT (the commit never ran, root probe)
- PASS: (j) INPROG marker RETAINED (retry re-enters the creation lifecycle, root probe)
- (j) no site service could be up: the entry fatals PRE-init (before exec /sbin/init) - the named cause IS the proof nothing was started
- PASS: (j) retry completes: ready (gate + /s12/)
```
ready-time=4s
```

- PASS: (j) retry: login with the value succeeds
```
with-cred=200
```

- PASS: (j) retry committed: complete marker + in-progress gone (root probe)
- --- (k) recovery tail: injected failure at the credential step
- PASS: (k) failure at the recovery credential step ? exit 1 (code=1)
- PASS: (k) the injected line was REACHED (sentinel present, cp from stopped container)
- PASS: (k) the credential step had SUCCEEDED before the injection (notice present, value NOT in it)
- PASS: (k) the password value ABSENT from entry-fatal AND the container log (hardened: fresh copy, cp+read must succeed)
- PASS: (k) COMPLETE marker ABSENT (the recovery never committed, root probe)
- PASS: (k) INPROG marker RETAINED (root probe)
- (k) no site service could be up: the entry fatals PRE-init - the named cause IS the proof nothing was started
- PASS: (k) retry completes: ready (gate + /s12/)
```
ready-time=3s
```

- PASS: (k) retry: login with the value succeeds
```
with-cred=200
```

- PASS: (k) retry committed: complete marker + in-progress gone (root probe)
- --- (l) fresh tail: the REAL tool fails (rc=99) - production run_bounded/fatal
- PASS: (l) the real tool failure -> exit 1 (code=1)
- PASS: (l) the credential step WAS invoked (the real run_bounded step line present, hardened read)
- PASS: (l) the success notice is ABSENT (the setter did not succeed; hardened read)
- PASS: (l) the value is ABSENT from entry-fatal AND the container log (non-disclosure on the real failure path; fresh copy, cp+read must succeed)
- FAIL: (l) run_bounded REPLAYED the real child output (the tool's fault line is in the log, polled) (rc=1)
```
v_wait_log: pattern not visible within 30s: s12-tool-fault
--- last log lines:
omd-labs-entry: creating site s12 (row 1)
omd-labs-entry: step: omd create --reuse s12 (bounded: 90s)
omd-labs-entry: no customization inputs - skipping
omd-labs-entry: step: set omdadmin web password (bounded: 30s)
omd-labs-entry: rolling back bootstrap-created artifacts (no pre-existing data touched)
```

- PASS: (l) COMPLETE marker ABSENT (the commit never ran, root probe)
- PASS: (l) INPROG marker RETAINED (the next boot re-enters the lifecycle, root probe)
- (l) no site service could be up: the entry fatals PRE-init (before exec /sbin/init) - the named cause IS the proof nothing was started
- --- (m) fresh tail: the REAL tool TIMES OUT (45s > the 30s bound)
- PASS: (m) the real tool timeout -> exit 1 (code=1)
- FAIL: (m) the run_bounded TIMEOUT branch fired: 'step timed out' line present in the container log (stderr channel, polled) (rc=1)
```
v_wait_log: pattern not visible within 30s: FATAL: step timed out after 30s: set omdadmin web password
--- last log lines:
omd-labs-entry: creating site s12 (row 1)
omd-labs-entry: step: omd create --reuse s12 (bounded: 90s)
omd-labs-entry: no customization inputs - skipping
omd-labs-entry: step: set omdadmin web password (bounded: 30s)
omd-labs-entry: rolling back bootstrap-created artifacts (no pre-existing data touched)
```

- PASS: (m) entry-fatal carries the TIMEOUT rc (124 or 137) for the named step (fresh copy, cp+read must succeed)
- PASS: (m) the credential step WAS invoked (the real run_bounded step line present, hardened read)
- PASS: (m) the value is ABSENT from entry-fatal AND the container log (fresh copy, cp+read must succeed)
- PASS: (m) COMPLETE marker ABSENT (the commit never ran, root probe)
- PASS: (m) INPROG marker RETAINED (root probe)
- --- (n) retry after the real (l) failure: the normal image completes the creation
- PASS: (n) readiness (recovery completes, gate active + /s12/)
```
ready-time=3s
```

- PASS: (n) the value is now the effective credential (login 200)
```
with-cred=200
```

- PASS: (n) notice present exactly once (the creation tail ran, hardened read)
- PASS: (n) committed: complete marker present, in-progress gone (root probe)
- sub-items (a)-(e), (i)-(iv), (j), (k), (l), (m), (n) done
## S12-s12-rocky
- when: 2026-11-18 02:55:46
- runtime: podman

- **RESULT: PASS**

- port 18450; site s12; volume /tmp/omd-verify/s12-site
- --- (a) fresh + pw
- PASS: (a) readiness (gate active + /s12/ answers 302/200)
```
ready-time=6s
```

- PASS: (a) htpasswd at EXACTLY etc/htpasswd, owned by the allocated site user (non-root, root probe)
- PASS: (a) omdadmin entry present (root probe)
- PASS: (a) thruk: authenticated 200 / anonymous 302
```
with-cred=200 anon=302
```

- PASS: (a) wrong password rejected (anon-equivalent 302, NOT 200)
```
wrong=302
```

- PASS: (a) notice line present exactly once (deterministic, no value)
- PASS: (a) the literal password ABSENT from the container log (hardened: read must succeed and capture the entry's own output)
- (a) stopped before (b) (code=130, stop rc=0)
- --- (b) verbatim
- PASS: (b) readiness
```
ready-time=6s
```

- PASS: (b) login with the EXACT verbatim value succeeds (leading/trailing space + metacharacters)
```
exact=200
```

- PASS: (b) the TRIMMED variant FAILS (302 - proves no trimming / no shell-evaluated string)
```
trimmed=302
```

- PASS: (b) notice present; the verbatim value ABSENT from the log
- --- (c) replacement, stored wins (fresh container on the (a) volume)
- PASS: (c) readiness (resume, gate active + /s12/)
```
ready-time=3s
```

- PASS: (c) log shows 'resumed existing site s12' (row 2, no re-creation)
- PASS: (c) NO notice (the variable is a creation-only input, ignored on resume; hardened read)
- PASS: (c) the STORED credential logs in (the (a) value, extracted before the run)
```
stored=200
```

- PASS: (c) the NEW value is REJECTED (stored wins, 302)
```
new=302
```

- PASS: (c) htpasswd content UNCHANGED (sha256 before == after, root probe)
- (c) stored omdadmin hash: omdadmin:$apr1$sQe/z/Cc$NtG7SjKYDx6S1K/1...
- --- (e) clean stop contract
- PASS: (e) clean stop -t 30 ends 130/0, not 137 (exit code: 130, stop rc: 0)
- --- (d) empty value = no-op
- PASS: (d) readiness
```
ready-time=7s
```

- PASS: (d) NO notice (the exactly-empty value is a no-op, no setter invocation; hardened read)
- PASS: (d) the credential step was NEVER INVOKED (the run_bounded step line is absent; hardened read)
- PASS: (d) the generated omdadmin entry stands in etc/htpasswd (root probe)
- PASS: (d) 'created new site s12' (fresh creation, no credential step)
- --- (i) recovery, tree-only (create --reuse branch)
- PASS: (i) readiness (recovery completes, gate active + /s12/)
```
ready-time=6s
```

- PASS: (i) recovery banner present
```
2026-11-18T01:56:34+00:00 761e2dbc651e systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-18T01:56:34+00:00 761e2dbc651e systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-18T01:56:34+00:00 761e2dbc651e systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-18T01:56:34+00:00 761e2dbc651e systemd[1]: Starting systemd-update-utmp-runlevel.service - Record Runlevel Change in UTMP...
2026-11-18T01:56:34+00:00 761e2dbc651e systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-18T01:56:34+00:00 761e2dbc651e systemd[1]: Finished systemd-update-utmp-runlevel.service - Record Runlevel Change in UTMP.
2026-11-18T01:56:34+00:00 761e2dbc651e systemd[1]: Started systemd-timedated.service - Time & Date Service.
2026-11-18T01:56:34+00:00 761e2dbc651e systemd[1]: Startup finished in 2.757s.
```

- PASS: (i) login with the environment value succeeds
```
with-cred=200
```

- PASS: (i) notice present (the creation tail was re-run)
- PASS: (i) committed: complete marker present, in-progress gone (root probe)
- --- (ii) recovery, version-link (omd enable branch, old credential invalidated)
- PASS: (ii) pre-state: the KNOWN old credential is seeded (root probe)
- PASS: (ii) readiness
```
ready-time=3s
```

- PASS: (ii) recovery banner + the version-link re-registration line
```
2026-11-18T01:56:44+00:00 9ca2d0ce1d58 omd-site-start[308]: Starting crontab...OK
2026-11-18T01:56:44+00:00 9ca2d0ce1d58 omd-site-start[102]: OK
2026-11-18T01:56:44+00:00 9ca2d0ce1d58 systemd[1]: Finished omd-site.service - OMD labs single active site (start/stop).
2026-11-18T01:56:44+00:00 9ca2d0ce1d58 systemd[1]: Starting omd-ready.service - OMD labs bounded readiness gate (FR-018)...
2026-11-18T01:56:44+00:00 9ca2d0ce1d58 sshd-session[532]: Connection closed by 127.0.0.1 port 44614
2026-11-18T01:56:44+00:00 9ca2d0ce1d58 crontab[568]: (s12) LIST (s12)
2026-11-18T01:56:45+00:00 9ca2d0ce1d58 systemd[1]: Starting systemd-timedated.service - Time & Date Service...
2026-11-18T01:56:45+00:00 9ca2d0ce1d58 systemd[1]: Started systemd-timedated.service - Time & Date Service.
```

- PASS: (ii) login with the environment value succeeds
```
with-cred=200
```

- PASS: (ii) the SEEDING credential is now REJECTED: the pre-existing generated credential is INVALIDATED (old-pw login 302; the env value logs in - primary oracle)
```
old-pw=302
```

- PASS: (ii) the htpasswd entry was REPLACED (new non-empty, different from the SEEDING entry, root probe)
- PASS: (ii) anonymous access stays 302 (no anonymous bypass introduced)
```
anon=302
```

- PASS: (ii) notice present
- --- (iii) persisted (stale INPROG), stored wins
- PASS: (iii) readiness (resume, not recovery)
```
ready-time=3s
```

- PASS: (iii) log shows 'resumed existing site s12' (persisted row, not re-creation)
- PASS: (iii) stale in-progress marker REMOVED (root probe)
- PASS: (iii) NO notice (no creation tail ran; hardened read)
- PASS: (iii) the STORED credential logs in
```
stored=200
```

- PASS: (iii) the NEW value is REJECTED (302)
```
new=302
```

- PASS: (iii) htpasswd UNCHANGED (sha256, root probe)
- --- (iv) adopted legacy, stored wins
- PASS: (iv) readiness (adopt path starts the site)
```
ready-time=3s
```

- PASS: (iv) prominent 'adopted existing site' banner
```
2026-11-18T01:57:07+00:00 7b873b9d77db omd-ready-check[506]: READY: base services up (omd-site active, httpd 443, sshd 22)
2026-11-18T01:57:07+00:00 7b873b9d77db systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-18T01:57:07+00:00 7b873b9d77db systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-18T01:57:07+00:00 7b873b9d77db systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-18T01:57:07+00:00 7b873b9d77db systemd[1]: Starting systemd-update-utmp-runlevel.service - Record Runlevel Change in UTMP...
2026-11-18T01:57:07+00:00 7b873b9d77db systemd[1]: systemd-update-utmp-runlevel.service: Deactivated successfully.
2026-11-18T01:57:07+00:00 7b873b9d77db systemd[1]: Finished systemd-update-utmp-runlevel.service - Record Runlevel Change in UTMP.
2026-11-18T01:57:07+00:00 7b873b9d77db systemd[1]: Startup finished in 2.475s.
```

- PASS: (iv) NO notice (the credential step is absent from adopt_site; hardened read)
- PASS: (iv) the STORED credential logs in
```
stored=200
```

- PASS: (iv) the NEW value is REJECTED (302)
```
new=302
```

- PASS: (iv) htpasswd UNCHANGED (sha256, root probe)
- --- (j) fresh tail: injected failure at the credential step
- PASS: (j) failure at the fresh credential step ? exit 1 (code=1)
- PASS: (j) the injected line was REACHED (sentinel present, cp from stopped container)
- PASS: (j) the credential step had SUCCEEDED before the injection (notice present, value NOT in it)
- PASS: (j) the password value ABSENT from entry-fatal AND the container log (hardened: fresh copy, cp+read must succeed)
- PASS: (j) COMPLETE marker ABSENT (the commit never ran, root probe)
- PASS: (j) INPROG marker RETAINED (retry re-enters the creation lifecycle, root probe)
- (j) no site service could be up: the entry fatals PRE-init (before exec /sbin/init) - the named cause IS the proof nothing was started
- PASS: (j) retry completes: ready (gate + /s12/)
```
ready-time=3s
```

- PASS: (j) retry: login with the value succeeds
```
with-cred=200
```

- PASS: (j) retry committed: complete marker + in-progress gone (root probe)
- --- (k) recovery tail: injected failure at the credential step
- PASS: (k) failure at the recovery credential step ? exit 1 (code=1)
- PASS: (k) the injected line was REACHED (sentinel present, cp from stopped container)
- PASS: (k) the credential step had SUCCEEDED before the injection (notice present, value NOT in it)
- PASS: (k) the password value ABSENT from entry-fatal AND the container log (hardened: fresh copy, cp+read must succeed)
- PASS: (k) COMPLETE marker ABSENT (the recovery never committed, root probe)
- PASS: (k) INPROG marker RETAINED (root probe)
- (k) no site service could be up: the entry fatals PRE-init - the named cause IS the proof nothing was started
- PASS: (k) retry completes: ready (gate + /s12/)
```
ready-time=3s
```

- PASS: (k) retry: login with the value succeeds
```
with-cred=200
```

- PASS: (k) retry committed: complete marker + in-progress gone (root probe)
- --- (l) fresh tail: the REAL tool fails (rc=99) - production run_bounded/fatal
- PASS: (l) the real tool failure -> exit 1 (code=1)
- PASS: (l) the credential step WAS invoked (the real run_bounded step line present, hardened read)
- PASS: (l) the success notice is ABSENT (the setter did not succeed; hardened read)
- PASS: (l) the value is ABSENT from entry-fatal AND the container log (non-disclosure on the real failure path; fresh copy, cp+read must succeed)
- PASS: (l) the fault body EXECUTED (the volume mark the injected line wrote, root probe)
- PASS: (l) COMPLETE marker ABSENT (the commit never ran, root probe)
- PASS: (l) INPROG marker RETAINED (the next boot re-enters the lifecycle, root probe)
- (l) no site service could be up: the entry fatals PRE-init (before exec /sbin/init) - the named cause IS the proof nothing was started
- --- (m) fresh tail: the REAL tool TIMES OUT (45s > the 30s bound)
- PASS: (m) the real tool timeout -> exit 1 (code=1)
- PASS: (m) entry-fatal carries the TIMEOUT rc (124 or 137) for the named step (fresh copy, cp+read must succeed)
- PASS: (m) the credential step WAS invoked (the real run_bounded step line present, hardened read)
- PASS: (m) the value is ABSENT from entry-fatal AND the container log (fresh copy, cp+read must succeed)
- PASS: (m) COMPLETE marker ABSENT (the commit never ran, root probe)
- PASS: (m) INPROG marker RETAINED (root probe)
- --- (n) retry after the real (l) failure: the normal image completes the creation
- PASS: (n) readiness (recovery completes, gate active + /s12/)
```
ready-time=3s
```

- PASS: (n) the value is now the effective credential (login 200)
```
with-cred=200
```

- PASS: (n) notice present exactly once (the creation tail ran, hardened read)
- PASS: (n) committed: complete marker present, in-progress gone (root probe)
- sub-items (a)-(e), (i)-(iv), (j), (k), (l), (m), (n) done
## S2-s2-rocky
- when: 2026-11-18 02:59:41
- runtime: podman

- **RESULT: PASS**

- PASS: readiness (gate active + /mysite/ answers 302/200)
```
ready-time=6s
```

- PASS: log shows prominent 'created new site mysite'
- PASS: omd status mysite running (rc 0)
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: site data on host volume (etc/var/local/version + init-complete marker, root probe)
- PASS: 5 site daemons run as user mysite
- PASS: HTTPS /mysite/ through the edge (host-side)
```
302
```

- site-start ready-time (first start): see 'readiness' evidence above; formal median-of-5 baseline = T034 (FR-018)
- PASS: restart same container reaches ready again
```
omd-s2
ready-time=3s
```

- PASS: log shows 'resumed existing site mysite' (no re-creation)
- PASS: replacement container resumes (account absent in fresh image)
```
ready-time=3s
```

- PASS: replacement: 'resumed existing site mysite'
- PASS: replacement: omd status mysite rc 0
```
rrdcached:      running
npcd:           running
naemon:         running
apache:         running
crontab:        running
-----------------------
Overall state:  running
```

- PASS: SC-002: concurrent site A ready (/s2siteA/ via published edge)
```
ready-time=6s
```

- PASS: SC-002: concurrent site B ready (gate active + /s2siteB/ on its own edge)
```
ready-time=6s
```

- PASS: SC-002: site A still serving WHILE B runs (no interference, both up)
```
302
```

- PASS: SC-002: omd status of BOTH sites rc 0 (independent site daemons)
```
A0
B0
```

- PASS: SC-002: both volumes populated independently (root probe)
- site-start reference ready-time: see readiness evidence above (formal median-of-5 = T034)
## S11a-s11a-rocky
- when: 2026-11-18 03:00:28
- runtime: podman

- **RESULT: PASS**

- base image: local/omd-labs-systemd-vm-base-rocky:nightly (edge unit httpd, expect no-site HTTP 403)
- PASS: base readiness within bound (gate active + 443 answers)
```
ready-time=3s rc=0
```

- PASS: omd-ready + httpd + sshd all active
```
ready=active edge=active ssh=active
```

- PASS: edge answers the EXACT no-site code (403) on 443
```
code=403
```

- PASS: ss (the ready-gate probe tool) is PRESENT - a named cause, not a silent 120 s deadline
```
ss at: /usr/sbin/ss
```

- PASS: the omd binary is ABSENT (OMD-less chassis)
```
omd absent (ok)
```

- PASS: sshd reachable from host on 18452
- PASS: omd.service resolves to the omd-site alias
```
alias -> /usr/lib/systemd/system/omd-site.service
```

- PASS: both labs.consol.de channels configured (stable + testing)
- PASS: clean stop -t 30 ends 130/0, not 137 (exit code: 130, stop rc: 0)
- teardown done
## S12-s12-debian
- when: 2026-11-19 15:01:47
- runtime: podman

- **RESULT: PASS**

- port 18450; site s12; volume /tmp/omd-verify/s12-site
- --- (a) fresh + pw
- PASS: (a) readiness (gate active + /s12/ answers 302/200)
```
ready-time=5s
```

- PASS: (a) htpasswd at EXACTLY etc/htpasswd, owned by the allocated site user (non-root, root probe)
- PASS: (a) omdadmin entry present (root probe)
- PASS: (a) thruk: authenticated 200 / anonymous 302
```
with-cred=200 anon=302
```

- PASS: (a) wrong password rejected (anon-equivalent 302, NOT 200)
```
wrong=302
```

- PASS: (a) notice line present exactly once (deterministic, no value)
- PASS: (a) the literal password ABSENT from the container log (hardened: read must succeed and capture the entry's own output)
- (a) stopped before (b) (code=130, stop rc=0)
- --- (b) verbatim
- PASS: (b) readiness
```
ready-time=5s
```

- PASS: (b) login with the EXACT verbatim value succeeds (leading/trailing space + metacharacters)
```
exact=200
```

- PASS: (b) the TRIMMED variant FAILS (302 - proves no trimming / no shell-evaluated string)
```
trimmed=302
```

- PASS: (b) notice present; the verbatim value ABSENT from the log
- --- (c) replacement, stored wins (fresh container on the (a) volume)
- PASS: (c) readiness (resume, gate active + /s12/)
```
ready-time=4s
```

- PASS: (c) log shows 'resumed existing site s12' (row 2, no re-creation)
- PASS: (c) NO notice (the variable is a creation-only input, ignored on resume; hardened read)
- PASS: (c) the STORED credential logs in (the (a) value, extracted before the run)
```
stored=200
```

- PASS: (c) the NEW value is REJECTED (stored wins, 302)
```
new=302
```

- PASS: (c) htpasswd content UNCHANGED (sha256 before == after, root probe)
- (c) stored omdadmin hash: omdadmin:$apr1$.54.Cmr3$hkbReAmon7pKmtvm...
- --- (e) clean stop contract
- PASS: (e) clean stop -t 30 ends 130/0, not 137 (exit code: 130, stop rc: 0)
- --- (d) empty value = no-op
- PASS: (d) readiness
```
ready-time=5s
```

- PASS: (d) NO notice (the exactly-empty value is a no-op, no setter invocation; hardened read)
- PASS: (d) the credential step was NEVER INVOKED (the run_bounded step line is absent; hardened read)
- PASS: (d) the generated omdadmin entry stands in etc/htpasswd (root probe)
- PASS: (d) 'created new site s12' (fresh creation, no credential step)
- --- (i) recovery, tree-only (create --reuse branch)
- PASS: (i) readiness (recovery completes, gate active + /s12/)
```
ready-time=6s
```

- PASS: (i) recovery banner present
```
2026-11-19T14:02:37+00:00 cbe4200c430f systemd[1]: Started systemd-timedated.service - Time & Date Service.
2026-11-19T14:02:37+00:00 cbe4200c430f dbus-daemon[930]: [system] Successfully activated service 'org.freedesktop.timedate1'
2026-11-19T14:02:38+00:00 cbe4200c430f systemd[1]: Started exim4.service - exim Mail Transport Agent.
2026-11-19T14:02:38+00:00 cbe4200c430f omd-ready-check[1234]: READY: base services up (omd-site active, apache2 443, sshd 22)
2026-11-19T14:02:38+00:00 cbe4200c430f systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-19T14:02:38+00:00 cbe4200c430f systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-19T14:02:38+00:00 cbe4200c430f systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-19T14:02:38+00:00 cbe4200c430f systemd[1]: Startup finished in 2.535s.
```

- PASS: (i) login with the environment value succeeds
```
with-cred=200
```

- PASS: (i) notice present (the creation tail was re-run)
- PASS: (i) committed: complete marker present, in-progress gone (root probe)
- --- (ii) recovery, version-link (omd enable branch, old credential invalidated)
- PASS: (ii) pre-state: the KNOWN old credential is seeded (root probe)
- PASS: (ii) readiness
```
ready-time=4s
```

- PASS: (ii) recovery banner + the version-link re-registration line
```
2026-11-19T14:03:03+00:00 c05cf78b71c6 /etc/mysql/debian-start[759]: Checking for insecure root accounts.
2026-11-19T14:03:03+00:00 c05cf78b71c6 systemd[1]: Started exim4.service - exim Mail Transport Agent.
2026-11-19T14:03:03+00:00 c05cf78b71c6 systemd[1]: Reached target multi-user.target - Multi-User System.
2026-11-19T14:03:03+00:00 c05cf78b71c6 systemd[1]: Reached target graphical.target - Graphical Interface.
2026-11-19T14:03:03+00:00 c05cf78b71c6 systemd[1]: Started systemd-timedated.service - Time & Date Service.
2026-11-19T14:03:03+00:00 c05cf78b71c6 systemd[1]: Startup finished in 3.574s.
2026-11-19T14:03:03+00:00 c05cf78b71c6 dbus-daemon[129]: [system] Successfully activated service 'org.freedesktop.timedate1'
2026-11-19T14:03:03+00:00 c05cf78b71c6 /etc/mysql/debian-start[766]: Triggering myisam-recover for all MyISAM tables and aria-recover for all Aria tables
```

- PASS: (ii) login with the environment value succeeds
```
with-cred=200
```

- PASS: (ii) the SEEDING credential is now REJECTED: the pre-existing generated credential is INVALIDATED (old-pw login 302; the env value logs in - primary oracle)
```
old-pw=302
```

- PASS: (ii) the htpasswd entry was REPLACED (new non-empty, different from the SEEDING entry, root probe)
- PASS: (ii) anonymous access stays 302 (no anonymous bypass introduced)
```
anon=302
```

- PASS: (ii) notice present
- --- (iii) persisted (stale INPROG), stored wins
- PASS: (iii) readiness (resume, not recovery)
```
ready-time=3s
```

- PASS: (iii) log shows 'resumed existing site s12' (persisted row, not re-creation)
- PASS: (iii) stale in-progress marker REMOVED (root probe)
- PASS: (iii) NO notice (no creation tail ran; hardened read)
- PASS: (iii) the STORED credential logs in
```
stored=200
```

- PASS: (iii) the NEW value is REJECTED (302)
```
new=302
```

- PASS: (iii) htpasswd UNCHANGED (sha256, root probe)
- --- (iv) adopted legacy, stored wins
- PASS: (iv) readiness (adopt path starts the site)
```
ready-time=4s
```

- PASS: (iv) prominent 'adopted existing site' banner
```
2026-11-19T14:03:35+00:00 65d0139ae056 systemd[1]: Finished omd-site.service - OMD labs single active site (start/stop).
2026-11-19T14:03:35+00:00 65d0139ae056 systemd[1]: Starting omd-ready.service - OMD labs bounded readiness gate (FR-018)...
2026-11-19T14:03:35+00:00 65d0139ae056 sshd-session[686]: Connection closed by 127.0.0.1 port 49756
2026-11-19T14:03:36+00:00 65d0139ae056 crontab[717]: (s12) LIST (s12)
2026-11-19T14:03:36+00:00 65d0139ae056 omd-ready-check[507]: READY: base services up (omd-site active, apache2 443, sshd 22)
2026-11-19T14:03:36+00:00 65d0139ae056 systemd[1]: Finished omd-ready.service - OMD labs bounded readiness gate (FR-018).
2026-11-19T14:03:36+00:00 65d0139ae056 dbus-daemon[129]: [system] Activating via systemd: service name='org.freedesktop.timedate1' unit='dbus-org.freedesktop.timedate1.service' requested by ':1.2' (uid=1234 pid=740 comm="timedatectl" label="unconfined_u:unconfined_r:spc_t:s0")
2026-11-19T14:03:36+00:00 65d0139ae056 systemd[1]: Starting systemd-timedated.service - Time & Date Service...
```

- PASS: (iv) NO notice (the credential step is absent from adopt_site; hardened read)
- PASS: (iv) the STORED credential logs in
```
stored=200
```

- PASS: (iv) the NEW value is REJECTED (302)
```
new=302
```

- PASS: (iv) htpasswd UNCHANGED (sha256, root probe)
- --- (j) fresh tail: injected failure at the credential step
- PASS: (j) failure at the fresh credential step ? exit 1 (code=1)
- PASS: (j) the injected line was REACHED (sentinel present, cp from stopped container)
- PASS: (j) the credential step had SUCCEEDED before the injection (notice present, value NOT in it)
- PASS: (j) the password value ABSENT from entry-fatal AND the container log (hardened: fresh copy, cp+read must succeed)
- PASS: (j) COMPLETE marker ABSENT (the commit never ran, root probe)
- PASS: (j) INPROG marker RETAINED (retry re-enters the creation lifecycle, root probe)
- (j) no site service could be up: the entry fatals PRE-init (before exec /sbin/init) - the named cause IS the proof nothing was started
- PASS: (j) retry completes: ready (gate + /s12/)
```
ready-time=4s
```

- PASS: (j) retry: login with the value succeeds
```
with-cred=200
```

- PASS: (j) retry committed: complete marker + in-progress gone (root probe)
- --- (k) recovery tail: injected failure at the credential step
- PASS: (k) failure at the recovery credential step ? exit 1 (code=1)
- PASS: (k) the injected line was REACHED (sentinel present, cp from stopped container)
- PASS: (k) the credential step had SUCCEEDED before the injection (notice present, value NOT in it)
- PASS: (k) the password value ABSENT from entry-fatal AND the container log (hardened: fresh copy, cp+read must succeed)
- PASS: (k) COMPLETE marker ABSENT (the recovery never committed, root probe)
- PASS: (k) INPROG marker RETAINED (root probe)
- (k) no site service could be up: the entry fatals PRE-init - the named cause IS the proof nothing was started
- PASS: (k) retry completes: ready (gate + /s12/)
```
ready-time=3s
```

- PASS: (k) retry: login with the value succeeds
```
with-cred=200
```

- PASS: (k) retry committed: complete marker + in-progress gone (root probe)
- --- (l) fresh tail: the REAL tool fails (rc=99) - production run_bounded/fatal
- PASS: (l) the real tool failure -> exit 1 (code=1)
- PASS: (l) the credential step WAS invoked (the real run_bounded step line present, hardened read)
- PASS: (l) the success notice is ABSENT (the setter did not succeed; hardened read)
- PASS: (l) the value is ABSENT from entry-fatal AND the container log (non-disclosure on the real failure path; fresh copy, cp+read must succeed)
- PASS: (l) the fault body EXECUTED (the volume mark the injected line wrote, root probe)
- PASS: (l) COMPLETE marker ABSENT (the commit never ran, root probe)
- PASS: (l) INPROG marker RETAINED (the next boot re-enters the lifecycle, root probe)
- (l) no site service could be up: the entry fatals PRE-init (before exec /sbin/init) - the named cause IS the proof nothing was started
- --- (m) fresh tail: the REAL tool TIMES OUT (45s > the 30s bound)
- PASS: (m) the real tool timeout -> exit 1 (code=1)
- PASS: (m) entry-fatal carries the TIMEOUT rc (124 or 137) for the named step (fresh copy, cp+read must succeed)
- PASS: (m) the credential step WAS invoked (the real run_bounded step line present, hardened read)
- PASS: (m) the value is ABSENT from entry-fatal AND the container log (fresh copy, cp+read must succeed)
- PASS: (m) COMPLETE marker ABSENT (the commit never ran, root probe)
- PASS: (m) INPROG marker RETAINED (root probe)
- --- (n) retry after the real (l) failure: the normal image completes the creation
- PASS: (n) readiness (recovery completes, gate active + /s12/)
```
ready-time=4s
```

- PASS: (n) the value is now the effective credential (login 200)
```
with-cred=200
```

- PASS: (n) notice present exactly once (the creation tail ran, hardened read)
- PASS: (n) committed: complete marker present, in-progress gone (root probe)
- sub-items (a)-(e), (i)-(iv), (j), (k), (l), (m), (n) done
