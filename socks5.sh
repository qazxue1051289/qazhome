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
  echo "👉 TCP 出口检测 (1.1.1.1:443)"
  if ! timeout 5 sh -c "echo | nc -w 3 1.1.1.1 443" 2>/dev/null; then
    echo "❌ TCP 443 出口不可达"
    echo "❌ 当前 VPS 不适合作为代理节点"
    exit 1
  fi

  echo "👉 HTTPS 连通性检测"
  if ! curl -I --max-time 8 https://www.google.com >/dev/null 2>&1; then
    echo "❌ HTTPS 出口异常（可能被劫持或封锁）"
    echo "❌ 已终止安装"
    exit 1
  fi
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
