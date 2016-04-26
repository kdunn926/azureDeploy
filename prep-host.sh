#!/bin/bash

IPADDR=$1
HOSTNAME=$2
SEGMENTS=$3
APITOKEN=$4
SSHPRIVKEY=$5
IP_PREFIX=$6
SEGMENT_IP_BASE=$7

# Enable IP<->hostname mapping
echo -e "\n${IPADDR} ${HOSTNAME}" | tee --append /etc/hosts

# Allow passwordless sudo
sed -i -e 's/ALL$/NOPASSWD: ALL/' /etc/sudoers.d/waagent

# Don't require TTY for sudo
sed -i -e 's/^Defaults    requiretty/#Defaults    requiretty/' /etc/sudoers

# Allow loopback SSH
ssh-keyscan ${HOSTNAME} | tee --append /etc/ssh/ssh_known_hosts

# Generate ssh folder/key with right permissions, then overwrite
mkdir /root/.ssh
chmod 700 /root/.ssh
echo -e "${SSHPRIVKEY}" > /root/.ssh/id_rsa

# Generate ssh folder/key with right permissions, then overwrite
su gpadmin -c 'ssh-keygen -P "" -f /home/gpadmin/.ssh/id_rsa'
echo -e "${SSHPRIVKEY}" > /home/gpadmin/.ssh/id_rsa
rm -f /home/gpadmin/.ssh/id_rsa.pub

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

if [[ "${HOSTNAME}" == *"mdw"* ]] ; then
    # Stage the GPDB appliance tarball
    curl -o /home/gpadmin/greenplum-db-appliance-4.3.8.1-build-1-RHEL5-x86_64.bin  -d "" -H "Authorization: Token ${APITOKEN}" -L https://network.pivotal.io/api/v2/products/pivotal-gpdb/releases/1683/product_files/4369/download

    chown gpadmin:gpadmin /home/gpadmin/greenplum-db-appliance-*

    # Create a cluster deply hostfile
    python -c "print 'mdw' ; print '\n'.join(['sdw{0}'.format(n+1) for n in range(${SEGMENTS})])" > /home/gpadmin/hostfile

    chown gpadmin:gpadmin /home/gpadmin/hostfile

    # Update system host file with segment hosts
    python -c "print '\n'.join(['${IP_PREFIX}{0} {1}'.format(ip, 'sdw{0}'.format(n+1)) for n, ip in enumerate(range(${SEGMENT_IP_BASE}, ${SEGMENT_IP_BASE} + ${SEGMENTS}))])" >> /etc/hosts
    
    # Add cluster hosts to system-wide known_hosts
    for h in `grep sdw /etc/hosts | cut -f2 -d ' '` ; do ssh-keyscan ${h} | tee --append /etc/ssh/ssh_known_hosts ; done ;

    # Partition the data disk
    echo -e "n\np\n1\n\n\nw\n" | fdisk /dev/sdc

    # Create the XFS filesystem
    mkfs.xfs /dev/sdc1

    # Add an entry to /etc/fstab
    echo -e "/dev/sdc1  /data  xfs rw,noatime,inode64,allocsize=16m  0 0" >> /etc/fstab

    mkdir /data
    
    mount /data
else
    export SEGMENT=1
    # Run the prep-segment.sh

    READAHEAD="/sbin/blockdev --setra 16384 /dev/sd[c-z]"

    FSTAB_HEAD="# BEGIN GENERATED CONTENT"
    FSTAB_TAIL="# END GENERATED CONTENT"

    if [[ -z $DRIVE_PATTERN ]]; then
      DRIVE_PATTERN='/dev/sd[c-z]'
    fi

    #main() {
    #  echo Storage

    #  set_readahead

    #  calculate_volumes

    #  create_volumes
    #}

    #set_readahead() {
    #$READAHEAD
    echo "$READAHEAD" >> /etc/rc.local
    #}

    #calculate_volumes() {
      export GLOBIGNORE="/dev/xvdf"
      DRIVES=($(ls $DRIVE_PATTERN))
      DRIVE_COUNT=${#DRIVES[@]}

      if [[ -z "${VOLUMES}" ]]; then
        if [[ $DRIVE_COUNT -lt 8 ]]; then
          VOLUMES=1
        elif [[ $DRIVE_COUNT -lt 12 ]]; then
          VOLUMES=2
        else
          VOLUMES=4
        fi
      fi

      if (( ${DRIVE_COUNT} % ${VOLUMES} != 0 )); then
        echo "Drive count (${DRIVE_COUNT}) not divisible by number of volumes (${VOLUMES}), using VOLUMES=1"
        VOLUMES=1
      fi
    #}

    #create_volumes() {
      FSTAB=()

      umount /dev/md[0-9]* || true

      umount ${DRIVES[*]} || true

      mdadm --stop /dev/md[0-9]* || true

      mdadm --zero-superblock ${DRIVES[*]}

      for VOLUME in $(seq $VOLUMES); do
        DPV=$(expr "$DRIVE_COUNT" "/" "$VOLUMES")
        DRIVE_SET=($(ls ${DRIVE_PATTERN} | head -n $(expr "$DPV" "*" "$VOLUME") | tail -n "$DPV"))

        mdadm --create /dev/md${VOLUME} --run --level 0 --chunk 256K --raid-devices=${#DRIVE_SET[@]} ${DRIVE_SET[*]}

        mkfs.xfs -K -f /dev/md${VOLUME}

        mkdir -p /data${VOLUME}

        FSTAB+="/dev/md${VOLUME}  /data${VOLUME}  xfs rw,noatime,inode64,allocsize=16m  0 0\n"
      done

      mdadm --detail --scan > /etc/mdadm.conf

      for DRIVE in ${DRIVES[*]}; do
        sed -i -r "s|^${DRIVE}.+$||" /etc/fstab
      done

      sed -i -e "/$FSTAB_HEAD/,/$FSTAB_TAIL/d" /etc/fstab
      echo "$FSTAB_HEAD" >> /etc/fstab
      echo -e "${FSTAB[@]}" >> /etc/fstab
      echo "$FSTAB_TAIL" >> /etc/fstab

      mount -a
    #}

    #main "$@"

fi

# Fix ownership
chown -f gpadmin:gpadmin /data* 

echo "Done"
