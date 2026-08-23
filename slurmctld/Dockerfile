# =============================================================================
# vulcan-slurm: slurmctld image (Slurm controller)
# =============================================================================
# Build flow (see .github/workflows/build-push-workflow.yml):
#   1. The workflow copies the version-matched DEBs from slurm-debs/ into this
#      directory, so the build context contains *.deb for exactly one version.
#   2. docker build installs everything except the daemons that belong to the
#      other images (slurmdbd/slurmd/slurmrestd) and the -dbgsym debug packages.
#   3. The image is pushed as <repo>:slurmctld and <repo>:slurmctld-<version>.
#
# At runtime the container expects (mounted by the k8s Deployment):
#   /etc/slurm              - shared Slurm config (slurm.conf, plugins, ini files)
#   /etc/munge/.secret/     - cluster munge.key
#   /etc/sssd/.secret/      - sssd.conf for LDAP user resolution
#   /var/spool/slurmctld    - shared StateSaveLocation (job state, JWT key)
# =============================================================================

# Base image
FROM debian:bullseye-slim

# =============================================================================
# ENVIRONMENT VARIABLES - Standardized across all Slurm services
# =============================================================================

# Set default environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm

# =============================================================================
# MAIL RELAY CONFIGURATION (build args)
# =============================================================================
# The image ships with placeholder values so the public image stays generic.
# Site-specific values are injected at runtime through the SMTP_HOST /
# SMTP_PORT / MAIL_FROM environment variables (see entrypoint.sh), or can be
# baked in for private builds with --build-arg.

ARG SMTP_HOST=smtp.example.org
ARG SMTP_PORT=25
ARG MAIL_FROM=slurm-alerts@example.org

# =============================================================================
# LDAP CONFIGURATION - Standardized across Slurm services that require it
# =============================================================================

# Pre-configure LDAP packages to avoid interactive prompts
RUN echo "nslcd nslcd/ldap-uris string ldap://localhost" | debconf-set-selections && \
    echo "nslcd nslcd/ldap-base string dc=example,dc=com" | debconf-set-selections && \
    echo "libnss-ldapd libnss-ldapd/nsswitch multiselect passwd, group, shadow" | debconf-set-selections && \
    echo "libpam-ldapd libpam-ldapd/enable-debug boolean false" | debconf-set-selections

# =============================================================================
# USER & GROUP SETUP - Standardized across all Slurm services
# =============================================================================
# Fixed UIDs/GIDs: these must match the UIDs used on the compute/login nodes
# and on the NFS exports, because credentials and file ownership cross the
# container boundary (munge key, StateSaveLocation, config files).

# --- 1. Create Slurm service user (UID 999) ---
RUN groupadd -g 999 slurm && useradd -u 999 -g 999 -m -s /bin/bash slurm

# --- 2. Create Munge authentication user (UID 972) ---
RUN groupadd -g 972 munge && useradd -u 972 -g 972 -m -s /sbin/nologin munge

# --- 3. Create wwuser user accounts (UID 2000) ---
RUN groupadd -g 2000 wwgroup && \
    useradd -u 2000 -m -d /local/home/wwuser -g wwgroup -G sudo,munge -s /bin/bash wwuser

# --- 4. Create slurmrest user for REST API (UID 971) ---
RUN groupadd -g 971 slurmrest && useradd -u 971 -g 971 -m -s /bin/false slurmrest

# --- 5. Create distributive.network user (UID 2001) ---
RUN groupadd -g 2001 distgroup && \
    useradd -u 2001 -m -d /local/home/dist -g distgroup -s /bin/bash dist

# =============================================================================
# PACKAGE INSTALLATION - Standardized across all Slurm services
# =============================================================================
# MPI/PMIx libraries satisfy the Slurm DEB dependencies; sssd + libnss-sss
# provide LDAP user resolution inside the pod; msmtp + mailutils give
# slurmctld a working MailProg for job mail notifications.

