#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# Modify default IP
sed -i 's/192.168.1.1/10.0.0.1/g' ./package/base-files/files/bin/config_generate

# Modify default Wifiset
sed -i "s/set \${s}.disabled='\${defaults ? 0 : 1}'/set \${s}.disabled='0'/g" ./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc

# Modify default luci-theme-argon
curl -fsL https://raw.githubusercontent.com/bigdaddy-1/OpenWrt/master/bg1.jpg -o ./package/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg

# Modify default frpc-upx
# sed -i 's/PKG_SOURCE_DATE:=.*/PKG_SOURCE_DATE:=2021-04-23/g' ./package/openwrt-upx/upx/Makefile
# sed -i 's/PKG_SOURCE_VERSION:=.*/PKG_SOURCE_VERSION:=2dae2a39972bc7c562dd3b02444336050a0b242e/g' ./package/openwrt-upx/upx/Makefile
frp_version=$(curl -fsL 'https://api.github.com/repos/fatedier/frp/releases/latest' | jq -r '.tag_name' | sed 's/v//')
frp_hash=$(curl -fsL https://codeload.github.com/fatedier/frp/tar.gz/v$frp_version | sha256sum | awk '{print $1}')
sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$frp_version/g" ./feeds/packages/net/frp/Makefile
sed -i "s/PKG_HASH:=.*/PKG_HASH:=$frp_hash/g" ./feeds/packages/net/frp/Makefile
# sed -i 's/PKG_BUILD_DEPENDS:=golang\/host/PKG_BUILD_DEPENDS:=golang\/host upx\/host/g' ./feeds/packages/net/frp/Makefile
# sed -i '21 i GO_PKG_LDFLAGS:=-s -w' ./feeds/packages/net/frp/Makefile
# sed -i '43 i define Build/Compile\n\t$(call GoPackage/Build/Compile)\n\t$(STAGING_DIR_HOST)/bin/upx --lzma --best $(GO_PKG_BUILD_BIN_DIR)/frpc\nendef\n' ./feeds/packages/net/frp/Makefile

# Modify default ttyd
sed -i 's/services/system/g' ./feeds/luci/applications/luci-app-ttyd/root/usr/share/luci/menu.d/luci-app-ttyd.json
sed -i 's/START=99/START=98/g' ./feeds/packages/utils/ttyd/files/ttyd.init

# Modify default netdata
# netdata_version=$(curl -fsL 'https://api.github.com/repos/netdata/netdata/releases/latest' | jq -r '.tag_name' | sed 's/v//')
# netdata_hash=$(curl -fsL https://github.com/netdata/netdata/releases/download/v$netdata_version/netdata-v$netdata_version.tar.gz | sha256sum | awk '{print $1}')
# sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$netdata_version/g" ./feeds/packages/admin/netdata/Makefile
# sed -i "s/PKG_HASH:=.*/PKG_HASH:=$netdata_hash/g" ./feeds/packages/admin/netdata/Makefile
# sed -i 's/\.\.\/\.\.\/luci\.mk/$(TOPDIR)\/feeds\/luci\/luci\.mk/g' ./package/luci-app-netdata/Makefile

# Modify default zerotier
zerotier_version=$(curl -fsL 'https://api.github.com/repos/zerotier/ZeroTierOne/releases/latest' | jq -r '.tag_name' | sed 's/v//')
zerotier_hash=$(curl -fsL https://codeload.github.com/zerotier/ZeroTierOne/tar.gz/$zerotier_version | sha256sum | awk '{print $1}')
sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$zerotier_version/g" ./feeds/packages/net/zerotier/Makefile
sed -i "s/PKG_HASH:=.*/PKG_HASH:=$zerotier_hash/g" ./feeds/packages/net/zerotier/Makefile
sed -i 's/\.\.\/\.\./$(TOPDIR)\/feeds\/luci/g' ./package/luci-data/applications/luci-app-zerotier/Makefile

# Modify default sing-box
curl -LOs https://github.com/MetaCubeX/metacubexd/archive/gh-pages.zip
unzip -o gh-pages.zip -d ./package/sing-box/
singbox_prefor=$(curl -fsL 'https://api.github.com/repos/SagerNet/sing-box/releases' | jq -r 'map(select(.prerelease)) | first | .tag_name' | sed 's/v//')
singbox_latest=$(curl -fsL 'https://api.github.com/repos/SagerNet/sing-box/releases/latest' | jq -r '.tag_name' | sed 's/v//')
singbox_prefor_normalized=$(echo "$singbox_prefor" | sed 's/-.*//')
singbox_latest_normalized=$(echo "$singbox_latest" | sed 's/-.*//')
version1=( ${singbox_prefor_normalized//./ } )
version2=( ${singbox_latest_normalized//./ } )
for i in ${!version1[@]}; do
  if [[ -z "${version2[i]}" ]]; then
    version2[i]=0
  fi
  if (( ${version1[i]} > ${version2[i]} )); then
    singbox_version=$singbox_prefor
    apk_version=$singbox_prefor_normalized
    break
  elif (( ${version1[i]} < ${version2[i]} )); then
    singbox_version=$singbox_latest
    apk_version=$singbox_latest_normalized
    break
  fi
done
if [[ -z "$singbox_version" ]]; then
  singbox_version=$singbox_latest
  apk_version=$singbox_latest_normalized
fi
singbox_hash=$(curl -fsL https://codeload.github.com/SagerNet/sing-box/tar.gz/v$singbox_version | sha256sum | awk '{print $1}')
sed -i "s/PKG_VERSION:=.*/PKG_REAL_VERSION:=$singbox_version\nPKG_VERSION:=$apk_version/g" ./package/sing-box/Makefile
sed -i "s/PKG_HASH:=.*/PKG_HASH:=$singbox_hash\nPKG_BUILD_DIR:=\$(BUILD_DIR)\/sing-box-\$(PKG_REAL_VERSION)/g" ./package/sing-box/Makefile
sed -i 's/$(PKG_VERSION)/$(PKG_REAL_VERSION)/g' ./package/sing-box/Makefile
sed -i '/^define Package\/sing-box\/conffiles/,/^endef/d' ./package/sing-box/Makefile
sed -i '/^define Package\/sing-box\/install/,/^endef/d' ./package/sing-box/Makefile
sed -i '44 i define Package/sing-box/install\n\t$(call GoPackage/Package/Install/Bin,$(1))\n\t$(INSTALL_DIR) $(1)/etc/init.d\n\t$(INSTALL_BIN) $(PKG_BUILD_DIR)/scripts/openwrt/sing-box-init-openwrt $(1)/etc/init.d/sing-box\n\t$(INSTALL_DIR) $(1)/etc/sing-box\n\tcp -r ./metacubexd-gh-pages $(1)/etc/sing-box/ui\nendef' ./package/sing-box/Makefile
# sed -i 's/PKG_BUILD_DEPENDS:=golang\/host/PKG_BUILD_DEPENDS:=golang\/host upx\/host/g' ./package/sing-box/Makefile
# sed -i '38 i GO_PKG_LDFLAGS:=-s -w' ./package/sing-box/Makefile
# sed -i '60 i define Build/Compile\n\t$(call GoPackage/Build/Compile)\n\t$(STAGING_DIR_HOST)/bin/upx --lzma --best $(GO_PKG_BUILD_BIN_DIR)/sing-box\nendef' ./package/sing-box/Makefile
sed -i 's/\.\.\/\.\./$(TOPDIR)\/feeds\/packages/g' ./package/sing-box/Makefile
sed -i 's/$(PKG_BUILD_DIR)\/scripts\/openwrt\/sing-box-init-openwrt/$(TOPDIR)\/sing-box/g' ./package/sing-box/Makefile
sed -i "s/SURL/$SURL/g" ./sing-box

# Modify default mosdns
mosdns_prefor=$(curl -fsL 'https://api.github.com/repos/IrineSistiana/mosdns/releases' | jq -r 'map(select(.prerelease)) | first | .tag_name' | sed 's/v//')
mosdns_latest=$(curl -fsL 'https://api.github.com/repos/IrineSistiana/mosdns/releases/latest' | jq -r '.tag_name' | sed 's/v//')
mosdns_prefor_normalized=$(echo "$mosdns_prefor" | sed 's/-.*//')
mosdns_latest_normalized=$(echo "$mosdns_latest" | sed 's/-.*//')
version1=( ${mosdns_prefor_normalized//./ } )
version2=( ${mosdns_latest_normalized//./ } )
for i in ${!version1[@]}; do
  if [[ -z "${version2[i]}" ]]; then
    version2[i]=0
  fi
  if (( ${version1[i]} > ${version2[i]} )); then
    mosdns_version=$mosdns_prefor
    break
  elif (( ${version1[i]} < ${version2[i]} )); then
    mosdns_version=$mosdns_latest
    break
  fi
done
if [[ -z "$mosdns_version" ]]; then
  mosdns_version=$mosdns_latest
fi
mosdns_hash=$(curl -fsL https://codeload.github.com/IrineSistiana/mosdns/tar.gz/v$mosdns_version | sha256sum | awk '{print $1}')
sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$mosdns_version/g" ./package/mosdns/Makefile
sed -i "s/PKG_HASH:=.*/PKG_HASH:=$mosdns_hash/g" ./package/mosdns/Makefile
# sed -i 's/PKG_BUILD_DEPENDS:=golang\/host/PKG_BUILD_DEPENDS:=golang\/host upx\/host/g' ./package/mosdns/Makefile
# sed -i '23 i GO_PKG_LDFLAGS:=-s -w' ./package/mosdns/Makefile
# sed -i '41 i define Build/Compile\n\t$(call GoPackage/Build/Compile)\n\t$(STAGING_DIR_HOST)/bin/upx --lzma --best $(GO_PKG_BUILD_BIN_DIR)/mosdns\nendef' ./package/mosdns/Makefile
sed -i 's/\.\.\/\.\./$(TOPDIR)\/feeds\/packages/g' ./package/mosdns/Makefile
sed -i 's/$(PKG_BUILD_DIR)\/scripts\/openwrt\/mosdns-init-openwrt/$(TOPDIR)\/mosdns/g' ./package/mosdns/Makefile
sed -i "s/SURL2/$SURL2/g" ./mosdns
cat >./package/mosdns/files/config.yaml <<\EOF
log:
  level: error

api:
  http: 0.0.0.0:8088

plugins:
  - tag: 'CNIPS'
    type: ip_set
    args:
      files:
        - /tmp/cn.txt
        - /tmp/private.txt

  - tag: 'DIRECT'
    type: domain_set
    args:
      files:
        - /tmp/direct-list.txt
        - /tmp/apple-cn.txt

  - tag: 'PROXY'
    type: domain_set
    args:
      files:
        - /tmp/proxy-list.txt
        - /tmp/google-cn.txt

  - tag: 'cache'
    type: cache
    args:
      size: 10240

  - tag: 'lazycache'
    type: cache
    args:
      size: 1024
      lazy_cache_ttl: 86400

  - tag: 'hosts'
    type: hosts
    args:
      entries:
        - regexp:^[^.]+\.lan$ 10.1.1.10 10.1.1.11 10.1.1.12

  - tag: 'cndns'
    type: forward
    args:
      concurrent: 3
      upstreams:
        - tag: dns.2
          addr: 223.5.5.5
        - addr: 119.29.29.29
        - addr: 114.114.114.114

  - tag: 'dns'
    type: forward
    args:
      concurrent: 1
      upstreams:
        - tag: dns.8
          addr: udp://10.1.1.10

  - tag: 'doh'
    type: forward
    args:
      concurrent: 3
      upstreams:
        - addr: https://8.8.8.8/dns-query
          enable_http3: true
        - addr: https://8.8.4.4/dns-query
          enable_http3: true
        - addr: https://1.1.1.1/dns-query
          enable_http3: true
        - addr: https://1.0.0.1/dns-query
          enable_http3: true

  - tag: 'fallback'
    type: fallback
    args:
      primary: dns
      secondary: doh
      threshold: 300
      always_standby: true

  - tag: 'ecs'
    type: ecs_handler
    args:
      forward: true

  - tag: 'cnecs'
    type: ecs_handler
    args:
      send: true

  - tag: 'local'
    type: sequence
    args:
      - exec: $cnecs
      - exec: $cndns
      - exec: nftset inet,fw4,localnetwork,ipv4_addr,24 inet,fw4,localnetwork6,ipv6_addr,48

  - tag: 'remote'
    type: sequence
    args:
      - exec: $lazycache
      - matches: has_resp
        exec: accept
      - exec: $ecs
      - exec: $fallback
      - matches: resp_ip $CNIPS
        exec: goto local

  - tag: 'main'
    type: sequence
    args:
      - exec: $hosts
      - exec: ttl 1
      - exec: $cache
      - matches: has_resp
        exec: accept
      - matches: qname $PROXY
        exec: goto remote
      - matches: qname $DIRECT
        exec: goto local
      - exec: $fallback

  - type: udp_server
    args:
      entry: main
      listen: :5253
  - type: tcp_server
    args:
      entry: main
      listen: :5253
EOF
