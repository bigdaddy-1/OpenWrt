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
# Modify default system
sed -i 's/192.168.1.1/192.168.0.1/g' ./package/base-files/files/bin/config_generate
sed -i 's/GMT0/CST-8/g' ./package/base-files/files/bin/config_generate
sed -i 's/UTC/Asia\/Shanghai/g' ./package/base-files/files/bin/config_generate
sed -i "s/option cachesize.*/option cachesize '0'/g" ./package/network/services/dnsmasq/files/dhcp.conf
sed -i '/"admin\/system\/plugins": {/,/"admin\/system\/startup": {/ { /"admin\/system\/startup": {/!d; }' ./feeds/luci/modules/luci-mod-system/root/usr/share/luci/menu.d/luci-mod-system.json

# Modify default ssh-key
sed -i "/^define Package\/dropbear\/install/,/^endef/ s|^endef|\t\$(INSTALL_DIR) \$(1)/etc/dropbear\n\techo \"$KEY\" > \$(1)/etc/dropbear/authorized_keys\n\tchmod 0600 \$(1)/etc/dropbear/authorized_keys\nendef|" ./package/network/services/dropbear/Makefile

# Modify default Wifiset
sed -i "s/'\${defaults ? 0 : 1}'/'0'/g" ./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc
sed -i '/else if (width > 80)/, /width = 80/c \		else if ((band.he || band.eht) && width >= 160) width = 160;\n		else if (width > 80) width = 80;' ./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc
sed -i "s/'\${country || ''}'/'US'/g" ./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc

# Modify default luci-theme-argon
curl -fsL https://raw.githubusercontent.com/bigdaddy-1/OpenWrt/master/bg1.jpg -o ./package/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg

# attr 2.6.0 and acl 2.4.0 use struct xattr_args, which musl's linux/xattr.h does not have.
mkdir -p ./feeds/packages/utils/attr/patches ./feeds/packages/utils/acl/patches
cp "$GITHUB_WORKSPACE/patches/attr/001-xattrat-musl.patch" ./feeds/packages/utils/attr/patches/
cp "$GITHUB_WORKSPACE/patches/acl/001-xattrat-musl.patch" ./feeds/packages/utils/acl/patches/

# Modify default mdns
mv ./mdns ./feeds/packages/net/mdns-repeater/files/mdns_repeater.conf

# Modify default ttyd
sed -i 's/services/system/g' ./feeds/luci/applications/luci-app-ttyd/root/usr/share/luci/menu.d/luci-app-ttyd.json
sed -i 's/START=99/START=98/g' ./feeds/packages/utils/ttyd/files/ttyd.init
mv ./ttyd ./feeds/packages/utils/ttyd/files/ttyd.config

# Modify default netdata
# netdata_version=$(curl -fsL 'https://api.github.com/repos/netdata/netdata/releases/latest' | jq -r '.tag_name' | sed 's/v//')
# netdata_hash=$(curl -fsL https://github.com/netdata/netdata/releases/download/v$netdata_version/netdata-v$netdata_version.tar.gz | sha256sum | awk '{print $1}')
# sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$netdata_version/g" ./feeds/packages/admin/netdata/Makefile
# sed -i "s/PKG_HASH:=.*/PKG_HASH:=$netdata_hash/g" ./feeds/packages/admin/netdata/Makefile
# sed -i 's/\.\.\/\.\.\/luci\.mk/$(TOPDIR)\/feeds\/luci\/luci\.mk/g' ./package/luci-app-netdata/Makefile

