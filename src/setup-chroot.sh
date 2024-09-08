#!/bin/bash

# Set as non-interactive so apt does not prompt for user input
export DEBIAN_FRONTEND=noninteractive

echo Set hostname
echo "unassigned-hostname" > /etc/hostname

echo Install security updates and apt-utils
apt-get update
apt-get -y install apt-utils
apt-get -y upgrade

echo Set locale
apt-get -y install locales
sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
dpkg-reconfigure --frontend=noninteractive locales
update-locale LANG=en_US.UTF-8

echo Install packages
apt-get install -y --no-install-recommends linux-image-amd64 live-boot systemd-sysv
apt-get install -y --no-install-recommends amd64-microcode intel-microcode qemu-guest-agent
apt-get install -y bash-completion curl dbus dosfstools fdisk iputils-ping isc-dhcp-client less nginx openssh-client openssh-server procps ssl-cert vim wget wireguard-tools
apt-get install -y firmware-linux-free firmware-linux-nonfree

echo Clean apt
apt clean
rm -rf /var/lib/apt/lists

echo Enable systemd-networkd as network manager
systemctl enable systemd-networkd

echo Set resolv.conf
echo "search unassigned-domain" > /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf

echo Showing IP-addresses on tty
mkdir -p /etc/issue.d
echo "\4 \6" > /etc/issue.d/ip-addresses.issue
echo "" >> /etc/issue.d/ip-addresses.issue

echo Remove MOTD
echo -n "" > /etc/motd
rm /etc/update-motd.d/10-uname

echo Set root password
echo "root:toor" | chpasswd

echo Generate self-signed certs
make-ssl-cert generate-default-snakeoil

echo Configure nginx
sed -i "s/# listen 443 ssl default_server;/listen 443 ssl default_server;/g" /etc/nginx/sites-available/default
sed -i "s/# listen \[::\]:443 ssl default_server;/listen \[::\]:443 ssl default_server;/g" /etc/nginx/sites-available/default
sed -i "s/# include snippets\/snakeoil.conf;/include snippets\/snakeoil.conf;/g" /etc/nginx/sites-available/default
sed -i "s/gzip on;/gzip off;/g" /etc/nginx/nginx.conf
sed -i "s/worker_processes auto;/worker_processes 2;/g" /etc/nginx/nginx.conf

echo Remove machine-id
rm /etc/machine-id

echo List installed packages
dpkg --get-selections | tee /root/installed.txt

