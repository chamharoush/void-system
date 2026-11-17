#!/usr/bin/env bash

SKIP_PUBLIC=0
case "${1:-}" in
    -n|--no-public) SKIP_PUBLIC=1 ;;
    -h|--help)
        printf 'Usage: %s [-n|--no-public]\n  -n  skip lookups that contact the internet (public IP, geolocation)\n' "${0##*/}"
        exit 0
        ;;
esac

if [ -t 1 ]; then
    R=$'\e[0m'; B=$'\e[1m'; D=$'\e[2m'
    RED=$'\e[31m'; GRN=$'\e[32m'; YEL=$'\e[33m'
    BLU=$'\e[34m'; MAG=$'\e[35m'; CYN=$'\e[36m'
else
    R=''; B=''; D=''; RED=''; GRN=''; YEL=''; BLU=''; MAG=''; CYN=''
fi

have() { command -v "$1" >/dev/null 2>&1; }

rule() { printf '%*s' "${1:-66}" '' | tr ' ' '─'; }

section() {
    printf '\n%s%s▌ %s%s\n%s%s%s\n' "$B" "$CYN" "$1" "$R" "$D" "$(rule 66)" "$R"
}

row() { printf '  %s%-20s%s %s\n' "$BLU" "$1" "$R" "$2"; }

subrow() { printf '  %s%-20s%s %s\n' "$D" "$1" "$R" "$2"; }

note() { printf '  %s%s%s\n' "$D" "$1" "$R"; }

indent() { sed 's/^/  /'; }

http_get() {
    if have curl; then
        curl -fsS --max-time 4 "$@" 2>/dev/null
    elif have wget; then
        wget -qO- -T 4 "${@: -1}" 2>/dev/null
    fi
}

jget() { printf '%s\n' "$2" | sed -n "s/.*\"$1\": *\"\([^\"]*\)\".*/\1/p" | head -1; }

human() {
    awk -v b="${1:-0}" 'BEGIN{split("B KiB MiB GiB TiB",u," ");i=1;while(b>=1024&&i<5){b/=1024;i++}printf "%.1f %s",b,u[i]}'
}

dur() {
    local s=${1:-0} d h m
    d=$((s/86400)); h=$((s%86400/3600)); m=$((s%3600/60))
    if ((d>0)); then printf '%dd %dh %dm' "$d" "$h" "$m"
    elif ((h>0)); then printf '%dh %dm' "$h" "$m"
    else printf '%dm %ds' "$m" "$((s%60))"
    fi
}

ping_ms() {
    ping -c1 -W2 "$1" 2>/dev/null | sed -n 's/.*time=\([0-9.]*\).*/\1/p' | head -1
}

iface_flags() {
    ip -o link show "$1" 2>/dev/null | sed -n 's/.*<\([^>]*\)>.*/\1/p'
}

status_label() {
    local i=$1 st flags
    st=$(cat "/sys/class/net/$i/operstate" 2>/dev/null)
    flags=$(iface_flags "$i")
    case "$st" in
        up)
            printf '%s● UP%s' "$GRN" "$R" ;;
        dormant|lowerlayerdown|notpresent)
            printf '%s● %s%s' "$YEL" "${st^^}" "$R" ;;
        down)
            case ",$flags," in
                *,UP,*) printf '%s● NO-CARRIER%s' "$YEL" "$R" ;;
                *)      printf '%s● DOWN%s' "$RED" "$R" ;;
            esac ;;
        *)
            case ",$flags," in
                *,UP,*) printf '%s● UP%s %s(link state not reported)%s' "$GRN" "$R" "$D" "$R" ;;
                *)      printf '%s● DOWN%s' "$RED" "$R" ;;
            esac ;;
    esac
}

