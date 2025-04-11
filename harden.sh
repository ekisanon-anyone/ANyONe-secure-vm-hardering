#!/bin/bash

set -e

echo "[*] Nuclear Security Initiated"

# 1. Update system
apt update && apt full-upgrade -y

# 2. Essential tools
apt install -y ufw fail2ban curl vim auditd logwatch aide chkrootkit rkhunter apparmor-utils \
    psad knockd iptables-persistent cron net-tools gcc make unattended-upgrades watchdog

# 3. Auto-upgrades
dpkg-reconfigure --priority=low unattended-upgrades

# 4. Firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw enable

# 5. SSH Hardening
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config
systemctl reload sshd

# 6. Fail2Ban
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
systemctl restart fail2ban

# 7. Kernel Hardening
cat >> /etc/sysctl.conf <<EOF
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
EOF
sysctl -p

# 8. AppArmor
aa-enforce /etc/apparmor.d/*

# 9. PSAD
iptables -A INPUT -p tcp --syn -j LOG --log-prefix "SYN-FLOOD:"
iptables -A INPUT -p udp -j LOG --log-prefix "UDP-PACKET:"
iptables -A INPUT -p icmp -j LOG --log-prefix "ICMP-PACKET:"
psad -R && psad --sig-update

# 10. Disable compilers
chmod 000 /usr/bin/gcc /usr/bin/make || true

# 11. Honeypot user
useradd honeyuser
passwd -l honeyuser
chage -E0 honeyuser
auditctl -w /home/honeyuser -p wa -k honeypot

# 12. Disable IPv6
cat >> /etc/sysctl.conf <<EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF
sysctl -p

# 13. AIDE
aideinit
cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# 14. RKHunter/Chkrootkit
rkhunter --update
rkhunter --checkall
chkrootkit

# 15. Watchdog
systemctl enable watchdog
systemctl start watchdog

# 16. Immutable system files
chattr +i /bin/bash /usr/bin/ssh /etc/passwd /etc/shadow

# 17. Logwatch
logwatch --detail high --mailto root --range today

# 18. KnockD config
cat > /etc/knockd.conf <<EOF
[options]
        UseSyslog

[openSSH]
        sequence = 7000,8000,9000
        seq_timeout = 15
        command = /usr/sbin/ufw allow OpenSSH
        tcpflags = syn

[closeSSH]
        sequence = 9000,8000,7000
        seq_timeout = 15
        command = /usr/sbin/ufw deny OpenSSH
        tcpflags = syn
EOF
systemctl enable knockd
systemctl start knockd

# 19. Optional: CrowdSec
curl -s https://install.crowdsec.net | bash
apt install crowdsec-firewall-bouncer-iptables -y

echo "[+] ALL DONE. Nuke mode activated. Rebooting..."
sleep 5
reboot