# Modify default zerotier
zerotier_version=$(curl -fsL 'https://api.github.com/repos/zerotier/ZeroTierOne/releases/latest' | jq -r '.tag_name' | sed 's/v//')
zerotier_hash=$(curl -fsL https://codeload.github.com/zerotier/ZeroTierOne/tar.gz/$zerotier_version | sha256sum | awk '{print $1}')
sed -i 's/START=.*/START=97/g' ./feeds/packages/net/zerotier/files/etc/init.d/zerotier
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
version1=(${singbox_prefor_normalized//./ })
version2=(${singbox_latest_normalized//./ })
for i in ${!version1[@]}; do
  if [[ -z "${version2[i]}" ]]; then
    version2[i]=0
  fi
  if ((${version1[i]} > ${version2[i]})); then
    singbox_version=$singbox_prefor
    apk_version=$singbox_prefor_normalized
    break
  elif ((${version1[i]} < ${version2[i]})); then
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
python3 - "$singbox_version" "$apk_version" "$singbox_hash" <<'PY'
import pathlib, sys
version, apk, digest = sys.argv[1:]
path = pathlib.Path("./package/sing-box/Makefile")
text = path.read_text()
old_version = next(line.split(":=", 1)[1] for line in text.splitlines() if line.startswith("PKG_VERSION:="))
old_hash = next(line for line in text.splitlines() if line.startswith("PKG_HASH:="))
text = text.replace("PKG_VERSION:=" + old_version, "PKG_REAL_VERSION:=" + version + "\nPKG_VERSION:=" + apk, 1)
text = text.replace(old_hash, "PKG_HASH:=" + digest + "\nPKG_BUILD_DIR:=$(BUILD_DIR)/sing-box-$(PKG_REAL_VERSION)", 1)
text = text.replace("$(PKG_VERSION)", "$(PKG_REAL_VERSION)")
text = text.replace("../../lang/golang/golang-package.mk", "$(TOPDIR)/feeds/packages/lang/golang/golang-package.mk")
# Keep an existing assignment (sing-box needs -checklinkname=0). A second
# GO_PKG_LDFLAGS:= would win and drop it, and the link then fails.
if "GO_PKG_LDFLAGS:=" not in text:
    text = text.replace("GO_PKG_LDFLAGS_X:=", "GO_PKG_LDFLAGS:=-s -w\nGO_PKG_LDFLAGS_X:=", 1)
elif "-s -w" not in text.split("GO_PKG_LDFLAGS_X:=", 1)[0]:
    text = text.replace("GO_PKG_LDFLAGS:=", "GO_PKG_LDFLAGS:=-s -w ", 1)
# Full variant defaults Naive on and then links -lcronet, which these trees do not ship.
naive = "  config SING_BOX_BUILD_NAIVE_OUTBOUND\n  def_bool y\n"
naive_off = "  config SING_BOX_BUILD_NAIVE_OUTBOUND\n  bool \"Build with NaiveProxy outbound support\"\n  default n\n"
if naive not in text:
    raise SystemExit("sing-box naive default not found")
text = text.replace(naive, naive_off, 1)
old = """define Package/sing-box/install
\t$(call GoPackage/Package/Install/Bin,$(1))

\t$(INSTALL_DIR) $(1)/etc/sing-box
\t$(INSTALL_DATA) $(PKG_BUILD_DIR)/release/config/config.json $(1)/etc/sing-box

\t$(INSTALL_DIR) $(1)/etc/config/
\t$(INSTALL_CONF) ./files/sing-box.conf $(1)/etc/config/sing-box
\t$(INSTALL_DIR) $(1)/etc/init.d/
\t$(INSTALL_BIN) ./files/sing-box.init $(1)/etc/init.d/sing-box
endef"""
new = """define Package/sing-box/install
\t$(call GoPackage/Package/Install/Bin,$(1))
\t$(INSTALL_DIR) $(1)/etc/init.d
\t$(INSTALL_BIN) $(TOPDIR)/sing-box $(1)/etc/init.d/sing-box
\t$(INSTALL_DIR) $(1)/etc/sing-box
\tcp -r ./metacubexd-gh-pages $(1)/etc/sing-box/ui
endef"""
if old not in text:
    raise SystemExit("sing-box install block not found")
path.write_text(text.replace(old, new, 1))
PY
sed -i "s/SURL/$SURL/g" ./sing-box

# Modify default mosdns
mosdns_prefor=$(curl -fsL 'https://api.github.com/repos/IrineSistiana/mosdns/releases' | jq -r 'map(select(.prerelease)) | first | .tag_name' | sed 's/v//')
mosdns_latest=$(curl -fsL 'https://api.github.com/repos/IrineSistiana/mosdns/releases/latest' | jq -r '.tag_name' | sed 's/v//')
mosdns_prefor_normalized=$(echo "$mosdns_prefor" | sed 's/-.*//')
mosdns_latest_normalized=$(echo "$mosdns_latest" | sed 's/-.*//')
version1=(${mosdns_prefor_normalized//./ })
version2=(${mosdns_latest_normalized//./ })
for i in ${!version1[@]}; do
  if [[ -z "${version2[i]}" ]]; then
    version2[i]=0
  fi
  if ((${version1[i]} > ${version2[i]})); then
    mosdns_version=$mosdns_prefor
    break
  elif ((${version1[i]} < ${version2[i]})); then
    mosdns_version=$mosdns_latest
    break
  fi
done
if [[ -z "$mosdns_version" ]]; then
  mosdns_version=$mosdns_latest
fi
mosdns_hash=$(curl -fsL https://codeload.github.com/IrineSistiana/mosdns/tar.gz/v$mosdns_version | sha256sum | awk '{print $1}')
python3 - "$mosdns_version" "$mosdns_hash" <<'PY'
import pathlib, sys
version, digest = sys.argv[1:]
path = pathlib.Path("./package/mosdns/Makefile")
text = path.read_text()
old_version = next(line.split(":=", 1)[1] for line in text.splitlines() if line.startswith("PKG_VERSION:="))
old_hash = next(line for line in text.splitlines() if line.startswith("PKG_HASH:="))
text = text.replace("PKG_VERSION:=" + old_version, "PKG_VERSION:=" + version, 1)
text = text.replace(old_hash, "PKG_HASH:=" + digest, 1)
text = text.replace("../../lang/golang/golang-package.mk", "$(TOPDIR)/feeds/packages/lang/golang/golang-package.mk")
if "GO_PKG_LDFLAGS:=-s -w" not in text:
    text = text.replace("GO_PKG:=", "GO_PKG_LDFLAGS:=-s -w\nGO_PKG:=", 1)
old = "$(INSTALL_BIN) $(PKG_BUILD_DIR)/scripts/openwrt/mosdns-init-openwrt $(1)/etc/init.d/mosdns"
new = "$(INSTALL_BIN) $(TOPDIR)/mosdns $(1)/etc/init.d/mosdns"
if old not in text:
    raise SystemExit("mosdns init install line not found")
path.write_text(text.replace(old, new, 1))
PY
sed -i "s/SURL2/$SURL2/g" ./mosdns
cat >./package/mosdns/files/config.yaml <<\EOF
log:
  level: error

api:
  http: 10.1.1.1:8088

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

  - tag: 'cache.local'
    type: cache
    args:
      size: 5120
      lazy_cache_ttl: 86400

  - tag: 'cache.remote'
    type: cache
    args:
      size: 5120
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
        - tag: dns.cn
          addr: 223.5.5.5
        - addr: 119.29.29.29
        - addr: 114.114.114.114

  - tag: 'dns'
    type: forward
    args:
      concurrent: 3
      upstreams:
        - tag: dns.kr
          addr: udp://10.1.1.10
        - addr: udp://10.1.1.11
        - addr: udp://10.1.1.12
        - tag: dns.jp
          addr: udp://10.1.1.20
        - addr: udp://10.1.1.21
        - tag: dns.us
          addr: udp://10.1.1.30
        - addr: udp://10.1.1.31

  - tag: 'doh'
    type: forward
    args:
      concurrent: 2
      upstreams:
        - tag: cf
          addr: "https://cloudflare-dns.com/dns-query"
          dial_addr: "1.1.1.1"
        - tag: google
          addr: "https://dns.google/dns-query"
          dial_addr: "8.8.8.8"

  - tag: 'fallback'
    type: fallback
    args:
      primary: dns
      secondary: doh
      threshold: 300
      always_standby: true

  - tag: 'lookup'
    type: sequence
    args:
      - exec: $hosts
      - exec: ttl 1
      - matches: has_resp
        exec: accept

  - tag: 'local'
    type: sequence
    args:
      - exec: $cache.local
      - matches: has_resp
        exec: accept
      - exec: $cndns
      - exec: nftset inet,fw4,localnetwork,ipv4_addr,24 inet,fw4,localnetwork6,ipv6_addr,48
      - exec: accept

  - tag: 'remote'
    type: sequence
    args:
      - exec: $cache.remote
      - matches: has_resp
        exec: accept
      - exec: $fallback
      - matches: resp_ip $CNIPS
        exec: goto local
      - exec: accept

  - tag: 'main.local'
    type: sequence
    args:
      - exec: jump lookup
      - exec: goto local

  - tag: 'main.remote'
    type: sequence
    args:
      - exec: jump lookup
      - matches: qname $DIRECT
        exec: goto local
      - exec: goto remote

  - type: tcp_server
    args:
      entry: main.local
      listen: :5053
  - type: udp_server
    args:
      entry: main.remote
      listen: :5053
EOF

cat >> ./package/base-files/files/etc/sysctl.conf << 'EOF'

# ============================================
# BBR & Network Optimization
# ============================================
net.ipv4.tcp_congestion_control=bbr
net.core.default_qdisc=fq
net.ipv4.tcp_slow_start_after_idle=0
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.rmem_default=262144
net.core.wmem_default=262144
net.core.netdev_max_backlog=65536
net.ipv4.tcp_rmem=4096 262144 16777216
net.ipv4.tcp_wmem=4096 262144 16777216
net.ipv4.tcp_mem=16777216 16777216 16777216
net.ipv4.tcp_notsent_lowat=16384
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=15
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0

EOF

