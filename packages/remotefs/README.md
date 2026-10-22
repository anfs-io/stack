# remotefs

Mounts a remote directory over ssh (sshfs) under a name, at `~/mnt/<label>`:

```bash
remotefs add web1                      # web1: (your home there) at ~/mnt/web1
remotefs add web1-logs web1:/var/log   # a second path on the same host
remotefs mount web1                    # or: remotefs up web1, remotefs mount --all
remotefs list                          # LABEL REMOTE MOUNTPOINT STATE
remotefs cd web1                       # mount it if it is not, and go there
remotefs umount web1                   # -f when it is busy or not answering
```

**The label is the ssh host alias**, so user, port and key stay in `~/.ssh/config` and an entry
needs nothing else. A further path on the same host is `<host>-<what>`. Labels are lowercase
letters, digits, `.`, `_` and `-`: a label is the config key, the directory under `~/mnt` and,
on macOS, the volume's name in Finder.

Settings (`REMOTEFS_MOUNT_HOME`, the default options, `REMOTEFS_SSHFS`, the three timeouts) are
documented in `~/.config/remotefs/remotefs.env`; this machine's go in `remotefs.local.env` beside it
(`remotefs config list` shows them, `remotefs config set NAME=value` writes).

Definitions are in `~/.config/remotefs/mounts.yml` (`remotefs edit`):

```yaml
web1-logs:
  remote: web1:/var/log
  mountpoint: ~/logs          # optional; default ~/mnt/<label> (REMOTEFS_MOUNT_HOME)
  options: [ro, Port=2222]    # optional; sshfs and ssh options
  defaults: false             # optional; leave out the reconnect options
```

Every mount gets `reconnect`, `ServerAliveInterval=15` and `ServerAliveCountMax=3`, so a dropped
connection comes back by itself. While the host is away the mount is `stale`: still mounted, not
answering. It recovers when the host does, and `remotefs umount` clears it either way.

Like every anfs tool: `--json` (`list` as objects with `label`, `remote`, `mountpoint`, `state`;
`add`, `mount`, `umount` and `remove` as one object per label), `-d`, `anfs log remotefs`, and
exit 64 when used wrongly.

Before mounting, `remotefs` checks that ssh can log in without asking for anything, because sshfs
given a host it cannot log in to waits instead of failing.

sshfs is the distribution's on Linux. On macOS it is [FUSE-T](https://www.fuse-t.org)'s, which
needs no kernel extension: the volume is served to macOS over a local NFS server, so the mount
table shows it as `nfs`. If files read as "Operation not permitted", give your terminal
Privacy & Security → Files and Folders → Network Volumes. Extended attributes written from the
Mac become `._name` files on the remote.

```bash
bats packages/remotefs/tests/remotefs.bats   # offline, everything it drives is stubbed
```
