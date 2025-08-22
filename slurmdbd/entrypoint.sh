#!/bin/bash

# =============================================================================
# LOG REDIRECTION - Standardized across all Slurm services
# =============================================================================

# Redirect logs to stdout and stderr for Kubernetes
if [ -z "${LOG_FILE}" ] || [ "${LOG_FILE}" = "/var/log/slurm/slurm-dbd.log" ]; then
  export LOG_FILE=/dev/stdout
fi

# =============================================================================
# DIRECTORY SETUP - Standardized across all Slurm services
# =============================================================================

# slurmdbd-specific configuration
chown slurm:slurm /etc/slurm/slurmdbd.conf
chmod 600 /etc/slurm/slurmdbd.conf

# =============================================================================
# MUNGE SETUP - Standardized across all Slurm services
# =============================================================================

# Create Munge runtime directory
mkdir -p /run/munge

# Copy Munge key from secrets
cp /etc/munge/.secret/munge.key /etc/munge/munge.key

# Set proper ownership and permissions
chown munge:munge -R /etc/munge /run/munge
chmod 400 /etc/munge/munge.key

# Start munged daemon in background
su -s /bin/bash -c "/usr/sbin/munged --foreground --log-file=/dev/stdout &" munge

# Wait for Munge to initialize
sleep 2

# =============================================================================
# SERVICE EXECUTION - Standardized across all Slurm services
# =============================================================================

# Run slurmdbd as the slurm user
exec su -s /bin/bash slurm -c "/usr/sbin/slurmdbd $@"
