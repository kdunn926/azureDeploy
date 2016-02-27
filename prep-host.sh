#!/bin/bash

IPADDR=$1
HOSTNAME=$2
USER=$3

echo -e "\n${IPADDR} ${HOSTNAME}" | tee --append /etc/hosts
ssh-keyscan ${HOSTNAME} | tee --append ~${USER}/.ssh/known_hosts