is_physical() {
    local p
    p=$(readlink -f "/sys/class/net/$1" 2>/dev/null)
    case "$p" in
        */virtual/*) return 1 ;;
        *) return 0 ;;
    esac
}

virtual_kind() {
    local i=$1 t k
    t=$(cat "/sys/class/net/$i/type" 2>/dev/null)
    [ "$t" = "772" ] && { printf 'loopback'; return; }
    k=$(ip -d -o link show "$i" 2>/dev/null | grep -oE '\b(veth|bridge|tun|tap|vlan|bond|macvlan|macvtap|vxlan|wireguard|dummy|ipip|gre|sit|vrf|ifb|team)\b' | head -1)
    if [ -z "$k" ] && [ -d "/sys/class/net/$i/bridge" ]; then k=bridge; fi
    printf '%s' "${k:-virtual}"
}

wireless_info() {
    local i=$1 out ssid sig bitrate
    [ -d "/sys/class/net/$i/wireless" ] || [ -d "/sys/class/net/$i/phy80211" ] || return 0
    if have iw; then
        out=$(iw dev "$i" link 2>/dev/null)
        if printf '%s' "$out" | grep -q 'Connected'; then
            ssid=$(printf '%s\n' "$out" | sed -n 's/^[[:space:]]*SSID: //p')
            sig=$(printf '%s\n' "$out" | sed -n 's/^[[:space:]]*signal: //p')
            bitrate=$(printf '%s\n' "$out" | sed -n 's/^[[:space:]]*tx bitrate: //p')
            row "Wi-Fi SSID" "$ssid"
            [ -n "$sig" ] && row "Signal" "$sig"
            [ -n "$bitrate" ] && row "TX bitrate" "$bitrate"
        else
            row "Wi-Fi" "${YEL}not associated${R}"
        fi
    elif have nmcli; then
        ssid=$(nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | sed -n 's/^yes://p' | head -1)
        [ -n "$ssid" ] && row "Wi-Fi SSID" "$ssid"
    fi
}

show_iface() {
    local i=$1 sys=/sys/class/net/$1 mac mtu drv spd kind a rx tx first
    printf '\n  %s%s%s  %s\n' "$B" "$i" "$R" "$(status_label "$i")"

    if is_physical "$i"; then
        if [ -d "$sys/wireless" ] || [ -d "$sys/phy80211" ]; then
            kind="wireless"
        else
            kind="ethernet"
        fi
        drv=$(basename "$(readlink -f "$sys/device/driver" 2>/dev/null)" 2>/dev/null)
        subrow "Type" "$kind${drv:+  (driver: $drv)}"
    else
        subrow "Type" "$(virtual_kind "$i")"
    fi

    mac=$(cat "$sys/address" 2>/dev/null)
    mtu=$(cat "$sys/mtu" 2>/dev/null)
    [ -n "$mac" ] && subrow "MAC" "$mac"
    [ -n "$mtu" ] && subrow "MTU" "$mtu"

    spd=$(cat "$sys/speed" 2>/dev/null)
    if [ -n "$spd" ] && [ "$spd" -gt 0 ] 2>/dev/null; then
        subrow "Speed" "${spd} Mb/s"
    fi

    wireless_info "$i"

    first=1
    while read -r a; do
        [ -z "$a" ] && continue
        if [ $first -eq 1 ]; then subrow "IPv4" "${GRN}$a${R}"; first=0; else subrow "" "${GRN}$a${R}"; fi
    done < <(ip -4 -o addr show dev "$i" 2>/dev/null | awk '{print $4}')
    [ $first -eq 1 ] && subrow "IPv4" "${D}none${R}"

    first=1
    while read -r a; do
        [ -z "$a" ] && continue
        if [ $first -eq 1 ]; then subrow "IPv6" "$a"; first=0; else subrow "" "$a"; fi
    done < <(ip -6 -o addr show dev "$i" 2>/dev/null | awk '{print $4}')
    [ $first -eq 1 ] && subrow "IPv6" "${D}none${R}"

    rx=$(cat "$sys/statistics/rx_bytes" 2>/dev/null)
    tx=$(cat "$sys/statistics/tx_bytes" 2>/dev/null)
    if [ -n "$rx" ] && [ -n "$tx" ]; then
        subrow "Traffic" "↓ $(human "$rx")   ↑ $(human "$tx")"
    fi
}

sec_header() {
    printf '\n%s%s' "$B" "$MAG"
    printf '╔════════════════════════════════════════════════════════════════╗\n'
    printf '║%*s%s%*s║\n' 20 '' "NETWORK  OVERVIEW" 26 ''
    printf '╚════════════════════════════════════════════════════════════════╝\n'
    printf '%s' "$R"
    printf '  %s%s%s  •  %s  •  %s\n' "$D" "$(hostname 2>/dev/null)" "$R" "$(date '+%Y-%m-%d %H:%M:%S')" "$(uname -sr)"
}

sec_overview() {
    local route dev src gw fqdn
    section "Overview"
    fqdn=$(hostname -f 2>/dev/null || hostname 2>/dev/null)
    row "Hostname" "$fqdn"

    route=$(ip -4 route get 1.1.1.1 2>/dev/null | head -1)
    dev=$(printf '%s\n' "$route" | sed -n 's/.* dev \([^ ]*\).*/\1/p')
    src=$(printf '%s\n' "$route" | sed -n 's/.* src \([^ ]*\).*/\1/p')
    gw=$(ip -4 route show default 2>/dev/null | sed -n 's/^default via \([^ ]*\).*/\1/p' | head -1)

    if [ -n "$src" ]; then
        row "Private IPv4" "${GRN}${B}$src${R}"
        row "Default interface" "$dev"
        [ -n "$gw" ] && row "Default gateway" "$gw"
    else
        row "Private IPv4" "${RED}no active IPv4 route${R}"
    fi

    local v6
    v6=$(ip -6 -o addr show scope global 2>/dev/null | awk '{print $4}' | head -1)
    row "Global IPv6" "${v6:-${D}none${R}}"

    if have ping && [ -n "$gw" ]; then
        local ms
        ms=$(ping_ms "$gw")
        if [ -n "$ms" ]; then row "Gateway latency" "${GRN}${ms} ms${R}"; else row "Gateway latency" "${RED}unreachable${R}"; fi
    fi
}

