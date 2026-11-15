---
name: update-app
description: Bump the version of an application/service in main_vars.yml and redeploy the matching Ansible role tag (e.g. "update caddy to v2.11.10", "bump immich to v3.4.0", "mealie 3.30.0"). Use whenever the user gives an app name plus a target version and wants the VPS playbook run.
---

# Update an app version

The user gives an **app name** (or version variable name) and a **target version**.
You edit the single line in `main_vars.yml`, then run the playbook with the role tag
that owns that variable.

Repo root: `C:/Users/cocob/Documents/Dev/AnsibleVPS`

## Workflow

1. **Locate the line.**
   ```bash
   cd C:/Users/cocob/Documents/Dev/AnsibleVPS && grep -n -i "<app>" main_vars.yml
   ```
   The user's app name is usually the service, not the variable. Map it with the table
   below. If several variables match (e.g. `caddy` → 3 vars, `jellyfin` → 4 vars),
   update only the one the user actually pointed at; if ambiguous, ask which one
   (a version string with `v` or not, or a major-jump help disambiguate).

2. **Determine the tag** — it is the **section comment** directly above the variable
   block in `main_vars.yml` (`# backup`, `# piweb`, `# caddy ...`, `# immich`,
   `# jellyfin`, `# utils`). That comment is the `--tags=` value, because
   `intro_playbook.yml` registers one tag per role.

   | section / tag | variables |
   |---|---|
   | `backup`  | `gotify_version`, `version_backrest` |
   | `piweb`   | `node_version` |
   | `caddy`   | `caddy_version`, `caddy_sablier_plugin_version`, `go_version` |
   | `immich`  | `immich_version` |
   | `jellyfin`| `transmission_version`, `version_jellyfin`, `version_jellyseerr`, `yamtrack_version` |
   | `utils`   | `autokuma_version`, `mealie_version`, `sablier_version`, `uptime_kuma_version`, `vikunja_version` |

   There is also an `updates` role (host unattended-upgrades, not an app version) —
   never use it for an app bump.

3. **Edit in place.** Replace only the value, keep the existing quoting style and the
   surrounding comments. Use `edit`, never rewrite the file. Typical diff:
   ```diff
   -caddy_version: "v2.11.9"
   +caddy_version: "v2.11.10"
   ```

4. **Verify tag format** before running (wrong prefixes break the pull):
   - GHCR images have **no `v` prefix** even when the GitHub release does
     (`autokuma_version: "2.0.0"`, not `"v2.0.0"`).
   - `version_jellyfin` is a plain image tag (`12.4`), no `v`.
   - `caddy_version` / `go_version` **do** carry the `v` for Caddy and a plain `1.xx.y` for Go.
   - Optional upstream sanity check:
     `curl -s "https://hub.docker.com/v2/repositories/<org>/<repo>/tags/<tag>" | head -c 200`
     (or the GitHub releases API for releases/tarballs).

5. **Run the playbook — from WSL**, native Windows `ansible-playbook` is broken
   (`No module named 'grp'`):
   ```bash
   wsl -e bash -lc 'cd /mnt/c/Users/cocob/Documents/Dev/AnsibleVPS && ansible-playbook intro_playbook.yml --vault-password-file=password.sh --tags=<tag>'
   ```
   Add `--check --diff` only if the user asks for a dry run. Do not add `--limit`/other
   flags on your own.

6. **Verify.** Report the `changed`/`failed` recap. Optional smoke test:
   ```bash
   curl -sS -o /dev/null -w '%{http_code}\n' https://<subdomain>.corentinbeal.fr
   ```
   Subdomains live in `caddy/vars/main.yml` (`services` map): e.g. `photo` → immich,
   `jellyfin`, `status` → uptime-kuma, `mealie`, `track` → yamtrack, `gotify`,
   `backup` → backrest, `dockge`, `todo` → vikunja. Sablier-autostopped services
   (`mealie`, `fileshare`, `adventure`) may take a few seconds on first request.

## Failure handling

- `xcaddy`/Caddy builds take **several minutes** on the ARM VPS and are skipped unless
  the version or plugin actually changed — a slow `caddy` run is normal, don't cancel.
- If the pull fails with `manifest unknown`, the tag is wrong (see step 4); fix the
  value and rerun rather than forcing.
- If the playbook fails mid-run, report the exact failing task; don't retry with
  different flags.

## After the run

- Show `git diff main_vars.yml` so the user sees the one-line change.
- **Do not commit** unless asked; when asked, use a French commit message
  (e.g. `chore: bump immich vers v3.4.0`).
- Never run `ansible-lint` for a one-line bump (minutes-long, CI covers it). If asked
  anyway, it must run from WSL:
  `wsl -e bash -lc 'cd /mnt/c/Users/cocob/Documents/Dev/AnsibleVPS && ansible-lint'`.
