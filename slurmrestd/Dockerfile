# Base image
FROM debian:bullseye-slim

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

# Install Packages
RUN apt-get update && apt-get install -y \
    libpmix-dev \
    libpmix2 \
    libopenmpi-dev \
    libopenmpi3 \
    openmpi-bin \
    mailutils \
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

SHELL ["/bin/bash", "-c"]

RUN cd /tmp && \
    EXCLUDE_KEYWORDS=("slurmdbd" "slurmd" "slurmctld") && \
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

RUN apt-get upgrade -y

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
    mkdir -p /etc/hosts.d/ && touch /etc/hosts.d/hosts && \
    sed -i -E 's/^(passwd:\s*)files/\1slurm files/; s/^(group:\s*)files/\1slurm files/; s/^(hosts:\s*files)/\1 slurm/' /etc/nsswitch.conf

# Expose required ports
EXPOSE 6820

# Entry point
ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
CMD ["-f", "/etc/slurm/slurm.conf", "-a", "jwt", "-v"]

