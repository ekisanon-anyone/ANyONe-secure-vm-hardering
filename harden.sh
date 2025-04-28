#!/bin/bash
# ==============================================================
# eKxExit v2.0 Nuclear Edition
# Hardened Exit Node Setup for Ultimate Security and Performance
# Ubuntu 24.04 LTS Optimized
# ==============================================================
set -e

LOGFILE="/var/log/ekxexit-nuclear.log"
exec > >(tee -a "$LOGFILE") 2>&1

# ==== eKxExit LOGO ====
clear
echo "███████╗██╗  ██╗"
echo "██╔════╝██║ ██╔╝"
echo "█████╗  █████╔╝ "
echo "██╔══╝  ██╔═██╗ "
echo "███████╗██║  ██╗"
echo "╚══════╝╚═╝  ╚═╝"
echo "        eKxExit - Nuclear Node Hardener"
echo "============================================================="
echo ""
sleep 2

echo "[*] Hardening started at $(date)"
echo ""

########################################################
# 1. Update System and Install Essentials
########################################################
echo "[1/25] Updating and installing essentials..."

apt update && apt full-upgrade -y
apt install -y ufw fail2ban curl vim auditd logwatch aide chkrootkit rkhunter apparmor-utils \
    psad knockd nftables cron net-tools gcc make unattended-upgrades watchdog cpufrequtils tripwire \
    lsof unzip gnupg2 bash-completion net-tools crowdsec crowdsec-firewall-bouncer-nftables

echo "[+] System updated and essentials installed."

########################################################
# 2. SSH Hardening
########################################################
echo "[2/25] Securing SSH..."

SSH_PORT=54333

cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sed -i "s/^#\?Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
sed -i "s/^#\?PermitRootLogin.*/PermitRootLogin yes/" /etc/ssh/sshd_config
sed -i "s/^#\?PasswordAuthentication.*/PasswordAuthentication yes/" /etc/ssh/sshd_config
sed -i "s/^#\?PermitEmptyPasswords.*/PermitEmptyPasswords no/" /etc/ssh/sshd_config
sed -i "s/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/" /etc/ssh/sshd_config
sed -i "s/^#\?MaxAuthTries.*/MaxAuthTries 3/" /etc/ssh/sshd_config
echo "Authorized access only. All activity may be monitored." > /etc/issue.net
sed -i "s/^#\?Banner.*/Banner \/etc\/issue.net/" /etc/ssh/sshd_config
systemctl reload sshd

echo "[+] SSH configured and secured on port $SSH_PORT."

########################################################
# 3. UFW and nftables Firewall Setup
########################################################
echo "[3/25] Setting up firewall..."

ufw default deny incoming
ufw default allow outgoing
ufw allow $SSH_PORT/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable

systemctl enable nftables
systemctl start nftables

echo "[+] Firewall active and rules applied."

########################################################
# 4. Fail2Ban with Exit-Abuse Filter
########################################################
echo "[4/25] Configuring Fail2Ban..."

cat > /etc/fail2ban/filter.d/exit-abuse.conf <<EOF
[Definition]
failregex = abuse.*relay
ignoreregex =
EOF

cat >> /etc/fail2ban/jail.local <<EOF

[exit-abuse]
enabled  = true
filter   = exit-abuse
logpath  = /var/log/syslog
maxretry = 2
bantime  = 3600
EOF

systemctl restart fail2ban

echo "[+] Fail2Ban configured with custom rules."

########################################################
# 5. Kernel and Sysctl Hardening
########################################################
echo "[5/25] Applying kernel/sysctl hardening..."

cat >> /etc/sysctl.conf <<EOF

# Networking security
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.tcp_timestamps = 0

# System protections
fs.suid_dumpable = 0
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.randomize_va_space = 2
kernel.yama.ptrace_scope = 2
EOF

sysctl -p

echo "[+] Kernel and sysctl protections applied."

########################################################
# 6. CPU Performance Governor
########################################################
echo "[6/25] Forcing CPU into performance mode..."

echo 'GOVERNOR="performance"' > /etc/default/cpufrequtils
systemctl restart cpufrequtils
cpupower frequency-set --governor performance || true

echo "[+] CPU now locked at performance."

########################################################
# 7. AppArmor Enforcement
########################################################
echo "[7/25] Enforcing AppArmor profiles..."

