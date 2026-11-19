```ansi
[1;35m
  ░██████  ░██     ░██    ░███    ░███     ░███ ░██     ░██    ░███    ░█████████       ░██████     ░██████      ░██     ░██ 
 ░██   ░██ ░██     ░██   ░██░██   ░████   ░████ ░██     ░██   ░██░██   ░██     ░██     ░██   ░██   ░██   ░██     ░██     ░██ 
░██        ░██     ░██  ░██  ░██  ░██░██ ░██░██ ░██     ░██  ░██  ░██  ░██     ░██    ░██     ░██ ░██            ░██     ░██ 
░██        ░██████████ ░█████████ ░██ ░████ ░██ ░██████████ ░█████████ ░█████████     ░██     ░██  ░████████     ░██████████ 
░██        ░██     ░██ ░██    ░██ ░██  ░██  ░██ ░██     ░██ ░██    ░██ ░██   ░██      ░██     ░██         ░██    ░██     ░██ 
 ░██   ░██ ░██     ░██ ░██    ░██ ░██       ░██ ░██     ░██ ░██    ░██ ░██    ░██      ░██   ░██   ░██   ░██     ░██     ░██ 
  ░██████  ░██     ░██ ░██    ░██ ░██       ░██ ░██     ░██ ░██    ░██ ░██     ░██      ░██████     ░██████      ░██     ░██ 
                                                                                                                   
[0m

```
A minimal, suckless based Void Linux desktop setup with automated package installation, dotfiles, and system configurations.

## Prerequisites

* A fresh base installation of **Void Linux** (glibc or musl)
* Working internet connection
* A non-root user with `sudo` privileges

---

## Installation

### 1. Update Void Linux & Install Git

Always update `xbps` first on a fresh Void install before upgrading the rest of the system:

```sh
sudo xbps-install -Sy xbps
sudo xbps-install -Syu
sudo xbps-install -Sy git

```

### 2. Clone the Repository

```sh
git clone [https://github.com/chamharoush/void-system](https://github.com/chamharoush/void-system)
cd void-system

```

### 3. Install Packages

Make the package installation script executable and run it:

```sh
chmod +x system/scripts/install-packages.sh
./system/scripts/install-packages.sh

```

### 4. Configure `doas`

Create and configure `/etc/doas.conf` (replace `<username>` with your actual user, or use `:wheel` for the wheel group):

```sh
echo "permit persist :wheel" | sudo tee /etc/doas.conf
sudo chown -c root:root /etc/doas.conf
sudo chmod -c 0400 /etc/doas.conf

```

Verify the syntax before relying on it:

```sh
doas -C /etc/doas.conf && echo "config ok"

```

### 5. Deploy Dotfiles

Copy the configuration files to your home directory (`~`) and prepend them with a dot (`.`):

```sh
cp config/xinitrc ~/.xinitrc
cp config/bashrc ~/.bashrc
cp config/bash_profile ~/.bash_profile

```

### 6. Enable System Services

Link the required runit services into `/var/service/`:

```sh
doas ln -s /etc/sv/dbus /var/service/
doas ln -s /etc/sv/elogind /var/service/
doas ln -s /etc/sv/NetworkManager /var/service/
doas ln -s /etc/sv/chronyd /var/service/
doas ln -s /etc/sv/libvirtd /var/service/
doas ln -s /etc/sv/docker /var/service/
doas ln -s /etc/sv/polkitd /var/service/

```

### 7. Compile Suckless Tools

Build and install each suckless utility (`dwm`, `st`, `dmenu`):

```sh
for tool in dwm st dmenu; do
  cd "src/$tool" && doas make clean install && cd -
done

```

### 8. Reboot

```sh
doas reboot

```

After rebooting, log in and **Voilà!**

---

```

```
