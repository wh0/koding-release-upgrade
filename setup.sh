#!/bin/sh

# use default answers for any configuration
export DEBIAN_FRONTEND=noninteractive

# set some apt options for this procedure
cat > /etc/apt/apt.conf.d/99koding-release-upgrade <<EOF
// autoremove suggestions
APT::AutoRemove::SuggestsImportant "false";
// purge configuration files
APT::Get::Purge "true";
// don't sync on each operation
DPkg::Options {"--force-unsafe-io";};
// use current config files
DPkg::Options {"--force-confold";};
// keep manual list super tight
#clear APT::Never-MarkAuto-Sections;
EOF

gcc -shared -fPIC -xc - -ldl -o /usr/lib/libgiveup.so <<EOF
#define _GNU_SOURCE

#include <dlfcn.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

// some files cause ENOENT or EPERM when you try to make a hardlink of
// them (why?). to work around this, let dpkg unlink old files if it
// fails to back them up. use a custom library to detect failed backup
// links and unlink instead.

static int (*link_impl)(const char *, const char *);
__attribute__((constructor)) static void init() {
	link_impl = dlsym(RTLD_NEXT, "link");
}

int link(const char *oldpath, const char *newpath) {
	const int ret = link_impl(oldpath, newpath);
	// pass through if succeeded
	if (!ret) return ret;
	// pass through if some other error
	if (errno != ENOENT && errno != EPERM) return ret;
	// pass through if it doesn't look like a backup
	const int oldlen = strlen(oldpath);
	const int newlen = strlen(newpath);
	if (newlen != oldlen + 9) return ret;
	if (strncmp(oldpath, newpath, oldlen)) return ret;
	if (strcmp(".dpkg-tmp", newpath + oldlen)) return ret;
	// unlink instead
	fprintf(stderr, "libgiveup.so: unlinking %s\n", oldpath);
	return unlink(oldpath);
}

// ignoring sync speeds up these big operations, and it's not like
// people are gonna try to recover from a failure anyway. these shims
// are based on libeatmydata, but greatly simplified. glibc doesn't
// clear errno on success, so these shims don't either. neither apt
// nor dpkg seem to use O_SYNC or O_DSYNC, so `open` is not shimmed.

int fsync(int fd) {
	return 0;
}

int fdatasync(int fd) {
	return 0;
}

int msync(void *addr, size_t length, int flags) {
	return 0;
}
EOF

# do everything with our shims
export LD_PRELOAD=/usr/lib/libgiveup.so

# uninstall most of the bundled software, except:
# - ldap-auth-client is so that you can log in with your koding account
# - python-apt is for do-release-upgrade (shouldn't it be a dependency?)
# - screen is for the web terminal interface
# - sudo is so that you can do system administration as root
# - ubuntu-minimal and ubuntu-standard are for
# even uninstall openssh-akc-server, so that:
# - openssh-server postrm will work
# - regenerate host keys (all koding users are given the default keys)
apt-mark auto $(apt-mark showmanual)
apt-mark manual ldap-auth-client python-apt screen sudo ubuntu-minimal ubuntu-standard
apt-get -y autoremove openssh-server

# note: at this point we no longer have gcc, so everything we need
# better be built already

# reinstall the ssh server before we jump releases, because:
# - release upgrades will disable waeckerlin's repo
# - the current version references on ssh-vulnkey, which doesn't ship
#   in later Ubuntu releases
apt-get -y install openssh-akc-server

# koding's internal mirror doesn't have later releases, so switch to
# an external mirror before the upgrade
sed -i 's/apt-mirror.in.koding.com/us.archive.ubuntu.com/g' /etc/apt/sources.list

# raring -> saucy
do-release-upgrade -f DistUpgradeViewNonInteractive

# do-release-upgrade removes automatically installed packages that you
# can no longer download. this leaves them in the config-files
# state. purge them.
dpkg --purge $(dpkg -l | awk '/^rc / {print $2}')

# saucy -> trusty
do-release-upgrade -f DistUpgradeViewNonInteractive

# again, purge config files of obsolete packages
dpkg --purge $(dpkg -l | awk '/^rc / {print $2}')

# stop using our lib before we delete it
unset LD_PRELOAD

# clean up our stuff
rm -f /etc/apt/apt.conf.d/99koding-release-upgrade /usr/lib/libgiveup.so

# now that we're done, commit everything all at once
sync
