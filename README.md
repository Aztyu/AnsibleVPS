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

Installer Tailscale -> Immich ML

Sonarr ajout remote path
Radar ajout remote path -> localhost | /data/ | /home/cloud/data/transmission/download/
Récupérer les confs pour les mettre dans e playbook

Gérer les droits avec RClone pour utiliser le user cloud:media

VFS sans cache soucis si download de fichier > cache dispo

Backup voir https://www.backblaze.com/docs/cloud-storage-configure-backblaze-b2-with-duplicity-on-linux