sec_public() {
    local ip4 ip6 geo
    section "Public IP"
    if [ $SKIP_PUBLIC -eq 1 ]; then
        note "skipped (-n)"
        return
    fi
    if ! have curl && ! have wget; then
        note "curl or wget required"
        return
    fi
    ip4=$(http_get -4 https://api.ipify.org)
    [ -z "$ip4" ] && ip4=$(http_get -4 https://ifconfig.me)
    [ -z "$ip4" ] && ip4=$(http_get -4 https://icanhazip.com)
    ip6=$(http_get -6 https://api64.ipify.org)
    case "$ip6" in
        *:*) ;;
        *) ip6="" ;;
    esac

    if [ -n "$ip4" ]; then row "Public IPv4" "${GRN}${B}$ip4${R}"; else row "Public IPv4" "${RED}unavailable (offline?)${R}"; fi
    if [ -n "$ip6" ]; then row "Public IPv6" "${GRN}$ip6${R}"; else row "Public IPv6" "${D}none${R}"; fi

    if [ -n "$ip4" ]; then
        geo=$(http_get "https://ipinfo.io/$ip4/json")
        if [ -n "$geo" ]; then
            local host city region country org loc
            host=$(jget hostname "$geo")
            city=$(jget city "$geo")
            region=$(jget region "$geo")
            country=$(jget country "$geo")
            org=$(jget org "$geo")
            loc=$(jget timezone "$geo")
            [ -n "$host" ] && row "Reverse DNS" "$host"
            [ -n "$city$country" ] && row "Location" "${city}${region:+, $region}${country:+, $country}"
            [ -n "$org" ] && row "ISP / Org" "$org"
            [ -n "$loc" ] && row "Timezone" "$loc"
        fi
    fi
}

sec_physical() {
    local p i found=0
    section "Physical interfaces"
    for p in /sys/class/net/*; do
        i=${p##*/}
        is_physical "$i" || continue
        found=1
        show_iface "$i"
    done
    [ $found -eq 0 ] && note "none found"
}

sec_virtual() {
    local p i found=0
    section "Virtual interfaces"
    for p in /sys/class/net/*; do
        i=${p##*/}
        is_physical "$i" && continue
        found=1
        show_iface "$i"
    done
    [ $found -eq 0 ] && note "none found"
}

sec_routes() {
    section "Routing"
    printf '  %sIPv4%s\n' "$B" "$R"
    ip -4 route show 2>/dev/null | sed 's/^/    /'
    if [ -n "$(ip -6 route show 2>/dev/null | head -1)" ]; then
        printf '\n  %sIPv6%s\n' "$B" "$R"
        ip -6 route show 2>/dev/null | head -12 | sed 's/^/    /'
    fi
}

