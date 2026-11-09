# AGENTS.md

Project-specific guidance for AI agents and contributors working on **AnsibleVPS**.

## What this is

An Ansible playbook that provisions a personal ARM64 VPS (Hetzner) running Docker
stacks behind **Caddy** as a reverse proxy. There is a single inventory host:

- `vps` → `corentinbeal.fr`, SSH user `root` (see `hosts`).

## Validation / linting — run from WSL

`ansible-lint` **does not work on native Windows** (fails with `No module named 'grp'`).
Always run it from WSL:

```bash
wsl -e bash -lc 'cd /mnt/c/Users/cocob/Documents/Dev/AnsibleVPS && ansible-lint'
```

- A clean run ends with `Passed: 0 failure(s), 0 warning(s)` at the `production` profile.
- **It is slow (several minutes). Don't run it for every edit** — use
  `ansible-playbook intro_playbook.yml --syntax-check --vault-password-file=password.sh`
  while iterating, and leave the full lint to CI (or one final run).
- Warnings about the `.ansible` cache directory not being writable are harmless.
- There is a permanent `WARNING Found incompatible custom yamllint configuration`
  banner: harmless, the repo accepts that custom `.yamllint`.
- Config: `.ansible-lint` (excludes `.github`, `vault/`, `group_vars/all/vault`),
  `.yamllint` (line length 190, `comments.min-spaces-from-content: 1`).
- CI runs ansible-lint on every push: `.github/workflows/ansible-lint.yml`.

Do not reformat files just to satisfy a linter rule that the repo intentionally ignores.

## Running the playbook

```bash
# Everything
ansible-playbook intro_playbook.yml --vault-password-file=password.sh

# A single role / tag (tags: backup, piweb, caddy, immich, jellyfin, cleanup, utils)
ansible-playbook intro_playbook.yml --vault-password-file=password.sh --tags=utils
```

- `password.sh` is **gitignored** and passed via `--vault-password-file`.
- Roles are listed in `intro_playbook.yml`; each has a tag matching its name.
- Order matters: `backup` → `piweb` → `caddy` → `immich` → `jellyfin` → `cleanup` → `utils`.
- `intro_playbook.yml` `pre_tasks` handle OS setup (media group, cloud user, SSH
  password auth off, apt upgrade).

## Repository layout

```
intro_playbook.yml     play entrypoint (roles + tags)
main_vars.yml          versions + global paths (loaded as vars_files)
global_vars.yml        NOT loaded by the playbook; only declares vault_* mappings for ansible-lint
hosts                  inventory
ansible.cfg            inventory=./hosts
requirements.yml       community.docker
group_vars/all/vars    variable → vault_* mappings (auto-loaded)
group_vars/all/vault   encrypted secrets (committed)
<role>/                backup, caddy, immich, jellyfin, cleanup, utils, piweb
  defaults/main.yml    low-priority defaults
  vars/main.yml        role constants
  tasks/main.yml       tasks
  templates/           Jinja templates copied with `template` (can contain secrets)
  files/               static files copied with `copy`
  handlers/main.yml
  README.md
```

## Secrets (Ansible Vault)

- All secrets live in `group_vars/all/vault` (AES256, committed).
- `group_vars/all/vars` maps friendly names to `{{ vault_* }}` (e.g.
  `gotify_password: "{{ vault_gotify_password }}"`).
- `global_vars.yml` mirrors those mappings purely for ansible-lint; keep it in sync
  when adding a new secret.
- Add a secret with:
  `ansible-vault edit group_vars/all/vault --vault-password-file=password.sh`
- **Never** put real secret values in `vars`, templates are fine (they render on deploy).

## Conventions

- **Comments, task names, and commit messages are in French.** Keep it that way.
- One role per service/domain; keep `tasks/main.yml` readable and explicit.
- Version numbers are pinned in `main_vars.yml` (e.g. `immich_version`, `autokuma_version`).
  Reference them from templates; do not hardcode image tags in compose files.
- Use `become: true` + `owner/group: root`, `mode: '0644'` when writing files under `/opt`.
- `dockge_base_folder: /opt/stacks/` has a **trailing slash**; tasks concatenate it
  directly (`"{{ dockge_base_folder }}uptime-kuma"`). Keep that style.
- Files use LF; Git may warn about LF→CRLF on Windows. Ignore those warnings.

## Docker stacks — managed via Dockge

All stacks live in `/opt/stacks/<name>/` with a `docker-compose.yml`, and are browsable
in **Dockge** (`https://dockge.corentinbeal.fr`, container port 5001).

Pattern for a new stack (see `utils/tasks/main.yml`):

```yaml
- name: Create <name> directory
  ansible.builtin.file:
    path: "{{ dockge_base_folder }}<name>"
    state: directory
    mode: '0755'

- name: Setup <name> docker compose
  become: true
  ansible.builtin.template:        # or ansible.builtin.copy for static files
    src: <name>/docker-compose.yml.j2
    dest: "{{ dockge_base_folder }}<name>/docker-compose.yml"
    owner: root
    group: root
    mode: '0644'

- name: Create and start <name> via docker-compose
  community.docker.docker_compose_v2:
    project_src: "{{ dockge_base_folder }}<name>"
```

