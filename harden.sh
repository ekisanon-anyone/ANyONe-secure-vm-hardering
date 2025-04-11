#!/bin/bash

set -e

LOGFILE="/var/log/nuclear-security.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "[*] Nuclear Security Initiated at $(date)"

# 1. Update system
apt update && apt full-upgrade -y

# 2. Essential tools
apt install -y ufw fail2ban curl vim auditd logwatch aide chkrootkit rkhunter apparmor-utils \
    psad knockd iptables-persistent cron net-tools gcc make unattended-upgrades watchdog

# 3. Auto-upgrades
dpkg-reconfigure --priority=low unattended-upgrades

# 4. Firewall setup
ufw default deny incoming
ufw default allow outgoing
ufw allow 54777/tcp  # Allow the new SSH port
ufw enable

# 5. SSH Config: Keep password & root access, change port to 54777
echo "[*] Securing SSH and changing port to 54777"
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

sed -i 's/^#\?Port .*/Port 54777/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config
echo "Authorized access only. All activity may be monitored and reported." > /etc/issue.net
sed -i 's/^#\?Banner.*/Banner \/etc\/issue.net/' /etc/ssh/sshd_config
systemctl reload sshd

# 6. Fail2Ban + Exit Relay Abuse Filter
echo "[*] Configuring Fail2Ban with exit-abuse protection"
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

# 7. Kernel & Networking Hardening
cat >> /etc/sysctl.conf <<EOF

# Networking & Kernel Security
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.tcp_timestamps = 0

# Extra kernel hardening
fs.suid_dumpable = 0
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.randomize_va_space = 2
kernel.yama.ptrace_scope = 2
EOF
sysctl -p

# 8. AppArmor Enforcement
aa-enforce /etc/apparmor.d/* || true

# 9. PSAD Logging
iptables -A INPUT -p tcp --syn -j LOG --log-prefix "SYN-FLOOD:"
iptables -A INPUT -p udp -j LOG --log-prefix "UDP-PACKET:"
iptables -A INPUT -p icmp -j LOG --log-prefix "ICMP-PACKET:"
psad -R && psad --sig-update

# 10. Honeypot User Creation
useradd honeyuser || true
passwd -l honeyuser
chage -E0 honeyuser
auditctl -w /home/honeyuser -p wa -k honeypot

# 11. Disable IPv6
cat >> /etc/sysctl.conf <<EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF
sysctl -p

# 12. AIDE Setup and Daily Integrity Check
aideinit
cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
echo "0 3 * * * root /usr/bin/aide.wrapper --check" > /etc/cron.d/aide-check

# 13. RKHunter / Chkrootkit
rkhunter --update
rkhunter --checkall
chkrootkit

# 14. Watchdog Service
systemctl enable watchdog
systemctl start watchdog

# 15. KnockD Configuration for SSH Port (54777)
cat > /etc/knockd.conf <<EOF
[options]
    UseSyslog

[openSSH]
    sequence = 7000,8000,9000
    seq_timeout = 15
    command = /usr/sbin/ufw allow 54777/tcp
    tcpflags = syn

[closeSSH]
    sequence = 9000,8000,7000
    seq_timeout = 15
    command = /usr/sbin/ufw deny 54777/tcp
    tcpflags = syn
EOF

systemctl enable knockd
systemctl start knockd

# 16. Optional: CrowdSec Installation
curl -s https://install.crowdsec.net | bash
apt install -y crowdsec-firewall-bouncer-iptables

# 17. Block USB Storage (Physical Hardening)
echo "blacklist usb-storage" > /etc/modprobe.d/usbblock.conf
update-initramfs -u

# 18. Secure Temporary Directories (/tmp, /var/tmp, /dev/shm)
echo "[*] Locking down temporary directories"
cat >> /etc/fstab <<EOF
tmpfs /tmp tmpfs defaults,noexec,nosuid,nodev 0 0
tmpfs /var/tmp tmpfs defaults,noexec,nosuid,nodev 0 0
tmpfs /dev/shm tmpfs defaults,noexec,nosuid,nodev 0 0
EOF

mount -o remount /tmp
mount -o remount /var/tmp
mount -o remount /dev/shm

# 19. Prevent IP/DNS Logging via rsyslog
echo "[*] Disabling IP/DNS logs from syslog"
cat > /etc/rsyslog.d/00-secure.conf <<EOF
module(load="imuxsock")
\$ActionFileEnableSync off
:msg, contains, "DNS" stop
:msg, contains, "named" stop
EOF
systemctl restart rsyslog

# 20. Create Exit Relay DOS Mitigation Configuration File
echo "[*] Creating exit relay DOS mitigation configuration"
cat > /etc/exit_relay_dos.conf <<'EOF'
####STATISTICS OPTIONS####
ExitPortStatistics 1
ExtraInfoStatistics 1
OverloadStatistics 1
EntryStatistics 1

##############DOS MITIGATION OPTIONS##############

DoSCircuitCreationEnabled 1
DoSCircuitCreationBurst 30
DoSCircuitCreationDefenseTimePeriod 3600 seconds #A random value between N+1 to 3/2*N
DoSCircuitCreationDefenseType 2 #Refuse circuit creation for the defense period
DoSCircuitCreationMinConnections 3
DoSCircuitCreationRate 3

DoSConnectionEnabled 1
DoSConnectionDefenseType 2 #Immediately close new connections
DoSConnectionMaxConcurrentCount 50
DoSConnectionConnectRate 20
DoSConnectionConnectBurst 30
DoSConnectionConnectDefenseTimePeriod 24 hours #A random value between N+1 to 3/2*N

DoSRefuseSingleHopClientRendezvous 1

####EXIT RELAY ONLY OPTIONS####

DoSStreamCreationEnabled 1
DoSStreamCreationDefenseType 3 #Close the circuit creating too many streams
DoSStreamCreationRate 100
DoSStreamCreationBurst 200

####HIDDEN SERVICE DOS OPTIONS####
HiddenServiceEnableIntroDoSBurstPerSec 200
HiddenServiceEnableIntroDoSRatePerSec 25
HiddenServicePoWDefensesEnabled 1
HiddenServicePoWQueueRate 250
HiddenServicePoWQueueBurst 2500
CompiledProofOfWorkHash 1

##############DOS MITIGATION OPTIONS##############
EOF

# (Note: Adjust your exit relay software configuration to read from /etc/exit_relay_dos.conf as needed.)

# 21. Logwatch Summary
logwatch --detail high --mailto root --range today

echo "[+] HARDENING COMPLETE. Nuke mode activated at $(date). Rebooting in 10 seconds..."
sleep 10
reboot
