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

1. **Munge Key** - `/etc/munge/.secret/munge.key` (read-only)
2. **Slurm Config** - `/etc/slurm/slurm.conf` (read-only)
3. **Database Config** - `/etc/slurm/slurmdbd.conf` (read-only)
4. **State Directory** - `/var/spool/slurmctld` (read-write, persistent)
5. **SSSD Config** - `/etc/sssd/` (read-only, if using LDAP)

## 🔗 Dependencies

**slurmdbd must be running and accessible** - The container waits up to 60 seconds for slurmdbd on startup.

## 🚀 Deployment

### Kubernetes

```bash
kubectl apply -f slurmctld/slurmctld.yaml
```

## ⚙️ Startup Behavior

On startup, the container:
1. Generates JWT key at `/var/spool/slurmctld/jwt_hs256.key` (if missing)
2. Starts Munge and SSSD services
3. Waits for slurmdbd to become available
4. Starts `slurm_jobscripts.py` for job management
5. Runs slurmctld with flags: `-DRvis`

## 🔧 Customization

**Environment Variables:**
- `LOG_FILE` - Override log location (default: `/dev/stdout`)

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
