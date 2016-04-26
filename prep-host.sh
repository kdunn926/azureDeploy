#!/bin/bash

IPADDR=$1
HOSTNAME=$2
SEGMENTS=$3
APITOKEN=$4
SSHPRIVKEY=$5

# Enable IP<->hostname mapping
echo -e "\n${IPADDR} ${HOSTNAME}" | tee --append /etc/hosts

# Allow passwordless sudo
sed -i -e 's/ALL$/NOPASSWD: ALL/' /etc/sudoers.d/waagent

# Don't require TTY for sudo
sed -i -e 's/^Defaults    requiretty/#Defaults    requiretty/' /etc/sudoers

# Allow loopback SSH
ssh-keyscan ${HOSTNAME} | tee --append /etc/ssh/ssh_known_hosts

# Generate ssh folder/key with right permissions, then overwrite
ssh-keygen -P "" -f /root/.ssh/id_rsa
echo -e "${SSHPRIVKEY}" > /root/.ssh/id_rsa

# Generate ssh folder/key with right permissions, then overwrite
su gpadmin -c 'ssh-keygen -P "" -f /home/gpadmin/.ssh/id_rsa'
echo -e "${SSHPRIVKEY}" > /home/gpadmin/.ssh/id_rsa

# Disable selinux
sed -ie "s|SELINUX=enforcing|SELINUX=disabled|" /etc/selinux/config
setenforce 0

# Install an configure fail2ban for the script kiddies
yum install epel-release -y
yum install fail2ban -y

cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

sed -ie "s|ignoreip = 127\.0\.0\.1/8|ignoreip = 127.0.0.1/8\nignoreip = ${IPADDR}/24|" /etc/fail2ban/jail.local

echo -e "\n\n
[ssh-iptables]
enabled  = true
filter   = sshd
action   = iptables[name=SSH, port=ssh, protocol=tcp]
logpath  = /var/log/secure
maxretry = 5
" >> /etc/fail2ban/jail.local 

service fail2ban start
chkconfig fail2ban on

yum install xfsprogs -y

if [ "${HOSTNAME}" -eq "mdw" ] ; then
    # Stage the GPDB appliance tarball
    curl -o /home/gpadmin/greenplum-db-appliance-4.3.8.0-build-1-RHEL5-x86_64.bin  -d "" -H "Authorization: Token ${APITOKEN}" -L https://network.pivotal.io/api/v2/products/pivotal-gpdb/releases/1624/product_files/4177/download

    chown gpadmin:gpadmin /home/gpadmin/greenplum-db-appliance-4.3.8.0-build-1-RHEL5-x86_64.bin

    # Create a cluster hostfile
    python -c "print 'mdw' ; print '\n'.join(['sdw{0}'.format(n+1) for n in range(${SEGMENTS})])" > /home/gpadmin/hostfile

    chown gpadmin:gpadmin /home/gpadmin/hostfile

    # Partition the data disk
    echo -e "n\np\n1\n\n\nw\n" | fdisk /dev/sdc

    # Create the XFS filesystem
    mkfs.xfs /dev/sdc1

    # Add an entry to /etc/fstab
    echo -e "/dev/sdc1  /data  xfs rw,noatime,inode64,allocsize=16m  0 0" >> /etc/fstab
else
    export SEGMENT=1
    # Run the prep-segment.sh

fi

# Fix ownership
chown gpadmin:gpadmin /data* 
