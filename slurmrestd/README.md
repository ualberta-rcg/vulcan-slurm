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
# Pull latest version (automatically rebuilt with latest Slurm)
docker pull rkhoja/vulcan-slurm:slurmrestd

# Pull specific Slurm version
docker pull rkhoja/vulcan-slurm:slurmrestd-24-11-6-1
```

## 📋 Requirements

### Required Volumes

1. **Munge Key** - `/etc/munge/.secret/munge.key` (read-only)
2. **Slurm Config** - `/etc/slurm/slurm.conf` (read-only)
   - Must have `AuthAltTypes=auth/jwt` enabled
3. **SSSD Config** - `/etc/sssd/.secret/sssd.conf` (read-only, optional; sssd is skipped when not mounted - user resolution happens in slurmctld)

## 🔗 Dependencies

**slurmctld must be running** - slurmrestd needs the controller to be available and JWT key configured.

## 🚀 Deployment

### Kubernetes

```bash
kubectl apply -f slurmrestd/slurmrestd.yaml
```

## ⚙️ Startup Behavior

On startup, the container:
1. Sets environment variables for JWT authentication
2. Starts Munge (and SSSD, only when its config is mounted)
3. Runs slurmrestd with flags: `-f /etc/slurm/slurm.conf -a jwt -v`

**Environment Variables Set:**
- `SLURM_JWT=daemon`
- `SLURMRESTD_AUTH_TYPES=rest_auth/jwt`
- `SLURMRESTD_LISTEN=0.0.0.0:6820`

## 🔧 Customization

**Environment Variables:**
- `SLURMRESTD_DEBUG` - Debug level (default: `debug`, can be 0-9)
- `SLURMRESTD_LISTEN` - Listen address (default: `0.0.0.0:6820`)

## 🌐 API Usage

**Mint a token (on the controller):**
```bash
scontrol token lifespan=300 username=<user>
```

**With JWT token:**
```bash
curl -H "X-SLURM-USER-NAME: username" \
     -H "X-SLURM-USER-TOKEN: <jwt-token>" \
     http://localhost:6820/slurm/v0.0.44/ping
```

**Note:** the `slurmdb/*` endpoints additionally require `AuthAltTypes=auth/jwt` in `slurmdbd.conf` (with the JWT key readable by slurmdbd).

## 🔍 Troubleshooting

**Container won't start:**
- Verify slurmctld is running
- Check `slurm.conf` has `AuthAltTypes=auth/jwt`
- Ensure JWT key exists in slurmctld: `/var/spool/slurmctld/jwt_hs256.key`
- Check logs: `kubectl logs slurmrestd-<pod>`

**API not accessible:**
- Verify port 6820 is open
- Test: `curl -H "X-SLURM-USER-NAME: <user>" -H "X-SLURM-USER-TOKEN: <jwt>" http://localhost:6820/slurm/v0.0.44/ping`

## 📚 Related Documentation

- [Slurm REST API Documentation](https://slurm.schedmd.com/rest_api.html)
- [Slurm JWT Authentication](https://slurm.schedmd.com/jwt.html)
- [Main Repository README](../README.md)

## 🧠 About University of Alberta Research Computing

The [Research Computing Group](https://www.ualberta.ca/en/information-services-and-technology/research-computing/index.html) supports high-performance computing, data-intensive research, and advanced infrastructure for researchers at the University of Alberta and across Canada.

We help design and operate compute environments that power innovation — from AI training clusters to national research infrastructure.
