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

START=99
USE_PROCD=1

export CONFIG_URL=SURL
export SELECTED_MODE="${SELECTED_MODE:-tun}"
export USER_ID=65534
export REDIRECT_PORT_TCP=8012
export REDIRECT_PORT_UDP=8012
export TUN_REDIRECT_PORT=8011
export DNS_REDIRECT_PORT=5053
export FWMARK_MAIN=255
export FWMARK_POLICY_ROUTING=101
export POLICY_ROUTE_TABLE=80
export ZT_INTERFACE="ztj32b5oay"

APPBINARY=/usr/bin/sing-box
DIRECTORY=/etc/sing-box/
CONFIGFILE=/etc/sing-box/config.json
NFTFILE="/etc/nftables.d/singbox-${SELECTED_MODE}.nft"
capabilities='cap_sys_resource,cap_dac_override,cap_net_raw,cap_net_bind_service,cap_net_admin,cap_sys_ptrace'

chown nobody:nogroup "$APPBINARY" 2>/dev/null

check_config_update() {
    local interface=$(ip route | awk '/default/ {print $5}')
    [ -z "$CONFIG_URL" ] && return 0

    local remote_content_raw=$(curl -fsL --connect-timeout 3 "$CONFIG_URL")
    local remote_content_modified=$(echo "$remote_content_raw" | sed "s/auto-interface/$interface/")
    local remote_sha256=$(echo "$remote_content_modified" | sha256sum | awk '{print $1}')

    if [ -f "$CONFIGFILE" ]; then
        local local_content=$(cat "$CONFIGFILE")
        local local_sha256=$(echo "$local_content" | sha256sum | awk '{print $1}')

        if [ "$local_sha256" != "$remote_sha256" ]; then
            echo "Configuration file changed, updating..."
            echo "$remote_content_raw" | sed "s/auto-interface/$interface/" > "$CONFIGFILE"
        else
            echo "No update is necessary, the local file is identical to the remote file..."
        fi
    else
        echo "Configuration file not found, downloading..."
        echo "$remote_content_raw" | sed "s/auto-interface/$interface/" > "$CONFIGFILE"
    fi
}

