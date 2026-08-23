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
# Pull latest version (automatically rebuilt with latest Slurm)
docker pull rkhoja/vulcan-slurm:slurmdbd

# Pull specific Slurm version
docker pull rkhoja/vulcan-slurm:slurmdbd-24-11-6-1
```

## 📋 Requirements

### Required Volumes

1. **Munge Key** - `/etc/munge/.secret/munge.key` (read-only)
2. **Database Config** - `/etc/slurm/slurmdbd.conf` (read-only, 600 permissions managed on the NFS side)
3. **JWT Key** - `/var/spool/slurmctld` (read-only, optional; required for `AuthAltTypes=auth/jwt` in `slurmdbd.conf`, which the `slurmdb/*` REST endpoints depend on)

### Database Backend

Requires MySQL/MariaDB with an **empty database** (slurmdbd auto-initializes the schema on first connection).

## 🚀 Deployment

### Kubernetes

```bash
kubectl apply -f slurmdbd/slurmdbd.yaml
```

## ⚙️ Startup Behavior

On startup, the container:
1. Starts Munge service
2. Runs slurmdbd in the foreground with flags: `-Dvs`
3. Auto-initializes database schema on first connection

**⚠️ Major version upgrades:** the first start of a new major version runs a **one-way database schema conversion** that can take several minutes on large accounting databases. Always take a `mysqldump` first, and never kill the pod mid-conversion (the generous startup probe in the example manifest budgets for this - remove probes entirely for very large migrations and watch the logs to completion).

## 📝 Configuration Example

```conf
StorageType=accounting_storage/mysql
StorageHost=mysql.example.com
StoragePort=3306
StorageUser=slurm
StoragePass=password
StorageLoc=slurm_acct_db
AuthType=auth/munge
```

**Important:** The database must exist but can be empty - slurmdbd automatically creates all tables on first connection.

## 🔍 Troubleshooting

**Container won't start:**
- Test database connectivity: `kubectl exec -it slurmdbd-<pod> -- mysql -h <host> -u <user> -p`
- Verify `slurmdbd.conf` has correct credentials
- Ensure database exists (empty is fine)
- Check logs: `kubectl logs slurmdbd-<pod>`

## 📚 Related Documentation

- [Slurm Documentation](https://slurm.schedmd.com/)
- [slurmdbd.conf Configuration](https://slurm.schedmd.com/slurmdbd.conf.html)
- [Main Repository README](../README.md)

## 🧠 About University of Alberta Research Computing

The [Research Computing Group](https://www.ualberta.ca/en/information-services-and-technology/research-computing/index.html) supports high-performance computing, data-intensive research, and advanced infrastructure for researchers at the University of Alberta and across Canada.

We help design and operate compute environments that power innovation — from AI training clusters to national research infrastructure.
