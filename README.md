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

- Récupérer les confs Radarr/Sonarr pour les mettre dans le playbook
- Voir pour un Fail2Ban
- Passer caddy en docker-compose pour laisser les connexions dans Docker
- Passer le transmission avec le network sous VPN

# Info root docker Good question — let me first explain what's actually happening, because the fix isn't in the container at all.                                                                             
                                                                                                                                                                                            
 Why you can't add rights                                                                                                                                                                   
                                                                                                                                                                                            
 Your /mnt/storagebox was mounted by a root-run systemd .mount unit (Type=rclone). On an rclone mount the ownership shown to the kernel is synthesized from the process that runs rclone —  
 here root → everything appears as root:root locally, with the remote's mode bits (dirs 0755, files 0644 on a Hetzner Storage Box).                                                         
                                                                                                                                                                                            
 So the kernel denies writes to any non-root process, even though the remote SFTP user owns everything and would happily accept the write. And you can't fix it with chown:                 
                                                                                                                                                                                            
 - chown: rclone's SFTP backend doesn't implement chown at all → fails.                                                                                                                     
 - chmod: Hetzner supports chmod over SFTP, but it only changes mode bits, not the local ownership (still root:root), and newly created files on the box revert to default 0644/0755.       
                                                                                                                                                                                            
 That's also why changing PUID/PGID (or adding user: "1000:1000") inside the container can never work: the kernel checks the fuse-mount inode owner, not your container's effective UID.    
 The only container-side "solution" would be root — which you rightly don't want.                                                                                                           
                                                                                                                                                                                            
 The principle: fix the ownership at the mount, not in the container                                                                                                                        
                                                                                                                                                                                            
 The storage box's real users are cloud (uid 1000) and media (gid 1000) — which is exactly your PUID=1000/PGID=1000. So the goal: make the mount present everything as cloud:media.         
                                                                                                                                                                                            
 Option A — run the rclone process as cloud (recommended, works with any rclone version):                                                                                                   
                                                                                                                                                                                            
 Convert the root-run .mount unit into a systemd service (.mount units can't set User=):                                                                                                    
                                                                                                                                                                                            
 ```ini                                                                                                                                                                                     
   # /etc/systemd/system/mnt-storagebox.service                                                                                                                                             
   [Unit]                                                                                                                                                                                   
   Description=rclone mount storagebox                                                                                                                                                      
   After=network-online.target                                                                                                                                                              
   Wants=network-online.target                                                                                                                                                              
                                                                                                                                                                                            
   [Service]                                                                                                                                                                                
   Type=simple                                                                                                                                                                              
   User=cloud                                                                                                                                                                               
   Group=media                                                                                                                                                                              
   ExecStartPre=/usr/bin/mkdir -p /mnt/storagebox                                                                                                                                           
   ExecStart=/usr/bin/rclone mount storagebox: /mnt/storagebox \                                                                                                                            
       --allow-other --vfs-cache-mode full --vfs-cache-max-size 40G \                                                                                                                       
       --config /home/cloud/.config/rclone/rclone.conf \                                                                                                                                    
       --cache-dir /var/rclone --log-file /var/log/rclone.log                                                                                                                               
   ExecStop=/bin/fusermount -u /mnt/storagebox                                                                                                                                              
   Restart=on-failure                                                                                                                                                                       
                                                                                                                                                                                            
   [Install]                                                                                                                                                                                
   WantedBy=multi-user.target                                                                                                                                                               
 ```                                                                                                                                                                                        
                                                                                                                                                                                            
 Then:                                                                                                                                                                                      
 1. copy /root/.config/rclone/rclone.conf → /home/cloud/.config/rclone/ (readable by cloud)                                                                                                 
 2. fix /var/rclone cache dir + /var/log/rclone.log ownership (or drop the log file)                                                                                                        
 3. disable mnt-storagebox.automount & .mount and start the service                                                                                                                         
                                                                                                                                                                                            
 Result: transmission/prowlarr (1000:1000) read and write, jellyfin (uid 102, read-only use) keeps world-readable access. Nothing runs as root.