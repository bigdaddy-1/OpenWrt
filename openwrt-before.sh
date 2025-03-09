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

# 自定义插件
# Modify default frpc-upx
git clone https://github.com/kuoruan/openwrt-upx.git ./package/openwrt-upx
# git clone https://github.com/rufengsuixing/luci-app-zerotier.git ./package/luci-app-zerotier
git clone https://github.com/jerrykuku/luci-theme-argon.git ./package/luci-theme-argon

# Modify default avahi config
cat > ./avahi <<\EOF
[server]
use-ipv4=yes
use-ipv6=yes
check-response-ttl=no
use-iff-running=no
allow-interfaces=br-lan,ztj32b5oay

[publish]
publish-addresses=yes
publish-hinfo=no
publish-workstation=no
publish-domain=yes

[reflector]
enable-reflector=yes
reflect-ipv=yes

[rlimits]
rlimit-core=0
rlimit-data=4194304
rlimit-fsize=0
rlimit-nofile=50
rlimit-stack=4194304
rlimit-nproc=3

EOF

# Modify default SING-BOX config
cat > ./sing-box <<\EOF
#!/bin/sh /etc/rc.common

START=99
USE_PROCD=1

CONFIG_URL=SURL
SELECTED_MODE="${SELECTED_MODE:-tproxy}"
USER_ID=65534
TUN_REDIRECT_PORT=8011
TPROXY_REDIRECT_PORT=8012
DNS_REDIRECT_PORT=5253
FWMARK_MAIN=255
FWMARK_POLICY_ROUTING=101
POLICY_ROUTE_TABLE=80
ZT_INTERFACE="ztj32b5oay"

APPBINARY=/usr/bin/sing-box
DIRECTORY=/etc/sing-box/
CONFIGFILE=/etc/sing-box/config.json
NFTFILE="/etc/nftables.d/singbox-${SELECTED_MODE}.nft"
capabilities='cap_dac_override,cap_net_raw,cap_net_bind_service,cap_net_admin'

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
        elements = { 0.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 127.0.0.0/8, 169.254.0.0/16, 172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/3 }
    }

    set localnetwork6 {
        type ipv6_addr
        flags interval
        elements = { fc00::/7, ff00::/8, fe80::/10, 2002::/16, ::/127, 2001::/32, 2001:db8::/32, 100::/64, 64:ff9b::/96, ::ffff:0.0.0.0/96 }
    }

    chain proxy_prerouting {
        type filter hook prerouting priority mangle; policy accept;
        iifname "$ZT_INTERFACE" meta mark set 0xff
        ip daddr @localnetwork return
        ip6 daddr @localnetwork6 return
NFT_EOF
    if [ "$SELECTED_MODE" == "tproxy" ]; then
        cat >> "$NFTFILE" <<NFT_EOF
        meta l4proto { tcp,udp } ct state new ct mark set 0xff
        ct mark 0xff meta l4proto { tcp,udp } th dport { 0-65535 } mark set "$FWMARK_POLICY_ROUTING" counter tproxy to :"$TPROXY_REDIRECT_PORT"
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
        skuid != "$USER_ID" meta l4proto { tcp, udp } th dport { 0-65535 } mark set "$FWMARK_POLICY_ROUTING"
NFT_EOF
    fi
    if [ "$SELECTED_MODE" == "tun" ]; then
        cat >> "$NFTFILE" <<NFT_EOF
        skuid != "$USER_ID" meta l4proto udp th dport { 0-65535 } mark set "$FWMARK_POLICY_ROUTING"
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

    while ip tuntap | grep -q "tun0"; do
    ip link set tun0 down 2>/dev/null
    ip tuntap del dev tun0 mode tun 2>/dev/null
    sleep 1
    done
}

start_service() {
    local target_ip=10.1.1.10
    local max_attempts=3
    local attempt=1

    echo "Testing network connectivity to Zerotier.."

    while ! ping -c 1 -W 1 "${target_ip}" > /dev/null 2>&1; do
        if [ "$attempt" -ge "$max_attempts" ]; then
            echo "ERROR: Failed to connect to Zerotier after ${max_attempts} attempts. Exiting.."
            exit 1
        fi
        echo "Attempt ${attempt}/${max_attempts} to connect to Zerotier failed.."
        attempt=$((attempt + 1))
        sleep 5
    done

    check_config_update
    generate_nftables_rules

    procd_open_instance
    procd_set_param command capsh --caps="${capabilities}+eip" -- -c "capsh --user=nobody --addamb='${capabilities}' -- -c '$APPBINARY run -c $CONFIGFILE --disable-color'"
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
    echo "SING-BOX ($SELECTED_MODE) has been successfully started.."
    /etc/init.d/firewall restart >/dev/null 2>&1
}

reload_service() {
    stop
    start
}

stop_service() {
    local nft_file=$(ls /etc/nftables.d/singbox-*.nft 2>/dev/null | head -n 1)

    if [[ -n "$nft_file" ]]; then
        CURRENT_MODE=$(basename "$nft_file" | sed -E 's/singbox-(.*)\.nft/\1/')
    else
        CURRENT_MODE="unknown"
    fi
    
    echo "SING-BOX ($CURRENT_MODE) service has been stopped.."
    rm -f /etc/nftables.d/singbox-*.nft >/dev/null 2>&1
    /etc/init.d/firewall restart >/dev/null 2>&1
}
EOF

# Modify default MOSDNS config
cat > ./mosdns <<\EOF
#!/bin/sh /etc/rc.common

START=99
USE_PROCD=1

APPBINARY=/usr/bin/mosdns
DIRECTORY=/etc/mosdns
CONFIGFILE=$DIRECTORY/config.yaml

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
    local target_ip=10.1.1.10
    local max_attempts=3
    local attempt=1

    echo "Testing network connectivity to Zerotier.."

    while ! ping -c 1 -W 1 "${target_ip}" > /dev/null 2>&1; do
        if [ "$attempt" -ge "$max_attempts" ]; then
            echo "ERROR: Failed to connect to Zerotier after ${max_attempts} attempts. Exiting.."
            exit 1
        fi
        echo "Attempt ${attempt}/${max_attempts} to connect to Zerotier failed.."
        attempt=$((attempt + 1))
        sleep 5
    done

    check_files
    procd_open_instance
    procd_set_param command $APPBINARY start -d $DIRECTORY -c "$CONFIGFILE"

    procd_set_param user root
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
    echo "mosdns service has been successfully started.."
}

reload_service() {
    stop
    start
}

stop_service() {
    echo "mosdns service has been stopped.."
}
EOF

# Modify default packages
clone_sparse_checkout() {
    local repo_url=$1
    local branch=$2
    local sparse_checkout_files=("${@:3}")

    rm -rf .git
    git init
    git remote add -f origin "$repo_url"
    git config core.sparsecheckout true

    for file in "${sparse_checkout_files[@]}"; do
        echo "$file" >>.git/info/sparse-checkout
    done

    git pull origin "$branch"
}
mkdir -p ./package/luci-data
cd ./package/luci-data
clone_sparse_checkout "https://github.com/immortalwrt/packages.git" "master" "mosdns" "sing-box"
mv ./net/mosdns/ ./net/sing-box/ ..
clone_sparse_checkout "https://github.com/immortalwrt/luci.git" "master" "luci-app-zerotier"
gh pr checkout 470
