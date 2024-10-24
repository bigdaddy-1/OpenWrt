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

# Modify default nss-packages
# sed -i 's/NSS-12.5-K6.x/NSS-12.5-K6.x-NAPI/g' ./feeds.conf.default

# 自定义插件
# Modify default frpc-upx
git clone https://github.com/kuoruan/openwrt-upx.git ./package/openwrt-upx
# git clone https://github.com/rufengsuixing/luci-app-zerotier.git ./package/luci-app-zerotier
git clone https://github.com/jerrykuku/luci-theme-argon.git ./package/luci-theme-argon

# Modify default SING-BOX config
cat >./sing-box <<\EOF
#!/bin/sh /etc/rc.common

START=98
USE_PROCD=1

chown nobody:nogroup /usr/bin/sing-box 2>/dev/null
capabilities='cap_sys_resource,cap_dac_override,cap_net_raw,cap_net_bind_service,cap_net_admin,cap_sys_ptrace'

APPBINARY=/usr/bin/sing-box
DIRECTORY=/etc/sing-box/
CONFIGFILE=/etc/sing-box/config.json
selected_mode=tproxy

check_sha256sum() {
    INTERFACE=$(ip route | awk '/default/ {print $5}')
    if [ -f $CONFIGFILE ]; then
        local_sha256=$(cat "$CONFIGFILE" | sha256sum | awk '{print $1}')
        remote_sha256=$(curl -fsL --connect-timeout 3 SURL | sha256sum | awk '{print $1}')
        if [ $local_sha256 != $remote_sha256 ]; then
            curl -fsL --connect-timeout 3 -o $CONFIGFILE SURL
            sed -i "s/auto-interface/$INTERFACE/" $CONFIGFILE
        fi
    else
        curl -fsL --connect-timeout 3 -o $CONFIGFILE SURL
        sed -i "s/auto-interface/$INTERFACE/" $CONFIGFILE
    fi
}

check_firewall() {
    localnetwork='0.0.0.0/8, 127.0.0.0/8, 10.0.0.0/8, 169.254.0.0/16, 192.168.0.0/16, 224.0.0.0/4, 240.0.0.0/4, 172.16.0.0/12, 100.64.0.0/10'
    localnetwork6='::/128, ::1/128, ::ffff:0:0/96, ::ffff:0:0:0/96, 64:ff9b::/96, 100::/64, 2001::/32, 2001:20::/28, 2001:db8::/32, 2002::/16, fc00::/7, fe80::/10, ff00::/8'
    if [ -z "$(nft list table inet fw4 | grep localnetwork)" ]; then
        nft 'add set inet fw4 localnetwork { type ipv4_addr; flags interval; auto-merge; }'
        nft "add element inet fw4 localnetwork { $localnetwork }"
        nft 'add set inet fw4 localnetwork6 { type ipv6_addr; flags interval; auto-merge; }'
        nft "add element inet fw4 localnetwork6 { $localnetwork6 }"
    else
        setdown_server_firewall
    fi
}

