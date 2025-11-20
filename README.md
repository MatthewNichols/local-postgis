# Local PostGIS Development Environment

## Purpose & Description

This project provides a local PostgreSQL/PostGIS development environment using Docker Compose. It consists of two services:

- **postgis-local**: A PostgreSQL 17 database server with PostGIS 3.5 extensions for spatial/geographic data support
- **pg-shell**: An interactive shell environment with PostgreSQL client tools, utilities, and helper scripts for database management

The setup is designed for local development, with persistent data storage and a collection of utility scripts to streamline common database operations like cloning databases, creating backups, and managing schemas.

## Dependencies

- [Docker](https://www.docker.com/get-started)
- [Docker Compose](https://docs.docker.com/compose/install/)
- Environment variables configured in a `.env` file (see Setup section)

## Setup

1. **Clone this repository** (or create the files in your desired location)

2. **Create a `.env` file** in the project root with the following variables (see [.env.sample](.env.sample) for more details):

   ```env
   # PostgreSQL server credentials
   POSTGRES_USER=postgres
   POSTGRES_PASSWORD=yourpassword
   
   # pg-shell connection settings
   PGSHELL_USER=postgres
   PGSHELL_PASSWORD=yourpassword
   PGSHELL_DB=postgres
   
   # Host machine data/backup storage root
   HOST_DATA_FILE_ROOT=/home/yourusername
   ```

3. **Create the required host directories** for persistent storage:

   ```bash
   mkdir -p ~/data/postgis-local
   mkdir -p ~/backups/postgis-local
   ```

4. **Build and start the services**:

   ```bash
   docker compose up -d postgis-local
   ```

5. **Access the pg-shell** for interactive database work:

   ```bash
   docker compose run --rm pg-shell
   ```

## pg-shell Usage, Scripts & Installed Utilities

### Overview

The `pg-shell` service provides an interactive Zsh environment with PostgreSQL client tools and utilities pre-installed. It's designed for running database commands, executing scripts, and performing administrative tasks.

### Starting an Interactive Session

```bash
# Start a new interactive shell session
docker compose run --rm pg-shell

# Once inside, you can use any PostgreSQL tools or scripts
```

### Installed Utilities

The `pg-shell` container includes the following tools:

- **[PostgreSQL Client Tools](https://www.postgresql.org/docs/current/reference-client.html)**: `psql`, `pg_dump`, `pg_restore`, `createdb`, `dropdb`, and other standard PostgreSQL utilities
- **[pgcli](https://www.pgcli.com/)**: A modern, interactive PostgreSQL CLI with auto-completion and syntax highlighting
- **[Oh My Zsh](https://ohmyz.sh/)**: Feature-rich Zsh configuration framework with the `bira` theme
- **[Atuin](https://github.com/atuinsh/atuin)**: Magical shell history with sync, search, and backup capabilities
- **Git**: For version control operations
- **Standard Unix utilities**: `curl`, `tar`, `unzip`, `less`, etc.

### Available Scripts

All scripts are located in the `/opt/scripts` directory inside the container and can be executed directly:

#### `clone_db.sh`
Clone an existing database to a new database with a timestamped dump file.

```bash
/opt/scripts/clone_db.sh <source_db> <target_db>

# Example:
/opt/scripts/clone_db.sh production dev_feature_branch
```

- Creates a custom-format dump in `/var/backups/clones/`
- Creates the target database
- Restores the dump to the target
- Sets ownership to the configured user
- Adds a database comment recording the clone source and timestamp

#### `backup_db_data.sh`
Create a data-only backup using INSERT statements.

```bash
/opt/scripts/backup_db_data.sh <database_name>

# Example:
/opt/scripts/backup_db_data.sh myapp
```

- Exports only data (no schema) as SQL INSERT statements
- Saves to `/var/backups/<database>_data_YYYYMMDD_HHMMSS.sql`
- Useful for seeding data or migrating between different schema versions

#### `backup_db_full.sh`
Create a full backup (schema + data) using INSERT statements.

```bash
/opt/scripts/backup_db_full.sh <database_name>

# Example:
/opt/scripts/backup_db_full.sh myapp
```

- Exports complete database structure and data as SQL INSERT statements
- Saves to `/var/backups/<database>_full_YYYYMMDD_HHMMSS.sql`
- Portable format that's easy to inspect and edit

#### `drop_db.sh`
Drop (delete) a database.

```bash
/opt/scripts/drop_db.sh <database_name>

# Example:
/opt/scripts/drop_db.sh old_test_db
```

- Safely drops a database
- Includes confirmation prompts for safety

### Environment Configuration

The `pg-shell` container is pre-configured with these environment variables for seamless PostgreSQL connections:

- `PGHOST=postgis-local` - connects to the PostGIS container
- `PGPORT=5432`
- `PGUSER` - configured via `.env` file
- `PGPASSWORD` - configured via `.env` file
- `PGDATABASE` - default database, configured via `.env` file

This means you can run `psql`, `pgcli`, or other PostgreSQL commands without specifying connection parameters:

```bash
# Connect to the default database
pgcli

# Or specify a different database
pgcli myapp

# Use standard psql
psql -d myapp
```

### Persistent Storage

The `pg-shell` service has several persistent volumes:

- **Home directory** (`pg-shell-home` volume): Preserves shell history, Atuin data, and other user configurations across container rebuilds
- **Backups** (`${HOST_DATA_FILE_ROOT}/backups/postgis-local` → `/var/backups`): All backup scripts write to this directory (HOST_DATA_FILE_ROOT being defined in `.env`), making backups accessible on your host machine
- **Scripts** (`./scripts` → `/opt/scripts`): Mounted from the project directory, so you can edit scripts locally and use them immediately
- **pgcli config** (`~/.config/pgcli`): Persists pgcli settings and preferences
- **SSH keys** (`~/.ssh`, read-only): Available for git operations or remote connections

### Tips

- Use `pgcli` for an enhanced interactive experience with auto-completion
- Press `Ctrl+R` to search your Atuin shell history
- All backups are timestamped and stored on your host machine at `~/backups/postgis-local`
- The `pg-shell` container connects to the `postgis-local` database server automatically
- Edit scripts in your local `./scripts/` directory and they're immediately available in the container
