## Welcome

This repository holds the various scripts used to build Satellite 6.1 Beta
summit lab that was presented at Red Hat Summit, 2015.

## Requirements

* Physcial Machine, with KVM enabled
* Sufficent disk space (about 30GB) for virtual machines
* RHEL 7.1 or Fedora (Mostly tested with RHEL 7.1 / Fedora 22)
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
```sh
virsh define /root/satellite61_summit_lab_2015/libvirt/satellite61.summit-lab.redhat.com
qemu-img create -f qcow2 -o preallocation=metadata /var/lib/libvirt/images/Satellite61-Summit2015.img 50G
virsh start Satellite61-Summit2015
virsh autostart Satellite61-Summit2015
```

### Build the satellite VM your self

Use virt-manager to create a machine called Satellite61-Summit2015
with access to the Satellite bits. The requirements are:

* Create a RHEL 7.1 base VM
* Subscribed to the Satellite 6.1 beta bits
* yum install katello
* git clone (same as above)
* copy your manifest (named manifest.zip) into the satellite61_summit_lab_2015 directory 

```sh
hostnamectl set-hostname satellite61.summit-lab.redhat.com 
cd /root/satellite61_summit_lab_2015
git pull # to ensure you have latest version
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

#### Satellite VM
Make sure that the fqdn (output of **hostname -f**) of the physical system resolves to 192.168.150.254 on
the satellite vm

```sh
echo 192.168.150.254 "my real desktop hostname -f output" >> /etc/hosts
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
