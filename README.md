# 🔐 Ansible Role: SSH

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ansible Galaxy](https://img.shields.io/badge/Ansible%20Galaxy-cedricfarinazzo.ssh-blue)](https://galaxy.ansible.com/cedricfarinazzo/ssh)

> **A comprehensive Ansible role for secure SSH server configuration with hardened security settings based on [SSH Audit hardening guides](https://www.ssh-audit.com/hardening_guides.html).**

This role provides a secure, production-ready SSH server configuration with support for custom host keys, hardened cryptographic algorithms, and flexible user management.

## 🚀 Quick Start

```yaml
# Simple setup with secure defaults
- hosts: ssh_servers
  become: true
  roles:
    - cedricfarinazzo.ssh
```

The role will automatically:
- ✅ Install and configure OpenSSH server
- ✅ Apply hardened security settings based on [SSH Audit hardening guides](https://www.ssh-audit.com/hardening_guides.html)
- ✅ Generate secure host keys if they don't exist
- ✅ Configure the SSH port (default: 22), with an optional lock-out-safe move to a new port
- ✅ Disable password authentication and root login
- ✅ Enable only secure cryptographic algorithms

## 📋 Requirements

| Component | Requirement |
|-----------|-------------|
| **Operating System** | Debian, Ubuntu, RHEL family (see below) |
| **Ansible** | ansible-core 2.15+ (CI tests the version pinned in `requirements-dev.txt`) |
| **Collections** | `ansible.posix`, `community.general` (`requirements.yml`) |
| **Privileges** | Root or sudo access on target hosts |

### Supported Distributions

Each is tested in CI with Molecule; the port migration is also tested over real SSH (`tests/migration/run.sh`; in CI on Debian and Ubuntu, EL locally). The oldest OpenSSH the role accepts is 8.9.

| Distribution | Versions | OpenSSH |
|--------------|----------|---------|
| **Debian** | 12, 13 | 9.2, 10.0 |
| **Ubuntu** | 22.04, 24.04, 26.04 | 8.9, 9.6, 10.2 |
| **Rocky Linux / RHEL family** | 9, 10 | 9.9, 9.9 |

The role reads the installed OpenSSH version from the package database and loads the algorithm set for it, so the crypto follows OpenSSH, not the distribution name.

#### Platform notes

- **Ubuntu 22.10+ socket activation:** with `ssh_socket_activation: false` (default) the role disables `ssh.socket` and runs the plain `ssh` service, so `Port` is honoured directly. With `true` it keeps the socket and runs `systemctl daemon-reload` + restarts `ssh.socket` when the configuration changes.
- **SELinux (RHEL family):** when SELinux is enabled the role installs `policycoreutils-python-utils` and labels `ssh_port` as `ssh_port_t`, so sshd can bind a non-default port.
- **RHEL crypto-policies:** the role writes the full `sshd_config` without the `sshd_config.d` include (unless `ssh_include_config_dir: true`), so its algorithm lists apply instead of the system crypto policy.
- `DebianBanner` is only written on Debian and Ubuntu, whose OpenSSH builds carry that patch.

## ⚙️ Configuration

### Core Variables

The role uses secure defaults but can be customized through these variables:

#### SSH Service Configuration
```yaml
# Package and service management
ssh_package: openssh-server           # Package name (per OS family by default)
ssh_package_state: present           # Package state
ssh_service_name: ssh                # Service name (per OS family: ssh on Debian/Ubuntu, sshd on EL)
ssh_selinux_packages: [policycoreutils-python-utils]  # Installed when SELinux is enabled
ssh_service_state: started           # Service state
ssh_service_enabled: true            # Enable on boot
ssh_socket_activation: false         # Ubuntu 22.10+: keep ssh.socket (true) or use the plain service

# Network settings
ssh_port: 22                         # SSH port
ssh_port_migration: false            # Two-stage move from ssh_port_migration_from (see below)
ssh_port_migration_from: 22
ssh_port_migration_timeout: 30       # Seconds to wait for a login on the new port
ssh_port_probe_timeout: 3            # Controller probe in tasks_from: port_probe.yml
```

#### Authentication Configuration
```yaml
# Authentication settings
ssh_login_grace_time: 40             # Login grace time in seconds
ssh_permit_root_login: "no"          # Disable root login
ssh_strict_modes: true               # Enable strict mode checking
ssh_max_auth_tries: 3                # Maximum authentication attempts
ssh_max_sessions: 10                 # Maximum concurrent sessions
ssh_pubkey_authentication: true      # Enable public key authentication
ssh_password_authentication: false   # Disable password authentication
ssh_permit_empty_passwords: false    # Disable empty passwords
ssh_kbd_interactive_authentication: false  # Disable keyboard-interactive auth
ssh_hostbased_authentication: false  # Disable host-based auth
ssh_ignore_rhosts: true              # Ignore .rhosts / .shosts
ssh_authentication_methods: ""       # e.g. "publickey"; empty: sshd default

# Kerberos and GSSAPI
ssh_kerberos_authentication: false   # Disable Kerberos
ssh_gssapi_authentication: false     # Disable GSSAPI

# PAM integration
ssh_use_pam: true                    # Enable PAM authentication
```

#### Host Keys Configuration
```yaml
# Host key configuration
ssh_host_keys:
  - /etc/ssh/custom_ssh_host_rsa_key
  - /etc/ssh/custom_ssh_host_ed25519_key

ssh_generate_host_keys: true         # Generate host keys if missing
ssh_host_key_types:                  # Key types to generate
  - rsa
  - ed25519
ssh_host_key_rsa_bits: 4096          # Size of a generated RSA host key
```

#### Security and Hardening
```yaml
# Connection settings
ssh_client_alive_count_max: 3        # Max missed keepalive messages
ssh_client_alive_interval: 120       # Keepalive interval in seconds
ssh_max_startups: "10:30:60"         # Unauthenticated connection rate limiting
ssh_per_source_max_startups: ""      # e.g. "10" (empty: sshd default)
ssh_per_source_net_block_size: ""    # e.g. "32:128"
ssh_per_source_penalties: ""         # OpenSSH 9.8+, empty keeps sshd's defaults (on)
ssh_per_source_penalty_exempt_list: []  # OpenSSH 9.8+, e.g. your management network
ssh_unused_connection_timeout: ""    # OpenSSH 9.2+, e.g. "5m"
ssh_channel_timeout: ""              # OpenSSH 9.2+, e.g. "session=30m"

# Forwarding and session features (all off)
ssh_allow_agent_forwarding: false
ssh_allow_tcp_forwarding: false
ssh_allow_stream_local_forwarding: false
ssh_gateway_ports: false
ssh_permit_tunnel: false
ssh_x11_forwarding: false
ssh_permit_user_environment: false
ssh_compression: false               # Off: OpenSSH 10.6 disabled its dictionaries after a plaintext-recovery attack

# User restrictions
ssh_allow_users: []                  # Allowed users (empty list: no AllowUsers line)

# Authorized keys
ssh_authorized_keys_file: .ssh/authorized_keys  # authorized_keys2 is deprecated upstream
ssh_authorized_keys: []               # List of authorized keys to manage

# Logging
ssh_syslog_facility: AUTH
ssh_log_level: VERBOSE                # Logs the fingerprint of the key used at each login

# Additional settings
ssh_subsystem_sftp: ""                # SFTP server command, e.g. /usr/lib/openssh/sftp-server (empty: no Subsystem line)
ssh_print_motd: false
ssh_banner: none                      # SSH banner file path
ssh_debian_banner: false              # Debian/Ubuntu only
ssh_accept_env: "LANG LC_*"
ssh_additional_config: []             # Raw lines written last (Match blocks); cannot override a directive set above
ssh_include_config_dir: false         # Include sshd_config.d/*.conf first: drop-ins then win over the role
ssh_config_dir: /etc/ssh/sshd_config.d  # Directory included by ssh_include_config_dir
```

#### Cryptographic Algorithms

The algorithm lists follow the [ssh-audit hardening guides](https://www.ssh-audit.com/hardening_guides.html) and are computed from the installed OpenSSH version: `vars/main.yml` lists every algorithm the role may offer with the OpenSSH version range that knows it, and the role keeps those the installed version supports (`sshd -t` rejects an unknown name).

| What | Default |
|------|---------|
| Key exchange | `mlkem768x25519-sha256` and `sntrup761x25519-sha512` (OpenSSH 9.9+), `sntrup761x25519-sha512@openssh.com`, `curve25519-sha256`; finite-field DH (`group16`, `group18`, `group-exchange-sha256`) only below OpenSSH 10.0, which disables it by default |
| Ciphers | `chacha20-poly1305`, AES-GCM, AES-CTR |
| MACs | encrypt-then-MAC only: `hmac-sha2-512-etm`, `hmac-sha2-256-etm`, `umac-128-etm` |
| Host keys / user keys | Ed25519, FIDO Ed25519 (`sk-ssh-ed25519`), RSA-SHA2, with their certificates; no ECDSA |
| DH moduli | `/etc/ssh/moduli` filtered to 3072 bits and more |

```yaml
ssh_kex_post_quantum_only: false      # true: offer only ML-KEM / sntrup hybrids (as ssh-audit's Debian 13 / Ubuntu 26.04 guides)
ssh_pubkey_accept_sk_ecdsa: false     # true: accept FIDO ECDSA keys, for authenticators without ed25519-sk
ssh_required_rsa_size: 4096           # Minimum RSA key size (OpenSSH 9.1+)
ssh_moduli_minimum: 3072              # 0 leaves /etc/ssh/moduli untouched

# Each list can be replaced as a whole, e.g. in group_vars:
# ssh_kex_algorithms: [mlkem768x25519-sha256, curve25519-sha256]
# ssh_ciphers / ssh_macs / ssh_host_key_algorithms / ssh_pubkey_accepted_algorithms /
# ssh_hostbased_accepted_algorithms / ssh_ca_signature_algorithms / ssh_gssapi_kex_algorithms
```

## 🎯 Usage Examples

### Basic Secure Setup
```yaml
- hosts: ssh_servers
  become: true
  roles:
    - role: cedricfarinazzo.ssh
```

### Custom Port and Users
```yaml
- hosts: ssh_servers
  become: true
  roles:
    - role: cedricfarinazzo.ssh
      vars:
        ssh_port: 12345
        ssh_allow_users:
          - admin
          - developer
          - deploy
```

### Moving SSH to a new port without locking yourself out

With `ssh_port_migration: true`, when sshd does not answer on `ssh_port` yet the role moves it in two stages:

1. **Stage A:** sshd listens on `ssh_port` **and** `ssh_port_migration_from`, then Ansible reconnects on `ssh_port`, proves a login (`wait_for_connection`) and checks the session really uses `ssh_port`. If any of that fails, the previous `sshd_config` is restored on the old port and the play stops.
2. **Stage B:** the login on `ssh_port` is proven again and the controller sees an OpenSSH banner there; only then is the old port dropped, and the login is proven once more. If sshd refuses the final configuration, the two-port configuration is restored. A login that breaks after the old port is gone cannot be rolled back from Ansible: that is why stage B needs the proofs first.

"sshd already answers on `ssh_port`" means an OpenSSH banner there, not just an open port. A rerun after an interrupted stage B (sshd on both ports, connection on the old one) runs stage B only. The session port is read on the target (`SSH_CONNECTION`, without become), so `ansible_port` and `ansible_ssh_port` cannot disagree silently; the role sets both, and stops if the port cannot be read over SSH. Do not pin the old port with `-e ansible_port=…` (extra vars beat the role).

A run on a host already answering on `ssh_port` is a normal run. The role does not touch the firewall: open `ssh_port` before the play.

On the first contact the inventory already says the new port while sshd is still on the old one; `tasks_from: port_probe.yml` checks from the controller and connects on the old port while needed:

```yaml
- hosts: ssh_servers
  become: true
  gather_facts: false
  vars:
    ansible_port: 2222
    ssh_port: 2222
    ssh_port_migration: true
    ssh_port_migration_from: 22
  pre_tasks:
    - name: Find the port sshd answers on
      ansible.builtin.include_role:
        name: cedricfarinazzo.ssh
        tasks_from: port_probe.yml
    - name: Gather facts
      ansible.builtin.setup:
  roles:
    - cedricfarinazzo.ssh
```

### Authorized Keys Management
```yaml
- hosts: ssh_servers
  become: true
  roles:
    - role: cedricfarinazzo.ssh
      vars:
        ssh_authorized_keys:
          - user: infra
            key: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... admin@workstation"
          - user: infra
            key: "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQ... backup@server"
```

### Custom Host Keys
```yaml
- hosts: ssh_servers
  become: true
  roles:
    - role: cedricfarinazzo.ssh
      vars:
        ssh_host_keys:
          - /etc/ssh/ssh_host_rsa_key
          - /etc/ssh/ssh_host_ed25519_key
        ssh_host_key_types:
          - rsa
          - ed25519
```

### Additional Configuration
```yaml
- hosts: ssh_servers
  become: true
  roles:
    - role: cedricfarinazzo.ssh
      vars:
        ssh_additional_config:
          - "Match Group sftponly"
          - "  ForceCommand internal-sftp"
          - "  ChrootDirectory %h"
```

## 🧪 Testing

Molecule runs the role in a Docker container, then checks the rendered `sshd_config` and runs [`ssh-audit`](https://github.com/jtesta/ssh-audit) against it. The tooling is pinned in `requirements-dev.txt`; `run-tests.sh` installs it into `.venv`.

```bash
# One distribution
./run-tests.sh debian12

# Every supported distribution
make molecule-test-all

# Lint
source .venv/bin/activate && yamllint . && ansible-lint
```

CI (`.github/workflows/ci.yml`) runs the lint, the Molecule matrix and the real-SSH port-migration test (`tests/migration/run.sh`) on every pull request.

## 🚢 Releases

Once CI passes on `main`, [semantic-release](https://github.com/semantic-release/semantic-release) cuts the version from [Conventional Commits](https://www.conventionalcommits.org/): `fix:` releases a patch, `feat:` a minor, a `!` or `BREAKING CHANGE:` footer a major. semantic-release reads every commit that lands on `main`: a squash merge lands the pull request title (checked in CI), a merge commit lands each branch commit, so both must follow the convention. Each release gets a bare semver tag (`1.2.3`) and GitHub release notes; Ansible Galaxy imports the new tag from the repository. [Renovate](https://docs.renovatebot.com/) keeps the tooling and the pinned GitHub Actions up to date.

## 📦 Dependencies

This role has **minimal external dependencies** and uses:
- ✅ **Ansible Core Modules** (built-in)
- ✅ **Standard OS Packages** (openssh-server)
- ✅ **Collections** `community.general` (SELinux port) and `ansible.posix` (authorized keys), from `requirements.yml`

## 👥 Authors & Contributors

**Cédric Farinazzo** ([@cedricfarinazzo](https://github.com/cedricfarinazzo)) - *Author and Maintainer*
