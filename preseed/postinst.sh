#!/bin/sh

# The reference version of this script is maintained in
# ./live-build-config/kali-config/common/includes.installer/kali-finish-install
#
# It is used in multiple places to finish configuring the target system
# and build.sh copies it where required (in the simple-cdd configuration
# and in the live-build configuration).

configure_sources_list() {
    if grep -q '^deb ' /etc/apt/sources.list; then
	echo "INFO: sources.list is configured, everything is fine"
	return
    fi

    echo "INFO: sources.list is empty, setting up a default one for Kali"

    cat >/etc/apt/sources.list <<END
# See https://www.kali.org/docs/general-use/kali-linux-sources-list-repositories/
deb http://http.kali.org/kali kali-rolling main contrib non-free non-free-firmware

# Additional line for source packages
# deb-src http://http.kali.org/kali kali-rolling main contrib non-free non-free-firmware
END
    apt-get update
}

get_user_list() {
    for user in $(cd /home && ls); do
	if ! getent passwd "$user" >/dev/null; then
	    echo "WARNING: user '$user' is invalid but /home/$user exists" >&2
	    continue
	fi
	echo "$user"
    done
    echo "root"
}

configure_zsh() {
    if grep -q 'nozsh' /proc/cmdline; then
	echo "INFO: user opted out of zsh by default"
	return
    fi
    if [ ! -x /usr/bin/zsh ]; then
	echo "INFO: /usr/bin/zsh is not available"
	return
    fi
    for user in $(get_user_list); do
	echo "INFO: changing default shell of user '$user' to zsh"
	chsh --shell /usr/bin/zsh $user
    done
}

configure_usergroups() {
    # Ensure those groups exist
    addgroup --system kaboxer || true
    addgroup --system wireshark || true

    # adm - read access to log files
    # dialout - for serial access
    # kaboxer - for kaboxer
    # vboxsf - shared folders for virtualbox guest
    # wireshark - capture sessions in wireshark
    kali_groups="adm dialout kaboxer vboxsf wireshark"

    for user in $(get_user_list | grep -xv root); do
	echo "INFO: adding user '$user' to groups '$kali_groups'"
	for grp in $kali_groups; do
	    getent group $grp >/dev/null || continue
	    usermod -a -G $grp $user
	done
    done
}

configure_sources_list
configure_zsh
configure_usergroups

##################################
# Custom post-installation steps #
##################################

configure_swapfile() {
    dd if=/dev/zero of=/swapfile bs=2G count=1
    chmod 600 /swapfile
    mkswap /swapfile
    printf "/swapfile none swap sw 0 0\n" >> /etc/fstab
}

configure_swapfile
