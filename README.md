# StarShip

StarShip is a tool and process for ``cloud-config`` templating.

TL;DR: Main feature - replace ${VARIABLES} in a file based on an environment, secondary feature - package cloud-config nicely for distribution, tetiary feature - cloud-config "directories" with drop-ins

This allows you to bring up a CoreOS host and query metadata services (ANY metadata service - OpenStack, DO API, AWS - even your OWN custom metadata) before building/adding the host to the cluster. StarShip can wait for the public/private IP or even volume storage to be attached before downloading the template and initializing the node.

Once the metadata is gathered and preconditions satisfied, it replaces your chosen variables within a ``cloud-config`` template and initializes the system how you want.

Note: As of this current version, un-set variables are ignored - essentially placing them in a different namespace. Namespacing has not been a problem - however if you include Bash scripts in your write_files statements you must be careful. You can use the variables to make replacements in your script before it's written - however - if your script itself uses a variable with the same name, it will again, get replaced in the written script and will not be evaluated at runtime. We may decide to prefix variables with a %-sign in the future to avoid any confusion.

## Usage

```sh
#-bash#0 06:46:34|root@web:~/starship# bin/starship help
Running: bin/starship help

Shaped StarShip v0.01a
Usage: bin/starship command [options]

Available Commands: (parameters in square brackets are optional, while in parenthesis are required)

process  (template) [output] [env]    Generates a .starship file from a template directory.
combine  (template) [output]          Combines files in your template directroy into a yaml file.
package  (template) [output]          Packages a template for distribution (does not process).
explode  (template) [output]          Unpackages a packaged template.
validate (template)                   Combines if needed, processes and validates a template with coreos-cloudinit.
help     [command]                    Print full help, or help for specific command.

Command Options:

process (template) [output] [env]     Processes a template for use with coreos-cloudinit and replaces variables
                                      defined in your cloud-config template with ones in your system environment,
                                      or the one provided with the optional [env]. You can pass any type of template
                                      and starship will autodetect and work with it and yo

  (template)                          The location of your template, can be URL or local file/directory.
  [output]                            The output file to use. Must be a writable file path. You also can set
  [environment]                       An environment/script file to use - otherwise will use current environment.

combine (template) (output)           Combine files in a template directory into a single yaml file.
  (template)                          The location of your template, can be URL or local file/directory.
  (output)                            The output file for the yaml cloud-config template.

package (template) (output)           Create a starship package for distribution.
  (template)                          The location of your template directory.
  (output)                            The output file for the binary starship file.

explode (template) (output)           Unpacks a starship package.
  (template)                          The location of the packed template.
  (output)                            The output directory (will be created if does not exist).

validate (template)                   Process and validate a template with coreos-cloudinit - does not save template.
  (template)                          The location of your template, can be URL or local file/directory.
```

## FAQ:

Q. How does it work?

A. The best help is in the app. We can sum it up in 4 steps:

1. It uses a "bootstrap" cloud-config to load the tool and your metadata script. There's an example metadata (geared towards OpenStack) script at ``examples/metadata.sh`` - use this as your reference.

2. The metadata script simply waits for IP addresses to be attached, then populates the environment with $PUBLIC_IPV4, $PRIVATE_IPV4 and the hostname (instance name) you entered in when launching the unit {at your cloud provider | with nova}
Note: That, like a lot of tools like this (one favorite, <a href="https://github.com/zettio/weave">weave</a> for example) are installed with systemd units that require internet access. There are obviously other ways to get the tool on the host, if you require private-only networking but that is an excersize left to the reader.

3. Once the environment is set, the ``starship`` binary is called and it will pull your cloud-config template (yml or package) from either a URL (git or otherwise) or a file (provided by write_files, thus the original cloud-config) 

4. Once that's done, the boot-strap cloud config will continue (uses systemd units) loading another unit which runs ``coreos-cloudinit`` with the new file.

Q. What's a "template directory"?

A. Here's the structure of an example template directory. All the files in this directory are SIMPLY concatenated (will be properly yaml processed in the golang version, thus you have to keep your indenting proper in separate files). It's not even 100% tested.

In the next version - it will compile a YAML file for you properly with proper spacing and will also substitute any write_files for BASE64 encoding (can enable/disable this for ASCII files, always on for binaries obviously).

```
./                                      - template directory
./cloud-config.yml                      - main file (optional, contains #cloud-config header but would be added if doesn’t exist)
./hostname.yml                          - the hostname: section
./ssh_authorized_keys.yml               - the ssh_authorized_keys: section
./coreos.yml                            - the coreos: section, alternatively can use a drop in dir as below:
./coreos.d/                             - drop-ins for coreos: section
./coreos.d/etcd.yml                     - etcd: section
./coreos.d/fleet.yml                    - fleet: section
./coreos.d/units.d/                     - drop-ins for units: section
./coreos.d/units.d/docker.network.yml   - unit for docker network
./coreos.d/units.d/docker.service.yml   - unit for docker service
./coreos.d/units.d/docker.service.d/*   - drop-ins for docker service
./write_files.yml                       - any files you dont want to put as drop ins
./write_files.d/                        - drop in files for write_files directive
./write_files.d/etc/hosts               - an example drop in file
```

Q. Why should I use this?

A. You probably shouldn't! Maybe if you have a complex cloud config and would rather manage it as a directory of files than a single file but.. Really, if you can find a better way to do what you're trying to do, do it. This arose out of some issues with ``coreos-cloudinit`` mainly 205, 325. 325 even shows a way to stuff variables into etcd and fleetd leveraging systemd for variable substitution instead.

## History

CoreOS is awesome. Fleet is awesome. Containers are awesome. ``cloud-config``'s are awesome.

Setting it all up and managing it all, isn't as awesome.

## Use Case

For example, we want to spin up 3 nodes for a new CoreOS cluster. The fleet metadata is different for each node.

What are we supposed to do? Change the ``cloud-config`` for each system? Most providers allow you to use the ${public,private}_ipv{4,6} variables to specify IPs and this helps - but in my experience, it doesn't always work everywhere. One I used provider for example, only allows attaching of floating IPs after node creation. This means $public_ipv4 is never set when the cloud-config is parsed. Not good!

What if we wanted to create/use other variables? What if we just wanted our cloud-config to be a template?

#### One Way

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

Wait. Couldn't you kick the fleet and etcd stuff over into drop-in units inside the cloud-config and have systemd handle the substitution?

YEP! You could. Definitely, and you probably should. However. I personally think that this results in a more readable cloud-config in the end - plus you can do substitutions ANYWHERE not just as parameters to commands - maybe that's useful to you.

#### Our Way

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
Copyright 2015 Jai Boudreault / Shaped.ca

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

### Copyright
(C) 2015 Jai Boudreault / Shaped.ca - All Rights Reserved
