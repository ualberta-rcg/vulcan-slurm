#!/bin/bash
# Enable JWT authentication for Slurm REST API
export SLURM_JWT=daemon

# Set debug level (0-9 or "debug")
export SLURMRESTD_DEBUG=debug

# Set authentication type explicitly to JWT (ensure AuthAltTypes=auth/jwt is enabled in slurm.conf)
export SLURMRESTD_AUTH_TYPES=rest_auth/jwt

# Listen on TCP port 6820 and a UNIX socket for security
export SLURMRESTD_LISTEN="0.0.0.0:6820"

# Redirect logs to stdout and stderr for Kubernetes
if [ -z "${LOG_FILE}" ] || [ "${LOG_FILE}" = "/var/log/slurm/slurmrestd.log" ]; then
  export LOG_FILE=/dev/stdout
fi

# Set proper permissions for slurm directories
mkdir -p /var/spool/slurmd /var/log/slurm/ /var/run/slurm /etc/slurm
touch /var/log/slurm/slurmrestd.log
chown -R slurm:slurm /var/spool/slurmd /var/log/slurm/ /var/run/slurm /etc/slurm
chmod 644 /etc/slurm/*.conf

# Setup Munge
mkdir /run/munge 
cp /etc/munge/.secret/munge.key /etc/munge/munge.key
chown munge:munge -R /etc/munge /run/munge 
chmod 400 /etc/munge/munge.key

# Start munged in the background
su -s /bin/bash -c "/usr/sbin/munged --foreground --log-file=/var/log/munge/munge.log &" munge

# Start sssd in the background
su -s /bin/bash -c "/usr/sbin/sssd -i -d 9 &" root

# Wait briefly for munge to start
sleep 2

# Run slurmctld as the slurm user
exec su -s /bin/bash slurmrest -c "slurmrestd $*"
