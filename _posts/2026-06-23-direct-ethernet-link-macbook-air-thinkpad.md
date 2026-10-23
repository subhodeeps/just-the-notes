---
title: "A Direct Ethernet Link between a MacBook Air and an Arch Linux ThinkPad"
short_title: "Direct Ethernet Link" # in the note graph
description: "A single USB-C to RJ45 cable between a MacBook Air M1 and a ThinkPad P15 running Arch Linux, with fixed addresses, checks of the link, and passwordless SSH for Julia workers and Mathematica kernels."
date: 2026-06-23 00:00:00 +0530
categories: [Homelab, Guides]
tags: [homelab, linux, arch-linux, ssh, ethernet, cluster, macos, julia, mathematica]
primary_tags: [homelab, linux, arch-linux] # one to three tags for the note graph
math: true
pin: false
---

In this post, we will describe how to connect a MacBook Air M1 to a ThinkPad P15 Gen 1 running Arch Linux with a single Ethernet cable, without using a router or a switch. We will give each machine a fixed address and set up passwordless SSH from the Mac to the ThinkPad. This Ethernet link will connect the two machines (as described in [[2025-11-25-maltar|this setup]]). We will use the Mac to launch Julia workers and Mathematica kernels on the ThinkPad and use both machines concurrently to run our embarrassingly parallel computations. For remote access over the internet, see the [[2026-10-22-remote-login-arch-thinkpad-from-macos|notes on remote login]], where we have used Tailscale.

## 1. Overview

The Mac will use the address `192.168.0.1` and the ThinkPad has the IP address `192.168.0.2`, both being on the network `192.168.0.0/16`. All traffic between the two machines goes over the cable. Since neither machine has a gateway on this network, internet traffic will continue to go through Wi-Fi, and the link works even without an internet connection.

Note that the setup has the following limitations:

1. The cable can connect only two machines. Adding a third machine will need an Ethernet switch.
2. Many home routers assign addresses of the form `192.168.0.x`. If the Mac's Wi-Fi network does so too, the Mac might route traffic for `192.168.0.2` through Wi-Fi. In that case, we use a range that no other network uses, for example `10.10.0.1` and `10.10.0.2` with the subnet mask `255.255.255.0`.
3. macOS names a USB network adapter when it first detects it, so the interface may not be called `en7` on another Mac or another USB-C port.

## 2. The cable

The MacBook Air has no Ethernet port, so we use a Cat6 cable with a USB-C plug on one end and an RJ45 plug on the other. The ThinkPad has an old-fashioned RJ45 port. The USB-C plug contains a Gigabit Ethernet adapter:

```text
MacBook Air M1 (USB-C)
      │
USB-C to RJ45 Cat6 cable
      │
ThinkPad P15 Gen 1 (RJ45)
```

## 3. Checking the link

Once the cable is plugged in, both machines should detect the link, even before we assign any addresses. On the Mac, run:

```bash
ifconfig en7
```

The output should include:

```text
status: active
media: 1000baseT <full-duplex>
```

Here, `status: active` means that the Mac detects a live port at the other end of the cable, and `1000baseT <full-duplex>` means that the link runs at 1 Gb/s in both directions simultaneously. If `en7` does not exist, `networksetup -listallhardwareports` lists all network ports with their device names, and the cable appears as a USB LAN port.

On the ThinkPad:

```bash
ip addr
```

The Ethernet interface is `enp0s31f6`, and its flags should include `UP` and `LOWER_UP`:

```text
enp0s31f6: <BROADCAST,MULTICAST,UP,LOWER_UP>
```

`UP` means that the interface is enabled, and `LOWER_UP` means that it detects the cable.

## 4. Fixed addresses

Without a router, there is no DHCP server to assign addresses, so we assign them manually. On the Mac, we open System Settings $\to$ Network, select the Ethernet interface, open its details, and set:

```text
Configure IPv4: Manually
IP address:     192.168.0.1
Subnet mask:    255.255.0.0
Router:         (blank)
```

We leave the router field blank so that the Mac continues to use Wi-Fi for internet access. After applying the changes, `ifconfig en7` should show:

```text
inet 192.168.0.1
```

On the ThinkPad, NetworkManager manages the Ethernet interface. In its settings, we edit the connection `Wired connection 1`, which NetworkManager creates for the Ethernet port, and set:

