# Local PostGIS Development Environment

This is how I manage a local PostgreSQL/PostGIS development environment using Docker Compose. In particular it allows me to make branch specific clones of development dbs so I can test migrations prior to commit and/or merge.

## Purpose & Description

This project provides a local PostgreSQL/PostGIS development environment using Docker Compose. It consists of two services:

- **postgis-local**: A PostgreSQL 17 database server with PostGIS 3.5 extensions for spatial/geographic data support
- **pg-shell**: An interactive shell environment with PostgreSQL client tools, utilities, and helper scripts for database management

The setup is designed for local development, with persistent data storage and a collection of utility scripts to streamline common database operations like cloning databases, creating backups, and managing remote database copies.

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

The `pg-shell` service provides an interactive Zsh environment with PostgreSQL client tools and utilities pre-installed. It's designed for running database commands, executing scripts, and performing database management tasks.

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

All scripts are located in the `/opt/scripts` directory inside the container. For convenience, shell functions are automatically loaded that wrap these scripts, so you can call them from anywhere in your shell session.

Available scripts:

- `backup_db_data <database_name>` - Create a data-only backup
- `backup_db_full <database_name>` - Create a full backup (schema + data)
- `clone_db <source_db> <target_db>` - Clone a database
- `clone_db_from_remote <source_connection_string> <target_db>` - Clone a database from a remote PostgreSQL server
- `drop_db <database_name>` - Drop a database

You can also execute the scripts directly if preferred:

#### `clone_db.sh`
Clone an existing database to a new database with a timestamped dump file.

```bash
# Using the shell function (recommended)
clone_db production dev_feature_branch

# Or using the script directly
/opt/scripts/clone_db.sh production dev_feature_branch
```

- Creates a custom-format dump in `/var/backups/clones/`
- Creates the target database
- Restores the dump to the target
- Sets ownership to the configured user
- Adds a database comment recording the clone source and timestamp

#### `clone_db_from_remote.sh`
Clone a database from a remote PostgreSQL server to your local development environment.

```bash
# Using the shell function (recommended)
clone_db_from_remote "postgresql://user:pass@remote.host:5432/prod_db" local_copy

# Or using the script directly
/opt/scripts/clone_db_from_remote.sh "postgresql://user:pass@remote.host:5432/prod_db" local_copy
```

**Arguments:**
- `source_connection_string` - A PostgreSQL connection URI for the remote source database (e.g., `postgresql://user:password@hostname:5432/database_name`)
- `target_db` - The name of the new local database to create

**Environment Variables:**
The script uses the following environment variables for connecting to your local PostgreSQL server (all have defaults):
- `PGHOST` - Local PostgreSQL host (default: `postgis-local`)
- `PGPORT` - Local PostgreSQL port (default: `5432`)
- `PGUSER` - Local PostgreSQL user (default: `postgres`)
- `PGPASSWORD` - Local PostgreSQL password (default: `localdev`)

**What it does:**
1. Connects to the remote PostgreSQL server using the provided connection string
2. Creates a custom-format dump file locally at `/var/backups/clones/remote_YYYYMMDDHHMMSS.dump`
3. Creates a new database on your local PostgreSQL server with the specified name
4. Restores the remote dump into the new local database
5. Reassigns object ownership to the local PostgreSQL user
6. Adds a database comment with the clone timestamp for reference

**Examples:**

```bash
# Clone a production database
clone_db_from_remote "postgresql://prod_user:prod_pass@prod.example.com:5432/main_app" prod_local

# Clone a staging database from a different host
clone_db_from_remote "postgresql://staging_user:staging_pass@10.0.1.50/staging_db" staging_local

# With custom local credentials
PGUSER=custom_user PGPASSWORD=custom_pass clone_db_from_remote "postgresql://user:pass@remote.host/db" target_db
```

#### `backup_db_data.sh`
Create a data-only backup using INSERT statements.

```bash
# Using the shell function (recommended)
backup_db_data myapp

# Or using the script directly
/opt/scripts/backup_db_data.sh myapp
```

- Exports only data (no schema) as SQL INSERT statements
- Saves to `/var/backups/<database>_data_YYYYMMDD_HHMMSS.sql`
- Useful for seeding data or migrating between different schema versions

#### `backup_db_full.sh`
Create a full backup (schema + data) using INSERT statements.

```bash
# Using the shell function (recommended)
backup_db_full myapp

# Or using the script directly
/opt/scripts/backup_db_full.sh myapp
```

- Exports complete database structure and data as SQL INSERT statements
- Saves to `/var/backups/<database>_full_YYYYMMDD_HHMMSS.sql`
- Portable format that's easy to inspect and edit

#### `drop_db.sh`
Drop (delete) a database.

```bash
# Using the shell function (recommended)
drop_db old_test_db

# Or using the script directly
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
- **Backups** (`${HOST_DATA_FILE_ROOT}/backups/postgis-local` → `/var/backups`): All backup scripts write to this directory (HOST_DATA_FILE_ROOT being defined in `.env`), making backups accessible from your host machine
- **Scripts** (`./scripts` → `/opt/scripts`): Mounted from the project directory, so you can edit scripts locally and use them immediately
- **Custom Zsh scripts** (`./zsh-custom/` → `/root/.oh-my-zsh/custom/`): Any `.zsh` files you place in the `zsh-custom` directory will be automatically loaded by oh-my-zsh, allowing you to add custom functions and aliases
- **pgcli config** (`~/.config/pgcli`): Persists pgcli settings and preferences
- **SSH keys** (`~/.ssh`, read-only): Available for git operations or remote connections

### Customizing Your Shell

You can add custom Zsh functions, aliases, or configurations by creating `.zsh` files in the `zsh-custom/` directory:

1. Create your custom script in `zsh-custom/` (e.g., `my-aliases.zsh`)
2. Rebuild the container: `docker compose build pg-shell`
3. Your customizations will be automatically loaded in new shell sessions

The project already includes `zsh-custom/pg-scripts.zsh` which provides the convenient shell function wrappers for the database management scripts.

### Tips

- Use `pgcli` for an enhanced interactive experience with auto-completion
- Press `Ctrl+R` to search your Atuin shell history
- All backups are timestamped and stored on your host machine at `~/backups/postgis-local`
- The `pg-shell` container connects to the `postgis-local` database server automatically
- Edit scripts in your local `./scripts/` directory and they're immediately available in the container
- Add custom Zsh functions or aliases in `./zsh-custom/` and rebuild to have them available in your shell
