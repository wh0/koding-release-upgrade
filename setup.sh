#!/bin/sh
export DEBIAN_FRONTEND=noninteractive
apt-mark showmanual | xargs apt-mark auto
apt-mark manual ldap-auth-client openssh-akc-server python-apt screen sudo ubuntu-minimal ubuntu-standard
apt-get -y -o Dpkg::Options::=--force-unsafe-io -o Apt::AutoRemove::SuggestsImportant=false autoremove --purge
sed -i 's/apt-mirror.in.koding.com/us.archive.ubuntu.com/g' /etc/apt/sources.list
rm /sbin/agetty /usr/share/man/man8/agetty.8.gz /bin/uncompress /bin/dnsdomainname /bin/domainname /bin/bzip2 /usr/sbin/uuidd
do-release-upgrade -f DistUpgradeViewNonInteractive
apt-get -y -o Dpkg::Options::=--force-unsafe-io install curl emacs24-nox git zip