```text
IPv4 method: Manual
Address:     192.168.0.2
Netmask:     255.255.0.0
Gateway:     (blank)
```

We save the connection and reconnect it. To verify the address, run:

```bash
ip addr show enp0s31f6
```

The output should include `inet 192.168.0.2/16`.

## 5. Connectivity

### 5.1 Ping

We can now test the link in both directions. From the Mac, run:

```bash
ping -c 4 192.168.0.2
```

and from the ThinkPad:

```bash
ping -c 4 192.168.0.1
```

The option `-c 4` sends four packets and then stops. If we do not specify the flag, `ping` runs until we press Ctrl-C. Both commands should report `0% packet loss`.

### 5.2 ARP

A successful ping does not tell us which interface the Mac used. For that, we check the Mac's ARP table, which maps IP addresses to the hardware (MAC) addresses of network cards:

```bash
arp -a | grep 192.168.0.2
```

The output should look like:

```text
isengard (192.168.0.2) at 84:a9:38:5b:3d:ff on en7 ifscope [ethernet]
```

The entry shows the ThinkPad's name and the MAC address of its network card, and `on en7` confirms that the Mac reached the ThinkPad through the cable rather than through Wi-Fi. If there is no entry yet, we send a single ping first:

```bash
ping -c 1 192.168.0.2
arp -a | grep 192.168.0.2
```

## 6. SSH server on the ThinkPad

Unlike the setup in the [[2026-10-22-remote-login-arch-thinkpad-from-macos|notes on remote login]], which uses Tailscale SSH, this link uses the OpenSSH server. We can install it from the official Arch repositories and enable it:

```bash
sudo pacman -S openssh
sudo systemctl enable --now sshd
```

`enable` starts the server at every boot, and `--now` also starts it immediately. To check that it is running:

```bash
systemctl status sshd
```

The output should show `active (running)`.

## 7. First SSH login

From Terminal on the Mac, we run a single command on the ThinkPad:

```bash
ssh subhodeep@192.168.0.2 hostname
```

SSH asks for the ThinkPad's password, runs `hostname` on the ThinkPad, and returns to the Mac. The output should be the ThinkPad's hostname:

```text
isengard
```

This command tests the cable, the addresses, the SSH server and the login at once.

## 8. Passwordless login

Julia and Mathematica can launch their remote workers over SSH but cannot enter a password, so the Mac must log in with a key. If the Mac does not have a key pair yet, we can create one as follows:

```bash
ssh-keygen -t ed25519
```

We then copy the public key to the ThinkPad. `ssh-copy-id` adds it to `~/.ssh/authorized_keys` on the ThinkPad and asks for the password one last time:

```bash
ssh-copy-id subhodeep@192.168.0.2
```

Repeating the test from Section 7 should now print `isengard` without asking for a password.

To avoid typing the address each time, we can define a host alias in `~/.ssh/config` on the Mac:

```text
Host isengard
    HostName 192.168.0.2
    User subhodeep
```

After saving the file, `ssh isengard` opens a shell on the ThinkPad. Julia and Mathematica can use the alias too.

## 9. Julia and Mathematica

Julia's `addprocs` and Mathematica's `LaunchKernels` start their workers through non-interactive SSH sessions, which may not read the same start-up files as an interactive login. We therefore check that such a session can find both programs:

```bash
ssh isengard hostname
ssh isengard julia -e 'println(VERSION)'
ssh isengard wolframscript -code '1+1'
```

The first command should print `isengard`, the second the Julia version installed on the ThinkPad, and the third `2`, which also confirms that Mathematica starts and finds its licence. If all three succeed without a password prompt, the Mac can launch Julia workers and Mathematica kernels on the ThinkPad over the cable, as shown in the [[2025-11-25-maltar-phase-1-tests|benchmark notes]].

## 10. Performance

The link runs at 1 Gb/s. After protocol overhead, large file transfers reach about 100–115 MB/s, and the latency is below a millisecond. This is sufficient for embarrassingly parallel jobs. The link also works well for remote development, for example with VS Code's Remote SSH, and for copying large files with `rsync` or `scp`, as described in the [[2026-07-06-transfer-files-ubuntu-arch|rsync guide]].

---

We used the [Portronics EtherC](https://www.portronics.com/products/etherc), a USB-C to RJ45 Cat6 cable, for our setup.
