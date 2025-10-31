<img src="https://www.ualberta.ca/en/toolkit/media-library/homepage-assets/ua_logo_green_rgb.png" alt="University of Alberta Logo" width="50%" />

# slurmrestd - Slurm REST API Daemon

The Slurm REST API daemon that provides programmatic access to Slurm cluster information and operations via HTTP/HTTPS.

![Docker Pulls](https://img.shields.io/docker/pulls/rkhoja/vulcan-slurm?label=slurmrestd&style=flat-square)

**Maintained by:** Rahim Khoja ([khoja1@ualberta.ca](mailto:khoja1@ualberta.ca)) & Karim Ali ([kali2@ualberta.ca](mailto:kali2@ualberta.ca))

## 🐳 Docker Image

**Image:** `rkhoja/vulcan-slurm:slurmrestd`  
**Port:** `6820`

### Pulling the Image

```bash
# Pull latest version
docker pull rkhoja/vulcan-slurm:slurmrestd

# Pull specific Slurm version
docker pull rkhoja/vulcan-slurm:slurmrestd-24-11-6-1
docker pull rkhoja/vulcan-slurm:slurmrestd-24-11-5-1
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
   - Must have `AuthAltTypes=auth/jwt` enabled for JWT authentication

3. **SSSD Configuration** (Required if using LDAP)
   - Mount path: `/etc/sssd/`
   - Complete SSSD directory structure including `sssd.conf` and `.secret/` directory
   - Required for LDAP/Active Directory user authentication

## 🔗 Dependencies

- **slurmctld must be running** (slurmrestd needs to communicate with the controller)
- JWT key must be configured in slurmctld for authentication to work
- The REST API uses JWT authentication by default

## 🚀 Building

### Prerequisites

You need Slurm DEB packages in the `slurm-debs/` directory (see main repository README for build process).

### Build Command

```bash
# Copy DEB packages to this directory first
cp ../slurm-debs/*.deb ./

# Build the image
docker build -t rkhoja/vulcan-slurm:slurmrestd .
```

**Note:** The Dockerfile automatically filters DEB packages and excludes `slurmdbd`, `slurmd`, and `slurmctld` packages - only installing what's needed for the REST API.

## 🏃 Running

### Basic Docker Run

```bash
docker run -d \
  --name slurmrestd \
  -p 6820:6820 \
  -v /path/to/munge.key:/etc/munge/.secret/munge.key:ro \
  -v /path/to/slurm.conf:/etc/slurm/slurm.conf:ro \
  -v /path/to/sssd:/etc/sssd:ro \
  rkhoja/vulcan-slurm:slurmrestd
```

### Kubernetes Deployment

See `slurmrestd.yaml` for a complete Kubernetes deployment example.

## ⚙️ What the Container Does

On startup, the entrypoint script:

1. **Sets environment variables:**
   - `SLURM_JWT=daemon` - Enable JWT authentication
   - `SLURMRESTD_DEBUG=debug` - Verbose debug logging
   - `SLURMRESTD_AUTH_TYPES=rest_auth/jwt` - Use JWT authentication
   - `SLURMRESTD_LISTEN=0.0.0.0:6820` - Listen on all interfaces, port 6820

2. **Creates required directories** with proper permissions

3. **Starts SSSD** (if configured) for LDAP authentication in background

4. **Sets up Munge** - copies Munge key and starts `munged` daemon

5. **Runs slurmrestd** - with default flags: `-f /etc/slurm/slurm.conf -a jwt -v`
   - `-f`: Configuration file path
   - `-a jwt`: Use JWT authentication
   - `-v`: Verbose logging

## 📦 Installed Components

### Slurm Packages
- slurmrestd daemon
- All Slurm client tools
- All Slurm common libraries

### Other Components
- **Munge** - Authentication service
- **SSSD** - System Security Services Daemon for LDAP
- **OpenMPI/PMIx** - MPI libraries for job support

### Excluded Packages
- `slurmdbd` packages (separate container)
- `slurmd` packages (compute node daemon)
- `slurmctld` packages (separate container)

## 🔐 Authentication

### JWT Authentication

The container uses **JWT (JSON Web Token) authentication** by default. The JWT key must be:

1. Generated in slurmctld (automatically done by slurmctld container)
2. Shared via the JWT key file or configured in slurm.conf
3. Referenced in slurm.conf with `AuthAltTypes=auth/jwt`

### slurm.conf Configuration

Ensure your `slurm.conf` includes:

```conf
# Enable JWT authentication
AuthAltTypes=auth/jwt

# JWT key location (if not using default)
# JwtFile=/var/spool/slurmctld/jwt_hs256.key
```

## 🔧 Customization

### Environment Variables

You can override default behavior:

- `LOG_FILE` - Override log file location (default: `/dev/stdout`)
- `SLURM_JWT` - JWT configuration (default: `daemon`)
- `SLURMRESTD_DEBUG` - Debug level (default: `debug`, can be 0-9 or "debug")
- `SLURMRESTD_AUTH_TYPES` - Authentication type (default: `rest_auth/jwt`)
- `SLURMRESTD_LISTEN` - Listen address (default: `0.0.0.0:6820`)

Example:
```bash
docker run -e SLURMRESTD_DEBUG=5 \
  -e SLURMRESTD_LISTEN="0.0.0.0:8080" \
  ... rkhoja/vulcan-slurm:slurmrestd
```

### Override CMD

You can override the default slurmrestd command:

```bash
docker run ... rkhoja/vulcan-slurm:slurmrestd \
  -f /etc/slurm/slurm.conf -a jwt -vvv
```

### Debug Mode

To debug the container without starting slurmrestd:

```bash
docker run -it --entrypoint /bin/bash \
  -v /path/to/slurm.conf:/etc/slurm/slurm.conf:ro \
  rkhoja/vulcan-slurm:slurmrestd
```

## 🌐 API Usage

### Example API Calls

Once running, you can access the REST API:

```bash
# Get cluster information
curl http://localhost:6820/slurm/v0.0.39/cluster

# Get job information (requires JWT token)
curl -H "X-SLURM-USER-NAME: username" \
     -H "X-SLURM-USER-TOKEN: <jwt-token>" \
     http://localhost:6820/slurm/v0.0.39/jobs

# Submit a job
curl -X POST \
     -H "X-SLURM-USER-NAME: username" \
     -H "X-SLURM-USER-TOKEN: <jwt-token>" \
     -H "Content-Type: application/json" \
     http://localhost:6820/slurm/v0.0.39/job/submit
```

### JWT Token Generation

To get a JWT token for API access:

```bash
# From slurmctld container
docker exec slurmctld cat /var/spool/slurmctld/jwt_hs256.key
```

Or use the Slurm JWT token generation tool (if available in your installation).

## 👥 Users

The container creates the following users:
- `slurmrest` (UID 971) - Runs the slurmrestd daemon
- `slurm` (UID 999) - Slurm service user
- `munge` (UID 972) - Runs Munge authentication
- `wwuser` (UID 2000) - Warewulf user
- `dist` (UID 2001) - Distributive network user

## 🔍 Troubleshooting

### slurmrestd won't start

1. **Check slurmctld connectivity:**
   ```bash
   docker exec slurmrestd sinfo
   ```

2. **Check Munge key:**
   ```bash
   docker exec slurmrestd munge -n | munge -n
   # Should return without error
   ```

3. **Check logs:**
   ```bash
   docker logs slurmrestd
   ```

4. **Verify configuration:**
   - Ensure `slurm.conf` has `AuthAltTypes=auth/jwt`
   - Ensure JWT key is accessible from slurmctld

### Authentication Issues

1. **Verify JWT is enabled in slurm.conf:**
   ```conf
   AuthAltTypes=auth/jwt
   ```

2. **Check JWT key exists in slurmctld:**
   ```bash
   docker exec slurmctld ls -la /var/spool/slurmctld/jwt_hs256.key
   ```

3. **Test JWT token:**
   Use a JWT token generator or check slurmctld logs for JWT-related errors

### API Connection Issues

1. **Check if service is listening:**
   ```bash
   docker exec slurmrestd netstat -tlnp | grep 6820
   # or
   curl http://localhost:6820/slurm/v0.0.39/cluster
   ```

2. **Check firewall rules** - port 6820 must be open

3. **Verify network connectivity** from client to container

## 📚 Related Documentation

- [Slurm REST API Documentation](https://slurm.schedmd.com/rest_api.html)
- [Slurm JWT Authentication](https://slurm.schedmd.com/jwt.html)
- [Main Repository README](../README.md)

## 🧠 About University of Alberta Research Computing

The [Research Computing Group](https://www.ualberta.ca/en/information-services-and-technology/research-computing/index.html) supports high-performance computing, data-intensive research, and advanced infrastructure for researchers at the University of Alberta and across Canada.

We help design and operate compute environments that power innovation — from AI training clusters to national research infrastructure.
