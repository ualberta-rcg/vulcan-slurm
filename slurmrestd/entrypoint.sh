#!/bin/bash
# =============================================================================
# slurmrestd container entrypoint
# =============================================================================
# Prepares munge (and sssd when configured), then execs slurmrestd in the
# foreground (k8s owns supervision and log collection). Authentication is
# JWT-only: users present a token minted by `scontrol token`; the daemon
# itself talks to slurmctld/slurmdbd with munge.
#
# NOTE: the NFS-mounted config (/etc/slurm) is deliberately NOT chown/chmod'ed
# here - permissions are managed on the NFS side and root is squashed by the
# export anyway.
# =============================================================================

# Enable JWT authentication for Slurm REST API
export SLURM_JWT=daemon

# Set debug level (0-9 or "debug")
export SLURMRESTD_DEBUG=debug

# Set authentication type explicitly to JWT (ensure AuthAltTypes=auth/jwt is enabled in slurm.conf)
export SLURMRESTD_AUTH_TYPES=rest_auth/jwt

# Listen on TCP port 6820
export SLURMRESTD_LISTEN="0.0.0.0:6820"

# =============================================================================
# DIRECTORY SETUP - container-local runtime dirs only
# =============================================================================

mkdir -p /var/log/slurm /var/run/slurm

# =============================================================================
# SSSD SETUP - optional, only when a config is mounted
# =============================================================================
# The DaemonSet does not currently mount /etc/sssd/.secret/, so sssd is
# skipped here (REST requests are resolved end-to-end by slurmctld, which
# does run sssd). If the mount is added later this block picks it up.

if [ -f /etc/sssd/.secret/sssd.conf ]; then
    cp -rL /etc/sssd/.secret/* /etc/sssd
    chmod 700 /etc/sssd
    chmod 600 /etc/sssd/sssd.conf
    chown root:root /etc/sssd /etc/sssd/sssd.conf
    # -d 1 keeps the pod log readable; raise for LDAP debugging only.
    /usr/sbin/sssd -i -d 1 &
else
    echo "NOTE: /etc/sssd/.secret/sssd.conf not mounted - skipping sssd"
fi

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

# Run slurmrestd as the unprivileged slurmrest user with the CMD flags
exec su -s /bin/bash slurmrest -c "slurmrestd $*"
