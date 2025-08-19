# Base image
FROM debian:bullseye-slim

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
    munge 

# Copy all .deb files into the container
COPY *.deb /tmp/

SHELL ["/bin/bash", "-c"]

RUN cd /tmp && \
    EXCLUDE_KEYWORDS=("slurmctld" "slurmrestd") && \
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
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/log/* /usr/src/* \
    /usr/share/doc /usr/share/man /usr/share/locale /usr/share/info

# Expose required ports
EXPOSE 6819

# Entry point
ENTRYPOINT ["/entrypoint.sh"]
#CMD ["-Dvvv", "-s"]
CMD ["-D", "-s"]
