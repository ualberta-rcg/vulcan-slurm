<img src="https://www.ualberta.ca/en/toolkit/media-library/homepage-assets/ua_logo_green_rgb.png" alt="University of Alberta Logo" width="50%" />

# slurmctld - Slurm Controller Daemon

The Slurm controller daemon that manages the entire cluster, schedules jobs, and coordinates with compute nodes.

![Docker Pulls](https://img.shields.io/docker/pulls/rkhoja/vulcan-slurm?label=slurmctld&style=flat-square)

**Maintained by:** Rahim Khoja ([khoja1@ualberta.ca](mailto:khoja1@ualberta.ca)) & Karim Ali ([kali2@ualberta.ca](mailto:kali2@ualberta.ca))

## 🐳 Docker Image

**Image:** `rkhoja/vulcan-slurm:slurmctld`  
**Port:** `6817`

### Pulling the Image

```bash
# Pull latest version
docker pull rkhoja/vulcan-slurm:slurmctld

# Pull specific Slurm version
docker pull rkhoja/vulcan-slurm:slurmctld-24-11-6-1
docker pull rkhoja/vulcan-slurm:slurmctld-24-11-5-1
```

## 📋 Requirements

### Required Volumes/Configurations

1. **Munge Key** (Required)
   - Mount path: `/etc/munge/.secret/munge.key`
   - Must be the same key used by all Slurm services
   - Used for secure inter-service authentication

2. **Slurm Configuration** (Required)
   - Mount path: `/etc/slurm/slurm.conf`
   - Main Slurm cluster configuration file

3. **Database Configuration** (Required)
   - Mount path: `/etc/slurm/slurmdbd.conf`
   - Configuration for connecting to the Slurm database daemon

4. **Slurm State Directory** (Required)
   - Mount path: `/var/spool/slurmctld`
   - Persistent storage for controller state files
   - Must be writable by user `slurm` (UID 999)

5. **SSSD Configuration** (Required if using LDAP)
   - Mount path: `/etc/sssd/`
   - Complete SSSD directory structure including `sssd.conf` and `.secret/` directory
   - Required for LDAP/Active Directory authentication

## 🔗 Dependencies

- **slurmdbd must be running and accessible** before slurmctld starts
- The entrypoint script waits up to 60 seconds for slurmdbd to become available
- If slurmdbd is not accessible, the container will exit with an error

## 🚀 Building

### Prerequisites

You need Slurm DEB packages in the `slurm-debs/` directory (see main repository README for build process).

### Build Command

```bash
# Copy DEB packages to this directory first
cp ../slurm-debs/*.deb ./

# Build the image
docker build -t rkhoja/vulcan-slurm:slurmctld .
```

**Note:** The Dockerfile automatically filters DEB packages and excludes `slurmdbd`, `slurmd`, and `slurmrestd` packages - only installing what's needed for the controller.

## 🏃 Running

### Basic Docker Run

```bash
docker run -d \
  --name slurmctld \
  -p 6817:6817 \
  -v /path/to/munge.key:/etc/munge/.secret/munge.key:ro \
  -v /path/to/slurm.conf:/etc/slurm/slurm.conf:ro \
  -v /path/to/slurmdbd.conf:/etc/slurm/slurmdbd.conf:ro \
  -v /path/to/slurmctld-state:/var/spool/slurmctld \
  -v /path/to/sssd:/etc/sssd:ro \
  rkhoja/vulcan-slurm:slurmctld
```

### Kubernetes Deployment

See `slurmctld.yaml` for a complete Kubernetes deployment example.

## ⚙️ What the Container Does

On startup, the entrypoint script:

1. **Creates required directories** with proper permissions
2. **Generates JWT key** at `/var/spool/slurmctld/jwt_hs256.key` (if it doesn't exist)
3. **Sets up Munge** - copies Munge key and starts `munged` daemon
4. **Starts SSSD** (if configured) for LDAP authentication
5. **Waits for slurmdbd** - checks connectivity using `sacctmgr show cluster`
6. **Starts slurm_jobscripts.py** - Python script for advanced job management
7. **Runs slurmctld** - with default flags: `-DRvis`
   - `-D`: Daemon mode (run in foreground)
   - `-R`: Reset state (optional, can be removed)
   - `-v`: Verbose logging
   - `-i`: Include in logging
   - `-s`: Log to syslog

## 📦 Installed Components

### Slurm Packages
- slurmctld daemon
- All Slurm client tools (sbatch, srun, squeue, etc.)
- All Slurm common libraries

### Other Components
- **Munge** - Authentication service
- **SSSD** - System Security Services Daemon for LDAP
- **OpenMPI/PMIx** - MPI libraries for job support
- **Python 3** with `slurm_jobscripts.py` - Advanced job management script
- **msmtp** - Email notification (configured for U of A SMTP)

### Excluded Packages
- `slurmdbd` packages (separate container)
- `slurmd` packages (compute node daemon)
- `slurmrestd` packages (separate container)

## 🔧 Customization

### Environment Variables

- `LOG_FILE` - Override log file location (default: `/dev/stdout`)

### Override CMD

You can override the default slurmctld command:

```bash
docker run ... rkhoja/vulcan-slurm:slurmctld -Dvvv -i -s
```

### Debug Mode

To debug the container without starting slurmctld:

```bash
docker run -it --entrypoint /bin/bash \
  -v /path/to/config:/etc/slurm:ro \
  rkhoja/vulcan-slurm:slurmctld
```

## 👥 Users

The container creates the following users:
- `slurm` (UID 999) - Runs the slurmctld daemon
- `munge` (UID 972) - Runs Munge authentication
- `wwuser` (UID 2000) - Warewulf user
- `slurmrest` (UID 971) - For REST API (created but not used)
- `dist` (UID 2001) - Distributive network user

## 🔍 Troubleshooting

### slurmctld won't start

1. **Check slurmdbd connectivity:**
   ```bash
   docker exec slurmctld sacctmgr show cluster
   ```

2. **Check Munge key:**
   ```bash
   docker exec slurmctld munge -n | munge -n
   # Should return without error
   ```

3. **Check logs:**
   ```bash
   docker logs slurmctld
   ```

4. **Verify configuration files:**
   - Ensure `slurm.conf` points to correct slurmdbd host
   - Ensure `slurmdbd.conf` has correct database connection

### JWT Key Issues

The JWT key is auto-generated on first run. If you need to regenerate it:

```bash
docker exec slurmctld rm /var/spool/slurmctld/jwt_hs256.key
# Restart container
```

## 📚 Related Documentation

- [Slurm Documentation](https://slurm.schedmd.com/)
- [slurm.conf Configuration](https://slurm.schedmd.com/slurm.conf.html)
- [Main Repository README](../README.md)

## 🧠 About University of Alberta Research Computing

The [Research Computing Group](https://www.ualberta.ca/en/information-services-and-technology/research-computing/index.html) supports high-performance computing, data-intensive research, and advanced infrastructure for researchers at the University of Alberta and across Canada.

We help design and operate compute environments that power innovation — from AI training clusters to national research infrastructure.
