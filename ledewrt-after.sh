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
#sed -i 's/ImmortalWrt/OpenWrt/g' package/base-files/files/bin/config_generate

# Modify default OPENCLASH
mkdir -p ./feeds/luci/applications/luci-updata
cd ./feeds/luci/applications/luci-updata
git init
git remote add -f origin https://github.com/vernesong/OpenClash.git
git config core.sparsecheckout true
echo "luci-app-openclash" >> .git/info/sparse-checkout
git pull --depth 1 origin dev
git branch --set-upstream-to=origin/dev master
rm -rf ./luci-app-openclash/root/etc/openclash/*.* ./luci-app-openclash/root/etc/openclash/*rule*
mv ./luci-app-openclash .. && cd ../../../.. && ./scripts/feeds update -a && ./scripts/feeds install -a