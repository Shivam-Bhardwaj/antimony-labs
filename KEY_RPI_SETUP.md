# Key Raspberry Pi Setup ("sbl-key")

This guide prepares the dedicated Raspberry Pi that acts as the secure control point for the Antimony Labs devices (`sbl0`, `sbl1`, `sblX`). Once configured, plugging the key Pi into an internet connection gives you SSH and Ansible access to the rest of the fleet.

## Overview

- **Device role:** bastion + automation runner
- **Managed hosts:**
  - `sbl0` – perimeter RPi (reverse proxy & security gateway)
  - `sbl1` – Ubuntu 24.04 server (main services & LLM stack)
  - `sblX` – HPC nodes (batch workers, GPUs, etc.)
- **Primary tools:** SSH, WireGuard/Tailscale, Ansible, git

## 0. Prerequisites

1. Raspberry Pi 4/5 with 4GB+ RAM and reliable power supply.
2. 16GB+ microSD card (Class 10/UHS-I).
3. Ethernet uplink preferred (Wi-Fi fallback acceptable).
4. SSH keypair (`~/.ssh/id_ed25519`) with the public key copied to GitHub and to each managed host.
5. Latest `antimony-labs` repository cloned locally (or ready to pull).

## 1. Flash Raspberry Pi OS Lite

1. Download **Raspberry Pi OS Lite (64-bit)**.
2. Flash using Raspberry Pi Imager or `dd`.
3. Before ejecting the SD card, add an empty `ssh` file to the boot partition to enable SSH.
4. Optional: add `wpa_supplicant.conf` if Wi-Fi is required.

## 2. First Boot Hardening

```bash
# Default login
ssh pi@<key-pi-ip>
pass: raspberry

# Create admin user and disable default `pi`
sudo adduser curious
sudo usermod -aG sudo curious
sudo passwd -l pi

# Set hostname
sudo hostnamectl set-hostname sbl-key

# Update & reboot
sudo apt update && sudo apt full-upgrade -y
sudo reboot
```

Reconnect as `curious@sbl-key`.

## 3. Base Packages & Firewall

```bash
sudo apt install -y git curl ufw fail2ban python3-pip
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw enable
```

Optional: enable unattended upgrades for automatic security patches.

### Quick Bootstrap Script

Once you have `antimony-labs` cloned on the key Pi, you can automate most of the remaining configuration with:

```bash
cd ~/workspace/antimony-labs
sudo ./scripts/setup-key-rpi.sh
```

The script creates/updates the `curious` user, locks the default `pi` account, installs the base packages (git, curl, ufw, fail2ban, python3, ansible), configures the firewall, and scaffolds an Ansible workspace at `~/workspace/ops` with starter inventory and playbook files. Review the summary the script prints, then update the generated `inventory.ini` with the real LAN or WireGuard addresses before running any playbooks.

## 4. WireGuard / Tailscale Access

Choose one secure overlay so the key Pi is reachable from anywhere.

### Option A: WireGuard (recommended if already running on `sbl0`)

1. Generate a new WireGuard keypair on the key Pi.
2. Add the peer to `sbl0`'s `/etc/wireguard/wg0.conf` and restart WireGuard.
3. Place the matching config on the key Pi (`/etc/wireguard/wg0.conf`) and enable it:
   ```bash
   sudo systemctl enable wg-quick@wg0
   sudo systemctl start wg-quick@wg0
   ```

### Option B: Tailscale

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --ssh --authkey tskey-auth-<generated>
```

Label the device `sbl-key` inside the Tailscale admin panel.

## 5. Git & Repository Setup

```bash
mkdir -p ~/workspace && cd ~/workspace
git clone https://github.com/Shivam-Bhardwaj/antimony-labs.git
cd antimony-labs
cp .credentials.example .credentials  # fill values securely (never commit)
```

Configure git identity if needed:

```bash
git config --global user.name "Shivam Bhardwaj"
git config --global user.email "shivam@shivambhardwaj.com"
```

## 6. SSH Access To Managed Hosts

Copy the key Pi's public SSH key to each host.

```bash
ssh-copy-id curious@sbl0.local
ssh-copy-id curious@sbl1.local
ssh-copy-id curious@sblx.local
```

Alternatively, append the key manually to `~/.ssh/authorized_keys` on each host.

Map hostnames in `/etc/hosts` for convenience:

```bash
sudo tee -a /etc/hosts <<'EOK'
10.0.0.201 sbl0
10.0.0.202 sbl1
10.0.0.210 sblx
EOK
```

Adjust addresses to match your LAN.

## 7. Install Ansible & Bootstrap Inventory

```bash
sudo apt install -y ansible
mkdir -p ~/workspace/ops
cat <<'INVENTORY' > ~/workspace/ops/inventory.ini
[sbl_edge]
sbl0 ansible_host=10.0.0.201 ansible_user=curious

[core]
sbl1 ansible_host=10.0.0.202 ansible_user=curious

[hpc]
sblx ansible_host=10.0.0.210 ansible_user=curious
INVENTORY
```

Test connectivity:

```bash
ansible all -i ~/workspace/ops/inventory.ini -m ping
```

## 8. Reusable Playbooks

Create a starter playbook to configure each tier.

```bash
cat <<'SITE' > ~/workspace/ops/site.yml
---
- hosts: sbl_edge
  become: true
  roles:
    - role: roles/sbl0

- hosts: core
  become: true
  roles:
    - role: roles/sbl1

- hosts: hpc
  become: true
  roles:
    - role: roles/sblx
SITE
```

Populate `roles/` with tasks for package installs, Docker setup, service templates, and credential sync. Commit only the automation code—never plain-text secrets.

Run deployments when needed:

```bash
ansible-playbook -i ~/workspace/ops/inventory.ini site.yml
```

## 9. Secrets Handling

- Store API keys in `/root/antimony-labs/.credentials` on the key Pi.
- Use Ansible Vault for sensitive variables (`ansible-vault create group_vars/all/vault.yml`).
- Restrict permissions: `chmod 600 ~/.git-credentials`, `.credentials`, and vault files.

## 10. Operational Checklist Before Each Use

1. Plug the key Pi into power and internet.
2. Confirm overlay network connectivity (WireGuard/Tailscale).
3. `ssh curious@sbl-key` and run `ansible all -i inventory.ini -m ping`.
4. Apply desired playbooks (`site.yml`, `update.yml`, etc.).
5. Monitor logs via `tmux` or `ssh` sessions as needed.
6. Disconnect and store the key Pi securely after the maintenance window.

## 11. Optional Enhancements

- Install `tmux`, `btop`, or `lazydocker` for richer terminal workflows.
- Configure log shipping (e.g., `promtail` or `vector`) from managed hosts.
- Schedule cron jobs that pull the latest Git repositories nightly.
- Enforce hardware-backed SSH (YubiKey + `ssh-sk`) and set `AllowUsers curious` in `sshd_config`.

Once this Pi is prepared, it becomes the portable "key" that orchestrates the Antimony Labs infrastructure. Keep it offline when not in active use and rotate credentials regularly.
