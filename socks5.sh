#!/bin/sh
# =========================================
# sing-box SOCKS5 一键脚本（可中转版）
# =========================================

set -e

ACTION="$1"
SB_DIR="/usr/local/sb"
SB_BIN="$SB_DIR/sing-box"
SB_CONF="$SB_DIR/config.json"
SB_LOG="$SB_DIR/sing-box.log"

usage() {
  echo "用法: $0 {install|upgrade|status|link|uninstall}"
  echo "示例:"
  echo "PORT=12805 USERNAME=user PASSWORD=pass bash <(curl -Ls https://raw.githubusercontent.com/qazxue1051289/qazhome/main/socks5.sh) install"
  exit 1
}

[ -z "$ACTION" ] && usage

need_env() {
  if [ -z "$PORT" ] || [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo "❌ 必须设置 PORT USERNAME PASSWORD"
    exit 1
  fi
}

allow_firewall() {
  if command -v iptables >/dev/null 2>&1; then
    iptables -C INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null || \
    iptables -I INPUT -p tcp --dport "$PORT" -j ACCEPT
  fi
  if command -v ip6tables >/dev/null 2>&1; then
    ip6tables -C INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null || \
    ip6tables -I INPUT -p tcp --dport "$PORT" -j ACCEPT
  fi
}

install_sb() {
  need_env
  mkdir -p "$SB_DIR"

  echo "👉 下载 sing-box..."
  curl -Lso "$SB_BIN" https://github.com/SagerNet/sing-box/releases/latest/download/sing-box-linux-amd64
  chmod +x "$SB_BIN"

  echo "👉 生成可中转配置..."

  cat > "$SB_CONF" <<EOF
{
  "log": {
    "level": "info",
    "output": "$SB_LOG"
  },
  "inbounds": [
    {
      "type": "socks",
      "tag": "socks-in",
      "listen": "0.0.0.0",
      "listen_port": $PORT,
      "users": [
        {
          "user": "$USERNAME",
          "pass": "$PASSWORD"
        }
      ],
      "udp": true,
      "sniff": true,
      "outbound": "direct"
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
EOF

  allow_firewall

  echo "👉 启动 sing-box..."
  pkill -f "$SB_BIN" 2>/dev/null || true
  nohup "$SB_BIN" run -c "$SB_CONF" >/dev/null 2>&1 &

  sleep 1
  echo "✅ sing-box SOCKS5 已启动（支持中转）"
  show_info
}

show_info() {
  IPV4=$(curl -4 -s --max-time 2 ifconfig.me || true)
  IPV6=$(curl -6 -s --max-time 2 ifconfig.me || true)

  echo ""
  echo "📌 节点信息"
  echo "端口: $PORT"
  echo "用户名: $USERNAME"
  echo "密码: $PASSWORD"
  echo ""

  [ -n "$IPV4" ] && echo "🌐 IPv4: socks5://$USERNAME:$PASSWORD@$IPV4:$PORT"
  [ -n "$IPV6" ] && echo "🌐 IPv6: socks5://$USERNAME:$PASSWORD@[$IPV6]:$PORT"
}

status_sb() {
  if pgrep -f "$SB_BIN" >/dev/null; then
    echo "✅ sing-box 正在运行"
    show_info
  else
    echo "❌ sing-box 未运行"
  fi
}

uninstall_sb() {
  echo "👉 停止 sing-box..."
  pkill -f "$SB_BIN" 2>/dev/null || true
  rm -rf "$SB_DIR"
  echo "✅ 已卸载"
}

case "$ACTION" in
  install|upgrade) install_sb ;;
  status) status_sb ;;
  link) need_env; show_info ;;
  uninstall) uninstall_sb ;;
  *) usage ;;
esac
