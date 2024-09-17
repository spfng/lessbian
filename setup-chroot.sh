#!/bin/bash

# Set as non-interactive so apt does not prompt for user input
export DEBIAN_FRONTEND=noninteractive

echo Set hostname
echo "unassigned-hostname" > /etc/hostname

echo Install security updates
apt-get update
apt-get -y upgrade

echo Set locale
apt-get -y install locales tzdata
sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
dpkg-reconfigure --frontend=noninteractive locales
update-locale LANG=en_US.UTF-8
echo "Europe/Moscow" > /etc/timezone
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
dpkg-reconfigure --frontend=noninteractive tzdata

echo Install packages
apt-get install -y --no-install-recommends linux-image-amd64 libpam-systemd live-boot systemd-sysv systemd-resolved systemd-timesyncd
apt-get install -y --no-install-recommends amd64-microcode intel-microcode
apt-get install -y --no-install-recommends firmware-linux-free
apt-get install -y --no-install-recommends cron nginx
apt-get install -y bash-completion cifs-utils curl dbus dosfstools fdisk gdisk iputils-ping isc-dhcp-client ksmbd-tools less openssh-client openssh-server procps ssl-cert vim wget wireguard-tools wpasupplicant
apt-get install -y dmidecode lshw mstflint sg3-utils smartmontools

echo Clean apt
apt clean
rm -rf /var/lib/apt/lists

echo Enable systemd-networkd as network manager
systemctl enable systemd-networkd

echo Enable systemd-resolved as dns manager
systemctl enable systemd-resolved

echo Enable systemd-timesyncd as ntp daemon
systemctl enable systemd-timesyncd

echo Showing IP-addresses on tty
mkdir -p /etc/issue.d
echo "\4 \6" > /etc/issue.d/ip-addresses.issue
echo "" >> /etc/issue.d/ip-addresses.issue

echo Set root password and share it
openssl rand -base64 22 > /var/www/html/password
echo "root:$(cat /var/www/html/password)" | chpasswd

echo Generate ssh-key and share it
ssh-keygen -q -t ed25519 -N "" -f -C ""
install -D -m 0644 /root/.ssh/id_ed25519.pub /root/.ssh/authorized_keys
install -D -m 0644 /root/.ssh/id_ed25519 /var/www/html/id_ed25519
install -D -m 0644 /root/.ssh/id_ed25519.pub /var/www/html/id_ed25519.pub

echo Setup nginx
make-ssl-cert generate-default-snakeoil
sed -i "s/# listen 443 ssl default_server;/listen 443 ssl default_server;/g" /etc/nginx/sites-available/default
sed -i "s/# listen \[::\]:443 ssl default_server;/listen \[::\]:443 ssl default_server;/g" /etc/nginx/sites-available/default
sed -i "s/# include snippets\/snakeoil.conf;/include snippets\/snakeoil.conf;/g" /etc/nginx/sites-available/default
sed -i "s/gzip on;/gzip off;/g" /etc/nginx/nginx.conf
sed -i "s/worker_processes auto;/worker_processes 2;/g" /etc/nginx/nginx.conf

echo Setup samba
ksmbd.adduser -a "admin" -p "password"
ksmbd.addshare -a "media" -o "path = /media"
ksmbd.addshare -u "media" -o "force group = root"
ksmbd.addshare -u "media" -o "force user = root"
ksmbd.addshare -u "media" -o "guest ok = yes"
ksmbd.addshare -u "media" -o "writeable = yes"
ksmbd.addshare -a "www" -o "path = /var/www"
ksmbd.addshare -u "www" -o "force group = www-data"
ksmbd.addshare -u "www" -o "force user = www-data"
ksmbd.addshare -u "www" -o "guest ok = yes"
ksmbd.addshare -u "www" -o "writeable = yes"
chown -R www-data:www-data /var/www/html

echo Disable MOTD
echo -n "" > /etc/motd
rm /etc/update-motd.d/10-uname

echo Remove machine-id
rm /etc/machine-id

echo List installed packages
dpkg-query -W -f='${Package}\t${Version}\t${Installed-Size}\n' | sort -k3 -n | tee /root/installed.txt