- Docker itself is installed by the **`immich` role** (a historical quirk, not a mistake).
- Repo convention: status URL is `<subdomain>.corentinbeal.fr`.

## Reverse proxy — Caddy (systemd, not Docker)

Caddy is installed via apt and runs as a systemd service; its config is
`/etc/caddy/Caddyfile` rendered from `caddy/templates/Caddyfile.j2`.

**The binary is a custom xcaddy build**, because the `sablier` directive lives in
`github.com/sablierapp/sablier-caddy-plugin` and is *not* in the stock apt package.
The role therefore:

1. installs the apt package (only for the systemd unit, `caddy` user and `/etc/caddy`),
2. installs `xcaddy` + Go (`go_version` in `main_vars.yml`),
3. rebuilds `/usr/bin/caddy` with `xcaddy build {{ caddy_version }} --with
   <sablier module>@{{ caddy_sablier_plugin_version }}` **only if** `caddy version`
   does not match `caddy_version` or the plugin is missing from
   `caddy list-modules --packages`,
4. holds the apt package (`dpkg_selections: hold`) so `upgrade: dist` can't overwrite
   the custom binary,
5. runs `caddy validate` before reloading, so a bad Caddyfile can't take every site down.

Versions live in `main_vars.yml` (`caddy_version`, `caddy_sablier_plugin_version`).
**Never** pin the apt package with `caddy=<version>`: that reinstalls the stock binary
and Caddy then refuses to parse the `sablier` directive.

Caddy-specific gotchas:

- `caddy list-modules` alone prints **module IDs** (`http.handlers.sablier`), *not* the
  Go package path. Use `caddy list-modules --packages` to see
  `github.com/sablierapp/sablier-caddy-plugin`.
- Never point `xcaddy build --output` at the running `/usr/bin/caddy` (`ETXTBSY`).
  The role builds to `/tmp`, asserts the plugin is present, then installs the file with
  `ansible.builtin.copy` (atomic rename).
- Use `ansible_facts['env']['PATH']`, not `ansible_env.PATH` (ansible-core deprecation,
  removed in 2.24).
- A build takes a few minutes on the ARM VPS; it is skipped unless the version or the
  plugin actually changed.

`caddy/vars/main.yml` holds the source of truth — a `services` map keyed by subdomain:

```yaml
services:
  jellyfin:
    port: 8096                 # -> https://jellyfin.corentinbeal.fr -> localhost:8096
  fileshare:
    port: 1457
    user: cloud                # optional HTTP basic_auth
    password: $2a$14$...       # bcrypt hash
  mealie:
    port: 9925
    autostop:                  # optional Sablier on-demand start
      path: /
      names: mealie
  transmission:
    port: 9091
    http: true                 # also serve on :80
```

`domain_name: corentinbeal.fr` is defined in the same file. To expose a new service,
add an entry there; the Caddyfile loops over the map. Basic-auth passwords are bcrypt
hashes.

## Autostop — Sablier

On-demand services are started through **Sablier** (`sablierapp/sablier`, port 10000),
configured over the Docker socket (`utils/templates/sablier/`). Wire it per service
with the `autostop` block above; Caddy injects the `sablier` directive — which requires
the custom xcaddy build described above. Sablier exposes a liveness endpoint at `GET /health`.

## Monitoring — Uptime Kuma + AutoKuma

- **Uptime Kuma** runs as a Docker stack (`utils/templates/uptime-kuma/`), port 3001,
  served at `https://status.corentinbeal.fr`.
- **AutoKuma** (`utils/`) syncs monitors from the Docker socket and from static files.
  It runs with `network_mode: host` and reaches Kuma at `http://localhost:3001`.
  - Docker monitors use labels `kuma.<id>.<type>.<setting>` on each service
    (e.g. `kuma.jellyfin.http.name` / `...url`).
  - Static monitors live in `utils/files/autokuma/monitors/` (plain, copied) and
    `utils/templates/autokuma/monitors/*.json.j2` (templated, e.g. API keys from vault),
    deployed to `/opt/stacks/autokuma/monitors/`. The filename is the AutoKuma ID;
    files can define monitors, groups, tags and notifications.
  - `AUTOKUMA__ON_DELETE: keep` means removing a label/file keeps the monitor in Kuma.
- **GHCR image tags have no `v` prefix** even though GitHub release tags do:
  use `autokuma_version: "2.0.0"`, **not** `"v2.0.0"`.

## Gotchas / known debt

- `ansible-lint` **must** run from WSL (see top).
- Docker installation lives in the `immich` role.
- `global_vars.yml` must be kept in sync with new vault mappings for lint.
- Caddy is still a systemd service; moving it to Docker Compose is an open TODO in `README.md`.
- The `cleanup` role removes deprecated stacks/containers; add an entry there when
  replacing a service.
- Windows checkout has CRLF on some files; don't "fix" line endings as part of logic changes.
