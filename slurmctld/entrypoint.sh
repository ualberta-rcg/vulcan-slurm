#!/bin/bash

# Redirect logs to stdout and stderr for Kubernetes
if [ -z "${LOG_FILE}" ] || [ "${LOG_FILE}" = "/var/log/slurm/slurmctld.log" ]; then
  export LOG_FILE=/dev/stdout
fi

# Ensure the Slurm JWT key exists
JWT_KEY_PATH="/var/spool/slurmctld/jwt_hs256.key"

if [ ! -f "$JWT_KEY_PATH" ]; then
    echo "Creating JWT key for Slurm..."
    openssl rand -hex 32 > "$JWT_KEY_PATH"
fi

# Set proper permissions for slurm.conf
mkdir -p /var/spool/slurmctld /var/spool/slurmd /var/spool/slurmdbd /var/spool/slurmrestd /var/log/slurm/ /var/run/slurm /etc/slurm /run/munge 
touch /var/log/slurm/slurm-dbd.log /var/log/slurm/slurmctld.log /var/spool/slurmctld/priority_last_decay_ran
chown -R slurm:slurm /var/spool/slurmctld /var/spool/slurmd /var/spool/slurmdbd /var/spool/slurmrestd /var/log/slurm/ /var/run/slurm /etc/slurm 
chmod +x /usr/local/bin/slurm_jobscripts.py 
chmod 755 /var/spool/slurmctld
chmod 644 /etc/slurm/*.conf
chmod 660 "$JWT_KEY_PATH"
chown -R munge:munge /run/munge

# Setup SSSD
cp -r /etc/sssd/.secret/* /etc/sssd
chmod 700 /etc/sssd
chmod 600 /etc/sssd/sssd.conf
chown root:root /etc/sssd
chown root:root /etc/sssd/sssd.conf

# Setup Munge
cp /etc/munge/.secret/munge.key /etc/munge/munge.key
chown munge:munge -R /etc/munge
chmod 400 /etc/munge/munge.key

# Start munged in the background
su -s /bin/bash -c "/usr/sbin/munged --foreground --log-file=/var/log/munge/munge.log &" munge

# Start sssd in the background
su -s /bin/bash -c "/usr/sbin/sssd -i -d 6 &" root

# Wait briefly for munge to start
sleep 2

# Verify that the slurmdbd is accessible before starting slurmctld
timeout=60
counter=0
while ! sacctmgr show cluster &>/dev/null; do
    sleep 5
    counter=$((counter + 2))
    if [ $counter -ge $timeout ]; then
        echo "Timeout waiting for slurmdbd to become available"
        exit 1
    fi
    echo "Waiting for slurmdbd to become available..."
done

# Start Job Submit Script
su -s /bin/bash -c "/usr/bin/python3 /usr/local/bin/slurm_jobscripts.py &" root
#su -s /bin/bash -c "/usr/bin/python3 /usr/local/bin/slurm_jobscripts.py --verbose &" root

# Run slurmctld as the slurm user
exec su -s /bin/bash slurm -c "/usr/sbin/slurmctld $*"
