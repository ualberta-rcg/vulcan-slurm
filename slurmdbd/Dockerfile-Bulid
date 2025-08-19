# Base image
FROM debian:bullseye-slim

# Set environment variables
ENV SLURM_VERSION=24-05-5-1
ENV PYTHON_VERSION=3.12.8
ENV MUNGE_VERSION=0.5.14
ENV PMIX_VERSION=5.0.6
ENV PREFIX=/opt/software/slurm
ENV MUNGE_PREFIX=/opt/software/munge
ENV PMIX_PREFIX=/opt/software/pmix
ENV PATH=/usr/local/ssl/bin:$PREFIX/bin:/opt/software/slurm/sbin:${PATH:-}
ENV LD_LIBRARY_PATH=/usr/local/ssl/lib:${LD_LIBRARY_PATH:-}

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    curl \
    git \
    ca-certificates \
    libhwloc-dev \
    liblua5.3-dev \
    libnuma-dev \
    libpam0g-dev \
    libpmix-dev \
    libreadline-dev \
    rrdtool \
    libyaml-dev \
    libjson-c-dev \
    libhttp-parser-dev \
    libev-dev \
    libev4 \
    man-db \
    wget \
    gcc \
    make \
    gettext \
    linux-headers-amd64 \
    pkg-config \
    autoconf \
    automake \
    libssl-dev \
    libtool   \
    libhdf5-dev \
    libmariadb-dev \
    libjwt-dev \
    libreadline-dev \
    libhttp-parser-dev \
    libjson-c-dev \
    libyaml-dev \
    libgtk2.0-dev \
    libcurl4-openssl-dev \
    libbpf-dev \
    libdbus-1-dev \
    libibumad-dev \
    libfreeipmi17 \
    libibmad-dev
  
# Add runtime configurations, users and groups for Munge and Slurm
RUN groupadd -r slurm && useradd -r -g slurm -s /bin/false slurm && \
    groupadd -r munge && useradd -r -g munge -s /bin/false munge 

# Install Python from source
RUN cd /usr/src && \
    wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz && \
    tar -xvf Python-${PYTHON_VERSION}.tgz && \
    cd Python-${PYTHON_VERSION} && \
    ./configure --enable-optimizations && \
    make -j$(nproc) && make altinstall && \
    ln -sf /usr/local/bin/python${PYTHON_VERSION%.*} /usr/local/bin/python3 && \
    ln -sf /usr/local/bin/pip${PYTHON_VERSION%.*} /usr/local/bin/pip3  && \
    ln -sf /usr/local/bin/python${PYTHON_VERSION%.*} /usr/bin/python3

# Build and install MUNGE
RUN mkdir -p /usr/src && cd /usr/src && \
    curl -LO https://github.com/dun/munge/archive/munge-${MUNGE_VERSION}.tar.gz && \
    tar -xzf munge-${MUNGE_VERSION}.tar.gz && \
    cd munge-munge-${MUNGE_VERSION} && \
    ./bootstrap && \
    CPPFLAGS="-I/usr/local/ssl/include" ./configure \
        --prefix=$MUNGE_PREFIX \
        --sysconfdir=/etc \
        --localstatedir=/var && \
    make -j$(nproc) && make install && \
    mkdir -p /var/run/munge /run/munge /var/lib/munge /var/log/munge /etc/munge && \
    chown -R munge:munge /etc/munge /var/run/munge /var/lib/munge /var/log/munge /run/munge && \ 
    cp /opt/software/munge/bin/* /usr/local/bin && \
    chmod 700 /var/lib/munge /var/run/munge && \
    chmod 755 /run/munge

# Build and install PMIx
RUN mkdir -p /usr/src && cd /usr/src && \
    curl -LO https://github.com/openpmix/openpmix/releases/download/v${PMIX_VERSION}/pmix-${PMIX_VERSION}.tar.gz && \
    tar -xzf pmix-${PMIX_VERSION}.tar.gz && cd pmix-${PMIX_VERSION} && \
    ./configure --prefix=$PMIX_PREFIX && make -j$(nproc) && make install

# Download and build Slurm
RUN mkdir -p /usr/src /etc/slurm /var/spool/slurm /var/log/slurm && cd /usr/src && \
    curl -LO https://github.com/SchedMD/slurm/archive/refs/tags/slurm-${SLURM_VERSION}.tar.gz && \
    tar -xzf slurm-${SLURM_VERSION}.tar.gz && cd slurm-slurm-${SLURM_VERSION} && \
    ./configure --prefix=$PREFIX \
                --sysconfdir=/etc/slurm \
                --with-munge=$MUNGE_PREFIX \
                --with-pmix=$PMIX_PREFIX \
                --enable-debug \
                --enable-pam \
                --enable-restd \
                --enable-lua && \
    make -j$(nproc) && make install && \
    touch /var/log/slurm/slurm-dbd.log
    

COPY slurmdbd.conf.template /etc/slurm/slurmdbd.conf.template
COPY entrypoint.sh /entrypoint.sh

# Clean Up
RUN chmod +x /entrypoint.sh && \
    rm -rf /usr/src/* /tmp/* /var/tmp/* && \
    rm -rf /usr/share/doc /usr/share/man /usr/share/locale /usr/share/info && \
    apt-get purge -y \
    build-essential \
    cmake \
    git \
    gcc \
    curl \
    wget \
    make \
    man-db \    
    linux-headers-amd64 \
    pkg-config \
    autoconf \
    automake \
    libtool && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/log/*

# Expose required ports
EXPOSE 6819

# Entry point
ENTRYPOINT ["/entrypoint.sh"]
CMD ["-Dvvv", "-s"]