setup_server_firewall() {
    if [ -z "$selected_mode" ]; then
        rand_num=$(hexdump -n 1 -e '1/4 "%u"' /dev/urandom)
        if [ $((rand_num % 2)) -eq 0 ]; then
            selected_mode="tproxy"
        else
            selected_mode="tun"
        fi
    fi

    if [ "$selected_mode" == "tproxy" ]; then
        check_firewall
        if [ -z "$(nft list chain inet fw4 mangle_prerouting | grep tproxy)" ]; then
            nft 'add rule inet fw4 mangle_prerouting iifname ztj32b5oay mark set 0xff'
            nft 'add rule inet fw4 mangle_prerouting ip daddr @localnetwork return'
            nft 'add rule inet fw4 mangle_prerouting ip6 daddr @localnetwork6 return'
            nft 'add rule inet fw4 mangle_prerouting meta l4proto tcp ct state new ct mark set 0xff'
            nft 'add rule inet fw4 mangle_prerouting meta l4proto udp ct state new ct mark set 0xff'
            nft 'add rule inet fw4 mangle_prerouting ct mark 0xff meta l4proto { tcp,udp } th dport { 0-65535 } mark set 101 counter tproxy to :8012'
            nft 'add rule inet fw4 mangle_output meta mark 0xff counter accept'
            nft 'add rule inet fw4 mangle_output oifname ztj32b5oay mark set 0xff'
            nft 'add rule inet fw4 mangle_output ip daddr @localnetwork return'
            nft 'add rule inet fw4 mangle_output ip6 daddr @localnetwork6 return'
            nft 'add rule inet fw4 mangle_output skuid != 65534 meta l4proto udp th dport { 53,443 } mark set 101'
            nft 'add rule inet fw4 mangle_output skuid != 65534 meta l4proto tcp th dport { 0-65535 } mark set 101'

            nft 'add chain inet fw4 optnat { type nat hook output priority -100; }'
            nft 'add rule inet fw4 optnat tcp dport 53 ip daddr {127.0.0.1} meta skuid != 65534 counter redirect to :5353'
            nft 'add rule inet fw4 optnat udp dport 53 ip daddr {127.0.0.1} meta skuid != 65534 counter redirect to :5353'
            nft "add rule inet fw4 dstnat udp dport 53 counter redirect to :5353"
            nft "add rule inet fw4 dstnat tcp dport 53 counter redirect to :5353"

            clean_rules
            ip rule add fwmark 101 table 80
            ip rule add fwmark 255 lookup main
            ip route add local default dev lo table 80
            ip -6 rule add fwmark 101 table 80
            ip -6 rule add fwmark 255 lookup main
            ip -6 route add local default dev lo table 80
        fi
    elif [ "$selected_mode" == "tun" ]; then
        check_firewall
        if [ -z "$(nft list chain inet fw4 forward | grep tun0)" ]; then
            nft 'add rule inet fw4 mangle_prerouting iifname ztj32b5oay mark set 0xff'
            nft 'add rule inet fw4 mangle_prerouting ip daddr @localnetwork return'
            nft 'add rule inet fw4 mangle_prerouting ip6 daddr @localnetwork6 return'
            nft 'add rule inet fw4 mangle_prerouting meta l4proto tcp ct state new ct mark set 0xff'
            nft 'add rule inet fw4 mangle_prerouting meta l4proto udp ct state new mark set 101'
            nft 'add rule inet fw4 mangle_output meta mark 0xff counter accept'
            nft 'add rule inet fw4 mangle_output oifname ztj32b5oay mark set 0xff'
            nft 'add rule inet fw4 mangle_output ip daddr @localnetwork return'
            nft 'add rule inet fw4 mangle_output ip6 daddr @localnetwork6 return'
            nft 'add rule inet fw4 mangle_output skuid != 65534 meta l4proto udp th dport { 53,443 } mark set 101'
            nft 'add rule inet fw4 mangle_output skuid != 65534 meta l4proto tcp th dport { 0-65535 } ct mark set 0xff'

            nft 'add chain inet fw4 redir'
            nft 'add rule inet fw4 redir meta l4proto tcp counter redirect to :8011'
            nft 'add chain inet fw4 optnat { type nat hook output priority -100; }'
            nft 'add rule inet fw4 optnat ct mark 0xff jump redir'
            nft 'add rule inet fw4 optnat tcp dport 53 ip daddr {127.0.0.1} meta skuid != 65534 counter redirect to :5353'
            nft 'add rule inet fw4 optnat udp dport 53 ip daddr {127.0.0.1} meta skuid != 65534 counter redirect to :5353'
            nft 'insert rule inet fw4 dstnat position 0 ct mark 0xff jump redir'
            nft "add rule inet fw4 dstnat udp dport 53 counter redirect to :5353"
            nft "add rule inet fw4 dstnat tcp dport 53 counter redirect to :5353"

            nft insert rule inet fw4 forward position 0 meta l4proto {tcp,udp} oifname tun0 counter accept comment \"SING-BOX TUN Forward\"

            ip tuntap add mode tun user root name tun0 2>"/dev/null"
            ip link set tun0 up 2>"/dev/null"
            clean_rules
            ip rule add fwmark 101 lookup 80
            ip rule add fwmark 255 lookup main
            ip route replace default dev tun0 table 80
            ip -6 rule add fwmark 101 lookup 80
            ip -6 rule add fwmark 255 lookup main
            ip -6 route replace default dev tun0 table 80
        fi
    fi
}

