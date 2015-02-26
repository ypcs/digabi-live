#!/bin/sh

set -e

PROVISION_CHECKSUM="$(md5sum $0 |awk '{print $1}')"
PROVISION_STATEFILE="/root/.vagrant_provision_id"

if [ -f "${PROVISION_STATEFILE}" ]
then
    OLD_STATE="$(cat ${PROVISION_STATEFILE})"
    if [ "${OLD_STATE}" = "${PROVISION_CHECKSUM}" ]
    then
        echo "I: Already provisioned w/ ${PROVISION_CHECKSUM}, skipping..."
        exit 0
    fi
fi

contains() {
    string="$1"
    substring="$2"
    if test "${string#*$substring}" != "$string"
    then
        return 0
    else
        return 1
    fi
}

SNAPSHOT="false"

#
# Initialiaze new Vagrant (Debian wheezy/jessie)
#
DIGABI_REPOSITORY_PATH="/vagrant/custom-packages/digabi-repository"

if [ -x "/vagrant/scripts/vagrant-local.sh" ]
then
    echo "I: Run local Vagrant customization scripts.."
    /vagrant/scripts/vagrant-local.sh
fi

#
# Prefer IPv4 over IPv6
#
echo "I: Prefer IPv4 over IPv6..."
sed -i -e 's/#\(precedence ::ffff:.*100\)/\1/' /etc/gai.conf
sysctl -w net.ipv6.conf.all.disable_ipv6=1

if [ -f "/etc/apt/sources.list.d/digabi.list" ]
then
    echo "I: Digabi repository already configured, skipping configuration..."
else
    echo "I: Add Digabi repository..."
    if [ -f "${DIGABI_REPOSITORY_PATH}/digabi.list" ]
    then
        cp ${DIGABI_REPOSITORY_PATH}/digabi.list /etc/apt/sources.list.d/digabi.list
    else
        wget -qO /etc/apt/sources.list.d/digabi.list https://digabi.fi/debian/digabi.list
    fi
    if [ -f "${DIGABI_REPOSITORY_PATH}/digabi.asc" ]
    then
        apt-key add ${DIGABI_REPOSITORY_PATH}/digabi.asc
    else
        wget -qO- https://digabi.fi/debian/digabi.asc | apt-key add -
    fi
fi

if [ -n "${DEBIAN_MIRROR}" ]
then
    echo "I: Configuring custom Debian mirror: ${DEBIAN_MIRROR}..."
    if contains "${DEBIAN_MIRROR}" "snapshot.debian.org"
    then
        SNAPSHOT="true"
    fi
    if [ -z "${REPOSITORY_SUITE}" ]
    then
        REPOSITORY_SUITE="jessie"
    fi
    echo "deb ${DEBIAN_MIRROR} ${REPOSITORY_SUITE} main contrib non-free" >/etc/apt/sources.list
    echo "deb-src ${DEBIAN_MIRROR} ${REPOSITORY_SUITE} main contrib non-free" >>/etc/apt/sources.list
    echo "deb http://security.debian.org/ ${REPOSITORY_SUITE}/updates main contrib non-free" >>/etc/apt/sources.list
    echo "deb-src http://security.debian.org/ ${REPOSITORY_SUITE}/updates main contrib non-free" >>/etc/apt/sources.list
#    sed -ir "s,http://(ftp.[[:alpha:]][[:alpha:]].debian.org|http.debian.net)/debian(/)?,${DEBIAN_MIRROR},g" /etc/apt/sources.list
else
    echo "I: Using pre-configured Debian mirror."
fi

echo "I: Configure APT: do not install recommends..."
cat << EOF >/etc/apt/apt.conf.d/99-no-recommends
APT::Install-Recommends "false";
APT::Install-Suggests "false";
EOF

if [ "${SNAPSHOT}" = "true" ]
then
    echo "I: Using Debian snapshots, ignore APT Check-Valid-Until..."
    cat << EOF >/etc/apt/apt.conf.d/99-snapshots
Acquire::Check-Valid-Until "false";
EOF
fi

#install -o root -g root -m 755 /vagrant/provision/assets/build-dos /usr/local/bin

echo "I: Update package lists..."
apt-get -qy update

echo "I: Upgrade build system..."
DEBIAN_FRONTEND=noninteractive apt-get -qyf upgrade

echo "I: Install digabi-dev, rsync..."
DEBIAN_FRONTEND=noninteractive apt-get -o "Acquire::http::Pipeline-Depth=10" -qyf install digabi-buildbox rsync git

echo "I: Saving provisioning state..."
echo "${PROVISION_CHECKSUM}" >${PROVISION_STATEFILE}
