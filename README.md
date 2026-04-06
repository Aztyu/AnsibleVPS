# AnsibleVPS

## Getting started :

Create file `group_vars/all/vault` with all the values in `group_vars/all/vars`

Create file password.py and type the Vault file password

## Launch playbook 

The entire playbook

`ansible-playbook intro_playbook.yml --vault-password-file=password.sh`

Only one tag 

`ansible-playbook intro_playbook.yml --vault-password-file=password.sh --tag=jellyfin`

## Troubleshoot

If needed : Windows fix permissions https://github.com/trailofbits/algo/issues/1637

## TODO

- Récupérer les confs Radarr/Sonarr/Jackett pour les mettre dans le playbook
- Voir pour un Fail2Ban
- Passer caddy en docker-compose pour laisser les connexions dans Docker