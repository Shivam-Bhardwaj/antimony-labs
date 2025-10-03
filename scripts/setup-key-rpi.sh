#!/usr/bin/env bash
set -euo pipefail

# Key Raspberry Pi bootstrap script
# Prepares the "sbl-key" control Pi that manages the Antimony Labs fleet.
# Safe to re-run; only applies missing steps.

NEW_USER="${NEW_USER:-curious}"
HOSTNAME_TARGET="${HOSTNAME_TARGET:-sbl-key}"
WORKSPACE_DIR="/home/${NEW_USER}/workspace"
OPS_DIR="${WORKSPACE_DIR}/ops"
REPO_URL="${REPO_URL:-https://github.com/Shivam-Bhardwaj/antimony-labs.git}"

require_root() {
  if [[ $(id -u) -ne 0 ]]; then
    echo "[ERROR] Run this script as root (sudo)." >&2
    exit 1
  fi
}

create_user_if_missing() {
  if id "${NEW_USER}" >/dev/null 2>&1; then
    echo "[INFO] User '${NEW_USER}' already exists."
  else
    echo "[INFO] Creating user '${NEW_USER}'."
    adduser --disabled-password --gecos "" "${NEW_USER}"
    echo "[WARN] Set a password or install SSH keys for '${NEW_USER}'." >&2
  fi

  usermod -aG sudo "${NEW_USER}"
}

disable_pi_user() {
  if id pi >/dev/null 2>&1; then
    echo "[INFO] Disabling default 'pi' account."
    passwd -l pi || true
  fi
}

set_hostname() {
  local current
  current=$(hostnamectl --static)
  if [[ "${current}" != "${HOSTNAME_TARGET}" ]]; then
    echo "[INFO] Setting hostname to '${HOSTNAME_TARGET}'."
    hostnamectl set-hostname "${HOSTNAME_TARGET}"
  else
    echo "[INFO] Hostname already '${HOSTNAME_TARGET}'."
  fi
}

system_updates() {
  echo "[INFO] Updating and upgrading packages."
  apt update
  DEBIAN_FRONTEND=noninteractive apt full-upgrade -y
}

install_packages() {
  local packages=(git curl ufw fail2ban python3-pip ansible)
  echo "[INFO] Installing packages: ${packages[*]}"
  apt install -y "${packages[@]}"
}

configure_firewall() {
  echo "[INFO] Configuring UFW."
  ufw --force disable
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow OpenSSH
  ufw --force enable
}

setup_workspace() {
  echo "[INFO] Preparing workspace under ${WORKSPACE_DIR}."
  install -d -o "${NEW_USER}" -g "${NEW_USER}" "${WORKSPACE_DIR}" "${OPS_DIR}"

  if [[ ! -d "${WORKSPACE_DIR}/antimony-labs" ]]; then
    echo "[INFO] Cloning antimony-labs repository."
    sudo -u "${NEW_USER}" git clone "${REPO_URL}" "${WORKSPACE_DIR}/antimony-labs"
  else
    echo "[INFO] Repository already present; pulling latest."
    sudo -u "${NEW_USER}" git -C "${WORKSPACE_DIR}/antimony-labs" pull --ff-only || true
  fi
}

bootstrap_inventory() {
  local inventory_file="${OPS_DIR}/inventory.ini"
  if [[ -f "${inventory_file}" ]]; then
    echo "[INFO] Inventory already exists (${inventory_file})."
    return
  fi
  echo "[INFO] Creating starter Ansible inventory."
  cat <<'INVENTORY' > "${inventory_file}"
[sbl_key]
sbl-key ansible_host=127.0.0.1 ansible_user=curious

[sbl_edge]
sbl0 ansible_host=10.0.0.201 ansible_user=curious

[core]
sbl1 ansible_host=10.0.0.202 ansible_user=curious

[hpc]
sblx ansible_host=10.0.0.210 ansible_user=curious

[all:vars]
ansible_python_interpreter=/usr/bin/python3
INVENTORY
  chown "${NEW_USER}:${NEW_USER}" "${inventory_file}"
  chmod 640 "${inventory_file}"
}

bootstrap_playbook() {
  local playbook_file="${OPS_DIR}/site.yml"
  if [[ -f "${playbook_file}" ]]; then
    echo "[INFO] Playbook already exists (${playbook_file})."
    return
  fi
  echo "[INFO] Creating starter site.yml playbook."
  cat <<'SITE' > "${playbook_file}"
---
- hosts: sbl_key
  gather_facts: false
  become: true
  tasks:
    - name: Placeholder for sbl-key tasks
      debug:
        msg: "Configure sbl-key here"

- hosts: sbl_edge
  become: true
  tasks:
    - name: Placeholder for sbl0 tasks
      debug:
        msg: "Configure sbl0 here"

- hosts: core
  become: true
  tasks:
    - name: Placeholder for sbl1 tasks
      debug:
        msg: "Configure sbl1 here"

- hosts: hpc
  become: true
  tasks:
    - name: Placeholder for sblX tasks
      debug:
        msg: "Configure sblX here"
SITE
  chown "${NEW_USER}:${NEW_USER}" "${playbook_file}"
  chmod 640 "${playbook_file}"
}

print_summary() {
  cat <<EOF

[SETUP COMPLETE]
- User: ${NEW_USER}
- Hostname: ${HOSTNAME_TARGET}
- Repository: ${WORKSPACE_DIR}/antimony-labs
- Inventory: ${OPS_DIR}/inventory.ini (update host IPs and users)
- Playbook: ${OPS_DIR}/site.yml

Next steps:
1. Copy your SSH public key to sbl0/sbl1/sblX.
2. Update inventory with correct IPs (LAN or WireGuard).
3. Fill in Ansible roles/tasks before running playbooks.
EOF
}

main() {
  require_root
  create_user_if_missing
  disable_pi_user
  set_hostname
  system_updates
  install_packages
  configure_firewall
  setup_workspace
  bootstrap_inventory
  bootstrap_playbook
  print_summary
}

main "$@"
