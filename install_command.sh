katello-installer --foreman-admin-password changeme --capsule-tftp="true" --capsule-dhcp-interface="eth0" \
  --capsule-dns-interface="eth0" --capsule-tftp-servername="satellite61.summit-lab.redhat.com" --capsule-dns="true" \
  --capsule-puppet="true" --capsule-puppetca="true" --capsule-dhcp="true" --capsule-dns-forwarders="192.168.150.254" \
  --enable-foreman-plugin-discovery --capsule-dhcp-range "192.168.150.100 192.168.150.120" --capsule-dhcp-gateway "192.168.150.254" --capsule-dns-zone=summit-lab.redhat.com --capsule-dns-reverse=150.168.192.in-addr.arpa

# BZ1229125 and SCAP
yum -y install foreman-discovery-image ruby193-rubygem-foreman_openscap rubygem-smart_proxy_openscap.noarch
puppet module install isimluk-foreman_scap_client
