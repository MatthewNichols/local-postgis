---
name: pg-branch-db
description: Manage per-git-branch PostgreSQL databases on the local-postgis Docker setup. Use when the user wants to clone a database for a branch, switch the project's connection string to a branch DB, list local databases, or tidy up (drop) old branch databases. Triggers on "clone the db", "branch database", "make a db for this branch", "switch db", "list dbs", "clean up old dbs".
---

# Branch-specific databases (local-postgis)

The `local-postgis` repo runs PostgreSQL/PostGIS in Docker, plus a `pg-shell` container with helper scripts. This skill uses those scripts to give each git branch its own cloned database, so migrations can be tested before commit/merge.

## Naming convention

```
{stem}_branch_{branch}
```

- **stem**: the original ("base") database name, e.g. `gloria`.
- **branch**: the git branch name, sanitized (see below), e.g. `feature_login`.
- Example: branch `feature/login-v2` on base DB `gloria` → `gloria_branch_feature_login_v2`.

A DB with no `_branch_` in its name is a **base** DB. Never treat a base DB as disposable.

Sanitize the branch name identically every time, so cloning and tidying agree:

```bash
branch_slug() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/_/g; s/^_+|_+$//g'
}
# Full name; Postgres identifiers max out at 63 bytes
db_name() { printf '%s_branch_%s' "$1" "$(branch_slug "$2")" | cut -c1-63; }
```

If truncation would make two names collide, tell the user and ask for a shorter name rather than guessing.

To find the stem from a DB name that might already be a branch DB, strip `_branch_*`: `gloria_branch_x` → `gloria`.

## Running the scripts

The scripts live in this repo's `scripts/` dir and run inside the `pg-shell` container. Run them non-interactively from the host with `docker compose` (there is no TTY, so use `-T`):

```bash
docker compose -f "$LOCAL_POSTGIS_DIR/docker-compose.yml" run --rm -T --entrypoint bash pg-shell /opt/scripts/<script>.sh <args>
```

- `LOCAL_POSTGIS_DIR` is the checkout of the `local-postgis` repo. If the current directory is not that repo, find it (check the env var, then ask the user). Don't guess paths.
- The compose project name comes from the directory, so always pass `-f` with the full path.
- The `postgis-local` service must be running. Check with `docker compose -f ... ps postgis-local`; if it is stopped, tell the user and start it with `docker compose -f ... up -d postgis-local` (that is a safe, expected action, but say you're doing it).
- Scripts read `PGHOST/PGUSER/PGPASSWORD` from the container environment. Do not print or pass credentials.

| Script | Purpose |
|---|---|
| `list_dbs.sh [--json]` | List non-template DBs with kind, size, connection count, `cloned` date, `last_write`, comment |
| `clone_db.sh <source> <target>` | Dump source, create target, restore, record a comment |
| `drop_db.sh [-y] <db>` | Terminate connections and drop. Without `-y` it prompts, which cannot work non-interactively |

## Operations

### List

```bash
... /opt/scripts/list_dbs.sh --json
```

Summarize for the user grouped by stem: each base DB with its branch DBs underneath, with sizes. Call out:

- DBs with active connections (`connections > 0`).
- Age: show `cloned` (when the branch DB was created; null for DBs not made by `clone_db`) and `last_write`. `last_write` is the newest file mtime in the DB's data directory. It is approximate (checkpoint lag, autovacuum) and only tracks writes, not reads, so describe it as "last written", never "last used".
- **Legacy clones**: DBs whose comment starts with `Cloned from` but whose name lacks `_branch_`. They predate the convention. List them separately, and never rename or drop them without being asked.

### Clone

1. Determine the **branch**: `git branch --show-current` in the user's project (not the local-postgis repo). If detached HEAD or empty, ask.
2. Determine the **stem / source DB**. Look at the project's current connection string (see Switch for where to look) and strip any `_branch_*` suffix. If the user named a source, use that. If it's ambiguous, ask.
3. Compute the target with `db_name stem branch`.
4. Run `list_dbs.sh --json` to check state:
   - Target already exists: do **not** clone over it. Ask whether to reuse it (just Switch), or drop and re-clone (a destructive step that needs explicit confirmation, see Tidy).
   - Source doesn't exist: stop and show the available base DBs.
5. Run `clone_db.sh <source> <target>`. It creates a dump under `/var/backups/clones/` as a side effect; mention it. Cloning can take a while for large DBs.
6. Confirm by listing again, then offer to Switch.

Clone from the **stem/base DB**, not from another branch DB, unless the user asks for that (e.g. a stacked branch). Note in your answer which source you used.

### Switch

Point the project at the branch DB.

1. Find where the project keeps its DB connection. Typical places: `.env`, `.env.local`, `appsettings.Development.json`, `config/database.yml`, `docker-compose` override, `alembic.ini`, `knexfile`. Search for the current DB name and `postgres://` / `postgresql://` / `Database=` / `DATABASE_URL`.
2. Prefer **local, git-ignored** files (`.env`, `.env.local`, `appsettings.Development.json` if ignored). Check with `git check-ignore <file>`. If the only match is a tracked file, stop and ask. Don't put a personal branch DB name into a committed file.
3. Change only the database-name part of the connection string. Leave host, port, user and password untouched, and don't echo the password in your output.
4. Verify the new DB is reachable, e.g. `... pg-shell psql -d <target> -c 'select 1'` via the same `docker compose run` pattern with `--entrypoint psql`.
5. Tell the user what file/line changed and that any running dev server needs a restart.

To go back to the base DB, do the same in reverse.

### Tidy (drop old branch DBs)

Dropping is irreversible. Be conservative.

1. Get `list_dbs.sh --json` and the project's branches: `git branch --format='%(refname:short)'` plus `git branch --merged <default-branch>` to see which are merged.
2. For each DB with `kind = "branch"` and `stem` matching this project, compare `branch` with `branch_slug` of each local git branch:
   - **Candidate**: no matching local branch (deleted), or the branch is fully merged into the default branch.
   - **Keep**: matching branch is unmerged/active, the DB is the one the project currently points at, or `connections > 0`.
   - Use `last_write` as supporting evidence, not as the deciding signal. Include it in the table, e.g. "branch merged, last written 41 days ago". A recent `last_write` on an otherwise-candidate DB is a reason to flag it and ask. A DB whose branch still exists is kept however old it is, because reads are not tracked.
3. Present the candidates as a table (name, size, reason) and **ask for explicit confirmation** of the exact list before anything is dropped. A general "clean up" request is not confirmation of a specific list.
4. For each confirmed DB, run `drop_db.sh -y <db>`. Only pass `-y` after the user has confirmed that specific DB in this conversation.
5. Report what was dropped and the space freed.

**Hard rules for dropping:**

- Only drop DBs whose name contains `_branch_`. Refuse to drop base DBs, legacy clones, `postgres`, and `template*` through this skill. If the user explicitly asks to drop one, ask them to confirm the exact name, and say it's not a branch DB.
- Never drop the DB the project's connection string currently points to without switching first.
- Never use `-y` to batch-drop everything that "looks old".

## Quick reference

```bash
RUN="docker compose -f $LOCAL_POSTGIS_DIR/docker-compose.yml run --rm -T --entrypoint bash pg-shell"
$RUN /opt/scripts/list_dbs.sh --json
$RUN /opt/scripts/clone_db.sh gloria gloria_branch_feature_login
$RUN /opt/scripts/drop_db.sh -y gloria_branch_feature_login   # only after user confirmation
```
