#!/bin/bash

# Redirect logs to stdout and stderr for Kubernetes
if [ -z "${LOG_FILE}" ] || [ "${LOG_FILE}" = "/var/log/slurm/slurm-dbd.log" ]; then
  export LOG_FILE=/dev/stdout
fi

# Slurm 
chown slurm:slurm /etc/slurm/slurmdbd.conf
chmod 600 /etc/slurm/slurmdbd.conf

# Setup Munge
mkdir /run/munge 
cp /etc/munge/.secret/munge.key /etc/munge/munge.key
chown munge:munge -R /etc/munge /run/munge 
chmod 400 /etc/munge/munge.key

# Start munge
su -s /bin/bash -c "/usr/sbin/munged --foreground --log-file=/var/log/munge/munge.log &" munge

# Wait briefly for munge to start
sleep 2

# Run slurmdbd
exec slurmdbd "$@"
