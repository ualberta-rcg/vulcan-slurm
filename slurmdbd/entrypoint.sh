#!/bin/bash
# =============================================================================
# slurmdbd container entrypoint
# =============================================================================
# Prepares munge, then execs slurmdbd in the foreground (k8s owns supervision
# and log collection). On a major Slurm version bump the first start runs the
# one-way DB schema conversion - it MUST be allowed to finish uninterrupted,
# which is why slurmdbd runs in the foreground with no wrapper that could
# restart or kill it mid-conversion.
#
# NOTE: the NFS-mounted config (/etc/slurm) is deliberately NOT chown/chmod'ed
# here. slurmdbd.conf permissions (600, slurm-owned) are managed on the NFS
# side; root is squashed by the export anyway, and the old chmod fought with
# the slurmctld entrypoint over the same files.
# =============================================================================

# =============================================================================
# DIRECTORY SETUP - container-local runtime dirs only
# =============================================================================

mkdir -p /var/log/slurm /var/run/slurm

# =============================================================================
# MUNGE SETUP - Standardized across all Slurm services
# =============================================================================

# Create Munge runtime directory
mkdir -p /run/munge

# Copy Munge key from secrets (mounted read-only) into the local etc
cp /etc/munge/.secret/munge.key /etc/munge/munge.key
chown munge:munge /etc/munge/munge.key /run/munge
chmod 400 /etc/munge/munge.key

# Start munged daemon in background
su -s /bin/bash -c "/usr/sbin/munged --foreground --log-file=/dev/stdout &" munge

# Wait for Munge to initialize
sleep 2

# =============================================================================
# SERVICE EXECUTION - Standardized across all Slurm services
# =============================================================================

# Run slurmdbd as the slurm user, in the foreground, with the CMD flags
# (-D foreground, -v verbose, -s log to stdout)
exec su -s /bin/bash slurm -c "/usr/sbin/slurmdbd $@"
