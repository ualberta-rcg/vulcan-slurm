# Base image
FROM debian:bullseye-slim

# Pre-configure LDAP packages to avoid interactive prompts
RUN echo "nslcd nslcd/ldap-uris string ldap://localhost" | debconf-set-selections && \
    echo "nslcd nslcd/ldap-base string dc=example,dc=com" | debconf-set-selections && \
    echo "libnss-ldapd libnss-ldapd/nsswitch multiselect passwd, group, shadow" | debconf-set-selections && \
    echo "libpam-ldapd libpam-ldapd/enable-debug boolean false" | debconf-set-selections

# Ensure UID and GID 999 for slurm before package installation
RUN groupadd -g 999 slurm && useradd -u 999 -g 999 -m -s /bin/bash slurm

# Ensure UID and GID 972 for Munge
RUN groupadd -g 972 munge && useradd -u 972 -g 972 -m -s /sbin/nologin munge 

# Ensure UID and GID 1000 for Munge
RUN groupadd -g 1000 wwgroup && useradd -u 1000 -g 972 -m -s /bin/bash wwuser

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
    libpam-ldapd \
    python3 \
    python3-requests \
    bsd-mailx \
    msmtp \
    msmtp-mta \
    ca-certificates \
    && ls -l

RUN cat > /etc/msmtprc <<EOF
defaults
auth           off
tls            on
tls_starttls   on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account default
host smtp.ualberta.ca
port 25
from vulcan-slurm-alerts@westdri.ca
EOF

RUN chmod 644 /etc/msmtprc

RUN cat /etc/msmtprc 

# Copy all .deb files into the container
COPY *.deb /tmp/

# Copy the Job Submit Script in. From Trailblazing Turtle. 
COPY slurm_jobscripts.py /usr/local/bin/

SHELL ["/bin/bash", "-c"]

RUN cd /tmp && \
    EXCLUDE_KEYWORDS=("slurmdbd" "slurmd" "slurmrestd") && \
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

# Clean Up
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
EXPOSE 6817

# Entry point
ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
#CMD ["-D", "-R", "-vvv", "-i", "-s"]
CMD ["-D", "-R", "-i", "-s"]
