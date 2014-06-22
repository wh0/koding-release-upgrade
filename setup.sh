#!/bin/sh -x

export DEBIAN_FRONTEND=noninteractive

rm -f /etc/ssh/ssh_host_*
dpkg-reconfigure openssh-akc-server

echo '#clear APT::Never-MarkAuto-Sections;' > /etc/apt/apt.conf.d/80simple
echo 'APT::AutoRemove::SuggestsImportant "false";' >> /etc/apt/apt.conf.d/80simple

apt-mark showmanual | xargs apt-mark auto
apt-mark manual ldap-auth-client openssh-akc-server python-apt screen sudo ubuntu-minimal ubuntu-standard
apt-get -y -o Dpkg::Options::=--force-unsafe-io autoremove --purge

sed -i 's/apt-mirror.in.koding.com/us.archive.ubuntu.com/g' /etc/apt/sources.list

rm -f /sbin/agetty /usr/share/man/man8/agetty.8.gz /bin/uncompress /bin/dnsdomainname /bin/domainname /bin/bzip2 /usr/sbin/uuidd

do-release-upgrade -f DistUpgradeViewNonInteractive

apt-get -y -o Dpkg::Options::=--force-unsafe-io install curl emacs24-nox git zip

sync
