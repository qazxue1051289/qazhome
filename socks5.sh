#!/bin/sh
# sing-box 中文一键安装/升级/管理脚本（IPv4 + IPv6）
# 强制输入：PORT=端口 USERNAME=账号 PASSWORD=密码
# 使用方法：
# PORT=12806 USERNAME=hshshshs PASSWORD=jdjhdd bash <(curl -Ls https://你的GitHub路径/socks5.sh)

SB_DIR="/usr/local/sb"
SB_BIN="$SB_DIR/sing-box-socks5"
CONFIG_FILE="$SB_DIR/config.json"
SERVICE_NAME="sing-box-socks5"

# =============================
# 功能函数
# =============================

# 强制检查环境变量
check_env() {
    if [ -z "$PORT" ] || [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
        echo "❌ 错误：必须指定 PORT / USERNAME / PASSWORD"
        echo "示例：PORT=12806 USERNAME=hshshshs PASSWORD=jdjhdd bash <(curl -Ls https://你的GitHub路径/socks5.sh) install"
        exit 1
    fi
}

# 安装或升级 sing-box
install_or_upgrade() {
    mkdir -p "$SB_DIR"
    echo "👉 下载最新 sing-box..."
    curl -L -o "$SB_BIN" https://github.com/sing-box/sing-box/releases/download/v1.12.13/sing-box-linux-amd64
    chmod +x "$SB_BIN"

    echo "👉 生成/更新 socks5 配置..."
    cat > "$CONFIG_FILE" <<EOF
{
  "log": {"level":"info"},
  "inbounds":[
    {
      "type":"socks",
      "listen":"0.0.0.0",
      "listen_port":$PORT,
      "users":[
        {"username":"$USERNAME","password":"$PASSWORD"}
      ]
    }
  ],
  "outbounds":[{"type":"direct"}]
}
EOF

    echo "👉 写 OpenRC 服务..."
    cat > /etc/init.d/$SERVICE_NAME <<'EOF'
#!/sbin/openrc-run
command=/usr/local/sb/sing-box-socks5
command_args="run -c /usr/local/sb/config.json"
pidfile=/var/run/sing-box-socks5.pid
name=sing-box-socks5
description="sing-box SOCKS5 服务"
EOF
    chmod +x /etc/init.d/$SERVICE_NAME
    rc-update add $SERVICE_NAME default

    echo "👉 自动放行防火墙端口 $PORT ..."
    iptables -I INPUT -p tcp --dport $PORT -j ACCEPT
    echo "✅ 防火墙端口 $PORT 已放行"

    # 重启服务保证升级生效
    if rc-service $SERVICE_NAME status >/dev/null 2>&1; then
        echo "👉 停止旧服务..."
        rc-service $SERVICE_NAME stop
    fi
    echo "👉 启动 sing-box 服务..."
    rc-service $SERVICE_NAME start

    echo "✅ 安装/升级完成！"
    show_link
}

# 输出小火箭 IPv4 + IPv6 链接
show_link() {
    VPS_IPV4=$(curl -4 -s https://ifconfig.me)
    VPS_IPV6=$(curl -6 -s https://ifconfig.me)
    echo "📌 当前 Socks5 节点信息："
    echo "端口: $PORT"
    echo "用户名: $USERNAME"
    echo "密码: $PASSWORD"
    echo ""
    echo "🌐 小火箭 IPv4 链接："
    echo "socks5://$USERNAME:$PASSWORD@$VPS_IPV4:$PORT"
    echo "🌐 小火箭 IPv6 链接："
    echo "socks5://$USERNAME:$PASSWORD@[$VPS_IPV6]:$PORT"
}

# 查看已布置节点信息
status_node() {
    if [ -f "$CONFIG_FILE" ]; then
        PORT=$(jq .inbounds[0].listen_port "$CONFIG_FILE" 2>/dev/null)
        USERNAME=$(jq -r .inbounds[0].users[0].username "$CONFIG_FILE" 2>/dev/null)
        PASSWORD=$(jq -r .inbounds[0].users[0].password "$CONFIG_FILE" 2>/dev/null)
        VPS_IPV4=$(curl -4 -s https://ifconfig.me)
        VPS_IPV6=$(curl -6 -s https://ifconfig.me)
        echo "📌 当前已布置的 Socks5 节点："
        echo "端口: $PORT"
        echo "用户名: $USERNAME"
        echo "密码: $PASSWORD"
        echo "IPv4 链接：socks5://$USERNAME:$PASSWORD@$VPS_IPV4:$PORT"
        echo "IPv6 链接：socks5://$USERNAME:$PASSWORD@[$VPS_IPV6]:$PORT"
    else
        echo "❌ 尚未布置任何 Socks5 节点"
    fi
}

# 卸载所有 sing-box
uninstall() {
    echo "⚠️ 卸载 sing-box..."
    rc-service $SERVICE_NAME stop 2>/dev/null
    rc-update del $SERVICE_NAME default 2>/dev/null
    rm -f /etc/init.d/$SERVICE_NAME
    rm -rf "$SB_DIR"
    echo "✅ 卸载完成！"
    echo "💡 注意：防火墙规则需手动删除，例如："
    echo "iptables -D INPUT -p tcp --dport $PORT -j ACCEPT"
}

# =============================
# 主菜单
# =============================
case "$1" in
install|upgrade)
    check_env
    install_or_upgrade
    ;;
link)
    check_env
    show_link
    ;;
status)
    status_node
    ;;
uninstall)
    uninstall
    ;;
*)
    echo "用法: $0 {install|upgrade|link|status|uninstall}"
    echo "示例：PORT=12806 USERNAME=hshshshs PASSWORD=jdjhdd bash <(curl -Ls https://你的GitHub路径/socks5.sh) install"
    ;;
esac
