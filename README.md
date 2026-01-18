# ansible_intro
The files in this repository are part of the demo "Intro to Ansible" article. You can find the full article [here](https://spacelift.io/blog/ansible-tutorial)
# AnsibleVPS

Getting started :
Create file vault/secrets.yml 
```
immich_db_password: # Random immich dbpassword
storagebox_password: # Storage box rclone encrypted password
storagebox_user: # ID Storage box
```
Create file password.py and type the Vault file password, add to .gitignore

Launch playbook -> ansible-playbook intro_playbook.yml --vault-password-file=password.sh

-- Windows fix permissions https://github.com/trailofbits/algo/issues/1637

TODO

- Récupérer les confs Radarr/Sonarr/Jackett pour les mettre dans le playbook
- Backup voir https://www.backblaze.com/docs/cloud-storage-configure-backblaze-b2-with-duplicity-on-linux
- Installer https://github.com/bonukai/MediaTracker?tab=readme-ov-file 
- Voir pour un Fail2Ban

- Installer caddy via https://caddyserver.com/docs/build#package-support-files-for-custom-builds-for-debianubunturaspbian
- Passer caddy en docker-compose