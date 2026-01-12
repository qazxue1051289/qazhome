#!/usr/bin/env bash
set -e

ACTION="$1"

SB_DIR="/usr/local/sb"
SB_BIN="$SB_DIR/sing-box-socks5"
CONF="$SB_DIR/config.json"
SERVICE="/etc/init.d/sing-box-socks5"

require_env() {
  [ -z "$PORT" ] && echo "❌ 必须指定 PORT" && exit 1
  [ -z "$USERNAME" ] && echo "❌ 必须指定 USERNAME" && exit 1
  [ -z "$PASSWORD" ] && echo "❌ 必须指定 PASSWORD" && exit 1
}

self_check() {
  echo "👉 [自检] TCP 出口检测 (1.1.1.1:443)"
  if ! timeout 5 sh -c "echo | nc -w 3 1.1.1.1 443" >/dev/null 2>&1; then
    echo
    echo "❌ TCP 443 无法建立连接（超时或被阻断）"
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "❌ 结论：此 VPS 不适合用作代理节点"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "原因说明："
    echo "- ICMP (ping) 可通"
    echo "- 但 TCP 出口被封锁或严重限速"
    echo "- socks5 / HTTP / HTTPS 无法正常工作"
    echo
    echo "常见原因："
    echo "- NAT / 特价 VPS"
    echo "- 商家限制国际 TCP 出口"
    echo "- 仅允许 ICMP 或白名单流量"
    echo
    echo "建议："
    echo "- 更换 VPS 商家或线路"
    echo "- 选择明确支持代理 / 中转的 VPS"
    echo
    echo "脚本已安全退出，未进行任何安装。"
    exit 1
  fi

  echo "👉 [自检] HTTPS 连通性检测"
  if ! curl -I --max-time 8 https://www.google.com >/dev/null 2>&1; then
    echo
    echo "❌ HTTPS 请求异常或被劫持"
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "❌ 结论：此 VPS 不适合用作代理节点"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "原因说明："
    echo "- TCP 可连，但 HTTPS 流量异常"
    echo "- 代理流量将无法正常使用"
    echo
    echo "建议："
    echo "- 更换干净的国际线路 VPS"
    echo
    echo "脚本已安全退出，未进行任何安装。"
    exit 1
  fi

  echo "✅ [自检] TCP / HTTPS 出口正常"
}
install_singbox() {
  mkdir -p "$SB_DIR"
  if [ ! -f "$SB_BIN" ]; then
    echo "👉 下载 sing-box"
    curl -L https://github.com/SagerNet/sing-box/releases/latest/download/sing-box-linux-amd64 -o "$SB_BIN"
    chmod +x "$SB_BIN"
  fi
}

write_config() {
cat > "$CONF" <<EOF
{
  "inbounds": [
    {
      "type": "socks",
      "listen": "::",
      "listen_port": $PORT,
      "users": [
        {
          "username": "$USERNAME",
          "password": "$PASSWORD"
        }
      ]
    }
  ],
  "outbounds": [
    { "type": "direct" }
  ]
}
EOF
}

open_port() {
  echo "👉 自动放行防火墙端口 $PORT"
  iptables -I INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null || true
  ip6tables -I INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null || true
}

write_service() {
cat > "$SERVICE" <<EOF
#!/sbin/openrc-run
command="$SB_BIN"
command_args="run -c $CONF"
command_background="yes"
pidfile="/run/sing-box-socks5.pid"
EOF
  chmod +x "$SERVICE"
  rc-update add sing-box-socks5 default >/dev/null 2>&1 || true
}

start_service() {
  rc-service sing-box-socks5 stop >/dev/null 2>&1 || true
  rc-service sing-box-socks5 start
}

show_info() {
  IPV4=$(curl -4 -s ifconfig.me || echo "无")
  IPV6=$(curl -6 -s ifconfig.me || echo "无")

  echo
  echo "✅ Socks5 节点已准备好！"
  echo "IPv4: $IPV4"
  echo "IPv6: $IPV6"
  echo "端口: $PORT"
  echo "用户名: $USERNAME"
  echo "密码: $PASSWORD"
  echo
  [ "$IPV4" != "无" ] && echo "socks5://$USERNAME:$PASSWORD@$IPV4:$PORT"
  [ "$IPV6" != "无" ] && echo "socks5://$USERNAME:$PASSWORD@[$IPV6]:$PORT"
}

status() {
  rc-service sing-box-socks5 status || true
  netstat -lntp | grep sing-box || true
}

uninstall() {
  rc-service sing-box-socks5 stop || true
  rc-update del sing-box-socks5 default || true
  rm -rf "$SB_DIR" "$SERVICE"
  echo "✅ sing-box 已完全卸载"
}

case "$ACTION" in
  install)
    require_env
    self_check
    install_singbox
    write_config
    open_port
    write_service
    start_service
    show_info
    ;;
  status)
    status
    ;;
  link)
    require_env
    show_info
    ;;
  uninstall)
    uninstall
    ;;
  *)
    echo "用法: $0 {install|status|link|uninstall}"
    echo "示例："
    echo "PORT=12806 USERNAME=user PASSWORD=pass bash <(curl -Ls https://raw.githubusercontent.com/qazxue1051289/qazhome/main/socks5.sh) install"
    ;;
esac
