# Roles
- caddy
Install caddy and setup the reverse proxy

- immich
Install Immich and setup the network share to store data

## Storage Box mount (`/mnt/storagebox`)

The SFTP Storage Box is mounted by rclone as a **systemd service**
(`mnt-storagebox.service`, template `immich/templates/mnt-storagebox.service.j2`),
not as a `.mount` + `.automount` pair anymore: a `.mount` unit cannot restart
itself (`Restart=` is not allowed), so after an SSH drop it stayed "active" while
the applications silently wrote to the local disk.

- `Restart=always` + `RestartSec=15` → systemd relaunches rclone forever
  (`StartLimitIntervalSec=0`).
- `Before=docker.service` → the mount is ready before containers start.
- Fast failure detection (`timeout`, `contimeout`, `sftp-idle-timeout`) and
  aggressive retries (`low-level-retries`, `retries`, `retries-sleep`).
- `--allow-non-empty` so a remount works even if local files were written into
  the mountpoint while it was down.
- `ExecStartPost` keeps the unit in "activating" until the mount actually answers,
  `ExecStopPre`/`ExecStopPost` clean stale FUSE mounts with `fusermount -uz`.

Useful commands:

```bash
systemctl status mnt-storagebox.service      # state + last restarts
journalctl -u mnt-storagebox.service -f      # logs (also /var/log/rclone.log)
systemctl restart mnt-storagebox.service     # manual remount
```
