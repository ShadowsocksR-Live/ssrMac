ShadowsocksR client for macOS
===========================
[![Build Status](https://travis-ci.org/shadowsocks/shadowsocks-iOS.svg?branch=master)](https://travis-ci.org/shadowsocks/shadowsocks-iOS)

**ssrMac已開發完畢.由於用蘋果開發者帳號簽名軟件,形同直接洩漏開發者全部信息給中共,希望哪個中國大陸以外的蘋果開發者幫忙編譯後封包發送到電郵地址 ssrlivebox(at)gmail(dot)com 不勝感激. 作者不想被中共及其走狗,自乾五,逮個正著並送進監獄.**

![tu](server-settings.png)

macOS
-----
[![OSX Icon](https://raw.githubusercontent.com/ShadowsocksR-Live/ssrMac/master/osx_128.png)](https://github.com/shadowsocks/shadowsocks-iOS/wiki/Shadowsocks-for-OSX-Help)  
[OSX Version](https://github.com/shadowsocks/shadowsocks-iOS/wiki/Shadowsocks-for-OSX-Help)


Build from source code
-----
**Dependencies**:
 * **Sodium** [Installation](https://download.libsodium.org/doc/installation/index.html)
 * **mbedTLS** [Installation](https://github.com/ARMmbed/mbedtls#cmake)
 * **libuv** [Installation](https://github.com/libuv/libuv#build-instructions)

Then pull **source code** and submodules
```bash
git clone https://github.com/ShadowsocksR-Live/ssrMac.git
cd ssrMac
git submodule update --init --recursive
git submodule foreach -q 'git checkout $(git config -f $toplevel/.gitmodules submodule.$name.branch || echo master)'
```


License
-------
The project is released under the terms of [GPLv3](https://raw.github.com/shadowsocks/shadowsocks-iOS/master/LICENSE).

Bugs and Issues
----------------

Please visit [issue tracker](https://github.com/ShadowsocksR-Live/ssrMac/issues?state=open)

Also see [troubleshooting](https://github.com/clowwindy/shadowsocks/wiki/Troubleshooting)
