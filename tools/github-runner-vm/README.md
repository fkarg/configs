# Ubuntu GitHub runner VMs

QEMU/KVM guests for `Epistree/backend-core`, launched as your ordinary user.
Nix supplies pinned host tools; cloud-init installs Docker, Buildx, Compose,
build tools and the GitHub runner in Ubuntu 24.04. No NixOS rebuild or flake
configuration is needed. Requires x86-64 Linux with access to `/dev/kvm`.

```sh
cd ~/configs/tools/github-runner-vm
nix-shell
./vm start 1
./vm wait 1
./vm test 1
./vm register 1
```

Registration uses your host `gh` login with runner administration permission.
Tokens flow directly from `gh` over SSH and are not saved in cloud-init or source.
Runner credentials remain inside the guest disk. Each VM also has a dedicated
local SSH key. All generated state is private and gitignored under `.state/`;
never commit or share that directory.

Registration configures the runner's tool cache at `/opt/hostedtoolcache`, the
path embedded in GitHub's prebuilt Python interpreters. This lets Python start
even when a test clears its environment. Existing runner services pick up cache
configuration changes when restarted; wait for idle before restarting them.

## Scale up and down

`./vm status` shows all local instances; `./vm status 2` shows just instance 2.
The overview queries QEMU for its actual run state, lists the local registration
record and SSH endpoint, and reports allocated overlay disk space. `unreachable`
means QEMU is listening on its control socket but did not answer. A socket left
behind by a QEMU that died with the host shows as `stopped`; `./vm start` removes
it before booting. Registration is a local
record, not a GitHub online/busy check. Status does not boot guests or contact
GitHub, and needs only Bash/Python, so it also works outside `nix-shell`.

Each number identifies an independent runner, overlay disk and Docker daemon:

```sh
for n in 2 3; do ./vm start "$n"; done
for n in 2 3; do ./vm wait "$n" && ./vm test "$n" && ./vm register "$n"; done
./vm ssh 2 'docker ps'
# Wait until GitHub reports the runner idle before stopping it.
./vm stop 3
# Resume the same registered runner, cache and workspace later:
./vm start 3
```

Defaults per VM: 4 vCPUs, 8 GiB RAM, sparse 100 GiB overlay. The immutable Ubuntu
base image is shared. Set `VM_CPUS=8 VM_MEMORY=12G ./vm start 1` to change resources
on the next start. Instances 1–3 forward SSH to localhost ports 2221–2223.
VMs run detached and survive the shell closing; they do not start automatically
after a host reboot or crash, so restart them with `./vm start`. GitHub deletes a
runner that stays offline for more than 14 days; it then has to be registered
again. Do not start more instances than host RAM/CPU/storage allow.

## Rebuild a guest

```sh
# Wait for idle first. This deletes the guest's workspace and Docker cache.
./vm unregister 3
./vm stop 3
./vm reset 3
./vm start 3
./vm wait 3
./vm test 3
./vm register 3
```

`reset` refuses running or locally marked registered guests. Registration and
unregistration can be retried after an API/network failure. Do not manually delete
registered VM disks: unregister first to avoid stale GitHub runners. Failed
cloud-init provisioning is visible through `./vm ssh 1 'sudo cloud-init status
--long'`; repair the template and rebuild an unregistered guest to retry it.

Host tools, Ubuntu base and initial runner archive are pinned; Ubuntu packages,
Docker packages and the runner's subsequent auto-updates follow their respective
repositories. This is rebuildable provisioning, not a byte-identical image.
Update the image URL/checksum in `vm` together and the runner version/checksum in
`cloud-init.yaml` together. Template changes apply when a guest is rebuilt.

## Isolation and workflow routing

Guests have their own kernels, filesystems and Docker daemons. No host directory
or host Docker socket is mounted. This is not a network sandbox: QEMU user-mode
networking allows outbound Internet, LAN and host access (including loopback
services through `10.0.2.2`). SSH forwarding binds only to `127.0.0.1`. Guests are
persistent across jobs; reset is explicit, not automatic per job.

Runners register with `Linux`, `X64`, `ubuntu-vm` and
**without** the default `self-hosted` label. This is deliberate: older backend CI
jobs select generic `self-hosted` while assuming ARM64 image builds. They must not
land on these x86 guests. Updated CI can select `Linux` for ordinary checks and
`[self-hosted, Linux, ARM64]` for native ARM64 image builds. Do not add the generic
label while old queued runs still have that assumption.

References: [Ubuntu/cloud-init with QEMU](https://docs.cloud-init.io/en/latest/tutorial/qemu.html),
[Docker Ubuntu installation](https://docs.docker.com/engine/install/ubuntu/),
[GitHub self-hosted runner requirements](https://docs.github.com/en/actions/reference/runners/self-hosted-runners),
[Setup-python on self-hosted Linux](https://github.com/actions/setup-python/blob/v5/docs/advanced-usage.md#linux),
[QEMU networking](https://www.qemu.org/docs/master/system/devices/net.html).

Test the local status command with `python3 -m unittest discover -s . -p test_status.py`.
