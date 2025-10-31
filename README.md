<img src="https://www.ualberta.ca/en/toolkit/media-library/homepage-assets/ua_logo_green_rgb.png" alt="University of Alberta Logo" width="50%" />

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
* **Python 3** with `slurm_jobscripts.py` for advanced job management
* **Email notification** via msmtp (configured for U of A SMTP)
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

1. **Detects Slurm version** (latest from GitHub API or manual override)
2. **Verifies DEBs exist** - requires matching DEB packages in `slurm-debs/` directory
3. **Builds all three Docker images** in sequence:
   - Each Dockerfile filters which DEB packages to install:
     - `slurmctld`: Excludes `slurmdbd`, `slurmd`, `slurmrestd` packages
     - `slurmdbd`: Excludes `slurmctld`, `slurmrestd` packages
     - `slurmrestd`: Excludes `slurmdbd`, `slurmd`, `slurmctld` packages
4. **Tags each image** with:
   - Service tag: `slurmctld`, `slurmdbd`, `slurmrestd` (latest)
   - Version tag: `slurmctld-24-11-6-1`, `slurmdbd-24-11-6-1`, etc.
5. **Pushes to Docker Hub**

### Weekly Automated Builds

The **Weekly Orchestrator** (`weekly-orchestrator.yml`) automatically runs **every Monday at 2:00 AM UTC**:

1. Triggers DEB package build workflow (Stage 1)
2. Waits 15 minutes for DEB build to complete
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

Example Kubernetes configurations are provided in each service directory:

```bash
kubectl apply -f slurmctld/slurmctld.yaml
kubectl apply -f slurmdbd/slurmdbd.yaml
kubectl apply -f slurmrestd/slurmrestd.yaml
```

### Required Configuration

All containers require:
- **Munge key**: Mount at `/etc/munge/.secret/munge.key`
- **Slurm config**: Mount `slurm.conf` at `/etc/slurm/slurm.conf`
- **Database config** (slurmctld): Mount `slurmdbd.conf` at `/etc/slurm/slurmdbd.conf`
- **SSSD config** (if using LDAP): Mount at `/etc/sssd/`

## 🔧 Service Details

- **[slurmctld](./slurmctld/README.md)**: Requires `slurmdbd` running. Auto-generates JWT key. Runs `slurm_jobscripts.py`.
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
