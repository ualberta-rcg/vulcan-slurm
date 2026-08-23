#!/bin/bash
# =============================================================================
# slurmctld container entrypoint
# =============================================================================
# Prepares the runtime pieces the controller needs, then execs slurmctld in
# the foreground (k8s owns supervision and log collection):
#   1. mail relay config from env vars (public image ships placeholders)
#   2. local runtime directories
#   3. JWT signing key (created on first boot of a brand new cluster)
#   4. sssd for LDAP user resolution (config mounted at /etc/sssd/.secret/)
#   5. munged (key mounted at /etc/munge/.secret/)
#   6. wait for slurmdbd, then start the jobscripts collector
#   7. exec slurmctld as the slurm user
#
# NOTE: the NFS-mounted config and state (/etc/slurm, /var/spool/slurmctld)
# are deliberately NOT chown/chmod'ed here. Their permissions are managed on
# the NFS side, root is squashed by the export anyway, and the old recursive
# chown fought with the other service entrypoints over the same files.
# =============================================================================

# =============================================================================
# MAIL RELAY CONFIG - regenerate /etc/msmtprc from env when provided
# =============================================================================

if [ -n "${SMTP_HOST}" ]; then
    cat > /etc/msmtprc <<EOF
defaults
auth           off
tls            on
tls_starttls   on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account default
host ${SMTP_HOST}
port ${SMTP_PORT:-25}
from ${MAIL_FROM:-slurm-alerts@example.org}
EOF
    chmod 644 /etc/msmtprc
    echo "Configured mail relay: ${SMTP_HOST}:${SMTP_PORT:-25} (from ${MAIL_FROM:-slurm-alerts@example.org})"
fi

# =============================================================================
# DIRECTORY SETUP - container-local runtime dirs only
# =============================================================================

mkdir -p /var/log/slurm /var/run/slurm

# =============================================================================
# JWT KEY - create on first boot of a brand-new cluster only
# =============================================================================
# Normally the key already exists in the shared StateSaveLocation and is
# owned by slurm on the NFS export; never overwrite it.

JWT_KEY_PATH="/var/spool/slurmctld/jwt_hs256.key"

if [ ! -f "$JWT_KEY_PATH" ]; then
    echo "Creating JWT key for Slurm..."
    openssl rand -hex 32 > "$JWT_KEY_PATH"
    chown slurm:slurm "$JWT_KEY_PATH" 2>/dev/null || true
    chmod 660 "$JWT_KEY_PATH" 2>/dev/null || true
fi

# =============================================================================
# SSSD SETUP - Standardized across Slurm services that require it
# =============================================================================
# The real sssd.conf is mounted read-only at /etc/sssd/.secret/ (a k8s
# Secret) and copied into place because sssd requires 0600 root-owned
# config, which a volume mount cannot guarantee by itself. -L dereferences
# the symlinks that Secret volumes use internally.

if [ -f /etc/sssd/.secret/sssd.conf ]; then
    cp -rL /etc/sssd/.secret/* /etc/sssd
    chmod 700 /etc/sssd
    chmod 600 /etc/sssd/sssd.conf
    chown root:root /etc/sssd /etc/sssd/sssd.conf
    # -d 1 keeps the pod log readable; raise for LDAP debugging only.
    /usr/sbin/sssd -i -d 1 &
else
    echo "WARNING: /etc/sssd/.secret/sssd.conf not mounted - LDAP lookups disabled"
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
# WAIT FOR SLURMDBD - the controller needs accounting up before it starts
# =============================================================================

timeout=120
counter=0
while ! sacctmgr show cluster &>/dev/null; do
    sleep 5
    counter=$((counter + 5))
    if [ $counter -ge $timeout ]; then
        echo "Timeout waiting for slurmdbd to become available"
        exit 1
    fi
    echo "Waiting for slurmdbd to become available..."
done

# =============================================================================
# JOBSCRIPTS COLLECTOR - uploads submit scripts to the userportal
# =============================================================================
# Runs as root because it reads the slurm-owned StateSaveLocation and the
# token config in /etc/slurm. Logs with a [jobscripts] prefix on stdout.

/usr/bin/python3 /usr/local/bin/slurm_jobscripts.py &

# =============================================================================
# SERVICE EXECUTION - Standardized across all Slurm services
# =============================================================================

# Run slurmctld as the slurm user, in the foreground, with the CMD flags
exec su -s /bin/bash slurm -c "/usr/sbin/slurmctld $@"
