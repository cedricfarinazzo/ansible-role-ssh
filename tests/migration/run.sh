#!/usr/bin/env bash
# Port migration over real SSH against a container: move, rerun, refused login on the new port, interrupted stage B.
# Usage: tests/migration/run.sh <distro> [extra ansible-playbook args]   (needs docker and requirements-dev.txt)
set -euo pipefail

DISTRO=${1:?distro, e.g. debian13}
shift
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
WORK=$(mktemp -d)
NAME=ssh-migration-$$
trap 'docker rm -f "$NAME" >/dev/null 2>&1 || true; rm -rf "$WORK"' EXIT

ssh-keygen -q -t ed25519 -N '' -f "$WORK/key"
docker run -d --name "$NAME" --privileged --cgroupns host -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  "geerlingguy/docker-${DISTRO}-ansible:latest" >/dev/null
sleep 5
docker exec "$NAME" bash -c "
  set -e
  if command -v apt-get >/dev/null; then apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq openssh-server sudo >/dev/null
  else dnf install -y -q openssh-server sudo >/dev/null; fi
  useradd -m -s /bin/bash tester
  # A usable, never-locked test account (useradd leaves it locked on EL)
  usermod -p '*' tester
  install -d -m 700 -o tester -g tester /home/tester/.ssh
  echo '$(cat "$WORK/key.pub")' > /home/tester/.ssh/authorized_keys
  chown tester: /home/tester/.ssh/authorized_keys && chmod 600 /home/tester/.ssh/authorized_keys
  echo 'tester ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/tester
  ssh-keygen -A >/dev/null
  # The test reconnects from one address many times; OpenSSH 9.8+ would penalise it
  if [ -d /etc/ssh/sshd_config.d ]; then echo 'PerSourcePenalties no' > /etc/ssh/sshd_config.d/00-test.conf; sshd -t 2>/dev/null || rm /etc/ssh/sshd_config.d/00-test.conf; fi
  systemctl enable --now ssh 2>/dev/null || systemctl enable --now sshd
  # Clear a boot-time nologin, if any, so the first key login is not refused
  systemctl start systemd-user-sessions 2>/dev/null || true
  rm -f /run/nologin /etc/nologin"
IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$NAME")
ready=0
for _ in $(seq 30); do
  if ssh -i "$WORK/key" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3 \
    "tester@$IP" true 2>/dev/null; then ready=1; break; fi
  sleep 2
done
if [[ $ready -ne 1 ]]; then
  echo "FAIL sshd in the container never accepted the test key" >&2
  docker exec "$NAME" bash -c 'systemctl is-system-running; ls -l /run/nologin /etc/nologin /etc/shadow; getent shadow tester; chage -l tester
    getenforce 2>/dev/null; grep -v "^#" /etc/pam.d/sshd; grep -v "^#" /etc/pam.d/password-auth 2>/dev/null; cat /etc/security/sepermit.conf 2>/dev/null | grep -v "^#"
    grep -i pam /var/log/secure 2>/dev/null | tail -10; journalctl --no-pager -o cat SYSLOG_FACILITY=10 | grep -iv "^$" | tail -15' >&2 || true
  docker exec "$NAME" journalctl -u ssh -u sshd --no-pager | tail -10 >&2 || true
  exit 1
fi

ln -s "$ROOT" "$WORK/ansible-role-ssh"
inventory() {
  cat > "$WORK/inventory.yml" <<INV
all:
  hosts:
    target:
      ansible_host: $IP
      ansible_user: tester
      # As inventory var it beats a task's become keyword: the role must still read SSH_CONNECTION
      ansible_become: true
      ansible_port: ${3:-$1}
      ansible_ssh_private_key_file: $WORK/key
      ansible_ssh_common_args: "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
      ssh_port: $1
      ssh_port_migration: true
      ssh_port_migration_from: $2
      ssh_allow_users: [tester]
      ssh_per_source_penalty_exempt_list: [172.16.0.0/12]
INV
}
play() { ANSIBLE_ROLES_PATH=$WORK ansible-playbook -i "$WORK/inventory.yml" "$ROOT/tests/migration/play.yml" "$@"; }
open_port() { timeout 3 bash -c "</dev/tcp/$IP/$1" 2>/dev/null; }
fails=0
check() { if "${@:2}"; then echo "ok   $1"; else echo "FAIL $1" >&2; fails=$((fails + 1)); fi; }

inventory 2222 22
play "$@" > "$WORK/run1.log" 2>&1 && r=0 || r=$?
check "22 -> 2222 succeeds" test "$r" -eq 0
check "port 2222 open" open_port 2222
check "port 22 closed" bash -c "! timeout 3 bash -c '</dev/tcp/$IP/22' 2>/dev/null"

play "$@" > "$WORK/run2.log" 2>&1 && r=0 || r=$?
check "rerun succeeds" test "$r" -eq 0
check "rerun changes nothing" grep -qE 'target +: .*changed=0 ' "$WORK/run2.log"

# Refused logins on the new port: stage A must restore the old configuration on 2222.
inventory 2223 2222
play -e '{"ssh_additional_config": ["Match LocalPort 2223", "  DenyUsers tester"]}' -e ssh_port_migration_timeout=10 "$@" \
  > "$WORK/run3.log" 2>&1 && r=0 || r=$?
check "refused login on 2223 fails the play" test "$r" -ne 0
check "stage A rescue ran" grep -q 'the previous sshd_config is back on port 2222' "$WORK/run3.log"
check "port 2222 still open" open_port 2222
check "port 2223 closed" bash -c "! timeout 3 bash -c '</dev/tcp/$IP/2223' 2>/dev/null"

# Interrupted stage B: sshd on both ports, the inventory still connects on the old one.
docker exec "$NAME" bash -c "sed -i 's/^Port 2222$/Port 2222\nPort 2224/' /etc/ssh/sshd_config
  if systemctl is-active -q ssh.socket; then systemctl daemon-reload && systemctl restart ssh.socket
  else systemctl restart ssh 2>/dev/null || systemctl restart sshd; fi"
check "both ports open before the interrupted run" bash -c "timeout 3 bash -c '</dev/tcp/$IP/2224' && timeout 3 bash -c '</dev/tcp/$IP/2222'"
inventory 2224 2222 2222
play "$@" > "$WORK/run4.log" 2>&1 && r=0 || r=$?
result() { grep -A1 -F "TASK [ansible-role-ssh : $1]" "$WORK/run4.log" | grep -q "^$2: \[target\]"; }
check "interrupted migration finishes" test "$r" -eq 0
check "stage B ran for it" result "Keep the two-port sshd_config" changed
check "stage A did not" bash -c "! grep -A1 -F 'TASK [ansible-role-ssh : Keep the sshd_config that works today]' '$WORK/run4.log' | grep -q '^changed:'"
check "port 2224 open" open_port 2224
check "port 2222 closed" bash -c "! timeout 3 bash -c '</dev/tcp/$IP/2222' 2>/dev/null"

if [[ $fails -gt 0 ]]; then
  for f in "$WORK"/run*.log; do echo "== $f"; tail -40 "$f"; done
  docker exec "$NAME" journalctl -u ssh -u sshd --no-pager | tail -40 || true
fi
exit $((fails > 0))
