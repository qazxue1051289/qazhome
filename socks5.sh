#!/bin/sh
# =====================================
# Sing-Box SOCKS5 一键安装/管理脚本
# 支持 IPv4 + IPv6
# =====================================

# 检查参数
if [ -z "$1" ]; then
    echo "用法: $0 {install|upgrade|link|status|uninstall}"
    echo "示例：PORT=12805 USERNAME=fsst PASSWORD=jbvcd bash <(curl -Ls https://raw.githubusercontent.com/qazxue1051289/qazhome/main/socks5.sh) install"
    exit 1
fi

ACTION="$1"

# 检查 PORT / USERNAME / PASSWORD
if [ "$ACTION" = "install" ] || [ "$ACTION" = "upgrade" ] || [ "$ACTION" = "link" ]; then
    if [ -z "$PORT" ] || [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
        echo "❌ 请设置 PORT、USERNAME、PASSWORD 环境变量"
        exit 1
    fi
fi

SB_DIR="/usr/local/sb"
SB_BIN="$SB_DIR/sing-box-socks5"
SB_CONF="$SB_DIR/config.json"
SB_LOG="$SB_DIR/sing-box.log"

# 自动放行防火墙
firewall_allow() {
    if command -v iptables >/dev/null 2>&1; then
        iptables -C INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null || \
        iptables -I INPUT -p tcp --dport "$PORT" -j ACCEPT
        echo "✅ 防火墙端口 $PORT 已放行"
    fi
    if command -v ip6tables >/dev/null 2>&1; then
        ip6tables -C INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null || \
        ip6tables -I INPUT -p tcp --dport "$PORT" -j ACCEPT
        echo "✅ IPv6 防火墙端口 $PORT 已放行"
    fi
}

# 安装 / 升级 sing-box
install_singbox() {
    echo "👉 下载 sing-box 最新版本..."
    mkdir -p "$SB_DIR"
    curl -Lso "$SB_BIN" "https://github.com/SagerNet/sing-box/releases/latest/download/sing-box-linux-amd64"
    chmod +x "$SB_BIN"

    echo "👉 生成配置文件..."
    cat > "$SB_CONF" <<EOF
{
  "inbounds": [{
    "type": "socks",
    "listen": "0.0.0.0:$PORT",
    "listen_ipv6": "[::]:$PORT",
    "users": [{
      "user": "$USERNAME",
      "pass": "$PASSWORD"
    }]
  }]
}
EOF

    firewall_allow

    echo "👉 启动 sing-box 服务..."
    "$SB_BIN" run -c "$SB_CONF" > "$SB_LOG" 2>&1 &
    sleep 1
    echo "✅ Socks5 节点已准备好！"

    show_links
}

# 显示节点信息和链接
show_links() {
    IPV4=$(curl -4 -s ifconfig.me)
    IPV6=$(curl -6 -s ifconfig.me)

    echo "📌 节点信息："
    echo "端口: $PORT"
    echo "用户名: $USERNAME"
    echo "密码: $PASSWORD"
    echo ""
    echo "🌐 小火箭 IPv4 链接："
    echo "socks5://$USERNAME:$PASSWORD@$IPV4:$PORT"
    echo ""
    echo "🌐 小火箭 IPv6 链接："
    echo "socks5://$USERNAME:$PASSWORD@[$IPV6]:$PORT"
}

# 查看服务状态
status_singbox() {
    if pgrep -f "$SB_BIN" >/dev/null 2>&1; then
        echo "✅ sing-box-socks5 正在运行"
        show_links
    else
        echo "❌ sing-box-socks5 未运行"
    fi
}

# 卸载服务
uninstall_singbox() {
    echo "👉 停止 sing-box 服务..."
    pkill -f "$SB_BIN"
    echo "👉 删除文件..."
    rm -rf "$SB_DIR"
    echo "✅ 卸载完成"
}

# 执行动作
case "$ACTION" in
    install|upgrade)
        install_singbox
        ;;
    status)
        status_singbox
        ;;
    link)
        show_links
        ;;
    uninstall)
        uninstall_singbox
        ;;
    *)
        echo "❌ 未知命令: $ACTION"
        exit 1
        ;;
esac
