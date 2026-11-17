## Groups

```sh
doas usermod -aG wheel,video,audio,kvm,libvirt,docker,network,bluetooth badr
```

## Services

```sh
doas ln -s /etc/sv/dbus /var/service/
doas ln -s /etc/sv/elogind /var/service/
doas ln -s /etc/sv/NetworkManager /var/service/
doas ln -s /etc/sv/chronyd /var/service/
doas ln -s /etc/sv/libvirtd /var/service/
doas ln -s /etc/sv/docker /var/service/
doas ln -s /etc/sv/polkitd /var/service/
doas ln -s /etc/sv/bluetoothd /var/service/
```
