#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#

# Uncomment a feed source
#sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default

# Add a feed source
#echo 'src-git helloworld https://github.com/fw876/helloworld' >>feeds.conf.default
#echo 'src-git passwall https://github.com/xiaorouji/openwrt-passwall' >>feeds.conf.default

# Modify default frpc-upx
git clone https://github.com/kuoruan/openwrt-upx.git ./package/openwrt-upx
git clone https://github.com/kuoruan/openwrt-frp.git ./package/openwrt-frp
git clone https://github.com/rufengsuixing/luci-app-zerotier.git ./package/luci-app-zerotier

# Modify default OPENCLASH
mkdir -p ./package/luci-data
cd ./package/luci-data
git init
git remote add -f origin https://github.com/vernesong/OpenClash.git
git config core.sparsecheckout true
echo "luci-app-openclash" >> .git/info/sparse-checkout
git pull --depth 1 origin dev
git branch --set-upstream-to=origin/dev master
rm -rf ./luci-app-openclash/root/etc/openclash/*.* ./luci-app-openclash/root/etc/openclash/*rule*
mv ./luci-app-openclash ..

# Modify default NETDATA
rm -rf .git
git init
git remote add -f origin https://github.com/immortalwrt/luci.git
git config core.sparsecheckout true
echo "luci-app-netdata" >> .git/info/sparse-checkout
git pull origin master
mv ./applications/luci-app-netdata/ ..