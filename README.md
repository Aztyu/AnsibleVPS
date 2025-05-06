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
- Brancher Uptime Kuma via mail
- Voir pour un Fail2Ban


Investigation Rclone/Restic/Backrest

- Error : getfattr -d -m '' -- test.txt
getfattr: test.txt: Input/output error

root@debian-4gb-fsn1-1:/mnt/storagebox# strace getfattr -d -m '' -- test.txt
execve("/usr/bin/getfattr", ["getfattr", "-d", "-m", "", "--", "test.txt"], 0xffffce2e8de8 /* 20 vars */) = 0
brk(NULL)                               = 0xaaaac6df4000
mmap(NULL, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0xffff82029000
faccessat(AT_FDCWD, "/etc/ld.so.preload", R_OK) = -1 ENOENT (No such file or directory)
openat(AT_FDCWD, "/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 3
newfstatat(3, "", {st_mode=S_IFREG|0644, st_size=25399, ...}, AT_EMPTY_PATH) = 0
mmap(NULL, 25399, PROT_READ, MAP_PRIVATE, 3, 0) = 0xffff82022000
close(3)                                = 0
openat(AT_FDCWD, "/lib/aarch64-linux-gnu/libc.so.6", O_RDONLY|O_CLOEXEC) = 3
read(3, "\177ELF\2\1\1\3\0\0\0\0\0\0\0\0\3\0\267\0\1\0\0\0000y\2\0\0\0\0\0"..., 832) = 832
newfstatat(3, "", {st_mode=S_IFREG|0755, st_size=1651408, ...}, AT_EMPTY_PATH) = 0
mmap(NULL, 1826912, PROT_NONE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0xffff81e31000
mmap(0xffff81e40000, 1761376, PROT_READ|PROT_EXEC, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0) = 0xffff81e40000
munmap(0xffff81e31000, 61440)           = 0
munmap(0xffff81fef000, 96)              = 0
mprotect(0xffff81fc7000, 86016, PROT_NONE) = 0
mmap(0xffff81fdc000, 24576, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0x18c000) = 0xffff81fdc000
mmap(0xffff81fe2000, 49248, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_ANONYMOUS, -1, 0) = 0xffff81fe2000
close(3)                                = 0
set_tid_address(0xffff8202a090)         = 292315
set_robust_list(0xffff8202a0a0, 24)     = 0
rseq(0xffff8202a6e0, 0x20, 0, 0xd428bc00) = 0
mprotect(0xffff81fdc000, 16384, PROT_READ) = 0
mprotect(0xaaaab0c2f000, 4096, PROT_READ) = 0
mprotect(0xffff8202e000, 8192, PROT_READ) = 0
prlimit64(0, RLIMIT_STACK, NULL, {rlim_cur=8192*1024, rlim_max=RLIM64_INFINITY}) = 0
munmap(0xffff82022000, 25399)           = 0
getrandom("\xbb\x57\x38\xd0\x6b\x9f\x07\xb6", 8, GRND_NONBLOCK) = 8
brk(NULL)                               = 0xaaaac6df4000
brk(0xaaaac6e15000)                     = 0xaaaac6e15000
openat(AT_FDCWD, "/usr/lib/locale/locale-archive", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
openat(AT_FDCWD, "/usr/share/locale/locale.alias", O_RDONLY|O_CLOEXEC) = 3
newfstatat(3, "", {st_mode=S_IFREG|0644, st_size=2996, ...}, AT_EMPTY_PATH) = 0
read(3, "# Locale name alias data base.\n#"..., 4096) = 2996
read(3, "", 4096)                       = 0
close(3)                                = 0
openat(AT_FDCWD, "/usr/lib/locale/en_US.UTF-8/LC_CTYPE", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
openat(AT_FDCWD, "/usr/lib/locale/en_US.utf8/LC_CTYPE", O_RDONLY|O_CLOEXEC) = 3
newfstatat(3, "", {st_mode=S_IFREG|0644, st_size=353616, ...}, AT_EMPTY_PATH) = 0
mmap(NULL, 353616, PROT_READ, MAP_PRIVATE, 3, 0) = 0xffff81de9000
close(3)                                = 0
openat(AT_FDCWD, "/usr/lib/aarch64-linux-gnu/gconv/gconv-modules.cache", O_RDONLY) = 3
newfstatat(3, "", {st_mode=S_IFREG|0644, st_size=27028, ...}, AT_EMPTY_PATH) = 0
mmap(NULL, 27028, PROT_READ, MAP_SHARED, 3, 0) = 0xffff82022000
close(3)                                = 0
futex(0xffff81fe188c, FUTEX_WAKE_PRIVATE, 2147483647) = 0
openat(AT_FDCWD, "/usr/lib/locale/en_US.UTF-8/LC_MESSAGES", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
openat(AT_FDCWD, "/usr/lib/locale/en_US.utf8/LC_MESSAGES", O_RDONLY|O_CLOEXEC) = 3
newfstatat(3, "", {st_mode=S_IFDIR|0755, st_size=4096, ...}, AT_EMPTY_PATH) = 0
close(3)                                = 0
openat(AT_FDCWD, "/usr/lib/locale/en_US.utf8/LC_MESSAGES/SYS_LC_MESSAGES", O_RDONLY|O_CLOEXEC) = 3
newfstatat(3, "", {st_mode=S_IFREG|0644, st_size=57, ...}, AT_EMPTY_PATH) = 0
mmap(NULL, 57, PROT_READ, MAP_PRIVATE, 3, 0) = 0xffff82021000
close(3)                                = 0
prlimit64(0, RLIMIT_NOFILE, NULL, {rlim_cur=1024, rlim_max=1024*1024}) = 0
newfstatat(AT_FDCWD, "test.txt", {st_mode=S_IFREG|0644, st_size=19, ...}, AT_SYMLINK_NOFOLLOW) = 0
listxattr("test.txt", NULL, 0)          = -1 EIO (Input/output error)
openat(AT_FDCWD, "/usr/share/locale/en_US.UTF-8/LC_MESSAGES/libc.mo", O_RDONLY) = -1 ENOENT (No such file or directory)
openat(AT_FDCWD, "/usr/share/locale/en_US.utf8/LC_MESSAGES/libc.mo", O_RDONLY) = -1 ENOENT (No such file or directory)
openat(AT_FDCWD, "/usr/share/locale/en_US/LC_MESSAGES/libc.mo", O_RDONLY) = -1 ENOENT (No such file or directory)
openat(AT_FDCWD, "/usr/share/locale/en.UTF-8/LC_MESSAGES/libc.mo", O_RDONLY) = -1 ENOENT (No such file or directory)
openat(AT_FDCWD, "/usr/share/locale/en.utf8/LC_MESSAGES/libc.mo", O_RDONLY) = -1 ENOENT (No such file or directory)
openat(AT_FDCWD, "/usr/share/locale/en/LC_MESSAGES/libc.mo", O_RDONLY) = -1 ENOENT (No such file or directory)
write(2, "getfattr: test.txt: Input/output"..., 39getfattr: test.txt: Input/output error
) = 39
exit_group(1)                           = ?
+++ exited with 1 +++


Ok sur fichier en dehors du mount

Tester ce fix https://github.com/restic/restic/pull/5344/files