setdown_server_firewall() {
    if [ -n "$(nft list table inet fw4 | grep localnetwork)" ]; then
        chain="mangle_prerouting mangle_output redir optnat"
        clean_rules
        for i in $chain; do
            nft flush chain inet fw4 "$i" 2>"/dev/null"
        done
        chain="redir optnat"
        for i in $chain; do
        nft delete chain inet fw4 "$i" 2>"/dev/null"
        done
    fi
    if [ -n "$(nft -a list chain inet fw4 dstnat | grep udp)" ]; then
        nft delete rule inet fw4 dstnat handle "$(nft -a list chain inet fw4 dstnat | grep udp | awk '{print $NF}')" 2>"/dev/null"
        nft delete rule inet fw4 dstnat handle "$(nft -a list chain inet fw4 dstnat | grep tcp | awk '{print $NF}')" 2>"/dev/null"
    fi
    if [ -n "$(nft list chain inet fw4 forward | grep tun0)" ]; then
        nft delete rule inet fw4 forward handle "$(nft -a list chain inet fw4 forward | grep tun0 | awk '{print $NF}')" 2>"/dev/null"
        nft delete rule inet fw4 dstnat handle "$(nft -a list chain inet fw4 dstnat | grep 0x000000ff | awk '{print $NF}')" 2>"/dev/null"
    fi
        ip link set tun0 down 2>"/dev/null"
        sleep 3
        ip tuntap del mode tun name tun0 2>"/dev/null"
}

clean_rules() {
    ip rule del fwmark 255 lookup main 2>"/dev/null"
    ip -6 rule del fwmark 255 lookup main 2>"/dev/null"
    ip rule del table 80 2>"/dev/null"
    ip -6 rule del table 80 2>"/dev/null"
    ip route flush table 80 2>"/dev/null"
    ip -6 route flush table 80 2>"/dev/null"
}

start_service() {
    check_sha256sum
    procd_open_instance
    procd_set_param command capsh --caps="${capabilities}+eip" -- -c "capsh --user=nobody --addamb='${capabilities}' -- -c '$APPBINARY run -c $CONFIGFILE --disable-color'"

    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
    echo "SING-BOX $selected_mode is started.."
    setup_server_firewall
}

reload_service() {
    stop
    start
}

stop_service() {
    echo "SING-BOX is stopped.."
    setdown_server_firewall
}
EOF

# Modify default MOSDNS config
cat >./mosdns <<\EOF
#!/bin/sh /etc/rc.common

START=99
USE_PROCD=1

APPBINARY=/usr/bin/mosdns
DIRECTORY=/etc/mosdns/
CONFIGFILE=./config.yaml

check_files() {
    files="direct-list.txt apple-cn.txt proxy-list.txt google-cn.txt"
    files_url="https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/"
    ip_cidr="cn.txt private.txt"
    ip_url="https://raw.githubusercontent.com/Loyalsoldier/geoip/release/text/"

    download_file() {
        local file="$1"
        local url="$2"
        local path="/tmp/$file"

        if [ ! -f "$path" ] || [ "$(curl -fsL --connect-timeout 3 "SURL2/convert/_start_/$url$file/_end_/$file?type=plain-text&target=plain-text&del=true" | md5sum)" != "$(cat "$path" | md5sum)" ]; then
            curl -fsL --connect-timeout 3 -o "$path" "SURL2/convert/_start_/$url$file/_end_/$file?type=plain-text&target=plain-text&del=true"
            return $?
        else
            return 0
        fi
    }

    for i in $(seq 1 3); do
        status="success"
        for file in $files; do
            download_file "$file" "$files_url"
            if [ $? -ne 0 ]; then
                status="failed"
            fi
        done
        for ip in $ip_cidr; do
            download_file "$ip" "$ip_url"
            if [ $? -ne 0 ]; then
                status="failed"
            fi
        done

        if [ "$status" == "success" ]; then
            break
        else
            sleep 3
        fi
    done
}

start_service() {
    check_files
    procd_open_instance
    procd_set_param command $APPBINARY start -d $DIRECTORY -c "$CONFIGFILE"

    procd_set_param user root
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
    echo "mosdns is started.."
}

reload_service() {
    stop
    start
}

stop_service() {
    echo "mosdns is stopped.."
}
EOF

# # Modify default NETDATA
# rm -rf .git
# git init
# git remote add -f origin https://github.com/immortalwrt/luci.git
# git config core.sparsecheckout true
# echo "luci-app-netdata" >> .git/info/sparse-checkout
# git pull origin master
# mv ./applications/luci-app-netdata/ ..

# Modify default packages
mkdir -p ./package/luci-data
cd ./package/luci-data
rm -rf .git
git init
git remote add -f origin https://github.com/immortalwrt/packages.git
git config core.sparsecheckout true
echo "mosdns" >>.git/info/sparse-checkout
echo "sing-box" >>.git/info/sparse-checkout
git pull origin master
mv ./net/mosdns/ ./net/sing-box/ ..

# Modify default luci-app-zerotier
rm -rf .git
git init
git remote add -f origin https://github.com/immortalwrt/luci.git
git config core.sparsecheckout true
echo "luci-app-zerotier" >>.git/info/sparse-checkout
git pull origin master
