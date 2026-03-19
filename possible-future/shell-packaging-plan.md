# Plan: Package pgshell Container for Project Reuse

## Overview

Create a reusable Helm chart or Docker Compose template that decouples the pgshell container from your project. Publish the Dockerfile and scripts to a shared repository (private or Docker Hub), then reference it in other projects via environment variables and volume mounts.

## Steps

1. **Extract pgshell assets into a dedicated Git repository** — Move `Dockerfile.pgshell`, `scripts/`, and `zsh-custom/` to a separate repo (e.g., `pgshell-container`) for version control and reusability.

2. **Build and publish the Docker image** — Choose a distribution method: Docker Hub registry (`docker.io/username/pgshell`), GitHub Container Registry (ghcr.io), or private registry based on your sharing needs.

3. **Create a reusable Compose service definition** — Define a standard `pgshell` service template (file or snippet) that other projects can include via `extends` or copy into their docker-compose.yml, requiring only `PGHOST`, `PGUSER`, `PGPASSWORD`, `PGDATABASE` environment variables.

4. **Optional: Build a Helm chart** — If projects use Kubernetes, create a minimal Helm chart for the pgshell deployment that accepts PostgreSQL connection parameters as values.

5. **Document mounting requirements** — Clarify which volumes/mounts are required (scripts, zsh config) vs. optional (SSH keys, pgcli config), so consuming projects know what to mount.

6. **Create a usage example** — Provide a sample docker-compose.yml showing how to use pgshell with an existing postgresql container, with clear environment variable instructions.

## Further Considerations

1. **Distribution strategy** — Will you publish to Docker Hub/GHCR for public use, or keep it private? Private approaches: self-hosted registry, GitHub Releases (OCI), or private Docker Hub repos.

2. **Customization approach** — Should consuming projects extend the base Dockerfile, mount custom scripts, or both? This affects versioning and maintenance burden.

3. **Versioning** — Docker image tags (latest/X.Y.Z) or Git release tags? Consider semantic versioning for predictable updates in other projects.