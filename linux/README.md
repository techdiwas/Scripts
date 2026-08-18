# 📱 Ubuntu Scripts

This repository contains a Bash script designed to streamline the setup of the **Ubuntu**, **Arch** and **Fedora** environment for seamless **GitHub usage** on Linux Distro.

It automates the configuration process, saving time and ensuring a smooth developer experience when working with GitHub via Ubuntu, Arch and Fedora.

---

## 🚀 Getting Started

For Arch:

```bash
bash arch_setup.sh
```

For Fedora:

```bash
bash fedora_setup.sh
```

For Ubuntu:

```bash
bash ubuntu_setup.sh
```

---

---

## Memory Tweaks (Generally Not Recommanded)

To clear buff/cache and swap:

```bash
sudo sh -c 'echo 3 >  /proc/sys/vm/drop_caches'
```

---

---
## Swap Tweaks

Create this configuration file:

```bash
sudo nano /etc/sysctl.d/99-swap-tweaks.conf
```

Add these lines:

```bash
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_background_ratio=5
vm.dirty_ratio=10
```

Apply changes:

```bash
sudo sysctl --system
```

---

---

# Lock Screen Settings

Edit `/etc/gdm3/greeter.dconf-defaults`.

```bash
# These are the options for the greeter session that can be set 
# through GSettings. Any GSettings setting that is used by the 
# greeter session can be set here.

# Note that you must configure the path used by dconf to store the 
# configuration, not the GSettings path.


# Login manager options
# =====================
[org/gnome/login-screen]
# See /usr/share/glib-2.0/schemas/org.gnome.login-screen.gschema.xml
# - Distro logo shown below the user list or username box
#logo='/usr/share/images/vendor-logos/logo-text-version-64.png'

# - Disable user list
# disable-user-list=true
# - Disable restart buttons
# disable-restart-buttons=true
# - Show a login welcome message
# banner-message-enable=true
# banner-message-text='Welcome'
# - Don't use a fingerprint reader for authentication
# enable-fingerprint-authentication=false
# - Don't use a smartcard reader for authentication
# enable-smartcard-authentication=false

# Automatic suspend
# =================
[org/gnome/settings-daemon/plugins/power]
# See /usr/share/glib-2.0/schemas/org.gnome.settings-daemon.plugins.power.gschema.xml
# - Time inactive in seconds before suspending with AC power
#   1200=20 minutes, 0=never
# sleep-inactive-ac-timeout=1200
# - What to do after sleep-inactive-ac-timeout
#   'blank', 'suspend', 'shutdown', 'hibernate', 'interactive' or 'nothing'
# sleep-inactive-ac-type='suspend'
# - As above but when on battery
# sleep-inactive-battery-timeout=1200
# sleep-inactive-battery-type='suspend'

# Appearance
# ==========
[org/gnome/desktop/interface]
# See /usr/share/glib-2.0/schemas/org.gnome.desktop.interface.gschema.xml
# - Accent color for UI widgets, could be chosen to match distro branding
accent-color='blue'

# - Clock settings
clock-format='12h'
clock-show-date=true
clock-show-weekday=true
clock-show-seconds=false
```

Apply changes:

```bash
sudo systemctl restart gdm3
```

# Bootloader settings

Edit /etc/default/grub

```bash
sudo nano /etc/default/grub
```

Set `GRUB_RECORDFAIL_TIMEOUT=0`

Run this after the change have been made

```bash
sudo update-grub
``` 

---

---

# Ubuntu Server

After the server has been installed on your system, you can do these things.

```bash
sudo apt update && sudo apt upgrade
sudo apt install ubuntu-desktop
sudo apt purge vim
sudo apt install gnome-software
sudo snap install brave
sudo snap install desktop-security-center
sudo apt install flatpak
sudo apt install gnome-software-plugin-flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
sudo apt autoremove
sudo reboot
```
---
