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
#sed -i '21 i GO_PKG_LDFLAGS:=-s -w' ./feeds/packages/net/frp/Makefile
#sed -i 's/PKG_BUILD_DEPENDS:=golang\/host/PKG_BUILD_DEPENDS:=golang\/host upx\/host/g' ./feeds/packages/net/frp/Makefile
#sed -i '44 i define Build/Compile\n\t$(call GoPackage/Build/Compile)\n\t$(STAGING_DIR_HOST)/bin/upx --lzma --best $(GO_PKG_BUILD_BIN_DIR)/frpc\nendef\n' ./feeds/packages/net/frp/Makefile
mv ./feeds/packages/net/frp/files ./package/openwrt-frp/
rm -rf ./feeds/packages/net/frp
sed -i '34,66d' ./package/openwrt-frp/Makefile
sed -i '33 i \\ndefine Package/frp/install\n\t$(call GoPackage/Package/Install/Bin,$(PKG_INSTALL_DIR))\n\n\t$(INSTALL_DIR) $(1)/usr/bin/\n\t$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/$(2) $(1)/usr/bin/\n\t$(INSTALL_DIR) $(1)/etc/frp/$(2).d/\n\t$(INSTALL_DATA) $(PKG_BUILD_DIR)/conf/$(2)_full.ini $(1)/etc/frp/$(2).d/\n\t$(INSTALL_DIR) $(1)/etc/config/\n\t$(INSTALL_CONF) ./files/$(2).config $(1)/etc/config/$(2)\n\t$(INSTALL_DIR) $(1)/etc/init.d/\n\t$(INSTALL_BIN) ./files/$(2).init $(1)/etc/init.d/$(2)\n\n\tif [ -r ./files/$(2).uci-defaults ]; then \\\n\t\t$(INSTALL_DIR) $(1)/etc/uci-defaults; \\\n\t\t$(INSTALL_DATA) ./files/$(2).uci-defaults $(1)/etc/uci-defaults/$(2); \\\n\tfi\nendef\ndefine Build/Compile\n\t$$(call GoPackage/Build/Compile)\n\t$$(STAGING_DIR_HOST)/bin/upx --lzma --best $$(GO_PKG_BUILD_BIN_DIR)/frpc\nendef' ./package/openwrt-frp/Makefile
sed -i 's/PKG_BUILD_DEPENDS:=golang\/host/PKG_BUILD_DEPENDS:=golang\/host upx\/host/g' ./package/openwrt-frp/Makefile
#sed -i '44 i define Build/Compile\n\t$$(call GoPackage/Build/Compile)\n\t$$(STAGING_DIR_HOST)/bin/upx --lzma --best $$(GO_PKG_BUILD_BIN_DIR)/frpc\nendef\n' ./package/openwrt-frp/Makefile
cat >> ./package/openwrt-frp/Makefile << \EOF
define Package/frp/template
  define Package/$(1)
    SECTION:=net
    CATEGORY:=Network
    SUBMENU:=Web Servers/Proxies
    TITLE:=$(1) - fast reverse proxy $(2)
    URL:=https://github.com/fatedier/frp
    DEPENDS:=$(GO_ARCH_DEPENDS)
  endef

  define Package/$(1)/description
    $(1) is a fast reverse proxy $(2) to help you expose a local server behind
    a NAT or firewall to the internet.
  endef

  define Package/$(1)/conffiles
  /etc/config/$(1)
  endef

  define Package/$(1)/install
    $(call Package/frp/install,$$(1),$(1))
  endef
endef

$(eval $(call Package/frp/template,frpc,client))
$(eval $(call Package/frp/template,frps,server))
$(eval $(call BuildPackage,frpc))
$(eval $(call BuildPackage,frps))
EOF

# Modify default ttyd
sed -i 's/services/system/g' ./feeds/luci/applications/luci-app-ttyd/root/usr/share/luci/menu.d/luci-app-ttyd.json

# # Modify default netdata
# sed -i 's/\.\.\/\.\.\/luci\.mk/$(TOPDIR)\/feeds\/luci\/luci\.mk/g' ./package/luci-app-netdata/Makefile

# Modify default zerotier
sed -i '24d' ./package/luci-app-zerotier/luasrc/model/cbi/zerotier/manual.lua

# Modify default mosdns
mosdns_version=$(curl -fs --max-time 10 "https://api.github.com/repos/IrineSistiana/mosdns/releases/latest" | jq -r '.tag_name')
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
  - tag: geosite
    file: /tmp/geosite.dat
    auto_reload: true
  - tag: geoip
    file: /tmp/geoip.dat
    auto_reload: true

plugins:
  - tag: 'forward_local'
    type: fast_forward
    args:
      upstream:
        - addr: 223.5.5.5
        - addr: 119.29.29.29

  - tag: 'forward_remote'
    type: fast_forward
    args:
      upstream:
        - addr: 8.8.8.8
        - addr: 1.1.1.1

  - tag: query_is_local_domain
    type: query_matcher
    args:
      domain:
        - 'provider:geosite:cn'

  - tag: query_is_non_local_domain
    type: query_matcher
    args:
      domain:
        - 'provider:geosite:geolocation-!cn'
  - tag: query_is_ad_domain
    type: query_matcher
    args:
      domain:
        - 'provider:geosite:category-ads-all'

  - tag: response_has_local_ip
    type: response_matcher
    args:
      ip:
        - 'provider:geoip:cn'

  - tag: main_sequence
    type: sequence
    args:
      exec:
      - _single_flight
      - _misc_optm
        - if: 'query_is_ad_domain'
          exec:
            - _new_nxdomain_response
            - _return

        - if: 'query_is_local_domain'
          exec:
            - forward_local
            - _return

        - if: 'query_is_non_local_domain'
          exec:
            - forward_remote
            - _return

        - primary:
            - forward_local
            - if: '(! response_has_local_ip) && [_response_valid_answer]'
              exec:
                - _drop_response
          secondary:
            - _prefer_ipv4
            - forward_remote
          fast_fallback: 200

servers:
  - exec: main_sequence
    listeners:
      - protocol: udp
        addr: 127.0.0.1:5353
      - protocol: tcp
        addr: 127.0.0.1:5353
EOF