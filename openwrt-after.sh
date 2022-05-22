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
sed -i '21 i GO_PKG_LDFLAGS:=-s -w' ./feeds/packages/net/frp/Makefile
sed -i 's/PKG_BUILD_DEPENDS:=golang\/host/PKG_BUILD_DEPENDS:=golang\/host upx\/host/g' ./feeds/packages/net/frp/Makefile
sed -i '44 i define Build/Compile\n\t$(call GoPackage/Build/Compile)\n\t$(STAGING_DIR_HOST)/bin/upx --lzma --best $(GO_PKG_BUILD_BIN_DIR)/frpc\nendef\n' ./feeds/packages/net/frp/Makefile

# Modify default ttyd
sed -i 's/services/system/g' ./feeds/luci/applications/luci-app-ttyd/root/usr/share/luci/menu.d/luci-app-ttyd.json