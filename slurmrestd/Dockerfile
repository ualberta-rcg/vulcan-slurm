# =============================================================================
# vulcan-slurm: slurmrestd image (Slurm REST API daemon)
# =============================================================================
# Build flow (see .github/workflows/build-push-workflow.yml):
#   1. The workflow copies the version-matched DEBs from slurm-debs/ into this
#      directory, so the build context contains *.deb for exactly one version.
#   2. docker build installs everything except the daemons that belong to the
#      other images (slurmctld/slurmd/slurmdbd) and -dbgsym debug packages.
#   3. The image is pushed as <repo>:slurmrestd and <repo>:slurmrestd-<version>.
#
# At runtime the container expects (mounted by the k8s DaemonSet):
#   /etc/slurm              - shared Slurm config
#   /etc/munge/.secret/     - cluster munge.key
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
    libpam-ldapd 

# =============================================================================
# MUNGE SETUP - Standardized across all Slurm services
# =============================================================================

# Install Munge package
# Note: munge package is already included in the apt-get install above

# Copy all .deb files into the container
COPY *.deb /tmp/

# =============================================================================
# DEB INSTALLATION - Standardized across all Slurm services
# =============================================================================

# Install every DEB from the build context except:
#   - daemons that belong to the other service images ("slurmd" also covers
#     slurmdbd by substring)
#   - *-dbgsym* debug-symbol packages (hundreds of MB, useless at runtime)

SHELL ["/bin/bash", "-c"]

RUN cd /tmp && \
    EXCLUDE_KEYWORDS=("slurmdbd" "slurmd" "slurmctld" "dbgsym") && \
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
EXPOSE 6820

# Entry point: entrypoint.sh preps munge then execs slurmrestd with the CMD
# flags (-f config file, -a jwt auth plugin, -v verbose). The listen address
# comes from SLURMRESTD_LISTEN set in entrypoint.sh.
ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
CMD ["-f", "/etc/slurm/slurm.conf", "-a", "jwt", "-v"]

