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
- ✅ Configure custom SSH port (default: 22) for security through obscurity
- ✅ Disable password authentication and root login
- ✅ Enable only secure cryptographic algorithms

## 📋 Requirements

| Component | Requirement |
|-----------|-------------|
| **Operating System** | Linux (Debian/Ubuntu/RHEL/CentOS/Rocky) |
| **Ansible** | Version 2.9+ |
| **Python** | Python 3.8+ on target hosts |
| **Privileges** | Root or sudo access on target hosts |

### Supported Distributions

- ✅ **Debian** 11, 12
- ✅ **Ubuntu** 20.04, 22.04, 24.04

## ⚙️ Configuration

### Core Variables

The role uses secure defaults but can be customized through these variables:

#### SSH Service Configuration
```yaml
# Package and service management
ssh_package: openssh-server           # Package name
ssh_package_state: present           # Package state
ssh_service_name: sshd               # Service name (auto-detected)
ssh_service_state: started           # Service state
ssh_service_enabled: true            # Enable on boot

# Network settings
ssh_port: 22                         # SSH port
ssh_protocol: 2                      # SSH protocol version
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
```

#### Security and Hardening
```yaml
# Connection settings
ssh_client_alive_count_max: 3        # Max missed keepalive messages
ssh_client_alive_interval: 120       # Keepalive interval in seconds
ssh_max_startups: "10:30:100"        # Connection rate limiting

# Forwarding settings
ssh_allow_agent_forwarding: false    # Disable agent forwarding
ssh_x11_forwarding: false           # Disable X11 forwarding
ssh_compression: true                # Enable compression

# User restrictions
ssh_allow_users:                     # Allowed users
  - infra

# Authorized keys
ssh_authorized_keys_file: .ssh/authorized_keys .ssh/authorized_keys2  # Location of authorized keys file
ssh_authorized_keys: []               # List of authorized keys to manage

# Additional settings
ssh_print_motd: false                 # Print message of the day
ssh_banner: none                      # SSH banner file path
ssh_debian_banner: false              # Enable Debian banner
ssh_accept_env: "LANG LC_*"           # Environment variables to accept
ssh_syslog_facility: AUTH             # Syslog facility for SSH messages
```

#### Cryptographic Algorithms
The role includes hardened cryptographic settings based on [SSH Audit hardening guides](https://www.ssh-audit.com/hardening_guides.html):

Cryptographic algorithm values are automatically configured per operating system through dedicated variable files in `vars/` directory:

- `vars/openssh-8.2.yml` - Compatible with Ubuntu 20.04 (8.2), Debian 11 (8.4)
- `vars/openssh-9.2.yml` - Compatible with Debian 12 (9.2) 
- `vars/openssh-9.6.yml` - Compatible with Ubuntu 24.04 (9.6)

These files ensure compatibility with each distribution's OpenSSH version and available algorithms. The role automatically detects the OpenSSH version and loads the appropriate algorithm configuration.

##### Cryptographic options
```yaml
# RSA Key Requirements
ssh_required_rsa_size: 4096           # Minimum RSA key size
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
          - "PermitTunnel no"
          - "ChrootDirectory none"
          - "AllowTcpForwarding no"
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

CI (`.github/workflows/ci.yml`) runs the lint and the Molecule matrix on every pull request.

## 🚢 Releases

Versions are cut by [semantic-release](https://github.com/semantic-release/semantic-release) from [Conventional Commits](https://www.conventionalcommits.org/) on `main`: `fix:` releases a patch, `feat:` a minor, a `!` or `BREAKING CHANGE:` footer a major. Pull requests are squash-merged, so the pull request title must follow the convention (checked in CI). Each release gets a bare semver tag (`1.2.3`) and GitHub release notes; Ansible Galaxy imports the new tag from the repository. [Renovate](https://docs.renovatebot.com/) keeps the tooling and the pinned GitHub Actions up to date.

## 📦 Dependencies

This role has **minimal external dependencies** and uses:
- ✅ **Ansible Core Modules** (built-in)
- ✅ **Standard OS Packages** (openssh-server)
- ✅ **Optional Collections** (community.general, ansible.posix)

## 👥 Authors & Contributors

**Cédric Farinazzo** ([@cedricfarinazzo](https://github.com/cedricfarinazzo)) - *Author and Maintainer*
