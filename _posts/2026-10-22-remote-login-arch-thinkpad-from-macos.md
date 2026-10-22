---
title: "Remote Login to an Arch Linux ThinkPad from macOS"
description: "Remote access from a Mac to an Arch Linux ThinkPad over Tailscale: a terminal over SSH, the desktop over VNC, Sunshine and Moonlight for 3D plots and video, and file transfer."
date: 2026-10-22 00:00:00 +0530
categories: [Homelab, Guides]
tags: [linux, arch-linux, macos, ssh, tailscale, vnc, remote-desktop]
math: false
pin: false
---

This post describes how we set up remote access from a Mac to an Arch Linux ThinkPad, with a terminal over SSH and the full desktop over VNC. The setup is free for personal use and has no session time limit, and all traffic stays encrypted between our own machines. For our own devices, it covers what we would otherwise use AnyDesk or TeamViewer for. For graphics-heavy work, such as interactive 3D plots in Jupyter or Mathematica notebooks, we add a high-performance mode that streams the desktop as video using Sunshine and Moonlight.

The setup uses Tailscale for networking, Tailscale SSH for authentication, TigerVNC's Wayland server (`w0vncserver`) for desktop sharing, and the Screen Sharing app included with macOS. Section 13 describes the high-performance mode, and Section 14 covers file transfer between the two machines. Where the desktop environment matters, the examples assume KDE Plasma on Wayland.

## 1. Overview

A VNC session follows this path. Screen Sharing on the Mac connects to `127.0.0.1:5901` on the Mac. An SSH tunnel forwards that port over Tailscale to `127.0.0.1:5900` on the ThinkPad, where `w0vncserver` shares the desktop session that is already running.

Tailscale's free Personal plan is sufficient for this. At the time of writing, it allows up to six users, each with an unlimited number of personal devices, for non-commercial use, which covers one person's laptops, desktops, phone and tablet. Tailscale revises its plans from time to time, so we recommend checking the pricing page before adding other users or using the tailnet for work.

Tailscale encrypts all SSH and VNC traffic with WireGuard, and the VNC connection additionally runs inside an SSH tunnel. The VNC server listens only on the ThinkPad's loopback interface, so no other machine can connect to it directly. Lid-close sleep behaves normally until we enable a remote mode, and the remote session is the same desktop session we see at the keyboard rather than a separate virtual display.

`w0vncserver` requires TigerVNC 1.16 or later and a supported compositor: either a wlroots-based compositor, or one that implements the xdg-desktop-portal RemoteDesktop interface, as GNOME and KDE Plasma do. Running Wayland alone is not sufficient. Desktops that support neither interface need a different server, such as GNOME Remote Desktop or KDE's RDP server.

The setup has the following limitations:

1. `w0vncserver` shares an existing desktop session, so a user must remain logged in. After a logout or reboot there is no session to share until someone logs in at the keyboard; SSH continues to work in the meantime.
2. Tailscale cannot wake a suspended or powered-off laptop.
3. Some compositors switch off the internal display when the lid closes, which leaves nothing to capture. Section 8.4 tests for this.
4. Compositors differ in how they handle the lock screen. Some continue to share it, which allows us to unlock the session remotely; others pause capture until the session is unlocked. Section 8.4 tests this as well.
5. During a remote session, the ThinkPad's own display is also unlocked, so anyone who opens the lid can see and use the session. Section 8.5 discusses how to limit this exposure.

## 2. Tailscale on the ThinkPad

Tailscale and TigerVNC are both available in the official Arch repositories:

```bash
sudo pacman -Syu tailscale tigervnc
```

We then enable the Tailscale daemon and join the tailnet:

```bash
sudo systemctl enable --now tailscaled
sudo tailscale up
```

If `tailscale up` prints an authentication URL, we open it and sign in with a personal Tailscale account. Next, we enable Tailscale SSH:

```bash
sudo tailscale set --ssh
```

Tailscale SSH runs inside `tailscaled`, so we do not need the OpenSSH server (`sshd.service`). To verify the connection:

```bash
tailscale status
tailscale ip -4
```

The ThinkPad's Tailscale IPv4 address begins with `100.`. MagicDNS, which Tailscale enables by default, also resolves the machine name shown by `tailscale status`. We record both.

By default, a device's Tailscale key expires after 180 days, and the device then leaves the tailnet until someone authenticates it again at the keyboard. For a machine that we mainly reach remotely, this would cut off access, so we disable key expiry for the ThinkPad in the admin console under **Machines** → the ThinkPad → **⋯** → **Disable key expiry**.

## 3. Tailscale on the Mac