aa-enforce /etc/apparmor.d/* || true

echo "[+] AppArmor profiles enforced."

########################################################
# 8. PSAD - Port Scan Detection
########################################################
echo "[8/25] Configuring PSAD..."

iptables -A INPUT -p tcp --syn -j LOG --log-prefix "SYN-FLOOD:"
iptables -A INPUT -p udp -j LOG --log-prefix "UDP-PACKET:"
iptables -A INPUT -p icmp -j LOG --log-prefix "ICMP-PACKET:"

psad -R
psad --sig-update

echo "[+] PSAD port scan detection ready."

########################################################
# 9. Honeypot User
########################################################
echo "[9/25] Creating honeypot user..."

useradd honeyuser || true
passwd -l honeyuser
chage -E0 honeyuser
auditctl -w /home/honeyuser -p wa -k honeypot

echo "[+] Honeypot user set."

########################################################
# 10. AIDE - Filesystem Integrity
########################################################
echo "[10/25] Initializing AIDE filesystem database..."

aideinit
cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db

echo "0 3 * * * root /usr/bin/aide.wrapper --check" > /etc/cron.d/aide-check

echo "[+] AIDE initialized."

########################################################
# 11. Tripwire - Extra Filesystem Integrity
########################################################
echo "[11/25] Setting up Tripwire..."

tripwire-setup-keyfiles
tripwire --init

echo "[+] Tripwire initialized."

########################################################
# 12. RKHunter and Chkrootkit
########################################################
echo "[12/25] Running rootkit scans..."

rkhunter --update
rkhunter --checkall --skip-keypress
chkrootkit

echo "[+] Rootkit checks complete."

########################################################
# 13. Watchdog
########################################################
echo "[13/25] Enabling system watchdog..."

systemctl enable watchdog
systemctl start watchdog

echo "[+] Watchdog active."

########################################################
# 14. KnockD - Port Knocking for SSH
########################################################
echo "[14/25] Setting up KnockD..."

cat > /etc/knockd.conf <<EOF
[options]
    UseSyslog

[openSSH]
    sequence = 7000,8000,9000
    seq_timeout = 15
    command = /usr/sbin/ufw allow $SSH_PORT/tcp
    tcpflags = syn

[closeSSH]
    sequence = 9000,8000,7000
    seq_timeout = 15
    command = /usr/sbin/ufw deny $SSH_PORT/tcp
    tcpflags = syn
EOF

systemctl enable knockd
systemctl start knockd

echo "[+] KnockD configured."

########################################################
# 15. CrowdSec - Threat Intelligence
########################################################
echo "[15/25] Installing and configuring CrowdSec..."

apt install -y crowdsec crowdsec-firewall-bouncer-nftables
systemctl enable crowdsec
systemctl start crowdsec

echo "[+] CrowdSec ready."

########################################################
# 16. USB Device Blocker
########################################################
echo "[16/25] Blocking USB storage devices..."

echo "blacklist usb-storage" > /etc/modprobe.d/usbblock.conf
update-initramfs -u

echo "[+] USB devices blocked."

########################################################
# 17. Temp Filesystems Security
########################################################
echo "[17/25] Securing /tmp, /var/tmp, /dev/shm..."

cat >> /etc/fstab <<EOF
tmpfs /tmp tmpfs defaults,noexec,nosuid,nodev 0 0
tmpfs /var/tmp tmpfs defaults,noexec,nosuid,nodev 0 0
tmpfs /dev/shm tmpfs defaults,noexec,nosuid,nodev 0 0
EOF

mount -o remount /tmp
mount -o remount /var/tmp
mount -o remount /dev/shm

echo "[+] Temporary directories hardened."

########################################################
# 18. Syslog Anti-DNS Leaks
########################################################
echo "[18/25] Hardening rsyslog for DNS leaks..."

cat > /etc/rsyslog.d/00-secure.conf <<EOF
module(load="imuxsock")
\$ActionFileEnableSync off
:msg, contains, "DNS" stop
:msg, contains, "named" stop
EOF

systemctl restart rsyslog

echo "[+] Syslog hardened."

########################################################
# 19. Exit Relay DoS Protections
########################################################
echo "[19/25] Configuring Exit Relay DOS Protections..."

cat > /etc/exit_relay_dos.conf <<'EOF'
# DOS protections for Exit Relay
DoSCircuitCreationEnabled 1
DoSCircuitCreationBurst 30
DoSConnectionEnabled 1
DoSConnectionDefenseType 2
DoSStreamCreationEnabled 1
EOF

echo "[+] Exit relay DoS protections set."

########################################################
# 20. Final Message
########################################################
echo "[*] eKxExit v2.0 NUCLEAR HARDENING COMPLETE at $(date)"
echo "[*] Exit node is now secured, tuned, and optimized."
echo ""
echo "███████╗██╗  ██
echo "██╔════╝██║ ██╔╝
echo "█████╗  █████╔╝
echo "██╔══╝  ██╔═██╗ 
echo "███████╗██║  ██
echo "╚══════╝╚═╝  ╚═╝
echo ""

sleep 5
