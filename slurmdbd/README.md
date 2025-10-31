<img src="https://www.ualberta.ca/en/toolkit/media-library/homepage-assets/ua_logo_green_rgb.png" alt="University of Alberta Logo" width="50%" />

# slurmdbd - Slurm Database Daemon

The Slurm database daemon that stores job accounting, resource usage, and cluster state information in a MySQL/MariaDB database.

![Docker Pulls](https://img.shields.io/docker/pulls/rkhoja/vulcan-slurm?label=slurmdbd&style=flat-square)

**Maintained by:** Rahim Khoja ([khoja1@ualberta.ca](mailto:khoja1@ualberta.ca)) & Karim Ali ([kali2@ualberta.ca](mailto:kali2@ualberta.ca))

## 🐳 Docker Image

**Image:** `rkhoja/vulcan-slurm:slurmdbd`  
**Port:** `6819`

### Pulling the Image

```bash
# Pull latest version
docker pull rkhoja/vulcan-slurm:slurmdbd

# Pull specific Slurm version
docker pull rkhoja/vulcan-slurm:slurmdbd-24-11-6-1
docker pull rkhoja/vulcan-slurm:slurmdbd-24-11-5-1
```

## 📋 Requirements

### Required Volumes/Configurations

1. **Munge Key** (Required)
   - Mount path: `/etc/munge/.secret/munge.key`
   - Must be the same key used by all Slurm services
   - Used for secure inter-service authentication

2. **Database Configuration** (Required)
   - Mount path: `/etc/slurm/slurmdbd.conf`
   - Must contain valid MySQL/MariaDB connection information
   - File permissions: 600 (readable only by slurm user)

### Database Backend

slurmdbd requires a MySQL or MariaDB database. The database must:

1. Be accessible from the container (network connectivity)
2. Have credentials configured in `slurmdbd.conf`
3. Have the database specified in `StorageLoc` already created (empty database is fine)

**Important:** slurmdbd **automatically initializes** the database schema when it first connects. You only need to create an empty database - no manual schema setup required!

## 🔗 Dependencies

- **MySQL/MariaDB database** must be running and accessible
- **Empty database** must exist (created manually, but slurmdbd auto-initializes schema)
- No dependency on other Slurm services (but other services depend on this one)

## 🚀 Building

### Prerequisites

You need Slurm DEB packages in the `slurm-debs/` directory (see main repository README for build process).

### Build Command

```bash
# Copy DEB packages to this directory first
cp ../slurm-debs/*.deb ./

# Build the image
docker build -t rkhoja/vulcan-slurm:slurmdbd .
```

**Note:** The Dockerfile automatically filters DEB packages and excludes `slurmctld` and `slurmrestd` packages - only installing what's needed for the database daemon.

## 🏃 Running

### Basic Docker Run

```bash
docker run -d \
  --name slurmdbd \
  -p 6819:6819 \
  -v /path/to/munge.key:/etc/munge/.secret/munge.key:ro \
  -v /path/to/slurmdbd.conf:/etc/slurm/slurmdbd.conf:ro \
  rkhoja/vulcan-slurm:slurmdbd
```

### Kubernetes Deployment

See `slurmdbd.yaml` for a complete Kubernetes deployment example.

## ⚙️ What the Container Does

On startup, the entrypoint script:

1. **Creates required directories** with proper permissions
2. **Sets up Munge** - copies Munge key and starts `munged` daemon
3. **Sets file permissions** on `slurmdbd.conf` (600, owned by slurm user)
4. **Runs slurmdbd** - with default flags: `-Dvs`
   - `-D`: Daemon mode (run in foreground)
   - `-v`: Verbose logging
   - `-s`: Log to syslog
5. **Auto-initializes database** - When slurmdbd first connects to the database, it automatically creates all required tables and schema if they don't exist

## 📦 Installed Components

### Slurm Packages
- slurmdbd daemon
- Slurm database tools (sacctmgr, etc.)
- All Slurm common libraries

### Other Components
- **Munge** - Authentication service
- **LDAP support** - Libraries for LDAP authentication (if needed)

### Excluded Packages
- `slurmctld` packages (separate container)
- `slurmrestd` packages (separate container)
- `slurmd` packages (compute node daemon)
- SSSD (not needed for database daemon)

## 📝 Configuration File

### slurmdbd.conf Example

```conf
# Database connection
StorageType=accounting_storage/mysql
StorageHost=mysql.example.com
StoragePort=3306
StorageUser=slurm
StoragePass=password
StorageLoc=slurm_acct_db

# Logging
LogFile=/var/log/slurm/slurm-dbd.log

# Security
AuthType=auth/munge
```

**Important:** 
- The `slurmdbd.conf` file must have **600 permissions** and be owned by the `slurm` user. The container sets these automatically.
- The database specified in `StorageLoc` must exist, but can be empty - slurmdbd will automatically create all required tables on first connection.

## 🔧 Customization

### Environment Variables

- `LOG_FILE` - Override log file location (default: `/dev/stdout`)

### Override CMD

You can override the default slurmdbd command:

```bash
docker run ... rkhoja/vulcan-slurm:slurmdbd -Dvvv -s
```

### Debug Mode

To debug the container without starting slurmdbd:

```bash
docker run -it --entrypoint /bin/bash \
  -v /path/to/slurmdbd.conf:/etc/slurm/slurmdbd.conf:ro \
  rkhoja/vulcan-slurm:slurmdbd
```

## 👥 Users

The container creates the following users:
- `slurm` (UID 999) - Runs the slurmdbd daemon
- `munge` (UID 972) - Runs Munge authentication
- `wwuser` (UID 2000) - Warewulf user
- `slurmrest` (UID 971) - For REST API (created but not used)
- `dist` (UID 2001) - Distributive network user

## 🔍 Troubleshooting

### slurmdbd won't start

1. **Check database connectivity:**
   ```bash
   docker exec slurmdbd mysql -h <host> -u <user> -p
   ```

2. **Check Munge key:**
   ```bash
   docker exec slurmdbd munge -n | munge -n
   # Should return without error
   ```

3. **Check logs:**
   ```bash
   docker logs slurmdbd
   ```

4. **Verify configuration file:**
   - Check `slurmdbd.conf` has correct database credentials
   - Ensure file permissions are correct (600)
   - Ensure the database exists (empty is fine - slurmdbd will auto-initialize)

### Database Connection Issues

1. **Test from container:**
   ```bash
   docker exec slurmdbd mysql -h <StorageHost> -P <StoragePort> -u <StorageUser> -p
   ```

2. **Check firewall rules** - port 3306 (or your configured port) must be open

3. **Verify database exists (must be created, but can be empty):**
   ```sql
   CREATE DATABASE IF NOT EXISTS slurm_acct_db;
   ```
   
   The database only needs to exist - slurmdbd will automatically create all tables and schema on first connection.

### Permission Issues

If you see permission errors, ensure:
- `slurmdbd.conf` is mounted with proper ownership
- The file has 600 permissions (the container sets this automatically)

## 📚 Related Documentation

- [Slurm Documentation](https://slurm.schedmd.com/)
- [slurmdbd.conf Configuration](https://slurm.schedmd.com/slurmdbd.conf.html)
- [Main Repository README](../README.md)

## 🧠 About University of Alberta Research Computing

The [Research Computing Group](https://www.ualberta.ca/en/information-services-and-technology/research-computing/index.html) supports high-performance computing, data-intensive research, and advanced infrastructure for researchers at the University of Alberta and across Canada.

We help design and operate compute environments that power innovation — from AI training clusters to national research infrastructure.