On the Mac, we install the official app from [tailscale.com/download/mac](https://tailscale.com/download/mac), sign in with the same account, and confirm that both machines appear in the same tailnet. macOS includes an OpenSSH client:

```bash
ssh -V
```

## 4. First SSH login

From Terminal on the Mac, replacing the placeholders with our username and the ThinkPad's Tailscale IP:

```bash
ssh arch_username@100.x.y.z
```

If a sign-in URL appears, we open it in a browser on the Mac and approve the login. This is Tailscale SSH's *check* mode, which the default policy uses; it requests re-authentication periodically, and we can complete it from any location.

Two commands confirm that we are on the right machine, and `exit` returns us to the Mac:

```bash
whoami
hostname
exit
```

Tailscale SSH accepts a connection only if the tailnet policy permits it. The default policy permits access to our own devices as a non-root user. If we have edited the policy, both the network access rules and the `ssh` rules must permit the connection.

## 5. SSH host alias

To avoid typing the IP address each time, we define a host alias in the Mac's SSH configuration:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
nano ~/.ssh/config
```

with the following entry:

```text
Host thinkpad
    HostName 100.x.y.z
    User arch_username
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

`HostName` accepts either the Tailscale IP or the MagicDNS name. We use the IP because it does not depend on DNS. After saving the file:

```bash
chmod 600 ~/.ssh/config
ssh thinkpad
```

If a shell on the ThinkPad opens, the alias works. The VNC tunnel in Section 7 uses it.

## 6. TigerVNC on Wayland

### 6.1 Checking the session

In a terminal within the logged-in desktop session on the ThinkPad:

```bash
printf 'Session type: %s\n' "$XDG_SESSION_TYPE"
printf 'Desktop: %s\n' "$XDG_CURRENT_DESKTOP"
command -v w0vncserver
w0vncserver -version
```

The output should show the session type `wayland`, a path to `w0vncserver`, and version 1.16 or later. `w0vncserver -h` lists all parameters that the server accepts.

### 6.2 VNC password

```bash
mkdir -p ~/.config/tigervnc
chmod 700 ~/.config/tigervnc
vncpasswd ~/.config/tigervnc/passwd
chmod 600 ~/.config/tigervnc/passwd
```

`vncpasswd` also offers to create a view-only password, which we decline with `n`. The VNC password should differ from the Linux account password.

Classic VNC authentication uses only the first eight characters of the password and does not encrypt the session. This is acceptable here because the server listens only on loopback and every connection arrives through SSH. Port 5900 must never be reachable from the network directly.

### 6.3 Making the session visible to systemd

We run the VNC server as a systemd user service rather than with `nohup`. A service survives the terminal closing and writes its output to the journal, and we can restart it over SSH. The service needs to know which Wayland display to share, which we check as follows:

```bash
systemctl --user show-environment | grep -E '^(WAYLAND_DISPLAY|XDG_CURRENT_DESKTOP)='
```

KDE Plasma and GNOME export both variables at login. Some minimal compositors do not; in that case, we import the variables from a terminal within the desktop session:

```bash
systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
```

### 6.4 The VNC user service

```bash
mkdir -p ~/.config/systemd/user

cat > ~/.config/systemd/user/thinkpad-vnc.service <<'EOF'
[Unit]
Description=TigerVNC server for the current Wayland session
PartOf=graphical-session.target
After=graphical-session.target

[Service]
ExecStart=/usr/bin/w0vncserver -localhost -rfbport=5900 -PasswordFile=%h/.config/tigervnc/passwd -SecurityTypes=VncAuth -RememberDisplayChoice=Always
Restart=on-failure
RestartSec=5
EOF

systemctl --user daemon-reload
```

We leave the service disabled and start it only when we need remote access. The `systemctl --user` commands do not require `sudo`.

The options work as follows. `-localhost` accepts connections only from the ThinkPad itself, and `-rfbport=5900` sets the port. `-PasswordFile` (alias `-rfbauth`) points to the password file. `-SecurityTypes=VncAuth` selects plain VNC password authentication; the default also offers TLS, which macOS Screen Sharing does not support, and the SSH tunnel already provides encryption. `-RememberDisplayChoice=Always` concerns the permission prompt, which the next section explains.

### 6.5 The permission prompt

On portal-based desktops such as GNOME and KDE, a permission dialog appears on the ThinkPad's screen when the first viewer connects, not when the server starts. We cannot answer it from the Mac.

`-RememberDisplayChoice=Always` stores the answer, so we can restart the server over SSH later without a new prompt. The trade-off is that anyone with both SSH access and the VNC password can connect without a fresh approval. `w0vncserver-forget` deletes the stored choice.

The default value, `Session`, asks again after every restart. It is stricter, but if the server crashes while we are away, we cannot recover it remotely. To use the stricter behaviour, we remove the option from the service file.

In either case, we make the first connection while at the ThinkPad, as Section 7 explains.

### 6.6 Starting and checking the server

```bash
systemctl --user start thinkpad-vnc
systemctl --user --no-pager status thinkpad-vnc
ss -ltnp 'sport = :5900'
```

The service should report `active (running)`, and the server should listen only on loopback (`127.0.0.1:5900` or `[::1]:5900`), never on `0.0.0.0:5900` or `[::]:5900`. If the service fails, the journal usually states the reason, and we resolve any compositor or portal errors before continuing:

```bash
journalctl --user -u thinkpad-vnc -n 80 --no-pager
```

## 7. Connecting from the Mac

### 7.1 With two Terminal windows

In the first window, we open the tunnel, which forwards port 5901 on the Mac to port 5900 on the ThinkPad:

```bash
ssh -NT \
    -o ExitOnForwardFailure=yes \
    -L 127.0.0.1:5901:127.0.0.1:5900 \
    thinkpad
```

The command produces no output and runs for as long as the tunnel stays open. In the second window:

```bash
open 'vnc://127.0.0.1:5901'
```

Screen Sharing opens. If it asks for a user name, we leave the field empty and enter the VNC password from Section 6.2. On the first connection, the permission prompt appears on the ThinkPad, and someone must approve it there. Afterwards, keyboard input, pointer input and screen updates should all work. If Screen Sharing cannot connect, the tunnel window usually shows an error message; Section 10 covers the common cases.

We use port 5901 on the Mac rather than 5900 because Screen Sharing refuses connections to the Mac's own port 5900.

To disconnect, we close Screen Sharing and press `Control-C` in the tunnel window.

### 7.2 Helper functions (optional)

Because two windows are inconvenient, we wrap the same steps in two shell functions in `~/.zshrc` on the Mac. Running `source ~/.zshrc` loads them into the current shell.

```bash
thinkpad-vnc() {
    ssh -fNT -M -S ~/.ssh/thinkpad-vnc.sock \
        -o ExitOnForwardFailure=yes \
        -L 127.0.0.1:5901:127.0.0.1:5900 \
        thinkpad || return 1
    open 'vnc://127.0.0.1:5901'
}

thinkpad-vnc-stop() {
    ssh thinkpad 'loginctl lock-session "$(loginctl show-user "$USER" -p Display --value)"'
    ssh -S ~/.ssh/thinkpad-vnc.sock -O exit thinkpad
}
```

`thinkpad-vnc` opens the tunnel in the background and starts Screen Sharing. `thinkpad-vnc-stop` locks the ThinkPad's desktop session and then closes the tunnel.

We can test the locking step once with the lid open. The following command should print a session number, for example `2`:

```bash
ssh thinkpad 'loginctl show-user "$USER" -p Display --value'
```

After `thinkpad-vnc-stop`, the ThinkPad should show its lock screen.

## 8. Keeping the ThinkPad awake on demand

By default, the ThinkPad should sleep when the lid closes. We want it to stay awake only during remote work, so we add a remote mode that we can switch on and off.

### 8.1 The inhibitor service

```bash
sudo tee /etc/systemd/system/remote-lid-inhibit.service >/dev/null <<'EOF'
[Unit]
Description=Temporary lid and sleep inhibition for remote access

[Service]
Type=simple
ExecStart=/usr/bin/systemd-inhibit --what=handle-lid-switch:sleep --mode=block --who=RemoteSSH --why="Remote access session" /usr/bin/sleep infinity
EOF

sudo systemctl daemon-reload
```

We do not enable this service at boot. Its `handle-lid-switch` lock prevents systemd-logind from acting on the lid, and its `sleep` lock blocks suspend requests from desktop environments that handle the lid themselves. We deliberately leave idle actions unaffected, so that KDE can still lock the screen after a period of inactivity (Section 8.5). Desktop environments differ in these details, which is why Section 8.4 tests the actual behaviour.

### 8.2 The remote-mode command

A small script works both in an interactive shell and in a single SSH command. Shell functions defined in `~/.zshrc` would not, because only interactive shells read that file.

```bash
mkdir -p ~/.local/bin

cat > ~/.local/bin/remote-mode <<'EOF'
#!/bin/sh
unit=remote-lid-inhibit.service

status() {
    if systemctl is-active --quiet "$unit" &&
       systemd-inhibit --list --no-pager | grep -Fq RemoteSSH; then
        echo "ACTIVE: remote sleep inhibition is running."
        return 0
    fi
    echo "INACTIVE: remote sleep inhibition is not running."
    return 1
}

case "${1:-status}" in
    on)     sudo systemctl start "$unit" || exit 1; sleep 1; status ;;
    off)    sudo systemctl stop "$unit"  || exit 1; sleep 1; status ;;
    status) status ;;
    *)      echo "usage: remote-mode on|off|status" >&2; exit 2 ;;
esac
EOF

chmod +x ~/.local/bin/remote-mode
```

If `~/.local/bin` is not on the `PATH`, the full path `~/.local/bin/remote-mode` works equally well.

### 8.3 Passwordless sudo for remote-mode (optional)

To avoid entering the sudo password over SSH each time, a sudoers rule can permit exactly these two commands without it:

```bash
sudo visudo -f /etc/sudoers.d/remote-mode
```

The file needs a single line containing our username:

```text
arch_username ALL=(root) NOPASSWD: /usr/bin/systemctl start remote-lid-inhibit.service, /usr/bin/systemctl stop remote-lid-inhibit.service
```

### 8.4 Testing lid, lock and display

With the ThinkPad open and unlocked, we start the VNC server, connect from the Mac as in Section 7, and enable remote mode on the ThinkPad:

```bash
remote-mode on
systemd-inhibit --list --no-pager
```

The output should report `ACTIVE`, and the list should include `RemoteSSH`. We then carry out four checks while watching from the Mac:

1. We lock the screen. Screen Sharing should continue to show the lock screen, and entering the Linux account password should unlock it remotely.
2. We close the lid for a minute. The ThinkPad should remain on Tailscale, SSH should continue to work, and Screen Sharing should show a live desktop rather than a black or frozen image.
3. We reopen the lid and run `remote-mode off`, which should report `INACTIVE`.
4. We close the lid again. This time the laptop should suspend as usual.

If step 1 fails, the compositor stops sharing while the screen is locked. The options are then to leave the screen unlocked, which is reasonable only in a physically secure location, or to use a different remote-desktop server. A black image in step 2 indicates that the compositor switches off the panel when the lid closes. Its lid or display settings may change this; otherwise, leaving the lid slightly open avoids it. If the laptop suspends in step 2, the desktop environment's power settings are the next thing to check. We do not leave the ThinkPad unattended until all four checks pass.

### 8.5 Privacy during a session

Remote access unlocks the actual desktop, so the ThinkPad's own display is unlocked as well. Anyone who opens the lid during a session can watch it and use the keyboard, and KDE provides no way to blank the local display for a shared session.

Three measures limit this exposure. The `thinkpad-vnc-stop` helper from Section 7.2 locks the session before closing the tunnel; with the two-window method, we lock it manually using the command below. Because the inhibitor in Section 8.1 leaves idle actions unaffected, KDE still locks the screen after its usual timeout, which we verify once with remote mode enabled. During an active session, the only remaining protection is a closed lid and a private location.

To lock the ThinkPad from the Mac at any time:

```bash
ssh thinkpad 'loginctl lock-session "$(loginctl show-user "$USER" -p Display --value)"'
```

Keeping the local display private during a session would require a remote-desktop server that creates a separate session instead of sharing the existing one, which is outside the scope of this post.

## 9. A typical session

Before leaving the ThinkPad, with the lid still open:

1. We connect the power adapter.
2. We check that `tailscale status` reports the ThinkPad as online.
3. We confirm that the Wayland desktop session is logged in, and we do not log out.
4. We start the server with `systemctl --user start thinkpad-vnc`.
5. If the server has not yet stored the display choice, we connect once from the Mac and approve the prompt.
6. We run `remote-mode on` and confirm that it reports `ACTIVE`.
7. We lock the screen and close the lid.

All of these steps take place before we lock the screen.

From the Mac, `thinkpad-vnc` (or the two-window method in Section 7.1) opens the session, and we unlock the ThinkPad through Screen Sharing if necessary.

At the end of a session, we run these commands in this order:

```bash
thinkpad-vnc-stop
ssh thinkpad 'systemctl --user stop thinkpad-vnc'
ssh -t thinkpad '~/.local/bin/remote-mode off'
```

We close Screen Sharing first. The stop helper then locks the ThinkPad before closing the tunnel. `remote-mode off` comes last because, with the lid closed, the ThinkPad may suspend immediately and drop the SSH connection, which is normal. If we intend to reconnect soon, we can leave the VNC server running.

In remote mode the laptop stays awake, produces heat and drains its battery, so it should not go into a bag or a closed space. Sustained GPU work increases the heat considerably, for example a long CUDA job or a game running on the NVIDIA GPU with the lid closed. During such work, we keep the ThinkPad on a laptop stand with the vents unobstructed and the charger connected.

## 10. Troubleshooting

Three checks from the Mac usually locate the problem:

1. Is the ThinkPad online? The Tailscale menu-bar app shows its status, as does `tailscale ping 100.x.y.z` if the command-line tool is installed.
2. Does SSH work? `ssh thinkpad 'echo ok'` tests this.
3. Are the services running? `ssh thinkpad 'systemctl --user is-active thinkpad-vnc; ~/.local/bin/remote-mode status'` reports both.

| Symptom | Likely cause | Remedy |
| --- | --- | --- |
| ThinkPad offline in Tailscale | Suspended, powered off, without network, or with an expired key | No remote remedy; someone needs physical access. Mains power, disabled key expiry and the tests in Section 8.4 prevent most cases. |
| SSH prints a sign-in URL and waits | Tailscale SSH check mode | Approving the sign-in at that URL on the Mac |
| Screen Sharing cannot connect; the tunnel window shows `administratively prohibited` | The `tailscaled` on the ThinkPad refuses forwarding, usually because it is outdated | `ssh thinkpad 'tailscale version --daemon'` shows the running version. Updating at the ThinkPad (`sudo pacman -Syu`, then `sudo systemctl restart tailscaled`) is safest, because the restart ends all Tailscale SSH sessions. The fallback below works in the meantime. |
| Screen Sharing cannot connect; the tunnel window shows `connect failed` | The VNC server is not running | Restarting it with `ssh thinkpad 'systemctl --user restart thinkpad-vnc'`, then reading `journalctl --user -u thinkpad-vnc -n 50` for the cause |
| `Address already in use` for 5901 | A previous tunnel is still running | `thinkpad-vnc-stop`, or finding the process with `lsof -nP -iTCP:5901 -sTCP:LISTEN` and ending it with `kill` |
| Restarted server, still no picture | The permission prompt is waiting on the ThinkPad's screen | Approval in person, unless the service already uses `RememberDisplayChoice=Always` |
| Black or frozen picture | The lid switched the panel off, or capture paused while the screen was locked | Restarting the VNC service often helps. If the problem recurs, the compositor needs the lid open or the screen unlocked (Section 8.4). |
| Service log: cannot connect to Wayland display | The session ended (logout or reboot), or systemd lacks the session environment | SSH still works, but someone needs to log in at the keyboard, after which we repeat Section 6.3. |
| `Failed to connect to bus` over SSH | The SSH session lacks the user session variables | `export XDG_RUNTIME_DIR=/run/user/$(id -u)` before the `systemctl --user` command |
| Password rejected, then connections refused | Repeated wrong passwords triggered a temporary block | The block lifts after 10 seconds at first and lasts longer after further failures. Only the first eight characters count; `vncpasswd` over SSH resets the password. |
| Remote mode left on | The inhibitor is still active | `ssh -t thinkpad '~/.local/bin/remote-mode off'` |

To end remote access and restore normal sleep with one command:

```bash
ssh -t thinkpad 'systemctl --user stop thinkpad-vnc; ~/.local/bin/remote-mode off'
```

If SSH forwarding fails, we can fall back temporarily to a direct connection over Tailscale. We replace `-localhost` with `-interface=100.x.y.z` in the service so that the server listens on the ThinkPad's Tailscale address, restart it, and connect to `vnc://100.x.y.z:5900`. Tailscale still encrypts the traffic and keeps it off the internet, but any tailnet device that the policy allows can now reach the VNC port, which only the eight-character VNC password protects. Restricting port 5900 to the Mac in the tailnet policy reduces this exposure, and we return to `-localhost` once forwarding works again. The VNC server should never listen on all interfaces or on the LAN address.

## 11. OpenSSH on Arch (optional)

Tailscale SSH does not need `sshd.service`. We install OpenSSH only if we need its client tools or a conventional SSH server for another purpose:

```bash
sudo pacman -S --needed openssh
sudo ssh-keygen -A
sudo sshd -t
```

No output from `sshd -t` means that the configuration is valid. Nothing in this post requires `sshd.service` to run. If we use it later, we would configure public-key authentication and restrict it to the Tailscale interface.

## 12. Final checks

Before relying on this setup for real work, we confirm that:

- All of our devices appear in the tailnet under one account, and we have disabled key expiry for the ThinkPad.
- `ssh thinkpad` works from the Mac.
- `w0vncserver` 1.16 or later runs as the `thinkpad-vnc` user service and listens only on loopback.
- The SSH tunnel forwards port 5901 on the Mac to port 5900 on the ThinkPad.
- Screen Sharing can view and control the existing desktop.
- The server stores the permission choice, or we accept that a restart requires someone at the machine.
- All four checks in Section 8.4 pass.
- Disconnecting locks the ThinkPad, and the ThinkPad locks itself when idle in remote mode (Section 8.5).
- We know the single command in Section 10 that ends remote access and restores sleep.

The two most likely sources of problems are compositor support for `w0vncserver` and the behaviour of the desktop after we lock the screen and close the lid. We test both before leaving the ThinkPad unattended.

## 13. High-performance mode with Sunshine and Moonlight (optional)

VNC performs well for terminals, editors and most desktop work. It degrades when large parts of the screen change in every frame, as happens when we rotate a 3D plot in a Jupyter or Mathematica notebook, play an animation, or watch a video.

The reason lies in how VNC transmits the screen. It sends changed regions as compressed blocks of pixels, and the CPU performs the compression. For text, only a few small regions change at a time, so each update is small and the result stays sharp. When a 3D surface rotates, nearly the entire window changes in every frame; the compression cannot keep up, and the frame rate drops. In our setup, VNC also travels through an SSH tunnel over TCP, where a single lost packet delays all data queued behind it, so an unreliable connection causes the image to freeze and then jump. The compression also consumes CPU time that the notebook would otherwise use.

Sunshine and Moonlight work differently. Sunshine captures the entire desktop and encodes it as a video stream on the GPU's hardware encoder, whose purpose is to compress continuously changing images. Moonlight receives the stream at a steady 60 frames per second over UDP, uses error correction to compensate for lost packets instead of waiting for retransmission, and plays audio as well. Video compression softens fine text slightly, so we use this high-performance mode for visual work and VNC for everything else. Moonlight runs on the Mac, the iPad and the phone. Unlike VNC, Sunshine does not use the SSH tunnel; it listens on the ThinkPad's Tailscale address.

|  | VNC (Sections 6–7) | Sunshine + Moonlight |
| --- | --- | --- |
| Best suited to | Terminals, code, text and documents | 3D plots, animations and video |
| Transmission | Changed screen regions, no audio | Hardware-encoded video with audio |
| Network path | SSH tunnel over Tailscale | Direct over Tailscale, bound to the Tailscale address |
| Clients | macOS Screen Sharing | Moonlight on the Mac, iPad and phone |
| Unreliable connections | Adequate for text; freezes on packet loss | Requires steady bandwidth; a lower resolution or a higher `qp` helps |
| Shares the real desktop | Yes; the lid, lock and privacy notes apply | Yes; the same notes apply |

### 13.1 Installing Sunshine

Sunshine is not in the official Arch repositories. LizardByte, the team that develops Sunshine, maintains its own pacman repository and describes it as the only official source of its Arch packages. LizardByte has also withdrawn support for the AUR package and does not accept bug reports from AUR installations, so we use their repository. We add it to `/etc/pacman.conf`:

```ini
[lizardbyte]
SigLevel = Optional
Server = https://github.com/LizardByte/pacman-repo/releases/latest/download
```

and install Sunshine from it:

```bash
sudo pacman -Syu lizardbyte/sunshine
```

`SigLevel = Optional` means that pacman does not require signatures for this repository, so we rely on LizardByte's GitHub releases being authentic. Subsequent Sunshine updates arrive with the regular `pacman -Syu`.

Next, we check that the GPU can encode video:

```bash
sudo pacman -S --needed libva-utils
vainfo --display drm --device /dev/dri/renderD128 | grep -i encslice
```

The output should contain at least one `VAProfileH264` line with `VAEntrypointEncSlice`. If `vainfo` stops with `vaInitialize failed`, the VA-API driver for the GPU is missing. For Intel graphics from Broadwell (2015) onwards, the driver is `intel-media-driver`:

```bash
sudo pacman -S --needed intel-media-driver
```

On a laptop with two GPUs, the following commands show which render node belongs to which GPU. The Intel GPU usually has `renderD128`:

```bash
lspci -k | grep -EA3 'VGA|3D|Display'
ls -l /dev/dri/by-path/
```

Because we capture the screen through KDE's portal, Sunshine does not need the `cap_sys_admin` capability that KMS capture requires. That capability grants close to root-level privileges, so we check whether the package has set it:

```bash
getcap "$(readlink -f "$(command -v sunshine)")"
```

If the output includes `cap_sys_admin`, we remove it, and we repeat the check after each Sunshine update:

```bash
sudo setcap -r "$(readlink -f "$(command -v sunshine)")"
```

### 13.2 Capture and network settings

`tailscale ip -4` prints the ThinkPad's Tailscale address. We substitute that address for `100.x.y.z` and add the following lines to `~/.config/sunshine/sunshine.conf`, creating the file if necessary:

```ini
capture = portal
bind_address = 100.x.y.z
origin_web_ui_allowed = lan
csrf_allowed_origins = https://100.x.y.z:47990
upnp = disabled
```

If the placeholder remains in the file, the following command replaces it with the actual address on both lines and displays the result:

```bash
sed -i "s/100\.x\.y\.z/$(tailscale ip -4)/g" ~/.config/sunshine/sunshine.conf
grep -E '^(bind_address|csrf_allowed_origins)' ~/.config/sunshine/sunshine.conf
```

`capture = portal` captures the screen through KDE's screen-sharing portal; if the stream stays black, `capture = kwin`, which uses KDE's own screencast interface, is an alternative. `bind_address` restricts Sunshine to the Tailscale address, so in normal use no device on the laptop's local network can reach it. `origin_web_ui_allowed = lan` allows the Mac to open the web interface over Tailscale, because Sunshine treats Tailscale's 100.64.0.0/10 range as LAN. `upnp = disabled` is the default and prevents Sunshine from opening ports on the router.

The web interface accepts changes only from addresses that it recognises, by default `localhost` and its loopback variants. `csrf_allowed_origins` adds the address that we use from the Mac in Section 13.4. Without it, the page reports a CSRF protection error as soon as we try to save a setting. If we open the web interface by its MagicDNS name, that address goes on the same line, separated by a comma.

Laptops with an additional NVIDIA GPU need two further lines. Our ThinkPad combines Intel UHD Graphics with a Quadro RTX 3000. KDE renders the desktop on the Intel GPU, and according to Sunshine's documentation NVENC expects to encode on the GPU that performs the capture, so we keep encoding on the Intel GPU with VA-API. Without these lines, Sunshine uses the first encoder it finds, which may be NVENC:

```ini
adapter_name = /dev/dri/renderD128
encoder = vaapi
```

These lines determine only which GPU encodes the stream. The NVIDIA GPU remains available for CUDA jobs and for games that we start with `prime-run` (from the `nvidia-prime` package), and those games still appear in the stream. When no process uses the NVIDIA GPU, it stays idle, which keeps a laptop with a closed lid cooler.

Two further lines address problems we encountered with this Intel GPU (UHD Graphics, Comet Lake). Its HEVC encoder produced a corrupted, blocky image and crashed Sunshine at the start of a stream, so we disable HEVC in Sunshine, and clients fall back to H.264. For H.264, the driver does not support the bitrate control that Sunshine prefers, so Sunshine uses a constant quantisation parameter (QP) instead. The default of 28 produces a soft image; 20 is considerably sharper at the cost of more bandwidth:

```ini
hevc_mode = 1
qp = 20
```

With a constant QP, Moonlight's bitrate setting has little effect on H.264 streams. Lower QP values give a sharper image and use more bandwidth.

By default, Sunshine does not encrypt traffic that it classifies as LAN. Tailscale already encrypts all traffic end to end, so this is acceptable here; `lan_encryption_mode = 1` adds Sunshine's own encryption for those who want both layers.

Binding to the Tailscale address does not fully isolate Sunshine from the local network. Linux accepts packets addressed to the Tailscale IP on any interface, so a device on the same Wi-Fi network could still reach Sunshine by deliberately routing traffic to that address. A small nftables table drops traffic to Sunshine's ports (47984–48010) unless it arrives over Tailscale:

```bash
sudo pacman -S --needed nftables

sudo tee /etc/sunshine-guard.nft >/dev/null <<'EOF'
destroy table inet sunshine_guard
table inet sunshine_guard {
    chain input {
        type filter hook input priority 0; policy accept;
        iifname != { "lo", "tailscale0" } tcp dport 47984-48010 drop
        iifname != { "lo", "tailscale0" } udp dport 47984-48010 drop
    }
}
EOF

sudo tee /etc/systemd/system/sunshine-guard.service >/dev/null <<'EOF'
[Unit]
Description=Allow Sunshine ports only over Tailscale
Wants=network-pre.target
Before=network-pre.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/nft -f /etc/sunshine-guard.nft
ExecStop=/usr/bin/nft destroy table inet sunshine_guard

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now sunshine-guard.service
sudo nft list table inet sunshine_guard
```

The last command should print the two drop rules. The table accepts all other traffic, so Tailscale, SSH and VNC are unaffected. We do not enable `nftables.service` for this purpose, because it loads Arch's separate default firewall from `/etc/nftables.conf`, which would need its own rules for Tailscale.

### 13.3 The Sunshine service

To find the user service that the package installs:

```bash
systemctl --user list-unit-files | grep -i sunshine
```

Current packages name it `app-dev.lizardbyte.app.Sunshine.service`, and older packages `sunshine.service`. The commands below use the current name. We prevent the service from starting at login and start it manually:

```bash
systemctl --user disable app-dev.lizardbyte.app.Sunshine
systemctl --user start app-dev.lizardbyte.app.Sunshine
```

Sunshine tests the available encoders before it opens its ports, so we wait about ten seconds before checking where it listens:

```bash
ss -ltunp | grep -i sunshine
```

No line should show `0.0.0.0`, `*` or `[::]`; Sunshine's ports should appear only on the ThinkPad's `100.` address. Repeating the check during a stream also covers ports that open only then. A wildcard address means that the installed version ignores `bind_address`; in that case we stop the service with `systemctl --user stop app-dev.lizardbyte.app.Sunshine` and update Sunshine before using it.

If Sunshine fails to start, the journal records the reason:

```bash
journalctl --user -u app-dev.lizardbyte.app.Sunshine -n 80 --no-pager
```

Sunshine crashed several times during our tests, mostly because of the HEVC problem from Section 13.2, and once during shutdown. After several crashes in quick succession, systemd stops restarting the service and refuses new starts until we reset it. A drop-in file makes systemd restart Sunshine a few seconds after any crash, without a limit:

```bash
mkdir -p ~/.config/systemd/user/app-dev.lizardbyte.app.Sunshine.service.d
printf '[Unit]\nStartLimitIntervalSec=0\n\n[Service]\nRestart=always\nRestartSec=3\n' > ~/.config/systemd/user/app-dev.lizardbyte.app.Sunshine.service.d/restart.conf
systemctl --user daemon-reload
```

An explicit `systemctl --user stop`, such as the one in `thinkpad-stream-stop`, still stops the service permanently.

### 13.4 Pairing Moonlight

1. Moonlight for the Mac is available from moonlight-stream.org or through `brew install --cask moonlight`; the iPad and phone versions are in the respective app stores.
2. On the Mac, we open `https://100.x.y.z:47990` in a browser, accept the warning about the self-signed certificate, and create the web interface login. Sunshine requires the username in email form, such as name@example.com, and rejects a plain name such as admin. We choose a strong password, since every device on the tailnet can reach this page.
3. In Moonlight, the **+** button at the top right ("Add PC manually") asks for an address. We enter the ThinkPad's Tailscale IP, and the ThinkPad appears as a tile with a padlock.
4. A single click on the tile starts pairing, and Moonlight displays a four-digit PIN. In the Sunshine web interface, we open **PIN** in the top menu. The request may appear there as a device named "roth" at a different address, namely the Mac's Tailscale IP. This is expected, because Moonlight sends roth as a fixed device name with every pairing request. We enter the PIN together with a recognisable name, such as MacBook, and submit it. The padlock disappears once pairing succeeds. A second click on the tile while the PIN is displayed starts another attempt, which Moonlight rejects with Error 409; restarting Sunshine clears the pending attempt.
5. A click on the ThinkPad tile now lists its applications, and **Desktop** streams the entire desktop. The first time Sunshine captures the screen, KDE displays a permission prompt on the ThinkPad that someone must approve in person. If KDE offers to remember the decision, we accept. Sunshine stores the approval and reuses it on later starts.

The iPad and phone apps work in the same way; we pair each device once with its own PIN.

Keyboard and mouse input reach the ThinkPad through `/dev/uinput`. The Sunshine package configures access to this device, so input normally works without further steps. If the stream shows the desktop but keyboard and mouse input have no effect, Section 13.6 describes the fix.

In Moonlight's settings (the gear icon at the top right), we select 1080p to match the ThinkPad's display, 60 FPS, and **H.264** as the video codec. Higher resolutions would only upscale the 1920×1080 panel, and we have disabled HEVC on the Sunshine side (Section 13.2).

### 13.5 Everyday use

Two further functions for `~/.zshrc` on the Mac, loaded with `source ~/.zshrc` as before:

```bash
thinkpad-stream() {
    ssh thinkpad 'systemctl --user start app-dev.lizardbyte.app.Sunshine' || return 1
    open -a Moonlight
}

thinkpad-stream-stop() {
    ssh thinkpad 'systemctl --user stop app-dev.lizardbyte.app.Sunshine; loginctl lock-session "$(loginctl show-user "$USER" -p Display --value)"'
}
```

`thinkpad-stream` starts Sunshine and opens Moonlight, and `thinkpad-stream-stop` stops Sunshine and locks the ThinkPad. Remote mode and the lid work as in Section 9: we run `remote-mode on` before locking the screen and closing the lid. The privacy considerations in Section 8.5 apply equally, because Sunshine also shares the actual desktop.

While a stream has keyboard focus, Moonlight responds to the following shortcuts. On the Mac, all of them begin with `Control-Option-Shift`:

| Shortcut | Function |
| --- | --- |
| `Control-Option-Shift-Q` | Leave the stream |
| `Control-Option-Shift-Z` | Release or recapture the keyboard and mouse |
| `Control-Option-Shift-X` | Switch between full screen and a window |
| `Control-Option-Shift-S` | Show or hide the statistics overlay (codec, bitrate, dropped frames) |
| `Control-Option-Shift-M` | Switch the mouse between remote-desktop and game mode |
| `Control-Option-Shift-V` | Type the Mac's clipboard text on the ThinkPad |
| `Control-Option-Shift-D` | Minimise the stream window |
| `Control-Option-Shift-C` | Show or hide the local cursor |
| `Control-Option-Shift-L` | Confine the pointer to the stream window |

The standard macOS screenshot shortcuts do not work during a stream, because Moonlight forwards them to the ThinkPad. We first press `Control-Option-Shift-Z` to return keyboard control to the Mac, take the screenshot with `Command-Shift-3`, `Command-Shift-4` or `Command-Shift-5`, and press `Control-Option-Shift-Z` again to return to the stream. Alternatively, the following command in Terminal takes a full-screen screenshot after a five-second delay, which leaves time to switch to the stream window:

```bash
screencapture -T 5 ~/Desktop/stream.png
```

### 13.6 Checks and common problems

Before relying on the stream, we confirm that:

- `ss` shows Sunshine listening only on the Tailscale address.
- `sudo nft list table inet sunshine_guard` shows the two drop rules.
- Moonlight streams the desktop with working keyboard, mouse and audio.
- The stream continues through a locked screen and a closed lid, using the tests from Section 8.4.
- `thinkpad-stream-stop` leaves the ThinkPad locked.

| Symptom | Likely cause | Remedy |
| --- | --- | --- |
| Sunshine crashes right after starting, `ss` shows nothing, and the log says `Invalid bind address` | `bind_address` in `sunshine.conf` still contains the `100.x.y.z` placeholder or an outdated address | `sed -i "s/^bind_address = .*/bind_address = $(tailscale ip -4)/" ~/.config/sunshine/sunshine.conf` inserts the actual address. If systemd then refuses to start the service because it was "attempted too often", `systemctl --user reset-failed app-dev.lizardbyte.app.Sunshine` clears that state before the next start. |
| The web interface shows "CSRF Protection Error" | `csrf_allowed_origins` is missing or does not match the address in the browser's address bar | Adding `csrf_allowed_origins = https://100.x.y.z:47990` with the actual address and restarting Sunshine with `systemctl --user restart app-dev.lizardbyte.app.Sunshine` |
| Corrupted, blocky image, or Sunshine crashes at the start of a stream; the log shows `hevc_vaapi` warnings followed by `dumped core` | The HEVC encoder on older Intel GPUs | `hevc_mode = 1` in `sunshine.conf` and H.264 in Moonlight (Section 13.2) |
| Soft H.264 image; the log says `Applying QP for compatible rate control method (QP value: 28)` | The driver lacks bitrate control for H.264, so Sunshine uses a constant QP | `qp = 20` in `sunshine.conf`; lower values give a sharper image and use more bandwidth |
| `start of the service was attempted too often` | Sunshine crashed several times in succession and systemd stopped restarting it | `systemctl --user reset-failed app-dev.lizardbyte.app.Sunshine` before starting it again; the drop-in from Section 13.3 prevents this |
| Moonlight cannot reach the PC, or the connection is refused | Sunshine stopped or crashed, or `bind_address` does not match the Tailscale IP | `ssh thinkpad 'systemctl --user status app-dev.lizardbyte.app.Sunshine'` shows the service state; `bind_address` should match `tailscale ip -4` |
| Black stream | The portal prompt is unanswered, or the lid switched the panel off | Approving the prompt at the ThinkPad; the tests in Section 8.4 |
| Desktop visible, but no keyboard or mouse input | Sunshine cannot open `/dev/uinput` | `getfacl /dev/uinput` should list our user with `rw-`; if it does not, the udev rule below the table fixes this |
| Stuttering or lag | A weak connection, or Tailscale relaying traffic instead of connecting directly | A lower resolution in Moonlight or a higher `qp`; `ssh thinkpad tailscale status` shows `relay` instead of `direct` for the Mac when Tailscale relays the traffic |

The udev rule from Sunshine's documentation grants the logged-in user access to `/dev/uinput`:

```bash
echo 'KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", TAG+="uaccess"' | sudo tee /etc/udev/rules.d/60-sunshine.rules
sudo udevadm control --reload-rules
sudo udevadm trigger
sudo modprobe uinput
```

After we log out and back in, `getfacl /dev/uinput` should list our user, and a restart of Sunshine applies the change.

Several log messages look alarming but are harmless in this setup. We expect `Failed to gain CAP_SYS_ADMIN`, because we removed that capability deliberately. `av1_vaapi … No usable encoding profile` means only that the GPU cannot encode AV1. `Failed to create client: Daemon not running` means that the Avahi daemon is not running, so Sunshine cannot announce itself on the local network; we do not need this, because Moonlight connects by IP address.

## 14. File transfer between the Mac and the ThinkPad

Screen Sharing and Moonlight do not transfer files, so we use one of two other methods: Taildrop, Tailscale's built-in file transfer, or `scp` over Tailscale SSH.

### 14.1 Taildrop

Taildrop is still in alpha, so we first enable it for the tailnet by turning on **Send Files** in the General settings of the Tailscale admin console. On the Mac, we also enable Tailscale's share extension under System Settings → General → Login Items & Extensions → Sharing.

To send a file from the Mac to the ThinkPad, we right-click it in Finder, choose **Share** → **Tailscale**, and select the ThinkPad. On Linux, received files do not appear automatically. They remain inside `tailscaled` until we retrieve them, and because `tailscaled` runs as root, retrieving them requires `sudo`:

```bash
mkdir -p ~/Downloads/taildrop
sudo tailscale file get ~/Downloads/taildrop
sudo chown -R "$USER": ~/Downloads/taildrop
```

The last line returns ownership of the files to our user, because `sudo` writes them as root. From the Mac, the same retrieval works over SSH:

```bash
ssh -t thinkpad 'mkdir -p ~/Downloads/taildrop && sudo tailscale file get ~/Downloads/taildrop && sudo chown -R "$USER": ~/Downloads/taildrop'
```

To send a file from the ThinkPad to the Mac, we use the Mac's machine name from `tailscale status`, followed by a colon. If the command reports an access error, prefixing it with `sudo` resolves this:

```bash
tailscale file cp ./results.pdf mac-name:
```

On the Mac, received files appear in `~/Downloads`.

### 14.2 scp over Tailscale SSH

Tailscale SSH supports SCP and SFTP, so the `thinkpad` alias from Section 5 also copies files, without `sudo` and without a retrieval step. Both commands run on the Mac; the first sends a file to the ThinkPad, and the second copies one back:

```bash
scp ./data.csv thinkpad:~/Downloads/
scp thinkpad:~/results/plot.png ~/Downloads/
```

`scp -r` copies entire directories, which makes this the simpler method for results and datasets.

## References

- [w0vncserver manual (TigerVNC)](https://man.archlinux.org/man/w0vncserver.1.en)
- [Tailscale pricing](https://tailscale.com/pricing)
- [Tailscale SSH](https://tailscale.com/docs/features/tailscale-ssh)
- [Tailscale for macOS](https://tailscale.com/download/mac)
- [LizardByte pacman repository](https://github.com/LizardByte/pacman-repo)
- [Sunshine pull request #2819](https://github.com/LizardByte/Sunshine/pull/2819), which withdraws support for the AUR package
- [Sunshine configuration reference](https://docs.lizardbyte.dev/projects/sunshine/master/md_docs_2configuration.html)
- [Sunshine v0.20.0 release notes](https://github.com/LizardByte/Sunshine/releases/tag/v0.20.0), the release in which Sunshine began treating Tailscale's address range as LAN
- [Moonlight](https://moonlight-stream.org/)
- [Taildrop](https://tailscale.com/docs/features/taildrop)