# Install Packages
RUN apt-get update && apt-get install -y \
    libpmix-dev \
    libpmix2 \
    libopenmpi-dev \
    libopenmpi3 \
    openmpi-bin \
    mailutils \
    curl \
    munge \
    sssd \
    sssd-tools \
    libnss-sss \
    libpam-sss \
    libsss-sudo \
    ldap-utils \
    libldap-common \
    libnss-ldapd \
    libpam-ldapd \
    python3 \
    python3-requests \
    bsd-mailx \
    msmtp \
    msmtp-mta \
    ca-certificates

# =============================================================================
# MAIL (msmtp) SETUP
# =============================================================================
# Default msmtp config from the build args above. entrypoint.sh regenerates
# this file at container start when SMTP_HOST/SMTP_PORT/MAIL_FROM env vars
# are provided by the Deployment, so one public image serves any site.

RUN cat > /etc/msmtprc <<EOF
defaults
auth           off
tls            on
tls_starttls   on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account default
host ${SMTP_HOST}
port ${SMTP_PORT}
from ${MAIL_FROM}
EOF

RUN chmod 644 /etc/msmtprc

# Copy all .deb files into the container
COPY *.deb /tmp/

# Job-script collector for the TrailblazingTurtle portal: vendored in this
# repo (reviewed changes only) instead of curling upstream main at build time,
# so builds are reproducible.
COPY slurm_jobscripts.py /usr/local/bin/slurm_jobscripts.py
RUN chmod 755 /usr/local/bin/slurm_jobscripts.py

# =============================================================================
# DEB INSTALLATION - Standardized across all Slurm services
# =============================================================================
# Install every DEB from the build context except:
#   - daemons that belong to the other service images (slurmdbd/slurmd/slurmrestd)
#   - *-dbgsym* debug-symbol packages (hundreds of MB, useless at runtime)

SHELL ["/bin/bash", "-c"]

RUN cd /tmp && \
    EXCLUDE_KEYWORDS=("slurmdbd" "slurmd" "slurmrestd" "dbgsym") && \
    ALL_DEBS=($(find ./ -maxdepth 1 -type f -name "*.deb")) && \
    INSTALL_LIST=() && \
    for deb in "${ALL_DEBS[@]}"; do \
        skip=false; \
        for keyword in "${EXCLUDE_KEYWORDS[@]}"; do \
            if [[ "$deb" == *"$keyword"* ]]; then \
                skip=true; \
                break; \
            fi; \
        done; \
        if [ "$skip" = false ]; then \
            INSTALL_LIST+=("$deb"); \
        fi; \
    done && \
    echo "The following .deb files will be installed:" && \
    printf '%s\n' "${INSTALL_LIST[@]}" && \
    if [ "${#INSTALL_LIST[@]}" -gt 0 ]; then \
        apt-get install -y "${INSTALL_LIST[@]}"; \
    else \
        echo "No .deb packages to install."; \
    fi

COPY entrypoint.sh /entrypoint.sh

# =============================================================================
# CLEANUP - Standardized across all Slurm services
# =============================================================================
# The nsswitch edit inserts the "slurm" NSS plugin (shipped with Slurm) ahead
# of "files" so tools inside the pod can resolve cluster node names, and sssd
# handles LDAP users via the standard sss entries.

RUN chmod +x /entrypoint.sh && \
    apt-get purge -y \
    man-db && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* \
    /var/tmp/* /var/log/* /usr/share/doc /usr/share/man \
    /usr/share/locale /usr/share/info && \
    mkdir -p /etc/hosts.d/ /var/spool/slurmd && touch /etc/hosts.d/hosts && \
    sed -i -E 's/^(passwd:\s*)files/\1slurm files/; s/^(group:\s*)files/\1slurm files/; s/^(hosts:\s*files)/\1 slurm/' /etc/nsswitch.conf

# Expose required ports
EXPOSE 6817

# Entry point: entrypoint.sh preps munge/sssd/jobscripts then execs
# slurmctld with the CMD flags (-D foreground, -R recover state, -v verbose,
# -i ignore versioned plugin errors, -s log to syslog/stdout).
ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
CMD ["-DRvis"]
