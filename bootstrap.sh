#!/usr/bin/env bash

yum -y install dhcp tftp-server

mount -o loop /vagrant/VMware-VMvisor-Installer-6.0.0.update03-5050593.x86_64.iso /mnt/
cp -rf /mnt /var/lib/tftpboot/esxi60u3
umount /mnt/

echo '# dhcpd.conf
#
# Sample configuration file for ISC dhcpd
#

# option definitions common to all supported networks...
option domain-name "damon.local";
option domain-name-servers localhost.localhost;

default-lease-time 600;
max-lease-time 7200;

# If this DHCP server is the official DHCP server for the local
# network, the authoritative directive should be uncommented.
authoritative;

# Use this to send dhcp log messages to a different log file (you also
# have to hack syslog.conf to complete the redirection).
log-facility local7;

allow booting;
allow bootp;
option client-system-arch code 93 = unsigned integer 16;

# This is a very basic subnet declaration.

subnet 192.168.33.0 netmask 255.255.255.0 {
  range 192.168.33.100 192.168.33.110;
  option routers 192.168.33.10;
}

class "pxeclients" {
   match if substring(option vendor-class-identifier, 0, 9) = "PXEClient";
   # specifies the TFTP Server
   next-server 192.168.33.10;
   if option client-system-arch = 00:07 or option client-system-arch = 00:09 {
      # PXE over EFI firmware
      filename = "esxi60u3/mboot.efi";
   } else {
      # PXE over BIOS firmware
      filename = "pxelinux.0";
   }
}
' > /etc/dhcp/dhcpd.conf

echo 'service tftp
{
        socket_type             = dgram
        protocol                = udp
        wait                    = yes
        user                    = root
        server                  = /usr/sbin/in.tftpd
        server_args             = -s /var/lib/tftpboot
        disable                 = no 
        per_source              = 11
        cps                     = 100 2
        flags                   = IPv4
}' > /etc/xinetd.d/tftp

sed -i 's/\///g' /var/lib/tftpboot/esxi60u3/boot.cfg

mkdir -p /var/lib/tftpboot/pxelinux.cfg
cp /usr/share/syslinux/pxelinux.0 /var/lib/tftpboot/
echo y | cp /usr/share/syslinux/menu.c32 /var/lib/tftpboot/esxi60u3/

echo 'DEFAULT esxi60u3/menu.c32
MENU TITLE ESXi-6.0 Boot Menu
NOHALT 1
PROMPT 0
TIMEOUT 300
LABEL install
KERNEL esxi60u3/mboot.c32
APPEND -c esxi60u3/boot.cfg
MENU LABEL ESXi-6.0U3 ^Installer
LABEL hddboot
LOCALBOOT 0x80
MENU LABEL ^Boot from local disk' > /var/lib/tftpboot/pxelinux.cfg/default


/etc/init.d/xinetd restart
/etc/init.d/dhcpd restart
/etc/init.d/iptables stop
/etc/init.d/ip6tables stop