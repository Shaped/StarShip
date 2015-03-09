# StarShip

StarShip is a tool and process for ``cloud-config`` templating.

This allows you to bring up a CoreOS host and query metadata services (ANY metadata service - OpenStack, DO API, AWS - even your OWN custom metadata) before building/adding the host to the cluster. StarShip can wait for the public/private IP or even volume storage to be attached before downloading the template and initializing the node.

Once the metadata is gathered and preconditions satisfied, it replaces your chosen variables within a ``cloud-config`` template and initializes the system how you want.

Note: As of this current version, un-set variables are ignored - essentially placing them in a different namespace. Namespacing has not been a problem - however if you include Bash scripts in your write_files statements you must be careful. You can use the variables to make replacements in your script before it's written - however - if your script itself uses a variable with the same name, it will again, get replaced in the written script and will not be evaluated at runtime. We may decide to prefix variables with a %-sign in the future to avoid any confusion.

## History

CoreOS is awesome. Fleet is awesome. Containers are awesome. ``cloud-config``'s are awesome.

Setting it all up and managing it all, isn't as awesome.

## Use Case

For example, we want to spin up 3 nodes for a new CoreOS cluster. The fleet metadata is different for each node.

What are we supposed to do? Change the ``cloud-config`` for each system? Most providers allow you to use the ${public,private}_ipv{4,6} variables to specify IPs and this helps - but in my experience, it doesn't always work everywhere. One I used provider for example, only allows attaching of floating IPs after node creation. This means $public_ipv4 is never set when the cloud-config is parsed. Not good!

What if we wanted to create/use other variables? What if we just wanted our cloud-config to be a template?

#### The Old Way

Create and edit your ``cloud-config`` for Host 1
```yaml
coreos:
  fleet:
    public-ip: 100.150.100.150   # used for fleetctl ssh command
    metadata: bandwidth_limit=1000,bandwidth_throughput=1000,cpus=2,host=core-os0.mydomain.com,memory=4096,provider=myhost,region=ca-west,storage_size=20,role=central
write_files:
  - path: /etc/hosts
    permissions: 0644
    owner: root
    content: |
      127.0.0.1       localhost
      ::1             localhost
      100.150.100.150 coreos-0.mydomain.com 
      search mydomain.com
```

and launch, check to make sure it worked and you didn't break your cloud-config..

Then.. create and edit a ``cloud-config`` for Host 2

```yaml
coreos:
  fleet:
    public-ip: 100.150.100.151   # used for fleetctl ssh command
    metadata: bandwidth_limit=5000,bandwidth_throughput=10000,cpus=4,host=core-os1.mydomain.com,memory=16384,provider=myhost,region=ca-west,storage_size=200,role=central,role=compute
write_files:
  - path: /etc/hosts
    permissions: 0644
    owner: root
    content: |
      127.0.0.1       localhost
      ::1             localhost
      100.150.100.151 coreos-1.mydomain.com myself
      search mydomain.com
```

test again, and then

Create and edit a ``cloud-config`` for Host 3
```yaml
coreos:
  fleet:
    public-ip: 100.150.100.152   # used for fleetctl ssh command
    metadata: bandwidth_limit=1000,bandwidth_throughput=1000,cpus=2,host=core-os0.mydomain.com,memory=4096,provider=myhost,region=ca-west,storage_size=20,role=central
write_files:
  - path: /etc/hosts
    permissions: 0644
    owner: root
    content: |
      127.0.0.1       localhost
      ::1             localhost
      100.150.100.152 coreos-2.mydomain.com myself 
      search mydomain.com
```

That's 3 nodes and already it's not fun.

#### The StarShip Way

``cloud-config`` template for all hosts
```yaml
coreos:
 fleet:
    public-ip: ${PRIVATE_IPV4}   # used for fleetctl ssh command
    metadata: bandwidth_limit=${BANDWIDTH_LIMIT},bandwidth_throughput=${BANDWIDTH_THROUGHPUT},cpus=${PROCESSORS},host=${HOSTNAME},memory=${MEMORY},provider=${PROVIDER},region=${REGION},storage_size=${INTERNAL_STORAGE},storage_type=${INTERNAL_STORAGE_TYPE},role=${ROLE},block_storage_size=${BLOCK_STORAGE_SIZE},block_storage_type=${BLOCK_STORAGE_TYPE},private_ip=${PRIVATE_IPV4},public_ip=${PUBLIC_IPV4}
write_files:
  - path: /etc/hosts
    permissions: 0644
    owner: root
    content: |
      127.0.0.1       localhost
      ::1             localhost
      ${PUBLIC_IPV4} ${HOSTNAME}    
      search ${DOMAIN}
```

### Other Patterns

You might be wondering, what if I want to have a 3 or 5 node etcd cluster and the rest as worker machines: no problem!

Just create a template for the central nodes and another template for the worker nodes. 

## License
This is currently completely private software. See <a href="LICENSE.md">``LICENSE.md``</a>. We do plan on releasing this in the future with a different license, preferably Open Source.

### Copyright
StarShip is (C) 2015 Jason Boudreault / Shaped.ca - All Rights Reserved
