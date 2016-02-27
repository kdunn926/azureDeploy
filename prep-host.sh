#!/bin/bash

IPADDR=$1
HOSTNAME=$2
USER=$3

# Enable IP<->hostname mapping
echo -e "\n${IPADDR} ${HOSTNAME}" | tee --append /etc/hosts

# Allow passwordless sudo
sed -i -e 's/ALL$/NOPASSWD: ALL/' /etc/sudoers.d/waagent

# Don't require TTY for sudo
sed -i -e 's/^Defaults    requiretty/#Defaults    requiretty/' /etc/sudoers

# Allow loopback SSH
mkdir ~${USER}/.ssh 
chmod 600 ~${USER}/.ssh
chown ${USER}:${USER} ~${USER}/.ssh
ssh-keyscan ${HOSTNAME} | tee --append ~${USER}/.ssh/known_hosts

