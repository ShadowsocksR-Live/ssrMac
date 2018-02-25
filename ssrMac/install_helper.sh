#!/bin/sh

#  install_helper.sh
#  shadowsocks
#
#  Created by clowwindy on 14-3-15.

cd `dirname "${BASH_SOURCE[0]}"`
sudo mkdir -p "/Library/Application Support/ssrMac/"
sudo cp ssr_mac_sysconf "/Library/Application Support/ssrMac/"
sudo chown root:admin "/Library/Application Support/ssrMac/ssr_mac_sysconf"
sudo chmod +s "/Library/Application Support/ssrMac/ssr_mac_sysconf"

echo done
