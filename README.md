<img src="./assets/ua_logo_green_rgb.png" alt="University of Alberta Logo" width="50%" />

# Vulcan Slurm Containers

[![CI/CD](https://github.com/ualberta-rcg/vulcan-slurm/actions/workflows/build-push-workflow.yml/badge.svg)](https://github.com/ualberta-rcg/vulcan-slurm/actions/workflows/build-push-workflow.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)

**Maintained by:** Rahim Khoja ([khoja1@ualberta.ca](mailto:khoja1@ualberta.ca)) & Karim Ali ([kali2@ualberta.ca](mailto:kali2@ualberta.ca))

## 🧰 Description

This repository contains **three hardened Docker containers** for Slurm control plane services, based on Debian Bullseye. These containers are designed for production deployment in Kubernetes environments and provide the core Slurm cluster management services.

The images are automatically built weekly (every Monday) or can be manually triggered via GitHub Actions.

## 📦 Docker Images

**Docker Hub:** [rkhoja/vulcan-slurm](https://hub.docker.com/r/rkhoja/vulcan-slurm)

The repository builds three separate Docker images:

### 1. **[slurmctld](./slurmctld/README.md)** - Slurm Controller Daemon
The primary Slurm controller that manages the entire cluster, schedules jobs, and coordinates with compute nodes.

**Port:** `6817`  
**Service:** Job scheduling and cluster coordination

See [slurmctld/README.md](./slurmctld/README.md) for detailed deployment instructions and Docker pull commands.

### 2. **[slurmdbd](./slurmdbd/README.md)** - Slurm Database Daemon
The accounting database daemon that stores job accounting, resource usage, and cluster state information.

**Port:** `6819`  
**Service:** Job accounting and database operations

See [slurmdbd/README.md](./slurmdbd/README.md) for detailed deployment instructions and Docker pull commands.

### 3. **[slurmrestd](./slurmrestd/README.md)** - Slurm REST API Daemon
The RESTful API service that provides programmatic access to Slurm cluster information and operations.

**Port:** `6820`  
**Service:** RESTful API for Slurm operations

See [slurmrestd/README.md](./slurmrestd/README.md) for detailed deployment instructions and Docker pull commands.

## 🏗️ What's Inside

Each container includes:

* **Slurm** (latest version, installed from custom DEB packages in `slurm-debs/`) - Images are constantly rebuilt with the latest Slurm release. Older versions are available via version-specific tags (e.g., `slurmctld-24-11-6-1`)
* **Service-specific Slurm components** (each image includes only what's needed)
* **Munge** authentication daemon for secure inter-service communication
* **SSSD/LDAP** support for user authentication and directory services
* **OpenMPI** and PMIx libraries for MPI job support
* **Python 3** with `slurm_jobscripts.py` (vendored in this repo) for uploading job scripts to a [TrailblazingTurtle](https://github.com/guilbaults/TrailblazingTurtle) portal, with `[jobscripts]`-prefixed stdout logging and upload retries
* **Email notification** via msmtp (generic image; set `SMTP_HOST`, `SMTP_PORT`, `MAIL_FROM` env vars at deploy time)
* Standardized user accounts:
  * `slurm` (UID 999) - Slurm service user
  * `munge` (UID 972) - Munge authentication user
  * `wwuser` (UID 2000) - Warewulf user account
  * `slurmrest` (UID 971) - REST API service user
  * `dist` (UID 2001) - Distributive network user

**Slurm** ([docs](https://slurm.schedmd.com/)) is fully configured and ready for production deployment.

## 🚀 How It Works

### Automated Build Pipeline

This repository uses a **two-stage automated build process**:

#### Stage 1: DEB Package Building (`build-and-commit-slurm-debs.yml`)

1. **Auto-detects latest Slurm version** from the official [SchedMD/slurm](https://github.com/SchedMD/slurm) repository
2. **Checks if DEBs already exist** - skips build if packages for that version are already in `slurm-debs/`
3. **Downloads Slurm source** tarball from GitHub releases
4. **Builds DEB packages** using `debuild` in a Debian Bullseye container
5. **Commits DEBs** to the `slurm-debs/` directory in this repository

#### Stage 2: Docker Image Building (`build-push-workflow.yml`)

1. **Fails fast** if the Docker Hub variables/secret are not configured
2. **Detects Slurm version** (manual override, or the newest version with DEBs committed in `slurm-debs/`)
3. **Verifies DEBs exist** - requires matching DEB packages in `slurm-debs/` directory
4. **Builds all three Docker images in parallel** (matrix job):
   - Debug-symbol (`*-dbgsym*`) packages are never installed
   - Each Dockerfile filters which DEB packages to install:
     - `slurmctld`: Excludes `slurmdbd`, `slurmd`, `slurmrestd` packages
     - `slurmdbd`: Excludes `slurmctld`, `slurmrestd`, `slurmd` packages
     - `slurmrestd`: Excludes `slurmdbd`, `slurmd`, `slurmctld` packages
5. **Tags each image** with:
   - Service tag: `slurmctld`, `slurmdbd`, `slurmrestd` (latest)
   - Version tag: `slurmctld-26-05-3-1`, `slurmdbd-26-05-3-1`, etc.
6. **Pushes to Docker Hub** and **verifies every pushed tag** with `docker buildx imagetools inspect`, writing a summary with digests and image sizes

The workflow also runs automatically on any push to `main` that touches the image sources (`slurmctld/`, `slurmdbd/`, `slurmrestd/` or the workflow itself), and superseded runs are cancelled.

### Weekly Automated Builds

The **Weekly Orchestrator** (`weekly-orchestrator.yml`) automatically runs **every Monday at 2:00 AM UTC**:

1. Triggers DEB package build workflow (Stage 1)
2. Polls that run until it actually completes (up to 75 minutes) and **stops if it failed** - a slow or broken DEB build can no longer be silently skipped
3. Triggers Docker image build workflow (Stage 2)

This ensures Docker images stay up-to-date with the latest Slurm releases automatically.

### Dockerfile Structure

All three containers share a standardized structure:
- **Base**: Debian Bullseye Slim
- **Standardized Setup**: Common user/group creation, package installation, and configuration
- **Service-Specific Filtering**: Each container intelligently installs only the required Slurm DEB packages
- **Entrypoint Scripts**: Handle Munge initialization, directory setup, and service startup

## 🛠️ GitHub Actions - CI/CD Pipeline

### Manual Build Trigger

You can manually trigger either workflow:

**Build DEBs:**
1. Go to **Actions** → **Build and Commit Slurm DEB Packages**
2. Click **Run workflow**
3. Optionally specify a Slurm version override (e.g., `24-11-6-1`)

**Build Docker Images:**
1. Go to **Actions** → **Build and Push Docker Images**
2. Click **Run workflow**
3. Optionally specify a Slurm version override (must match existing DEBs)

**Note:** Docker builds require DEB packages to exist first. If no DEBs are found, the workflow will skip the build.

### ✅ Setting Up GitHub Secrets & Variables

To enable pushing to Docker Hub:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Add **Repository Variables**:
   * `DOCKER_HUB_REPO` → `rkhoja/vulcan-slurm`
   * `DOCKER_HUB_USER` → your Docker Hub username
3. Add **Secret**:
   * `DOCKER_HUB_TOKEN` → create a [Docker Hub access token](https://hub.docker.com/settings/security)

## 🧪 Deployment

### Kubernetes

Production-style example configurations (sanitized: documentation IPs and `example.org` hostnames) are provided in each service directory:

```bash
kubectl apply -f slurmctld/slurmctld-prod.yaml
kubectl apply -f slurmdbd/slurmdbd.yaml
kubectl apply -f slurmrestd/slurmrestd.yaml
```

### High Availability Layout

`slurmctld-prod.yaml` deploys **three controller Deployments** (primary + two backups) behind three stable LoadBalancer IPs, matching three ordered `SlurmctldHost=` lines in `slurm.conf`:

```conf
SlurmctldHost=slurmctld-1(192.0.2.15)
SlurmctldHost=slurmctld-2(192.0.2.16)
SlurmctldHost=slurmctld-3(192.0.2.17)
```

Only one controller is active at a time; the backups watch the shared `StateSaveLocation` heartbeat on NFS and take over after `SlurmctldTimeout`. Do **not** put multiple hosts on a single comma-separated `SlurmctldHost` line - that never establishes a primary/backup order.

All Deployments use `strategy: Recreate` on purpose: a RollingUpdate would briefly run two copies of the same controller against the same state directory during image bumps. The manifests also include liberal resource requests/limits and TCP startup/liveness/readiness probes for each daemon.

### Required Configuration

All containers require:
- **Munge key**: Kubernetes Secret mounted at `/etc/munge/.secret/munge.key` (`kubectl -n slurm create secret generic slurm-munge-key --from-file=munge.key=...`)
- **Slurm config**: Mount `slurm.conf` at `/etc/slurm/slurm.conf`
- **Database config** (slurmdbd): Mount `slurmdbd.conf` at `/etc/slurm/slurmdbd.conf`
- **State directory** (slurmctld): Mount the shared `StateSaveLocation` at `/var/spool/slurmctld` (read-write; also mounted read-only by slurmdbd for the JWT key)
- **SSSD config** (if using LDAP): Kubernetes Secret mounted at `/etc/sssd/.secret/` (`kubectl -n slurm create secret generic slurm-sssd-conf --from-file=sssd.conf=...`)
- **Mail relay** (slurmctld, optional): Set `SMTP_HOST`, `SMTP_PORT`, `MAIL_FROM` env vars

See each service README for the exact secret-creation commands.

## 🔧 Service Details

- **[slurmctld](./slurmctld/README.md)**: Requires `slurmdbd` running (waits up to 120s). Auto-generates JWT key on brand-new clusters. Runs `slurm_jobscripts.py`.
- **[slurmdbd](./slurmdbd/README.md)**: Requires MySQL/MariaDB backend (configure in `slurmdbd.conf`).
- **[slurmrestd](./slurmrestd/README.md)**: JWT authentication. RESTful API on port 6820.

## 🤝 Support

Many Bothans died to bring us this information. This project is provided as-is, but reasonable questions may be answered based on my coffee intake or mood. ;)

Feel free to open an issue or email **[khoja1@ualberta.ca](mailto:khoja1@ualberta.ca)** or **[kali2@ualberta.ca](mailto:kali2@ualberta.ca)** for U of A related deployments.

## 📜 License

This project is released under the **MIT License** - one of the most permissive open-source licenses available.

**What this means:**
- ✅ Use it for anything (personal, commercial, whatever)
- ✅ Modify it however you want
- ✅ Distribute it freely
- ✅ Include it in proprietary software

**The only requirement:** Keep the copyright notice somewhere in your project.

That's it! No other strings attached. The MIT License is trusted by major projects worldwide and removes virtually all legal barriers to using this code.

**Full license text:** [MIT License](./LICENSE)

## 🧠 About University of Alberta Research Computing

The [Research Computing Group](https://www.ualberta.ca/en/information-services-and-technology/research-computing/index.html) supports high-performance computing, data-intensive research, and advanced infrastructure for researchers at the University of Alberta and across Canada.

We help design and operate compute environments that power innovation — from AI training clusters to national research infrastructure.
