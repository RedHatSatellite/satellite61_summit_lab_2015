## Welcome

This repository holds the various scripts used to build Satellite 6.1 Beta
summit lab that was presented at Red Hat Summit, 2015.

## Requirements

* Physcial Machine, with KVM enabled
* Sufficent disk space (about 30GB) for virtual machines
* Clean RHEL 7.1 or Fedora (Mostly tested with RHEL 7.1 / Fedora 22)
* Libvirt
* Open libvirt TCP connection (to avoid certificates), details bellow
* Subcriptions which allow you access to the Satellite 6.1 Beta Bits
* A Manifest which contains, at least, a Red Hat Enterprise Linux Subscription

## Installation

Please execute the following steps as **root**

### Packages

```sh
yum install kvm libvirt
```

### Clone this repository

```sh
GIT_SSL_NO_VERIFY=true git clone https://github.com/Katello/satellite61_summit_lab_2015.git /root/satellite61_summit_lab_2015
```

### Libvirt Configuration
EDIT /etc/libvirt/libvirtd.conf
```
  listen_tls = 0
  listen_tcp = 1
  auth_tcp = "none"
```
EDIT listen /etc/sysconfig/libvirtd
```
LIBVIRTD_ARGS="--listen"
```

Make sure the following modules are switched on.  We will be using NAT virtual network and TFTP does not work without them.
```
modprobe nf_nat_tftp
modprobe nf_conntrack_tftp
```

Make sure to restart libvirt

```
service libvirtd restart
```

### firewalld Configuration

```
firewall-cmd --zone=public --add-port=16509/tcp --permanent
firewall-cmd --zone=public --add-port=5900-5930/tcp --permanent
service firewalld restart
```

### Setup Libvirt NAT only networking

```sh
virsh net-define /root/satellite61_summit_lab_2015/libvirt/satellite61private.xml
virsh net-start Satellite61Private
virsh net-autostart Satellite61Private
```


### Setup Satellite 6.1 VM
From your Host:

```sh
virsh define /root/satellite61_summit_lab_2015/libvirt/satellite61.summit-lab.redhat.com
qemu-img create -f qcow2 -o preallocation=metadata /var/lib/libvirt/images/Satellite61-Summit2015.img 50G
virsh start Satellite61-Summit2015
virsh autostart Satellite61-Summit2015
```

At this point, you will need to define how best to set up the machine. 
For the purpose of this example, a RHEL7 ISO Was used with the following 
network data defined in Anaconda:

* IPv4 Manual
** Hostname: satellite61.summit-lab.redhat.com
** IP Address: 192.168.150.10
** NetMask: 255.255.255.0
** Gateway: 192.168.150.254 
** DNS: 192.168.150.254

Notes for the above:
* The hostname and ip must be the same as shown.
* the 254 address is the address of the host as seen from the guest. 

From inside the guest:

```sh
yum install katello
yum update
hostnamectl set-hostname satellite61.summit-lab.redhat.com 
systemctl stop firewalld
git clone https://github.com/Katello/satellite61_summit_lab_2015.git
cd /root/satellite61_summit_lab_2015
cp $YOUR_MANIFEST /root/satellite61_summit_lab_2015/manifest.zip
```

Make sure that the fqdn (output of **hostname -f**) of the physical system resolves to 192.168.150.254 on
the satellite vm

```sh
echo 192.168.150.254 "my real desktop hostname -f output" >> /etc/hosts
```

This is a good time to freeze the image, or create a qemu layer as a backup just in case.

```
cd /root/satellite61_summit_lab_2015
./install_command.sh
./summit.sh -c summit.config
```

### Setup Discovered Host VM
```sh
cp /root/lab_scripts/libvirt/discovery.img /var/lib/libvirt/images
virsh define /root/lab_scripts/libvirt/discovery.summit-lab.redhat.com
# power on manually after the whole satellite is up
```

### DNS

#### Physical Machine
Add to /etc/hosts on the desktop an entry for satellite61 vm
```sh
echo 192.168.150.10 satellite61.summit-lab.redhat.com >> /etc/hosts
```

### Certificates

Satellite 6.1 comes with its own CA, in order for certain functions (e.g.
VM Console etc) you are required to import the CA

#### Using a script

Stop your Firefox (make sure its not running)
As the user that runs firefox, execute
```sh
host/fetch_cert.bash
```

The script can be found in the checkout repository or [here](host/fetch_cert.bash)

#### Manually

https://satellite61.summit-lab.redhat.com/pub/katello-server-ca.crt and select web certificates.

# YOU ARE NOW READY

Please open the lab
[documentation](docs/Satellite6.1LabGuide.odt) start the lab


```
