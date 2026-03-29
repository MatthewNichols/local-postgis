# pg-shell Consumer Extensibility

## The Problem

A bind mount **replaces** the target directory, so mounting `./scripts:/opt/scripts` hides everything baked in to the image.

## Solution: Separate Consumer Mount Points

Designate a separate directory for consumer-provided scripts.

### In the Dockerfile (pg-shell repo)

```dockerfile
# Baked-in scripts
COPY scripts/ /opt/scripts/

# Create a mount point for consumer scripts; add both to PATH
RUN mkdir -p /opt/local-scripts
ENV PATH="/opt/local-scripts:/opt/scripts:${PATH}"
```

### In the consuming project's `docker-compose.yml`

```yaml
volumes:
  - ./scripts:/opt/local-scripts:cached
```

## zsh-custom Extensibility

Since oh-my-zsh loads all `*.zsh` files directly in `custom/`, mount individual files rather than the whole directory:

```yaml
volumes:
  - ./zsh-custom/99-local.zsh:/root/.oh-my-zsh/custom/99-local.zsh:cached
```

Or follow the oh-my-zsh plugin convention for multiple files:

```yaml
volumes:
  - ./zsh-custom:/root/.oh-my-zsh/custom/plugins/local:cached
```

Then add `local` to `plugins=(...)` in `.zshrc` — though that requires modifying `.zshrc`.

**Recommended:** mounting individual `.zsh` files is the least friction for consumers who only need one or two extra sourced files.
