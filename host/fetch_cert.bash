#! /bin/bash -x

# TODO: Make sure FF is not running!
URL='http://192.168.150.10/pub/katello-server-ca.crt'

certificateFile="katello-server-ca.crt"
certificateName="Satellite 6.1 LAB"

cd /tmp
wget -q $URL -O $certificateFile

certificateFile="/tmp/${certificateFile}"

for certDB in $(find  ~/.mozilla* ~/.thunderbird -name "cert8.db" 2>/dev/null)
do
  certDir=$(dirname ${certDB});
  certutil -A -n "${certificateName}" -t "TC,Cw,Tw" -i ${certificateFile} -d ${certDir}
  #certutil -A -n "${certificateName}" -t "TCu,Cuw,Tuw" -i ${certificateFile} -d ${certDir}
done
