# ANyONe-secure-vm-hardering
The ANyONe Network - Secure VM Hardening Script  This is a powerful VM security script made for high-risk servers, exit nodes, and exposed Linux environments. It’s built to lock down Debian/Ubuntu systems with extreme hardening.  Designed for: - Exit nodes 
# The ANyONe Network - Secure VM Hardening Script

Designed for:
- Exit nodes
- Hacktivist infrastructure
- Underground dev ops
- People who don’t want to get caught slippin’

## Features
- Enables root login with password (optional toggle)
- Applies strict firewall rules (UFW)
- Disables knockd, fail2ban if needed
- Removes file immutability locks
- Opens & restarts SSH properly
- No need for broken keyboard VNC magic

## Installation

Step 1: Clone the repo
```bash
git clone https://github.com/ekisanon/anyone-secure-vm-hardening.git

( bash <(curl -s https://raw.githubusercontent.com/ekisanon-anyone/ANyONe-secure-vm-hardering/main/harden.sh ) *COPY-PASTE*
cd anyone-secure-vm-hardening

Step 2: Run the script as root
chmod +x harden.sh
./harden.sh
You can also cURL it raw if you trust your own script:
bash <(curl -s https://raw.githubusercontent.com/your-username/anyone-secure-vm-hardening/main/harden.sh)

Usage
 • Run this right after VPS setup
 • Compatible with Debian/Ubuntu (20.04+)
 • Customize ports or toggle features by editing the script before running

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
