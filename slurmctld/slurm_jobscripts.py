#!/usr/bin/env python3
# =============================================================================
# slurm_jobscripts.py - TrailblazingTurtle job-script collector
# =============================================================================
# Runs as a sidecar daemon inside the slurmctld container (started by
# entrypoint.sh). Watches the Slurm StateSaveLocation hash.0..hash.9
# directories for new job scripts and uploads them to the userportal API so
# submit scripts are browsable in the portal.
#
# Base: upstream guilbaults/TrailblazingTurtle slurm_jobscripts/slurm_jobscripts.py
# Local changes on top of upstream (kept minimal, see git history):
#   * stdout logging with a "[jobscripts]" prefix and timestamps, so uploads
#     and failures are visible and greppable in `kubectl logs` among the
#     slurmctld/munge/sssd output (upstream was silent except on error)
#   * retry with backoff when the portal API is briefly unreachable
#     (upstream logged one error and the script was never uploaded)
#   * fail fast with a clear message when the config file is missing or
#     incomplete (upstream raised a bare KeyError traceback)
#
# Config file (default /etc/slurm/slurm_jobscripts.ini):
#   [api]   token, host, script_length
#   [slurm] spool   (StateSaveLocation, e.g. /var/spool/slurmctld)
# =============================================================================

import requests
import configparser
import os
import sys
import time
import argparse
import logging

# Transient upload failures are retried within send_job() with these backoffs;
# if all attempts fail the job stays un-sent and is retried on later scan
# cycles for as long as the job dir remains in the spool.
RETRY_BACKOFF_SECONDS = [5, 15, 30]


def send_job(jobid):
    """Upload one job script. Returns True when the job is handled (uploaded,
    duplicate, or unrecoverable) and False on transient failure (retry later)."""
    try:
        with open('{spool}/hash.{mod}/job.{jobid}/script'.format(
                spool=spool,
                mod=jobid % 10,
                jobid=jobid), 'r') as f:
            content = f.read()[:script_length].strip('\x00')
    except UnicodeDecodeError:
        # Ignore problems with wrong file encoding
        return True
    except FileNotFoundError:
        # The script disappeared before we could read it
        return True

    # Only log first 100 characters into DEBUG log
    logging.debug('Job script {}: {}'.format(jobid, content[:100]))

    # Try the upload, backing off on transient errors (API restarts, network
    # blips). Unrecoverable responses (bad token, malformed request) are not
    # retried.
    for attempt, backoff in enumerate([0] + RETRY_BACKOFF_SECONDS):
        if backoff:
            logging.warning('Job script {} upload retry in {}s (attempt {}/{})'.format(
                jobid, backoff, attempt + 1, len(RETRY_BACKOFF_SECONDS) + 1))
            time.sleep(backoff)

        try:
            r = requests.post(
                '{}/api/jobscripts/'.format(host),
                json={'id_job': int(jobid), 'submit_script': content},
                headers={'Authorization': 'Token ' + token},
                timeout=30,
            )
        except requests.exceptions.RequestException as e:
            logging.error('Job script {} not saved - API is unreachable: {}'.format(jobid, e))
            continue

        if r.status_code == 201:
            logging.info('Uploaded job script {}'.format(jobid))
            return True
        elif r.status_code == 401:
            logging.error('Token is invalid')
            return True
        elif r.status_code >= 500 or r.status_code == 503:
            logging.error('Job script {} not saved - API error {} - will retry'.format(
                jobid, r.status_code))
            continue
        elif 'job script with this id job already exists' in r.text:
            logging.debug('Job script already exists')
            return True
        else:
            logging.error('Job script {} not saved: {}'.format(jobid, r.text))
            return True

    logging.error('Job script {} still not saved after {} attempts - '
                  'will retry on a later scan'.format(jobid, len(RETRY_BACKOFF_SECONDS) + 1))
    return False


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--config',
        help='Path to the config file (default: %(default)s)',
        type=str,
        default='/etc/slurm/slurm_jobscripts.ini')
    parser.add_argument('--verbose', help='Verbose output', action='store_true')
    args = parser.parse_args()

    # Prefix + timestamp so these lines are identifiable in the pod log
    # stream: kubectl logs <pod> | grep '\[jobscripts\]'
    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format='[jobscripts] %(asctime)s %(levelname)s %(message)s',
        stream=sys.stdout,
    )

    config = configparser.ConfigParser()
    logging.debug('Reading config file: {}'.format(args.config))
    if not config.read(args.config):
        logging.error('Config file {} is missing or unreadable'.format(args.config))
        sys.exit(1)
    try:
        token = config['api']['token']
        host = config['api']['host']
        script_length = int(config['api']['script_length'])
        spool = config['slurm']['spool']
    except (KeyError, ValueError) as e:
        logging.error('Config file {} is incomplete or invalid: {}'.format(args.config, e))
        sys.exit(1)

    logging.info('Watching {} for job scripts, uploading to {}'.format(spool, host))

    jobs = set()

    while True:
        updated_jobs = set()
        for mod in range(10):
            try:
                listing = os.listdir('{spool}/hash.{mod}'.format(spool=spool, mod=mod))
            except FileNotFoundError:
                logging.debug('hash.{mod} does not exist yet'.format(mod=mod))
                continue
            for job in filter(lambda x: 'job' in x, listing):
                jobid = int(job[4:])  # parse the jobid (job.12345 -> 12345)
                updated_jobs.add(jobid)

                if jobid not in jobs:
                    logging.debug('New job: {}'.format(jobid))
                    if not send_job(jobid):
                        # Transient failure: leave it out of the seen set so
                        # the next scan cycle tries again.
                        updated_jobs.discard(jobid)

        jobs = updated_jobs
        time.sleep(5)
