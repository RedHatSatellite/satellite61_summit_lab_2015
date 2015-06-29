#! /bin/bash

# this is step where we expect to have an already installed satellite 6 and create the configuration for all further steps, the main org and subscriptions

# TODO short desc and outcome of this step

DIR="$PWD"
source "${DIR}/common.sh"

# check if organization already exists. if yes, exit
hammer organization info --name "$ORG" >/dev/null 2>&1 
if [ $? -ne 70 ]; then
  echo "Organization $ORG already exists. Exit."
  exit 1
fi

# Setup discovery
DISCOVERY_TEMPLATE_FILE="/var/lib/tftpboot/pxelinux.cfg/default"
cat > ${DISCOVERY_TEMPLATE_FILE} <<EOF
LABEL discovery
MENU LABEL Foreman Discovery
MENU DEFAULT
KERNEL boot/fdi-image-rhel_7-vmlinuz
APPEND initrd=boot/fdi-image-rhel_7-img rootflags=loop root=live:/fdi.iso rootfstype=auto ro rd.live.image acpi=force rd.luks=0 rd.md=0 rd.dm=0 rd.lvm=0 rd.bootif=0 rd.neednet=0 nomodeset proxy.url=https://${SATELLITE_SERVER}:9090 proxy.type=proxy
IPAPPEND 2

DEFAULT discovery
EOF

hammer template update --name "PXELinux global default" --file ${DISCOVERY_TEMPLATE_FILE}

# make sure discovered hosts are defaulting to our ORG
foreman-rake config -- --key discovery_organization --value "\'${ORG}\'"

# create org
hammer organization create --name "$ORG" --label "$ORG_LABEL" --description "$ORG_DESCRIPTION"

if [ -f $subscription_manifest_loc ]; then
  # upload manifest
  hammer subscription upload --organization "$ORG" --file "$subscription_manifest_loc"
else
  echo "please upload your manifest to the Satellite Server and specify the location in $HOME/.soe-config"
  exit 1
fi

# note: has worked for me only at the second try, so maybe we should check if successful before proceeding:
hammer subscription list --organization "$ORG" | ( grep -q 'Red Hat' && echo ok ) || ( echo "Subscription import has not been successful. Exit"; exit 1 )

TMPIFS=$IFS
IFS=","
# create location
for LOC in ${LOCATIONS}
do
  hammer location create --name "${LOC}"
  hammer location add-organization --name "${LOC}" --organization "${ORG}"
done
IFS=$TMPIFS

# Setup the compute resource to local libvirt.
hammer compute-resource create --name lab-host --set-console-password false --description "local libvirt connection" --url "qemu+tcp://lab-host:16509/system" --provider libvirt --organizations "$ORG" --locations "$LOCATIONS"

# create the generic lifecycle env path
hammer lifecycle-environment create --organization "$ORG" --name "QA" --description "Quality Assurance" --prior "Library"
hammer lifecycle-environment create --organization "$ORG" --name "STAGE" --description "Staging" --prior "QA"
hammer lifecycle-environment create --organization "$ORG" --name "PROD" --description "Production" --prior "STAGE"

# Load up some puppet modules
hammer product create --name='Puppet' --organization="$ORG"
hammer repository create --name='Puppet Modules' --organization="$ORG" --product='Puppet' --content-type='puppet'

