RaspiCam-Timelapse
==================

Simple Web-App and complete HowTo for setting up a Raspberry Pi with Camera for Time-lapse Photography.

- [Node.js](https://nodejs.org/) based Web-App for controlling and monitoring the camera and the Raspberry Pi
- Reverse-SSH-Tunnel to another server - reach your Raspberry Pi behind firewalls (optional)
- Dynamic-DNS-Client - find your Raspberry Pi easier in your local network (optional)
- Wi-Fi autoconnect - if you have a USB Wi-Fi Adapter (optional)
- Network-Watchdog - reset network and maybe emergency-reboot if connection is broken (optional)
- BitTorrent-Sync - as sync-solution to get the photos out of the Pi (optional)
- Prerequisites: Raspberry Pi + Power + SD-Card, RaspiCam, LAN Cable, USB Wi-Fi Adapter (optional)

![Screenshot](screenshot.jpg)

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [HowTo](#howto)
  - [Setup SD-Card](#setup-sd-card)
  - [Setup Raspbian + Raspberry Pi Camera](#setup-raspbian--raspberry-pi-camera)
  - [Setup RaspiCam-Timelapse](#setup-raspicam-timelapse)
  - [Reverse SSH-Tunnel (optional)](#reverse-ssh-tunnel-optional)
  - [Dynamic-DNS-Client (optional)](#dynamic-dns-client-optional)
  - [Wi-Fi autoconnect (optional)](#wi-fi-autoconnect-optional)
  - [Activate Network-Watchdog (optional)](#activate-network-watchdog-optional)
    - [Setup config file (optional)](#setup-config-file-optional)
  - [Install BitTorrent-Sync (optional)](#install-bittorrent-sync-optional)
  - [Use sync script (optional)](#use-sync-script-optional)
    - [Setup config file](#setup-config-file)
    - [Crontab](#crontab)
    - [less strict ssh restrictions needed on your remote server](#less-strict-ssh-restrictions-needed-on-your-remote-server)
- [TODO](#todo)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

HowTo
-----

### Setup SD-Card

- Download current [Raspbian](https://www.raspberrypi.org/downloads/raspbian/) ("Jessie" or newer - "Lite" is enough)
- Write extracted ".img"-file to SD-Card - [see OS specific instructions](https://www.raspberrypi.org/documentation/installation/installing-images/README.md)
- Attach the camera to the Raspberry Pi - [see instructions](https://www.raspberrypi.org/documentation/configuration/camera.md)
- Put the SD-Card into your Raspberry Pi, Connect to your LAN (DHCP server needed), Power on
- Login via SSH (maybe use local IP): `ssh raspberrypi` (Login: pi / Password: raspberry)
- Make complete SD-Card usable: `sudo raspi-config` - 1 Expand Filesystem - Finish - Reboot


### Setup Raspbian + Raspberry Pi Camera

- Install updates: `sudo apt-get update`, `sudo apt-get dist-upgrade` and `sudo apt-get clean`
- For some helpful optional customizations of your Raspberry Pi - [see here](Raspberry-Customizing.md)
- Enable camera: `sudo raspi-config` - 5 Enable Camera - Enable - Finish  
  (this also sets Memory Split to 128 MB)
- Disable camera LED when taking pictures (optional):  
  `sudo sh -c 'echo "disable_camera_led=1" >> /boot/config.txt'`
- Reboot for the camera settings to take effect: `sudo reboot`


### Setup RaspiCam-Timelapse

Install Node.js (for Node.js >=4.x you need Raspbian "Jessie" or newer - otherwise the native modules won't compile):

```bash
wget https://nodejs.org/dist/v4.2.3/node-v4.2.3-linux-armv6l.tar.gz
tar -xvzf node-v4.2.3-linux-armv6l.tar.gz
sudo cp -R node-v4.2.3-linux-armv6l/{bin,include,lib,share} /usr/local/
rm -rf node-v4.2.3-linux-armv6l
```

Install GIT:

```bash
sudo apt-get install git
```

Check out this repository:

```bash
cd ~
git clone https://github.com/not-implemented/raspicam-timelapse.git
cd raspicam-timelapse
npm install
```

Configuration:

```bash
# Create a self-signed certificate:
openssl req -x509 -days 3650 -sha256 -nodes -newkey rsa:2048 -keyout config/timelapse.key -out config/timelapse.crt
chmod og= config/timelapse.key

# Prepare capture directory:
mkdir ../capture
```

Start server:

```bash
npm start &
```

... now open your browser - i.e. with https://raspberrypi:4443/ or IP address (Login: timelapse / Password: timelapse) :-)

Enable start on reboot:

```bash
crontab -e

# Insert this line into crontab:
@reboot /usr/local/bin/node ~/raspicam-timelapse/server.js &
```


### Reverse SSH-Tunnel (optional)

Be sure, to change the default password before allowing connections from untrusted
networks - [see here](Raspberry-Customizing.md).

Generate SSH-Key on Raspberry Pi (just press ENTER everywhere):

```bash
cd ~
ssh-keygen -t rsa

# Show the public key for using later:
cat ~/.ssh/id_rsa.pub
```

Allow SSH connections from Raspberry Pi on your remote server:

```bash
# Maybe add a new user - i.e. "timelapse" on your remote server (but you can use an existing one):
adduser --gecos Timelapse timelapse
chmod go-rwx /home/timelapse
cd /home/timelapse

# Add the raspberry's key (.ssh/id_rsa.pub from above) on your remote server
# to the user and just allow port-forwarding (no login):
mkdir -p .ssh
echo "command=\"echo 'This account can only be used for port-forwarding'\",no-agent-forwarding,no-pty,no-X11-forwarding" \
    "{raspberry-public-key-from-above}" >> .ssh/authorized_keys
chmod -R go-rwx .ssh
chown -R timelapse:timelapse .ssh

# Some global settings:
editor /etc/ssh/sshd_config

# Enable listening on all interfaces for port-forwarding on your remote server
# (otherwise port-forwarding will listen only on localhost):
GatewayPorts yes

# Detect and close dead connections faster and close forwarded ports to reuse them:
ClientAliveInterval 30
ClientAliveCountMax 3

# Restart SSH server:
service sshd restart
```

Back on Raspberry Pi: Configure tunnels to be established - create a script with
`editor tunnels.sh` like the following example to forward port 10022 from your
remote server to port 22 on Raspberry Pi - same with port 4443 and 8888:

```bash
#!/bin/bash

~/raspicam-timelapse/ssh-reverse-tunnel/open-tunnel.sh timelapse@www.example.com 10022 22 &
~/raspicam-timelapse/ssh-reverse-tunnel/open-tunnel.sh timelapse@www.example.com 4443 4443 &
~/raspicam-timelapse/ssh-reverse-tunnel/open-tunnel.sh timelapse@www.example.com 18888 8888 &
```

```bash
# Make it executable:
chmod +x tunnels.sh

# Check SSH-Connection and permanently add the key (type "yes"):
ssh timelapse@www.example.com
# (... should print "This account can only be used for port-forwarding" and close SSH connection)

# Add script to crontab:
crontab -e

# Insert this lines into crontab:
@reboot ~/tunnels.sh
* * * * * ~/tunnels.sh
```


### Dynamic-DNS-Client (optional)

```bash
# Link script:
sudo ln -snf /home/pi/raspicam-timelapse/dynamic-dns-client/lib_dhcpcd_dhcpcd-hooks_90-dynamic-dns /lib/dhcpcd/dhcpcd-hooks/90-dynamic-dns

# Change config vars in dynamic-dns.conf:
sudo editor dynamic-dns-client/dynamic-dns.conf
```


### Wi-Fi autoconnect (optional)

```bash
sudo editor /etc/wpa_supplicant/wpa_supplicant.conf
```

Append as many networks as you want - some examples:

```
# Secure Wi-Fi example:
network={
    ssid="{your-ssid}"
    psk="{your-key}"
}

# Open Wi-Fi example:
network={
    ssid="muenchen.freifunk.net"
    key_mgmt=NONE
}
```


### Activate Network-Watchdog (optional)

```bash
crontab -e

# Insert this line into crontab:
* * * * * sudo ~/raspicam-timelapse/network-watchdog/check-network.sh
```
#### Setup config file (optional)
You can override IPV4_PING_DEST and IPV6_PING_DEST which are set to the default gateway by default.  
Location: config/check-network.conf

### Install BitTorrent-Sync (optional)

We currently use BitTorrent-Sync as sync-solution, because Syncthing is very slow on Raspberry Pi.

```bash
wget https://download-cdn.getsync.com/stable/linux-arm/BitTorrent-Sync_arm.tar.gz
mkdir btsync && cd btsync
tar -xvzf ../BitTorrent-Sync_arm.tar.gz

# Start BitTorrent-Sync:
./btsync --webui.listen 0.0.0.0:8888
cd ..

# Enable start on reboot:
crontab -e
@reboot ~/btsync/btsync --webui.listen 0.0.0.0:8888
```

Now open Web-Interface via "https://raspberrypi:8888/" and add "/home/pi/capture" folder for sync.

After that disable sync of "latest.jpg":

```bash
editor capture/.sync/IgnoreList

# Append to the end:
/latest.jpg
```

### Use sync script (optional)
second sync method is a [configurable sync script](sync/sync.sh). Currently only tested with rsync.

#### Setup config file
You have to configure some options in sync/sync.conf ([examples](sync/sync.conf.example)) at first 
#### Crontab
```
# add sync script to crontab
crontab -e
*/5 * * * * ~/raspicam-timelapse/sync/sync.sh ~/capture
```
#### less strict ssh restrictions needed on your remote server
You have to modify the authorized_keys line to allow the sync command to be executed
```diff
-command="echo 'This account can only be used for port-forwarding'"
+command=/path/to/command_validation.sh
```
Example for command_validation.sh:
```bash
#!/bin/bash

if [[ "$SSH_ORIGINAL_COMMAND" =~ [\&\;] ]] ;
then
    echo "Error: Invalid character found in command."
    exit 1
fi

case "$SSH_ORIGINAL_COMMAND" in
    rsync*/timelapse/capture*)
        ;;
    *)
        echo "Error: Invalid command over ssh executed."
        exit 1
        ;;
esac

exec $SSH_ORIGINAL_COMMAND
```

TODO
----

- Implement as a service (start on boot, restart on crash, restart raspistill after crash)
- Use NVM for installing Node.js - https://github.com/creationix/nvm
- Remove cron-mode
- Implement more options in frontend (username/password, camera upside-down with --hflip --vflip, ...)
- Get Dynamic-DNS-Client more stable (trigger on IP adress changes, not just on cable plug)