sec_dns() {
    local f=/etc/resolv.conf ns s e ms target proc found
    section "DNS"
    if [ -L "$f" ]; then
        target=$(readlink -f "$f")
        row "resolv.conf" "$f ${D}→ $target${R}"
    elif [ -e "$f" ]; then
        row "resolv.conf" "$f"
    else
        row "resolv.conf" "${RED}missing${R}"
    fi

    if [ -r "$f" ]; then
        local first=1
        for ns in $(awk '/^nameserver/{print $2}' "$f"); do
            if [ $first -eq 1 ]; then row "Nameservers" "$ns"; first=0; else row "" "$ns"; fi
        done
        [ $first -eq 1 ] && row "Nameservers" "${RED}none configured${R}"
        s=$(awk '/^search/{$1="";print substr($0,2)}' "$f" | head -1)
        [ -n "$s" ] && row "Search domains" "$s"
        s=$(awk '/^domain/{print $2}' "$f" | head -1)
        [ -n "$s" ] && row "Domain" "$s"
        s=$(awk '/^options/{$1="";print substr($0,2)}' "$f" | head -1)
        [ -n "$s" ] && row "Options" "$s"
    fi

    found=""
    for proc in unbound dnsmasq dnscrypt-proxy systemd-resolved NetworkManager named stubby resolvconf openresolv; do
        pgrep -x "$proc" >/dev/null 2>&1 && found="$found $proc"
    done
    [ -n "$found" ] && row "Resolver services" "${found# }"

    if have resolvconf; then
        row "resolvconf" "$(command -v resolvconf)"
    fi

    if [ -r "$f" ] && have dig; then
        printf '\n  %sNameserver response time%s\n' "$B" "$R"
        for ns in $(awk '/^nameserver/{print $2}' "$f"); do
            ms=$(dig +time=2 +tries=1 +noall +stats @"$ns" voidlinux.org 2>/dev/null | sed -n 's/.*Query time: \([0-9]*\) msec.*/\1/p')
            if [ -n "$ms" ]; then
                printf '    %s%-39s%s %s%s ms%s\n' "$BLU" "$ns" "$R" "$GRN" "$ms" "$R"
            else
                printf '    %s%-39s%s %sno response%s\n' "$BLU" "$ns" "$R" "$RED" "$R"
            fi
        done
    fi

    s=$EPOCHREALTIME
    if getent ahosts voidlinux.org >/dev/null 2>&1; then
        e=$EPOCHREALTIME
        ms=$(awk -v a="$s" -v b="$e" 'BEGIN{printf "%.0f",(b-a)*1000}')
        row "Resolve test" "voidlinux.org ${GRN}OK${R} ${D}(${ms} ms via system resolver)${R}"
    else
        row "Resolve test" "voidlinux.org ${RED}FAILED${R}"
    fi
}

dhcp_dhcpcd() {
    local i=$1 out k v
    have dhcpcd || return 1
    out=$(dhcpcd -U "$i" 2>/dev/null)
    printf '%s' "$out" | grep -q -E '^(ip_address|dhcp_server_identifier)=' || return 1
    get() { printf '%s\n' "$out" | sed -n "s/^$1=['\"]\{0,1\}\([^'\"]*\)['\"]\{0,1\}$/\1/p" | head -1; }
    row "Client" "dhcpcd"
    v=$(get dhcp_server_identifier); [ -n "$v" ] && row "DHCP server" "$v"
    v=$(get ip_address);             [ -n "$v" ] && row "Leased address" "$v"
    v=$(get subnet_mask);            [ -n "$v" ] && row "Subnet mask" "$v"
    v=$(get routers);                [ -n "$v" ] && row "Router(s)" "$v"
    v=$(get domain_name_servers);    [ -n "$v" ] && row "DNS servers" "$v"
    v=$(get domain_name);            [ -n "$v" ] && row "Domain" "$v"
    v=$(get ntp_servers);            [ -n "$v" ] && row "NTP servers" "$v"
    v=$(get dhcp_lease_time);        [ -n "$v" ] && row "Lease time" "$(dur "$v")"
    v=$(get dhcp_renewal_time);      [ -n "$v" ] && row "Renewal (T1)" "$(dur "$v")"
    v=$(get dhcp_rebinding_time);    [ -n "$v" ] && row "Rebinding (T2)" "$(dur "$v")"
    local lf mt lt
    lf=$(ls -t /var/db/dhcpcd/"$i"*.lease /var/lib/dhcpcd/"$i"*.lease 2>/dev/null | head -1)
    if [ -n "$lf" ]; then
        mt=$(stat -c %Y "$lf" 2>/dev/null)
        [ -n "$mt" ] && row "Lease updated" "$(date -d "@$mt" '+%Y-%m-%d %H:%M:%S')"
        lt=$(get dhcp_lease_time)
        if [ -n "$mt" ] && [ -n "$lt" ]; then
            row "Lease expires" "$(date -d "@$((mt+lt))" '+%Y-%m-%d %H:%M:%S')"
        fi
    fi
    return 0
}

