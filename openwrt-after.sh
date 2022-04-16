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
sed -i 's/192.168.1.1/10.0.0.1/g' package/base-files/files/bin/config_generate
# Modify default NAME
sed -i 's/ImmortalWrt/OpenWrt/g' package/base-files/files/bin/config_generate
# Modify default frpc-upx
cat > ./feeds/packages/frpc-upx << "EOF"
diff --git a/net/frp/Makefile b/net/frp/Makefile
index 0ea29e3..9df7180 100644
--- a/net/frp/Makefile
+++ b/net/frp/Makefile
@@ -12,6 +12,8 @@ PKG_MAINTAINER:=Richard Yu <yurichard3839@gmail.com>
 PKG_LICENSE:=Apache-2.0
 PKG_LICENSE_FILES:=LICENSE
 
+PKG_CONFIG_DEPENDS:=CONFIG_FRPC_COMPRESS_UPX
+
 PKG_BUILD_DEPENDS:=golang/host
 PKG_BUILD_PARALLEL:=1
 PKG_USE_MIPS16:=0
@@ -22,8 +24,17 @@ GO_PKG_BUILD_PKG:=github.com/fatedier/frp/cmd/...
 include $(INCLUDE_DIR)/package.mk
 include ../../lang/golang/golang-package.mk
 
+define Package/frp/config
+config FRPC_COMPRESS_UPX
+	bool "Compress executable files with UPX"
+	default n
+endef
+
 define Package/frp/install
 	$(call GoPackage/Package/Install/Bin,$(PKG_INSTALL_DIR))
+ifneq ($(CONFIG_FRPC_COMPRESS_UPX),)
+	$(STAGING_DIR_HOST)/bin/upx --lzma --best $(GO_PKG_BUILD_BIN_DIR)/frpc
+endif
 
 	$(INSTALL_DIR) $(1)/usr/bin/
 	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/$(2) $(1)/usr/bin/
EOF
cd ./feeds/packages && git apply frpc-upx && cd ../..
# Modify default OPENCLASH
rm -rf ./feeds/luci/applications/luci-app-openclash/*
cd ./feeds/luci/applications/luci-app-openclash
git init
git remote add -f origin https://github.com/vernesong/OpenClash.git
git config core.sparsecheckout true
echo "luci-app-openclash" >> .git/info/sparse-checkout
git pull --depth 1 origin master
git branch --set-upstream-to=origin/master master
