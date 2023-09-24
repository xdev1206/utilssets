sudo apt install qemu-kvm libvirt-daemon bridge-utils virt-manager

sudo systemctl enable libvirtd
sudo systemctl start libvirtd
sudo systemctl status libvirtd

sudo usermod -aG libvirt $(whoami)
sudo usermod -aG kvm $(whoami)