dhcp_nm() {
    local i=$1 out k v
    have nmcli || return 1
    pgrep -x NetworkManager >/dev/null 2>&1 || return 1
    out=$(nmcli -t -f DHCP4 device show "$i" 2>/dev/null | sed 's/^DHCP4\.OPTION\[[0-9]*\]://')
    [ -n "$out" ] || return 1
    row "Client" "NetworkManager"
    for k in dhcp_server_identifier ip_address subnet_mask routers domain_name_servers domain_name ntp_servers dhcp_lease_time; do
        v=$(printf '%s\n' "$out" | sed -n "s/^ *$k = //p" | head -1)
        [ -z "$v" ] && continue
        case "$k" in
            dhcp_server_identifier) row "DHCP server" "$v" ;;
            ip_address)             row "Leased address" "$v" ;;
            subnet_mask)            row "Subnet mask" "$v" ;;
            routers)                row "Router(s)" "$v" ;;
            domain_name_servers)    row "DNS servers" "$v" ;;
            domain_name)            row "Domain" "$v" ;;
            ntp_servers)            row "NTP servers" "$v" ;;
            dhcp_lease_time)        row "Lease time" "$(dur "$v")" ;;
        esac
    done
    return 0
}

dhcp_dhclient() {
    local i=$1 f blk l
    for f in /var/lib/dhclient/dhclient.leases /var/lib/dhcp/dhclient.leases /var/lib/dhclient/dhclient."$i".leases /var/db/dhclient.leases; do
        [ -r "$f" ] || continue
        blk=$(awk -v ifc="$i" '/^lease/{b="";inl=1} inl{b=b $0 "\n"} /^}/{inl=0; if (b ~ "interface \"" ifc "\"") last=b} END{printf "%s", last}' "$f")
        [ -n "$blk" ] || continue
        row "Client" "dhclient"
        printf '%s\n' "$blk" | sed -n \
            -e 's/^ *option \(dhcp-server-identifier\|routers\|domain-name-servers\|domain-name\|subnet-mask\) \(.*\);/\1: \2/p' \
            -e 's/^ *\(fixed-address\|renew\|rebind\|expire\) \(.*\);/\1: \2/p' |
        while IFS= read -r l; do
            row "${l%%: *}" "${l#*: }"
        done
        return 0
    done
    return 1
}

dhcp_kernel() {
    local i=$1 lt
    lt=$(ip -4 -o addr show dev "$i" scope global 2>/dev/null | grep -o 'valid_lft [^ ]*' | head -1 | awk '{print $2}')
    [ -n "$lt" ] || return 1
    if [ "$lt" = "forever" ]; then
        row "Assignment" "static / permanent"
    else
        row "Assignment" "dynamic (lease)"
        row "Lease remaining" "$(dur "${lt%sec}")"
    fi
    return 0
}

sec_dhcp() {
    local p i clients c shown any=0
    section "DHCP"
    clients=""
    for c in dhcpcd dhclient udhcpc NetworkManager connmand iwd systemd-networkd; do
        pgrep -x "$c" >/dev/null 2>&1 && clients="$clients $c"
    done
    if [ -n "$clients" ]; then row "Active clients" "${clients# }"; else row "Active clients" "${D}none detected${R}"; fi

    for p in /sys/class/net/*; do
        i=${p##*/}
        [ "$i" = "lo" ] && continue
        ip -4 -o addr show dev "$i" scope global 2>/dev/null | grep -q . || continue
        any=1
        printf '\n  %s%s%s\n' "$B" "$i" "$R"
        shown=0
        dhcp_dhcpcd "$i" && shown=1
        [ $shown -eq 0 ] && dhcp_nm "$i" && shown=1
        [ $shown -eq 0 ] && dhcp_dhclient "$i" && shown=1
        [ $shown -eq 0 ] && { dhcp_kernel "$i" && shown=1; }
        [ $shown -eq 0 ] && note "no lease information available (try running as root)"
    done
    [ $any -eq 0 ] && { printf '\n'; note "no interface with a global IPv4 address"; }
}