for module in $(ls ./puppet-summit/*gz)
do
  echo "Pushing example module $module into our puppet repo"
  hammer -v repository upload-content --organization "$ORG" --product Puppet --name "Puppet Modules" --path $module
done


# Pull down the RH content
hammer repository-set enable --organization "$ORG" --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='7Server' --name 'Red Hat Enterprise Linux 7 Server (Kickstart)'
hammer repository-set enable --organization "$ORG" --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='7Server' --name 'Red Hat Enterprise Linux 7 Server (RPMs)'
hammer repository-set enable --organization "$ORG" --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='7Server' --name 'Red Hat Enterprise Linux 7 Server - Extras (RPMs)'
hammer repository-set enable --organization "$ORG" --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='7Server' --name 'Red Hat Enterprise Linux 7 Server - Optional (RPMs)'
hammer product synchronize --organization "$ORG" --name  'Red Hat Enterprise Linux Server' 

# Add in the latest Sat Tools
hammer product create --name "SatTools" --organization "$ORG"
hammer repository create --name "RHEL7Tools" --organization "$ORG" --product "SatTools" --content-type 'yum' --url="http://sat-perf-02.idm.lab.bos.redhat.com/pulp/repos/Engineering/TEST/Satellite_Tools_RHEL7/custom/Red_Hat_Satellite_INTERNAL/RHEL7_sattools_x86_64_os/" --publish-via-http="true"
hammer product synchronize --organization "$ORG" --name "SatTools"

# Create a content view 
hammer content-view create --name "RHEL 7 SOE" --description "Standard Operating Environment for RHEL7" --organization "$ORG"
hammer content-view add-repository --organization "$ORG" --repository 'Red Hat Enterprise Linux 7 Server Kickstart x86_64 7Server' --name "RHEL 7 SOE" --product "Red Hat Enterprise Linux Server"
hammer content-view add-repository --organization "$ORG" --repository 'Red Hat Enterprise Linux 7 Server RPMs x86_64 7Server' --name "RHEL 7 SOE" --product "Red Hat Enterprise Linux Server"
hammer content-view add-repository --organization "$ORG" --repository 'Red Hat Enterprise Linux 7 Server - Extras RPMs x86_64 7Server' --name "RHEL 7 SOE" --product "Red Hat Enterprise Linux Server"
hammer content-view add-repository --organization "$ORG" --repository 'Red Hat Enterprise Linux 7 Server - Optional RPMs x86_64 7Server' --name "RHEL 7 SOE" --product "Red Hat Enterprise Linux Server"
hammer content-view add-repository --organization "$ORG" --repository 'RHEL7Tools' --name "RHEL 7 SOE" --product "SatTools"
hammer content-view puppet-module add --organization "$ORG" --content-view "RHEL 7 SOE" --name "motd"

# Create a filter
hammer content-view filter create --name="April 1" --organization "$ORG" --content-view "RHEL 7 SOE" --type="erratum"
hammer content-view filter rule create --organization "$ORG" --content-view-filter "April 1" --content-view "RHEL 7 SOE" --start-date "2015-04-01"

# Create a new version
hammer content-view publish --name "RHEL 7 SOE" --organization "$ORG" 

# Promote it to  QA, STAGE, PROD
hammer content-view version promote --organization "$ORG" --content-view "RHEL 7 SOE" --to-lifecycle-environment "QA"
hammer content-view version promote --organization "$ORG" --content-view "RHEL 7 SOE" --to-lifecycle-environment "STAGE"
hammer content-view version promote --organization "$ORG" --content-view "RHEL 7 SOE" --to-lifecycle-environment "PROD"

# Now Delete the filter so that the Demo can promote the errata
hammer content-view filter delete --name="April 1" --organization "$ORG" --content-view "RHEL 7 SOE"

# Populate some docker data
# create a container product
hammer product create --name='containers' --organization="$ORG"
hammer repository create --name='rhel' --organization="$ORG" --product='containers' --content-type='docker' --url='https://registry.access.redhat.com' --docker-upstream-name='rhel' --publish-via-http="true"
#hammer repository create --name='wordpress' --organization="$ORG" --product='containers' --content-type='docker' --url='https://registry.hub.docker.com' --docker-upstream-name='wordpress' --publish-via-http="true"
#hammer repository create --name='mysql' --organization="$ORG" --product='containers' --content-type='docker' --url='https://registry.hub.docker.com' --docker-upstream-name='mysql' --publish-via-http="true"

# Sync the images
hammer product synchronize --organization "$ORG" --name "containers"

hammer content-view create --name "registry" --description "Sample Registry" --organization "$ORG"
hammer content-view add-repository --organization "$ORG" --name "registry" --repository "rhel" --product "containers"
#hammer content-view add-repository --organization "$ORG" --name "registry" --repository "mysql" --product "containers"
#hammer content-view add-repository --organization "$ORG" --name "registry" --repository "wordpress" --product "containers"

hammer content-view publish --organization "$ORG" --name "registry" 

# Create an activtion-key
hammer activation-key create --name 'ak-rhel-7' --content-view='RHEL 7 SOE' --lifecycle-environment='QA' --organization="Summit 2015"

# Configure the OS
hammer os add-ptable --title "RedHat 7.1" --partition-table "Kickstart default"
hammer template add-operatingsystem --name "Satellite Kickstart Default" --operatingsystem "RedHat 7.1"
hammer template add-operatingsystem --name "Satellite Kickstart Default Finish" --operatingsystem "RedHat 7.1"
hammer template add-operatingsystem --name "Satellite Kickstart Default User Data" --operatingsystem "RedHat 7.1"
hammer template add-operatingsystem --name "Kickstart default iPXE" --operatingsystem "RedHat 7.1"
hammer template add-operatingsystem --name "Kickstart default PXELinux" --operatingsystem "RedHat 7.1"

$TEMPLATE_ID=$(hammer --csv template list --search 'name = "Kickstart default PXELinux"'|tail -1 |awk -F, '{print $1}')
$OS_ID=$(hammer --csv os list --search 'name = RedHat 7.1'|tail -1 |awk -F, '{print $1}')
hammer os set-default-template --id $OS_ID --config-template-id $TEMPLATE_ID

# Configure networks
hammer domain update --name "summit-lab.redhat.com" --locations "$LOCATIONS" --organizations "$ORG" --dns "satellite61.summit-lab.redhat.com"
hammer subnet create --name "lab network" --network "192.168.150.0" --mask "255.255.255.0" \
  --gateway "192.168.150.254" --organizations "$ORG" --locations "$LOCATIONS" \
  --from "192.168.150.20" --to "192.168.150.30" --domains "summit-lab.redhat.com" \
  --boot-mode "DHCP" --ipam "DHCP" --dhcp-id 1 --dns-id 1 --tftp-id 1

# Puppet config
hammer environment update --name "KT_Summit_2015_QA_RHEL_7_SOE_3" --locations "$LOCATIONS"

# Create the Hostgroup we need to use
hammer hostgroup create --name "RHEL 7 SOE" --organizations "$ORG" --locations "$LOCATIONS" --architecture "x86_64" --content-view "RHEL 7 SOE" --environment "KT_Summit_2015_QA_RHEL_7_SOE_3" --medium "Summit_2015/Library/Red_Hat_Server/Red_Hat_Enterprise_Linux_7_Server_Kickstart_x86_64_7Server" --operatingsystem "RedHat 7.1" --puppet-classes "motd" --puppet-ca-proxy "satellite61.summit-lab.redhat.com" --puppet-proxy "satellite61.summit-lab.redhat.com" --content-source-id 1 --lifecycle-environment "QA" --partition-table "Kickstart default"