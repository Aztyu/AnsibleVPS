# piweb

Déploie **PI WEB** (https://pi-web.dev, UI web pour Pi Coding Agent) pour un utilisateur
dédié `piweb` **sans droits sudo**, et l'expose via Caddy sur
`https://piweb.corentinbeal.fr` protégé par HTTP basic_auth.

## Ce que fait le rôle

- Crée l'utilisateur `piweb` (hors groupe sudo), active `loginctl enable-linger` et
  interdit toute connexion SSH (`DenyUsers piweb`) tout en conservant le shell de login
  requis par les services PI WEB.
- Installe Node.js `{{ node_version }}` (tarball ARM64) dans `/usr/local/nodejs`.
- Installe ou met à jour Pi Coding Agent, puis PI WEB (préfixe npm `~/.npm-global`).
- Installe ou met à jour les services utilisateur systemd `pi-web-sessiond` et `pi-web-server`.

Le rôle est « install-or-update » : relancer le tag réinstalle/mettra à jour l'existant
sans le casser (`pi-web install` est idempotent).

## Lancement

```bash
ansible-playbook intro_playbook.yml --vault-password-file=password.sh --tags=piweb,caddy
```

## Étape manuelle (une seule fois) : configurer le fournisseur de l'agent

PI WEB exécute Pi Coding Agent pour le compte de `piweb` ; il faut donc authentifier ce
nouvel utilisateur auprès d'un fournisseur :

```bash
sudo -u piweb -i
pi            # puis /login, ou exporter ANTHROPIC_API_KEY=...
exit
```

## Vérification

```bash
sudo -u piweb pi-web status
curl -u piweb:'' https://piweb.corentinbeal.fr   # 401 sans identifiants
```
