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
sed -i 's/set wireless.radio${devidx}.disabled=1/set wireless.radio${devidx}.disabled=0/g' ./package/kernel/mac80211/files/lib/wifi/mac80211.sh

# Modify default frpc-upx
sed -i 's/PKG_SOURCE_DATE:=.*/PKG_SOURCE_DATE:=2021-04-23/g' ./package/openwrt-upx/upx/Makefile
sed -i 's/PKG_SOURCE_VERSION:=.*/PKG_SOURCE_VERSION:=2dae2a39972bc7c562dd3b02444336050a0b242e/g' ./package/openwrt-upx/upx/Makefile
frp_version=$(curl -fs --max-time 10 "https://api.github.com/repos/fatedier/frp/releases/latest" | jq -r '.tag_name' | sed 's/v//')
frp_hash=$(curl https://codeload.github.com/fatedier/frp/tar.gz/v$frp_version | sha256sum | awk '{print $1}')
sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$frp_version/g" ./feeds/packages/net/frp/Makefile
sed -i "s/PKG_HASH:=.*/PKG_HASH:=$frp_hash/g" ./feeds/packages/net/frp/Makefile
sed -i 's/PKG_BUILD_DEPENDS:=golang\/host/PKG_BUILD_DEPENDS:=golang\/host upx\/host/g' ./feeds/packages/net/frp/Makefile
sed -i '21 i GO_PKG_LDFLAGS:=-s -w' ./feeds/packages/net/frp/Makefile
sed -i '43 i define Build/Compile\n\t$(call GoPackage/Build/Compile)\n\t$(STAGING_DIR_HOST)/bin/upx --lzma --best $(GO_PKG_BUILD_BIN_DIR)/frpc\nendef\n' ./feeds/packages/net/frp/Makefile

# Modify default ttyd
sed -i 's/services/system/g' ./feeds/luci/applications/luci-app-ttyd/root/usr/share/luci/menu.d/luci-app-ttyd.json

# # Modify default netdata
# sed -i 's/\.\.\/\.\.\/luci\.mk/$(TOPDIR)\/feeds\/luci\/luci\.mk/g' ./package/luci-app-netdata/Makefile

# Modify default zerotier
sed -i '24d' ./package/luci-app-zerotier/luasrc/model/cbi/zerotier/manual.lua

# Modify default mosdns
mosdns_version=$(curl -fs --max-time 10 "https://api.github.com/repos/IrineSistiana/mosdns/releases/latest" | jq -r '.tag_name' | sed 's/v//')
mosdns_hash=$(curl https://codeload.github.com/IrineSistiana/mosdns/tar.gz/v$mosdns_version | sha256sum | awk '{print $1}')
sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$mosdns_version/g" ./package/mosdns/Makefile
sed -i "s/PKG_HASH:=.*/PKG_HASH:=$mosdns_hash/g" ./package/mosdns/Makefile
sed -i 's/PKG_BUILD_DEPENDS:=golang\/host/PKG_BUILD_DEPENDS:=golang\/host upx\/host/g' ./package/mosdns/Makefile
sed -i '22 i GO_PKG_LDFLAGS:=-s -w' ./package/mosdns/Makefile
sed -i '50 i define Build/Compile\n\t$$(call GoPackage/Build/Compile)\n\t$$(STAGING_DIR_HOST)/bin/upx --lzma --best $$(GO_PKG_BUILD_BIN_DIR)/mosdns\nendef\n' ./package/mosdns/Makefile
sed -i 's/\.\.\/\.\./$(TOPDIR)\/feeds\/packages/g' ./package/mosdns/Makefile
cat > ./package/mosdns/files/config.yaml << \EOF
log:
  level: warn
  file: ''

data_providers:
  - tag: 'geosite'
    file: /tmp/etc/openclash/GeoSite.dat
    auto_reload: true

plugins:
  - tag: 'modify_ttl'
    type: ttl
    args:
      minimal_ttl: 300
      maximum_ttl: 3600

  - tag: 'forward_dns'
    type: fast_forward
    args:
      upstream:
        - addr: 223.5.5.5
        - addr: 119.29.29.29
        - addr: 114.114.114.114

  - tag: 'forward_doh'
    type: fast_forward
    args:
      upstream:
        - addr: https://223.5.5.5/dns-query
          enable_http3: true
          trusted: true
        - addr: https://223.6.6.6/dns-query
          enable_http3: true
          trusted: true

  - tag: 'forward_remote'
    type: fast_forward
    args:
      upstream:
        - addr: https://dns.google/dns-query
          dial_addr: 8.8.8.8
          enable_http3: true
          trusted: true
        - addr: https://cloudflare-dns.com/dns-query
          dial_addr: 1.1.1.1
          enable_http3: true
          trusted: true

  - tag: 'query_is_local_domain'
    type: query_matcher
    args:
      domain:
        - provider:geosite:cn

  - tag: 'query_is_non_local_domain'
    type: query_matcher
    args:
      domain:
        - provider:geosite:geolocation-!cn

  - tag: 'query_is_ad_domain'
    type: query_matcher
    args:
      domain:
        - provider:geosite:category-ads-all

  - tag: 'query_is_private'
    type: query_matcher
    args:
      domain:
        - provider:geosite:private

  - tag: 'query_is_vps_domain'
    type: query_matcher
    args:
      domain:
        - regexp:.+\.e?[udx]domain\.ml$

  - tag: 'main_sequence'
    type: sequence
    args:
      exec:
        - _misc_optm
        - _default_cache

        - if: 'query_is_ad_domain'
          exec:
            - _new_nxdomain_response
            - _return

        - if: 'query_is_local_domain'
          exec:
            - _prefer_ipv6
            - forward_dns
            - _return

        - if: 'query_is_vps_domain'
          exec:
            - primary:
                - _prefer_ipv6
                - forward_remote
                - _return
              secondary:
                - _prefer_ipv6
                - forward_dns
                - _return
              fast_fallback: 150

        - if: 'query_is_non_local_domain'
          exec:
            - _prefer_ipv4
            - forward_remote
            - _return

        - primary:
            - forward_doh
            - if: 'query_is_private'
              exec:
                - _drop_response
          secondary:
            - _prefer_ipv4
            - forward_remote
          fast_fallback: 50

        - modify_ttl

servers:
  - exec: 'main_sequence'
    listeners:
      - protocol: udp
        addr: 127.0.0.1:5353
      - protocol: tcp
        addr: 127.0.0.1:5353
EOF