sec_neighbors() {
    section "Neighbours (ARP)"
    local out
    out=$(ip -4 neigh show 2>/dev/null | grep -v FAILED | awk '{
        ip=$1; dev=""; mac=""; st=$NF
        for (i=1;i<=NF;i++) { if ($i=="dev") dev=$(i+1); if ($i=="lladdr") mac=$(i+1) }
        if (mac!="") printf "  %-16s %-18s %-10s %s\n", ip, mac, dev, st
    }')
    if [ -n "$out" ]; then
        printf '  %s%-16s %-18s %-10s %s%s\n' "$D" "ADDRESS" "MAC" "IFACE" "STATE" "$R"
        printf '%s\n' "$out"
    else
        note "no entries"
    fi
}

sec_listening() {
    section "Listening sockets"
    if ! have ss; then
        note "ss not available"
        return
    fi
    printf '  %s%-6s %s%s\n' "$D" "PROTO" "LOCAL ADDRESS" "$R"
    ss -H -tuln 2>/dev/null | awk '{printf "  %-6s %s\n",$1,$5}' | sort -u | head -30
}

sec_services() {
    local d n st found=0
    section "Network services (runit)"
    if [ ! -d /var/service ]; then
        note "/var/service not found"
        return
    fi
    for d in /var/service/*; do
        n=${d##*/}
        case "$n" in
            dhcpcd*|dhclient*|NetworkManager|wpa_supplicant*|iwd|dnsmasq|unbound|dnscrypt-proxy|openvpn*|wireguard*|sshd|connmand|ModemManager|dbus|nftables|iptables|ip6tables|ufw|chronyd|ntpd|openresolv|resolvconf|stubby|tor|hostapd|bluetoothd|wicd)
                found=1
                st=$(sv status "$d" 2>/dev/null | head -1)
                case "$st" in
                    run:*)  row "$n" "${GRN}● running${R} ${D}$(printf '%s' "$st" | sed 's/^run: [^:]*: //')${R}" ;;
                    down:*) row "$n" "${RED}● down${R}" ;;
                    *)      row "$n" "${YEL}● unknown${R}" ;;
                esac
                ;;
        esac
    done
    [ $found -eq 0 ] && note "no networking services enabled"
}

sec_connectivity() {
    local ms gw
    section "Connectivity"
    gw=$(ip -4 route show default 2>/dev/null | sed -n 's/^default via \([^ ]*\).*/\1/p' | head -1)
    if have ping; then
        for t in 1.1.1.1 8.8.8.8; do
            ms=$(ping_ms "$t")
            if [ -n "$ms" ]; then row "ping $t" "${GRN}${ms} ms${R}"; else row "ping $t" "${RED}no reply${R}"; fi
        done
    fi
    if getent ahosts voidlinux.org >/dev/null 2>&1; then
        row "Name resolution" "${GRN}working${R}"
    else
        row "Name resolution" "${RED}failing${R}"
    fi
    if [ $SKIP_PUBLIC -eq 0 ] && { have curl || have wget; }; then
        if http_get -I https://voidlinux.org >/dev/null 2>&1 || http_get https://voidlinux.org >/dev/null 2>&1; then
            row "HTTPS" "${GRN}working${R}"
        else
            row "HTTPS" "${RED}failing${R}"
        fi
    fi
}

main() {
    if ! have ip; then
        printf 'iproute2 is required: sudo xbps-install -S iproute2\n' >&2
        exit 1
    fi
    sec_header
    sec_overview
    sec_public
    sec_physical
    sec_virtual
    sec_routes
    sec_dns
    sec_dhcp
    sec_neighbors
    sec_listening
    sec_services
    sec_connectivity
    printf '\n'
}

main
