#!/bin/bash

IPADDR=$1
HOSTNAME=$2

echo -e "\n${IPADDR} ${HOSTNAME}" >> /etc/hosts
ssh-keyscan ${HOSTNAME} >> ~/.ssh/known_hosts