generate_nftables_rules() {

    echo "Generating nftables rules for $SELECTED_MODE mode to $NFTFILE"

    cat > "$NFTFILE" <<NFT_EOF
        set localnetwork {
            type ipv4_addr
            flags interval
            auto-merge
            elements = { 0.0.0.0/8, 10.0.0.0/8,
                            100.64.0.0/10, 127.0.0.0/8,
                            169.254.0.0/16, 172.16.0.0/12,
                            192.168.0.0/16, 224.0.0.0/3, 240.0.0.0/4 }
        }

        set localnetwork6 {
            type ipv6_addr
            flags interval
            auto-merge
            elements = { ::/127,
                            ::1/128,
                            ::ffff:0.0.0.0/96,
                            ::ffff:0:0:0/96,
                            64:ff9b::/96,
                            100::/64,
                            2001::/32,
                            2001:20::/28,
                            2001:db8::/32,
                            2002::/16,
                            fc00::/7,
                            fe80::/10,
                            ff00::/8 }
        }

    chain proxy_prerouting {
        type filter hook prerouting priority mangle; policy accept;
        iifname "$ZT_INTERFACE" meta mark set 0xff
        ip daddr @localnetwork return
        ip6 daddr @localnetwork6 return
NFT_EOF
    if [ "$SELECTED_MODE" == "tproxy" ]; then
        cat >> "$NFTFILE" <<NFT_EOF
        meta l4proto tcp ct state new ct mark set 0xff
        meta l4proto udp ct state new ct mark set 0xff
        ct mark 0xff meta l4proto { tcp,udp } th dport { 0-65535 } mark set "$FWMARK_POLICY_ROUTING" counter tproxy to :"$REDIRECT_PORT_TCP"
NFT_EOF
    elif [ "$SELECTED_MODE" == "tun" ]; then
        cat >> "$NFTFILE" <<NFT_EOF
        meta l4proto tcp ct state new ct mark set 0xff
        meta l4proto udp ct state new mark set "$FWMARK_POLICY_ROUTING"
NFT_EOF
    fi
    cat >> "$NFTFILE" <<NFT_EOF
    }

    chain proxy_output {
        type route hook output priority mangle; policy accept;
        meta mark 0xff counter accept
        oifname "$ZT_INTERFACE" meta mark set 0xff
        ip daddr @localnetwork return
        ip6 daddr @localnetwork6 return
NFT_EOF
    if [ "$SELECTED_MODE" == "tproxy" ]; then
        cat >> "$NFTFILE" <<NFT_EOF
        skuid != "$USER_ID" meta l4proto udp th dport { 53,443 } mark set "$FWMARK_POLICY_ROUTING"
        skuid != "$USER_ID" meta l4proto tcp th dport { 0-65535 } mark set "$FWMARK_POLICY_ROUTING"
NFT_EOF
    fi
    if [ "$SELECTED_MODE" == "tun" ]; then
        cat >> "$NFTFILE" <<NFT_EOF
        skuid != "$USER_ID" meta l4proto udp th dport { 53,443 } mark set "$FWMARK_POLICY_ROUTING"
        skuid != "$USER_ID" meta l4proto tcp th dport { 0-65535 } ct mark set 0xff
NFT_EOF
    fi
    cat >> "$NFTFILE" <<NFT_EOF
    }

    chain nat_optnat {
        type nat hook output priority -100; policy accept;
        tcp dport 53 ip daddr {127.0.0.1} meta skuid != "$USER_ID" counter redirect to :"$DNS_REDIRECT_PORT"
        udp dport 53 ip daddr {127.0.0.1} meta skuid != "$USER_ID" counter redirect to :"$DNS_REDIRECT_PORT"
NFT_EOF
    if [ "$SELECTED_MODE" == "tun" ]; then
        cat >> "$NFTFILE" <<NFT_EOF
        ct mark 0xff jump nat_redir
NFT_EOF
    fi
    cat >> "$NFTFILE" <<NFT_EOF
    }

    chain nat_dstnat {
        type nat hook prerouting priority dstnat; policy accept;
        udp dport 53 counter redirect to :"$DNS_REDIRECT_PORT"
        tcp dport 53 counter redirect to :"$DNS_REDIRECT_PORT"
NFT_EOF
    if [ "$SELECTED_MODE" == "tun" ]; then
        cat >> "$NFTFILE" <<NFT_EOF
        ct mark 0xff jump nat_redir
NFT_EOF
    fi
    cat >> "$NFTFILE" <<NFT_EOF
    }
NFT_EOF

    if [ "$SELECTED_MODE" == "tun" ]; then
        cat >> "$NFTFILE" <<NFT_EOF
    chain nat_redir {
        meta l4proto tcp counter redirect to :"$TUN_REDIRECT_PORT"
    }

    chain forward {
        type filter hook forward priority filter; policy drop;
        meta l4proto { tcp, udp } oifname tun0 counter accept comment "\Sing-box TUN Forward\"
    }
NFT_EOF
    fi

    cleanup_tunnel_routing

    ip rule add fwmark "$FWMARK_POLICY_ROUTING" table "$POLICY_ROUTE_TABLE" 2>/dev/null
    ip rule add fwmark "$FWMARK_MAIN" lookup main 2>/dev/null

    ip -6 rule add fwmark "$FWMARK_POLICY_ROUTING" table "$POLICY_ROUTE_TABLE" 2>/dev/null
    ip -6 rule add fwmark "$FWMARK_MAIN" lookup main 2>/dev/null

    if [ "$SELECTED_MODE" == "tproxy" ]; then
        ip -6 route add local default dev lo table "$POLICY_ROUTE_TABLE" 2>/dev/null
        ip route add local default dev lo table "$POLICY_ROUTE_TABLE" 2>/dev/null
    elif [ "$SELECTED_MODE" == "tun" ]; then
        ip tuntap add dev tun0 mode tun user root 2>/dev/null
        ip link set tun0 up 2>/dev/null
        ip route replace default dev tun0 table "$POLICY_ROUTE_TABLE" 2>/dev/null
        ip -6 route replace default dev tun0 table "$POLICY_ROUTE_TABLE" 2>/dev/null
    fi
}

cleanup_tunnel_routing(){
    ip rule del fwmark $FWMARK_MAIN lookup main 2>/dev/null
    ip -6 rule del fwmark $FWMARK_MAIN lookup main 2>/dev/null
    ip rule del table $POLICY_ROUTE_TABLE 2>/dev/null
    ip -6 rule del table $POLICY_ROUTE_TABLE 2>/dev/null
    ip route flush table $POLICY_ROUTE_TABLE 2>/dev/null
    ip -6 route flush table $POLICY_ROUTE_TABLE 2>/dev/null

    while ip route | grep -q "tun0"; do
    ip link set tun0 down 2>/dev/null
    sleep 1
    ip tuntap del dev tun0 mode tun 2>/dev/null
    sleep 3
    done
}

start_service() {
    check_config_update
    generate_nftables_rules

    procd_open_instance
    procd_set_param command capsh --caps="${capabilities}+eip" -- -c "capsh --user=nobody --addamb='${capabilities}' -- -c '$APPBINARY run -c $CONFIGFILE --disable-color'"
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
    echo "SING-BOX ($SELECTED_MODE) is started.."
    /etc/init.d/firewall restart >/dev/null 2>&1
}

reload_service() {
    stop
    start
}

stop_service() {
    echo "SING-BOX is stopped.."
    cleanup_tunnel_routing
    rm -f /etc/nftables.d/singbox-*.nft >/dev/null 2>&1
    /etc/init.d/firewall restart >/dev/null 2>&1
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
# echo "luci-app-netdata" >> .git/info/sparse-checkout
git pull origin master
gh pr checkout 470