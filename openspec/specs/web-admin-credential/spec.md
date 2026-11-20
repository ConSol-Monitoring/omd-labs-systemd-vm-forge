# web-admin-credential Specification

## Purpose

Defines the runtime contract for the site web credential (`omdadmin`): how it
is generated at site creation, how it can be set from the `podman run`
environment (`OMD_ADMIN_PASSWORD`), and the non-overwrite guarantee for
already-committed sites.

## Requirements

### Requirement: generated web credential at fresh site creation

When a site is created fresh (no populated volume), the system SHALL generate
a random web password for the `omdadmin` account during site creation. The
generated password SHALL NOT appear in container startup logs or the
container log output (it is not reliably visible by design; the user sets it
explicitly or via `OMD_ADMIN_PASSWORD`). The site's `etc/htpasswd` file SHALL
contain a valid `omdadmin` credential entry after creation.

#### Scenario: fresh site with no password variable

- **WHEN** a container starts with `SITENAME=<name>` and no populated volume, and `OMD_ADMIN_PASSWORD` is unset or empty
- **THEN** the site reaches ready, `${SITE_DIR}/etc/htpasswd` contains a valid `omdadmin` entry, and no password appears in the container logs

### Requirement: OMD_ADMIN_PASSWORD sets the web credential on site creation

When `OMD_ADMIN_PASSWORD` is set to a non-empty value and the site is being
created (fresh creation or interrupted-creation recovery), the system SHALL
set the `omdadmin` web password to that value verbatim, executed as the site
user with the site's own OMD version, before the init-complete commit and
before site services start. The value MUST be effective and any previously
generated credential MUST be invalid. On success the log SHALL print a
deterministic notice and never print the value.

#### Scenario: fresh site with OMD_ADMIN_PASSWORD

- **WHEN** a container starts with `SITENAME=<name>`, an empty volume, and `OMD_ADMIN_PASSWORD=<pw>`
- **THEN** the site reaches ready, the credential step ran as the site user against `${SITE_DIR}/etc/htpasswd`, login as `omdadmin` with `<pw>` succeeds (e.g. authenticated request 200, anonymous 302), a login with a different password is rejected, the notice line is present (it states the web admin password was set from `OMD_ADMIN_PASSWORD`), and the literal value of `<pw>` does not appear in the container logs

#### Scenario: value with shell metacharacters and whitespace

- **WHEN** the site is created with `OMD_ADMIN_PASSWORD` set to a value containing leading/trailing whitespace and shell metacharacters (e.g. `pw'x"y$z `)
- **THEN** the credential is set to that exact value verbatim (no shell
  evaluation, no trimming): login with the exact value succeeds and with a
  shell-expanded or trimmed variant fails

### Requirement: empty OMD_ADMIN_PASSWORD is a no-op

A value that is exactly the empty string (`OMD_ADMIN_PASSWORD=`) SHALL be
treated as unset: the credential-setting step SHALL NOT run (no tool
invocation), and the site behaves identically to the unset case (generated
random password, `etc/htpasswd` valid, no notice line, no password printed).
Values that are non-empty (including whitespace-only) are passed verbatim
per the setting requirement and are NOT treated as unset.

#### Scenario: empty variable on a fresh site

- **WHEN** a container starts with `SITENAME=<name>` and `OMD_ADMIN_PASSWORD=` (exactly empty)
- **THEN** the site reaches ready exactly as if the variable were unset: no credential-setting step ran (notice line absent), `etc/htpasswd` holds a valid generated entry, and no password appears in the container logs

### Requirement: committed sites keep their stored credential

For an already-committed site (init-complete marker present — persisted,
including with a stale in-progress marker, or adopted legacy), the stored
`omdadmin` web credential SHALL remain authoritative; `OMD_ADMIN_PASSWORD`
MUST NOT overwrite it, whether or not it is set. The invariant is
"not yet committed/served": the tool runs only on creation paths that end
in a fresh init-complete commit.

#### Scenario: replacement container with a different OMD_ADMIN_PASSWORD

- **WHEN** a site was created with `OMD_ADMIN_PASSWORD=<pw1>` (or with the generated password), and a replacement container starts from the SAME populated volume with `OMD_ADMIN_PASSWORD=<pw2>`
- **THEN** the site resumes (persisted, not re-created), the stored credential (`<pw1>`) still logs in, the `etc/htpasswd` content is unchanged, and `<pw2>` does not log in

#### Scenario: persisted site with a stale in-progress marker

- **WHEN** a committed site (init-complete marker present) also carries a stale in-progress marker, and a container starts it with `OMD_ADMIN_PASSWORD=<pw2>`
- **THEN** the site is treated as persisted (the stale marker is removed), the stored credential remains authoritative, and `<pw2>` is not applied

#### Scenario: adopted legacy site with a different OMD_ADMIN_PASSWORD

- **WHEN** a complete OMD site volume without any markers (legacy/pre-marker) is started with `OMD_ADMIN_PASSWORD=<pw2>`
- **THEN** the site is adopted, the stored credential remains authoritative, and `<pw2>` is not applied

### Requirement: credential-setting failure is a fatal pre-init error

If the credential-setting step fails (tool rejection, missing tool, or
timeout) during site creation, the container SHALL fail with a fatal
pre-init error naming the cause (return code / timeout, WITHOUT the
password value), SHALL NOT write the init-complete marker, SHALL retain the
in-progress marker, and SHALL NOT start site services or systemd.

#### Scenario: rejected password value

- **WHEN** site creation is in progress and the credential-setting step fails (e.g. injected tool failure)
- **THEN** the entry exits before systemd starts with the named fatal cause, the init-complete marker is absent, the in-progress marker is retained, no site service is running, and a subsequent start with a valid value completes the creation

### Requirement: documented run-contract entry and security note

The documentation (README.md configuration section and startup-input table)
SHALL list `OMD_ADMIN_PASSWORD` with its effect,
its scope (fresh creation and interrupted-creation recovery only — committed
sites keep their stored credential; rotation stays the explicit
`su - <site>` + `set_admin_password` action), and a security note (env vars
are visible via `podman inspect` and process listings — a lab convenience,
not secret management).

#### Scenario: docs completeness

- **WHEN** the environment-variable documentation is read (README.md)
- **THEN** `OMD_ADMIN_PASSWORD` is listed alongside `SITENAME` and `OMDCFG_<KEY>` in README.md, with the scope statement and the security note present
