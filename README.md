# eKxExit v2.0 - Nuclear Node Hardener

Maximum security and maximum performance exit relay setup.  
Built for high-speed, exit-friendly environments running Ubuntu 24.04 LTS.  
Developed with brutal precision by eK.

---

## Features

- Full system update and package hardening
- SSH port move and banner warning setup
- Fail2Ban with custom Exit-Abuse protection
- nftables and UFW hybrid firewall
- PSAD (Port Scan Attack Detection)
- AppArmor full enforcement
- AIDE + Tripwire filesystem integrity monitoring
- Watchdog service for automatic recovery
- KnockD for SSH stealth access (port knocking)
- CrowdSec threat intelligence and firewall
- USB storage blocking
- Hardened /tmp, /var/tmp, /dev/shm
- Hardened sysctl network + kernel parameters
- Secure rsyslog to prevent IP/DNS leaks
- Honeypot user trap and audit logging
- Exit relay DoS protections for Tor/Anyone nodes
- Logging everything under /var/log/ekxexit-nuclear.log

---

## Requirements

- Ubuntu 24.04 LTS fresh or clean server
- Root access (sudo privileges)
- Recommended: Minimum 4GB RAM and 50GB SSD storage

---

## Installation

1) wget https://raw.githubusercontent.com/ekisanon-anyone/ANyONe-secure-vm-hardering/main/ekxexit-v2.0-nuclear.sh
2) chmod +x ekxexit-v2.0-nuclear.sh
3) sudo ./ekxexit-v2.0-nuclear.sh

One-Line installation:

bash <(curl -s https://raw.githubusercontent.com/ekisanon-anyone/ANyONe-secure-vm-hardering/main/ekxexit-v2.0-nuclear.sh)

Warning: This is serious hardening—use at your own risk. SSH config and service rules will be modified.

⸻

Example Fixes:
 • Unlocks /etc/passwd, /bin/bash, /usr/bin/ssh if previously made immutable
 • Stops fail2ban and knockd from locking you out
 • Enables SSH root login & password auth (optional)

⸻

Support

Need help, stuck in VNC hell, or something broke?

Contact: @eketh1 (https://t.me/eketh1) on Telegram
Or open an issue here on GitHub.

License

MIT. Use it. Fork it. Weaponize it (ethically).
---

## Script File Suggestion: harden.sh
You can drop the final script inside the repo root. I can help you polish it up to be safe, clean, and flexible (e.g. add flags like --no-root, --allow-ssh-port 2222, etc.)

---

Want me to format the actual harden.sh for you too?  
Just say the word and I’ll build the final version based on the commands we tested together.
