#!/bin/bash
#Installing the Ubuntu desktop manager
sudo apt update -y
sudo apt install -y ubuntu-desktop
sudo apt install x11-xserver-utils
sudo apt install awscli -y
sudo apt install -y dpkg-dev
sudo systemctl restart gdm3
sudo apt-get install xorg-dev -y
#............................
# Disable the Wayland protocol. NICE DCV doesn't support the Wayland protocol.
sudo sed -i '/WaylandEnable/s/^#//g' /etc/gdm3/custom.conf
# .............................
# Install NVIDIA Drivers
#..............................
sudo apt-get install -y unzip gcc make linux-headers-$(uname -r)
cat << EOF | sudo tee --append /etc/modprobe.d/blacklist.conf
blacklist vga16fb
blacklist nouveau
blacklist rivafb
blacklist nvidiafb
blacklist rivatv
EOF
# ........
sudo sed -i -e '$a GRUB_CMDLINE_LINUX="rdblacklist=nouveau"' /etc/default/grub
sudo update-grub
# Make sure to give the EC2 instance S3 read permissions, otherwise this will fail
#sudo aws s3 cp --recursive s3://ec2-linux-nvidia-drivers/latest/ .
if [[ ! -f NVIDIA-Linux-x86_64-520.56.06.run ]] ; then
  echo "520.56.06/NVIDIA-Linux-x86_64-520.56.06.run doesn't exist, downloading it now"
  wget 'https://www.nvidia.com/content/DriverDownloads/confirmation.php?url=/XFree86/Linux-x86_64/520.56.06/NVIDIA-Linux-x86_64-520.56.06.run'
fi
sudo chmod +x NVIDIA-Linux-x86_64*.run
if [[ "$(modinfo /usr/lib/modules/$(uname -r)/kernel/drivers/video/nvidia.ko | grep ^version)" != 'version:        520.56.06' ]] ; then
  echo "Nvidia driver is not installed.  Installing it now..."
  echo sudo /bin/sh ./NVIDIA-Linux-x86_64*.run -q
fi
nvidia-smi -q | head# Configure the X Server
sudo systemctl set-default graphical.target
sudo systemctl isolate graphical.target
sudo apt install -y mesa-utils
sudo init 3
sudo init 5
sudo nvidia-xconfig --preserve-busid --enable-all-gpus
sudo DISPLAY=:0 XAUTHORITY=$(ps aux | grep "X.*\-auth" | grep -v grep \
| sed -n 's/.*-auth \([^ ]\+\).*/\1/p') glxinfo | grep -i "opengl.*version"
sudo systemctl isolate multi-user.target
sudo systemctl isolate graphical.target# Install DCV
wget https://d1uj6qtbmh3dt5.cloudfront.net/NICE-GPG-KEY
gpg --import NICE-GPG-KEY
sudo rm NICE-GPG-KEY
sudo dcvstartx &
if [[ ! -f nice-dcv-2022.0-12123-ubuntu2004-x86_64.tgz ]] ; then
  echo "nice-dcv-2022.0-12123-ubuntu2004-x86_64.tgz doesn't exist, downloading it now"
  sudo wget https://d1uj6qtbmh3dt5.cloudfront.net/2022.0/Servers/nice-dcv-2022.0-12123-ubuntu2004-x86_64.tgz
fi
if [[ ! -d nice-dcv-2022.0-12123-ubuntu2004-x86_64 ]] ; then
  sudo tar xvzf nice-dcv-*ubun*.tgz
fi
cd nice-dcv-2022.0-12123-ubuntu2004-x86_64
sudo apt install -y ./nice-dcv-ser*.deb
sudo apt install -y ./nice-x*.deb
sudo apt install -y ./nice-dcv-web*.deb
sudo usermod -aG video ubuntu
sudo usermod -aG video dcv
# Start the DCV Server and DCV session
sudo systemctl enable dcvserver
sudo systemctl start dcvserver
sudo dcv create-session --type=console --owner=ubuntu newsession
sudo dcv list-sessions
sudo dcv close-session newsession
# Create random password for the user Ubuntu
#PASS=$(aws secretsmanager get-random-password --require-each-included-type --password-length 20 --query RandomPassword)
#INSTANCE=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/public-hostname)
#aws secretsmanager create-secret --name DCV/$INSTANCE --description "Credentials for $INSTANCE." --secret-string "{\"user\":\"ubuntu\",\"password\":$PASS}"
sudo systemctl isolate multi-user.target
sudo systemctl isolate graphical.target

if [[ ! -d ~/PixelStreaming ]] ; then
  echo "WARNING: The PixelStreaming folder doesn't existing.  Please download and extract the PixelStreaming.tgz project file..."
fi
