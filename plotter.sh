#!/bin/sh
# 1.0 Install updates and tools

# 1.1 Update system
sudo apt update
sudo apt upgrade  --yes
sudo apt autoremove --yes

# 1.2 Install useful tools
sudo apt install --yes unzip iotop htop wget nano

# 1.3 Install duf
mkdir ~/lets-farm/tmp
cd ~/lets-farm/tmp
wget https://github.com/muesli/duf/releases/download/v0.6.2/duf_0.6.2_linux_amd64.deb
sudo dpkg -i duf_0.6.2_linux_amd64.deb
cd ~/lets-farm
rm -rf ~/lets-farm/tmp


# 2.0 Add Temp Storage (local SSDs)

# 2.1 Install mdadm:
sudo apt update && sudo apt install mdadm --no-install-recommends

# 2.1 Check that disks exist
lsblk

# 2.3 Format and mount multiple local SSD partitions into a single logical volume
sudo mdadm --create /dev/md0 --level=0 --raid-devices=24 /dev/nvme0n1 /dev/nvme0n2 /dev/nvme0n3 /dev/nvme0n4 /dev/nvme0n5 /dev/nvme0n6 /dev/nvme0n7 /dev/nvme0n8 /dev/nvme0n9 /dev/nvme0n10 /dev/nvme0n11 /dev/nvme0n12 /dev/nvme0n13 /dev/nvme0n14 /dev/nvme0n15 /dev/nvme0n16 /dev/nvme0n17 /dev/nvme0n18 /dev/nvme0n19 /dev/nvme0n20 /dev/nvme0n21 /dev/nvme0n22 /dev/nvme0n23 /dev/nvme0n24

# 2.4 Format the /dev/md0 array with an xfs file system
sudo mkfs.xfs -m crc=0 -f -L XFS /dev/md0

# 2.5 Create a directory to where you can mount /dev/md0
sudo mkdir -p /mnt/temp

# 2.6 Configure read and write access to the device
sudo chmod a+w /mnt/temp

# 2.7 Create the /etc/fstab entry for /mnt/temp
echo UUID=`sudo blkid -s UUID -o value /dev/md0` /mnt/temp  xfs discard,defaults 0 0 | sudo tee -a /etc/fstab


# 3.0 Add Plots Storage (Local Balanced Disk)

# 3.1 Format the full /dev/sdb array with an xfs file system:
sudo mkfs.xfs -m crc=0 -f -L XFS /dev/sdb

# 3.2 Create a directory to where you can mount the bucket
sudo mkdir -p /mnt/plots

# 3.3 Configure read and write access to the directory
sudo chmod a+w /mnt/plots

# 3.4 Create the /etc/fstab entry for /mnt/plots
echo UUID=`sudo blkid -s UUID -o value /dev/sdb` /mnt/plots  xfs discard,defaults 0 0 | sudo tee -a /etc/fstab


# 4.0 Add Plots Archive (GCP Cloud Storage Bucket)

# 4.1 Create a directory to where you can mount the bucket
sudo mkdir -p /mnt/farm/archive

# 4.2 Configure read and write access to the directory
sudo chmod a+w /mnt/farm/archive

# 4.3 Install Gcsfuse:
export GCSFUSE_REPO=gcsfuse-`lsb_release -c -s`
echo "deb http://packages.cloud.google.com/apt $GCSFUSE_REPO main" | sudo tee /etc/apt/sources.list.d/gcsfuse.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

# 4.4 Update the list of packages available and install gcsfuse.
sudo apt-get update
sudo apt-get install gcsfuse --yes

# 4.5 Create the /etc/fstab entry for /mnt/farm/archive
MYUID=$(id -u $USER)
MYGID=$(id -g $USER)
echo "What's the name of the GCP bucket you want to mount?"
read BUCKETNAME
echo $BUCKETNAME /mnt/farm/archive gcsfuse rw,_netdev,allow_other,uid=`echo $MYUID`,gid=`echo $MYGID` | sudo tee -a /etc/fstab


# 5.0 Mount all the entries added to /dev/fstab and list them

# 5.1 Mount
sudo mount -a
duf

# 5.2 Configure read and write access to the mounted directories
sudo chmod a+w /mnt/temp
sudo chmod a+w /mnt/plots
sudo chmod a+w /mnt/farm/archive


# 6.0 Setup Machinaris to plot Chia

# 6.1 Install Docker
mkdir ~/lets-farm/tmp
cd ~/lets-farm/tmp
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
cd ~/lets-farm
rm -rf ~/lets-farm/tmp

# 6.2 Manage Docker as a non-root user:
# sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker

read -p "Docker installed! Press enter to install Machinaris."

# 6.3 Install Machinaris
docker run -d --name='machinaris' -p 8926:8926 -e TZ="Europe/Oslo" -e mode=plotter -e farmer_pk=8bda5707b657821cab51a386a855adf787e6d992a6de3fadc7c0c0dafe38e26dcc4f209fbdf7ec6ddd475fb9f8e7c84c -e pool_pk=a901edfeaabb61e5c4ff2af983994c166a25be098ef523caa688aff166efebcab1a77dbbbbe867f76b7e1f417eeecc16 -v '/home/iamchriswick/.machinaris':'/root/.chia':'rw' -v '/mnt/plots':'/plots':'rw' -v '/mnt/temp':'/plotting':'rw' -t 'ghcr.io/guydavis/machinaris'


# 8.0 Setup SSH

# 8.1 Add SSH Key
ssh-keygen
#echo "# Added by iamchriswick" | sudo tee -a ~/.ssh/authorized_keys
#echo `cat ~/.ssh/id_rsa.pub` | sudo tee -a ~/.ssh/authorized_keys

# 8.2 Add SSH Key to GCP VM Instance
cat ~/.ssh/id_rsa.pub
read -p "Add the above Public Key to your GCP VM Instance, and press enter to continue"
read -p "Wait untill the GCP VM Instance has updated and press enter to continue"

# 8.3 Test if SSH was set up corectly
ssh -i ~/.ssh/id_rsa iamchriswick@localhost df -aBK | grep /mnt/farm/

# 9.0 rsync

# 9.1 Set up rsync daemon (rsyncd)
sudo cp ~/lets-farm/rsyncd.conf /etc/rsyncd.conf
sudo systemctl start rsync
sudo systemctl enable rsync

# 9.2 Test rsync
echo "testing" > testfile.test
rsync -P testfile.test rsync://iamchriswick@localhost:12000/chia/archive
ls /mnt/farm/archive
read -p "Press enter to continue if you see the testfile"
rm /mnt/farm/archive/testfile.test
rm ~/lets-farm/testfile.test


# 10.0 Cleanup
cd ~/
rm -rf ~/lets-farm


# 11.0  Configure Plotman
echo 'Visit http://<vm-ip>:8926/settings/plotting to configure Plotman and start plotting.'
read -p "All done! Press enter to exit session"
exit
