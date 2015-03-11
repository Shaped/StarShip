#!/bin/bash
###############################################################
## starship (C) 2015 Jai Boudreault - see LICENSE.md         ##
## main application file                                     ##
## Description: starship is a cloud-config templating system ##
## Documentation: http://starship.shaped.ca -or- README.md   ##
###############################################################

ENV=/env/environment

# Test for RW access to $1
touch $ENV
if [ $? -ne 0 ]; then
    echo exiting, unable to modify: $ENV
    exit 1
fi        

# Setup environment for coreos-cloudinit
sed -i -e '/^COREOS_PUBLIC_IPV4=/d' \
    -e '/^COREOS_PRIVATE_IPV4=/d' \
    "${ENV}"

function wait_pub_ip () {
  while [ 1 ]; do
     _out=$(curl -s 169.254.169.254/latest/meta-data/public-ipv4)
     if [ -z "$_out" ]; then
       sleep 1
     else
       echo $_out
       exit
     fi
  done
}

# Echo results of IP queries to environment file as soon as network interfaces 
# get assigned IPs
echo getting private ipv4 from metadata..

export private_ipv4=$(curl -s 169.254.169.254/latest/meta-data/local-ipv4)
export PRIVATE_IPV4=\$private_ipv4
echo COREOS_PRIVATE_IPV4=\$private_ipv4 >> $ENV # Also assigned to same IP

echo getting public-facing ipv4 from metadata..

export public_ipv4=$(wait_pub_ip)
export PUBLIC_IPV4=\$public_ipv4
echo COREOS_PUBLIC_IPV4=\$public_ipv4 >> $ENV #eno1 should be changed to your device name

export HOSTNAME=$(curl -s 169.254.169.254/latest/meta-data/hostname | awk '{ print substr($1, 0, length($1)-10); }')

NENV="/etc/${HOSTNAME}.env"

echo "#!/bin/bash" > $NENV
cat $ENV >> $NENV

echo HOSTNAME=$HOSTNAME >> $NENV;

export HOST=$(echo $HOSTNAME | cut -d. -f1); echo HOST=$HOST >> $NENV;
export DOMAIN=$(echo $HOSTNAME | rev | cut -d. -f-2 | rev); echo DOMAIN=$DOMAIN >> $NENV;   
export CLUSTER='dev001' ; echo CLUSTER=$CLUSTER >> $NENV;
export DISCOVERY=$(curl -s http://shaped.ca/coreos/$CLUSTER.discovery); echo DISCOVERY=$DISCOVERY >> $NENV;
export INSTANCE_TYPE=$(curl -s 169.254.169.254/latest/meta-data/instance-type); echo INSTANCE_TYPE=$INSTANCE_TYPE >> $NENV;
export INSTANCE_ID=$(curl -s 169.254.169.254/latest/meta-data/instance-id); echo INSTANCE_ID=$INSTANCE_ID >> $NENV;
export PROCESSORS=$(nproc); echo PROCESSORS=$PROCESSORS >> $NENV;
export MEMORY=$(expr $(free -h --si|awk '/^Mem:/{print $2}' | cut -d '.' -f 1) \* 1024); echo MEMORY=$MEMORY >> $NENV;
export INTERNAL_STORAGE=$(expr $(blockdev --getsize64 /dev/vda) / 1024 / 1024 / 1024); echo INTERNAL_STORAGE=$INTERNAL_STORAGE >> $NENV;
export INTERNAL_STORAGE_TYPE=SSD; echo INTERNAL_STORAGE_TYPE=$INTERNAL_STORAGE_TYPE >> $NENV;
export BANDWIDTH_LIMIT=0; echo BANDWIDTH_LIMIT=$BANDWIDTH_LIMIT >> $NENV;
export BANDWIDTH_THROUGHPUT=100; echo BANDWIDTH_THROUGHPUT=$BANDWIDTH_THROUGHPUT >> $NENV;
export BLOCK_STORAGE_SIZE=10; echo BLOCK_STORAGE_SIZE=$BLOCK_STORAGE_SIZE >> $NENV;
export BLOCK_STORAGE_TYPE=attached; echo BLOCK_STORAGE_TYPE=$BLOCK_STORAGE_TYPE >> $NENV;
export PROVIDER=auro.io; echo PROVIDER=$PROVIDER >> $NENV;
export REGION=ca-west; echo REGION=$REGION >> $NENV;
export AVAILABILITY_ZONE=$(curl -s 169.254.169.254/2009-04-04/meta-data/placement/availability-zone); echo AVAILABILITY_ZONE=$AVAILABILITY_ZONE >> $NENV;
export ROLE=central; echo ROLE=$ROLE >> $NENV;

ln -s $NENV /etc/node-environment

echo Fetching real cloud-config..
curl -s $CLOUD_CONFIG_TEMPLATE_URL > /opt/cloud-config.yml

replace_regex='\$\{([a-zA-Z_][a-zA-Z_0-9]*)\}'

x=0
while IFS='' read -r line; do
    let x=x+1
    while [[ "$line" =~ $replace_regex ]]; do
        param="${BASH_REMATCH[1]}"
        if [ -z ${!param+x} ]; then
          echo "line: $x not substituting an unset variable $param"
          break
        else
          line=${line//${BASH_REMATCH[0]}/${!param}}
        fi
    done
    printf "%s\n" "$line" >> /opt/new-cloud-config.yml
done < /opt/cloud-config.yml
mv /opt/cloud-config.yml /opt/cloud-config.yml.template
mv /opt/new-cloud-config.yml /opt/cloud-config.yml

## END ##
