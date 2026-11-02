# CLAUDE.md — ansible-role-ssh

Orientation for Claude Code sessions in this repository. `AGENTS.md` is a symlink to this file.

## Purpose

Public Ansible role `cedricfarinazzo.ssh` (Ansible Galaxy): installs OpenSSH server and templates a complete, hardened `/etc/ssh/sshd_config`. Generic by design: no reference to any downstream project, host, user or network in code, defaults, docs or commit messages.

## Layout

- `defaults/main.yml` — every user-facing variable (`ssh_*`), with its secure default.
- `vars/<os_family>.yml` — package and service names per OS family; loaded first.
- `vars/openssh-<version>.yml` — algorithm lists and `openssh_supports_*` capability flags for one OpenSSH version band. `tasks/main.yml` detects the installed OpenSSH version and loads the highest band not above it.
- `tasks/main.yml` — install, host keys, authorized keys, template (validated with `sshd -t` before it replaces the live file), service.
- `templates/sshd_config.j2` — the whole `sshd_config`; a directive newer than the oldest supported OpenSSH sits behind an `openssh_supports_*` flag.
- `handlers/main.yml` — restart the service.
- `meta/main.yml` — Galaxy metadata.
- `molecule/default/` — the one Molecule scenario (docker driver, `geerlingguy/docker-<distro>-ansible` images); `verify/` asserts the rendered config and runs `ssh-audit`; `collections.yml` holds test-only collections.
- `run-tests.sh` / `Makefile` — local Molecule entry points; `run-tests.sh <distro>`.
- `requirements.yml` — collections the role needs at runtime (consumer-facing ranges).
- `requirements-dev.txt` — controller tooling (ansible-core, ansible-lint, molecule, molecule-plugins, yamllint, ssh-audit), exact pins.
- `package.json`, `bun.lock`, `.releaserc.json` — semantic-release tooling only; the role itself has no Node code.
- `.github/workflows/` — `ci.yml` (lint + Molecule matrix), `pr-title.yml` (Conventional Commit title check), `release.yml` (semantic-release on `main`).
- `renovate.json` — dependency updates.

## Conventions

- **Conventional Commits** (`conventionalcommits` preset, so a `!` after the type is breaking). `feat:` → minor, `fix:` / `perf:` → patch, `!` or a `BREAKING CHANGE:` footer → major; `docs:` / `ci:` / `chore:` / `test:` / `refactor:` / `build:` release nothing. Scope optional (`feat(template): …`). PRs are squash-merged, so the **PR title is the commit** semantic-release reads; `pr-title.yml` checks it.
- **Breaking = a consumer must act.** Dropping a platform, renaming or removing a variable, changing a default that alters the rendered `sshd_config` in a way that can lock someone out or reject a client (port, users, algorithms, auth methods, host key paths).
- **Tags are bare semver** (`1.2.3`, no `v`), matching the tags published before semantic-release (`tagFormat` in `.releaserc.json`). Release notes live in GitHub Releases; there is no `CHANGELOG.md` and no release commit (the `main` ruleset requires a PR, so CI cannot push one).
- **Variables:** every user-facing variable starts with `ssh_`, is defined in `defaults/main.yml` and documented in `README.md` in the same PR. Internal facts start with `openssh_`.
- **One OpenSSH band per algorithm set.** Never branch on distro name for crypto: branch on the detected OpenSSH version (`is version(...)`), so a new distro with a known OpenSSH version works unchanged.
- **The template must stay valid on every tested platform.** A distro-specific directive (e.g. `DebianBanner`) is emitted only on the family that patches it in.
- **GitHub Actions pinned by full commit SHA**, tag in a trailing comment: `actions/checkout@<40-char sha> # v7.0.1`. Never a mutable tag. Resolve a SHA with `gh api repos/<owner>/<repo>/git/refs/tags/<tag> --jq .object.sha` (dereference annotated tags).
- **Exact pins for tooling** (`requirements-dev.txt`, `package.json`, `molecule/default/collections.yml`); ranges only in the consumer-facing `requirements.yml`. Renovate bumps both kinds.
- **License:** MIT.

## Supported platforms

`meta/main.yml` `platforms`, the CI matrix in `.github/workflows/ci.yml`, the `README.md` table and `run-tests.sh --help` list the same set. End-of-life releases are dropped (a `feat!:` change), not kept as non-blocking jobs.

### Adding a platform — checklist

1. Check a `geerlingguy/docker-<distro>-ansible:latest` image exists.
2. Find its OpenSSH version; if no `vars/openssh-*.yml` band fits, add one (copy the nearest, adjust algorithms and `openssh_supports_*` flags, add the band to the selection in `tasks/main.yml` and `molecule/default/verify/playbook.yml`).
3. New OS family → `vars/<os_family>.yml` with `ssh_package` and `ssh_service_name`.
4. Add it to the CI matrix, `meta/main.yml`, `README.md` and `run-tests.sh` usage.
5. `./run-tests.sh <distro>` green locally, `ssh-audit` included.

## How releases work

1. A PR is squash-merged into `main` with a Conventional Commit title.
2. `release.yml` runs `bunx semantic-release`: it analyses commits since the last tag, creates the tag and a GitHub Release with generated notes, and comments on the released PRs.
3. Ansible Galaxy watches the repository and imports each new tag by itself; nothing in CI pushes to Galaxy.

## Commands

- Lint: `source .venv/bin/activate && yamllint . && ansible-lint`
- Molecule on one distro: `./run-tests.sh debian12` (creates `.venv` from `requirements-dev.txt`)
- All distros: `make molecule-test-all`
- Install release tooling: `bun install --frozen-lockfile`
- Release dry run (needs a token, runs only on `main`): `GITHUB_TOKEN=$(gh auth token) bunx semantic-release --dry-run --no-ci`
- Rendered config on a test instance: `molecule converge && molecule login`, then `sshd -T`

## Gotchas

- The Molecule docker driver comes from `molecule-plugins[docker]` and needs `community.docker` (`molecule/default/collections.yml`, installed by the `dependency` step).
- Renovate automerge cannot complete while the `main` ruleset requires approval of the most recent push: Renovate PRs wait for the owner.
- `ssh-audit` exits 0 (clean), 1 (connection error), 2 (warnings), 3 (failures); its JSON flag is `--json`.
- `sshd -t` rejects unknown directives, so a directive is guarded by the OpenSSH version that introduced it.
