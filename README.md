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

- Fix ansible-lint vault en faisant https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html#keep-vaulted-variables-safely-visible
- Récupérer les confs Radarr/Sonarr/Jackett pour les mettre dans le playbook
- Voir pour un Fail2Ban
