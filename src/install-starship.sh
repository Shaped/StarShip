#!/bin/bash
###############################################################
## starship (C) 2015 Jai Boudreault - see LICENSE.md         ##
## starship installer                                        ##
## Description: starship is a cloud-config templating system ##
## Documentation: http://starship.shaped.ca -or- README.md   ##
###############################################################

echo Fetching \& installing the starship binary, please wait..

INSTALL_URL="https://raw.github.com/Shaped/Starship/master/bin/starship"

while [ ! -e /opt/bin/starship ]; do
 wget -q -N -P /opt/bin $INSTALL_URL && chmod +x /opt/bin/starship
 if [ ! -e /opt/bin/starship ]; then 
   echo Failed to install.. Retrying in 5 seconds.. ^C to quit.
   sleep 5
 else
   echo starship installed successfully to /opt/bin
 fi
done

## END ##
