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
# Pull latest version (automatically rebuilt with latest Slurm)
docker pull rkhoja/vulcan-slurm:slurmctld

# Pull specific Slurm version
docker pull rkhoja/vulcan-slurm:slurmctld-24-11-6-1
```

## 📋 Requirements

### Required Volumes

1. **Munge Key** - `/etc/munge/.secret/munge.key` (k8s Secret, read-only)
2. **Slurm Config** - `/etc/slurm/slurm.conf` (read-only)
3. **Database Config** - `/etc/slurm/slurmdbd.conf` (read-only)
4. **State Directory** - `/var/spool/slurmctld` (read-write, persistent)
5. **SSSD Config** - `/etc/sssd/.secret/sssd.conf` (k8s Secret, read-only, if using LDAP)

### Creating the Secrets

The munge key and `sssd.conf` (which contains LDAP bind credentials) are
mounted from Kubernetes Secrets - they are the only credential material the
pods need and they never touch a shared filesystem:

```bash
kubectl -n slurm create secret generic slurm-munge-key \
  --from-file=munge.key=/path/to/munge.key

kubectl -n slurm create secret generic slurm-sssd-conf \
  --from-file=sssd.conf=/path/to/sssd.conf
```

The example manifest (`slurmctld-prod.yaml`) mounts them at
`/etc/munge/.secret/` and `/etc/sssd/.secret/`; the entrypoint copies them
into place with the ownership/permissions each daemon demands.

## 🔗 Dependencies

**slurmdbd must be running and accessible** - The container waits up to 120 seconds for slurmdbd on startup.

## 🚀 Deployment

### Kubernetes

```bash
kubectl apply -f slurmctld/slurmctld-prod.yaml
```

`slurmctld-prod.yaml` deploys **three controllers** (primary + two backups on stable LoadBalancer IPs) for high availability - see the [main README](../README.md) for the matching `SlurmctldHost` lines and the `strategy: Recreate` rationale.

## ⚙️ Startup Behavior

On startup, the container:
1. Regenerates `/etc/msmtprc` from `SMTP_HOST`/`SMTP_PORT`/`MAIL_FROM` (if set)
2. Generates JWT key at `/var/spool/slurmctld/jwt_hs256.key` (only if missing - i.e. brand-new clusters)
3. Starts Munge and SSSD services
4. Waits for slurmdbd to become available (up to 120s)
5. Starts `slurm_jobscripts.py` (logs with a `[jobscripts]` prefix, retries failed uploads)
6. Runs slurmctld with flags: `-DRvis`

## 🔧 Customization

**Environment Variables:**
- `SMTP_HOST` - Mail relay host (image default is a placeholder)
- `SMTP_PORT` - Mail relay port (default: `25`)
- `MAIL_FROM` - From address for job notifications

## 🔍 Troubleshooting

**Container won't start:**
- Check slurmdbd is accessible: `kubectl exec -it slurmctld-<pod> -- sacctmgr show cluster`
- Verify Munge key matches other services
- Check logs: `kubectl logs slurmctld-<pod>`

**JWT Key Issues:**
- Auto-generated on first run. To regenerate: `kubectl exec -it slurmctld-<pod> -- rm /var/spool/slurmctld/jwt_hs256.key` then restart pod

## 📚 Related Documentation

- [Slurm Documentation](https://slurm.schedmd.com/)
- [slurm.conf Configuration](https://slurm.schedmd.com/slurm.conf.html)
- [Main Repository README](../README.md)

## 🧠 About University of Alberta Research Computing

The [Research Computing Group](https://www.ualberta.ca/en/information-services-and-technology/research-computing/index.html) supports high-performance computing, data-intensive research, and advanced infrastructure for researchers at the University of Alberta and across Canada.

We help design and operate compute environments that power innovation — from AI training clusters to national research infrastructure.
