#!/bin/sh

yum install -y tftp-server dhcp-server httpd syslinux
wget https://mirrors.up.pt/rocky/8/isos/x86_64/Rocky-8.7-x86_64-minimal.iso -P /tmp/
mkdir -p /var/www/html/pub/Rocky8
echo "/tmp/Rocky-8.7-x86_64-minimal.iso /var/www/html/pub/Rocky8 iso9660 loop 0 0" > /etc/fstab
mount -avs
cp /var/www/html/pub/Rocky8/images/pxeboot/vmlinuz /var/lib/tftpboot/
cp /var/www/html/pub/Rocky8/images/pxeboot/initrd.img /var/lib/tftpboot/

systemctl enable --now httpd tftp dhcpd
firewall-cmd --permanent --add-service=tftp
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=dhcp
firewall-cmd --reload

tee -a /etc/dhcp/dhcpd.conf <<EOF
subnet 10.10.10.0 netmask 255.255.255.0 {
  range 10.10.10.151 10.10.10.152;
  option broadcast-address 10.10.10.255;
  option routers 10.10.10.150;
  option subnet-mask 255.255.255.0;
  option domain-name "mydomain.com";
  option domain-name-servers 10.10.10.150;
  next-server 10.10.10.150;
  filename 'pxelinux.0';
}
EOF

cp -prv /usr/share/syslinux/* /var/lib/tftpboot/
mkdir -p /var/lib/tftpboot/pxelinux.cfg
tee -a /var/lib/tftpboot/pxelinux.cfg/default <<EOF
default menu.c32
prompt 0
timeout 3
label Install Rocky Linux 8 from PXE
  kernel vmlinuz
  append initrd=initrd.img ip=dhcp inst.repo=http://10.10.10.150/pub/Rocky8 inst.ks=http://10.10.10.150/pub/rocky.ks
EOF

chmod -R 777 /var/lib/tftpboot

tee -a /var/www/html/pub/rocky.ks <<EOF
eula --agreed
text
url --url http://10.10.10.150/pub/Rocky8/BaseOS
keyboard --vckeymap=pt --xlayouts='pt'
lang en_GB.UTF-8
selinux --disabled
firewall --enabled --ssh
firstboot --disable
network  --bootproto=dhcp --device=eth0 --nameserver=10.10.10.254 --noipv6 --activate
reboot
ignoredisk --only-use=sda
rootpw --plaintext 12345678
timezone Europe/London --isUtc
bootloader --location=mbr --timeout=1 --boot-drive=vda
zerombr
clearpart --all --initlabel
autopart --type=lvm
%packages --ignoremissing
yum
dhclient
chrony
vim
@Core
%end
%addon com_redhat_kdump --disable --reserve-mb='auto'
%end
EOF

systemctl enable --now httpd dhcpd tftp
