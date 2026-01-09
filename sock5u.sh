#!/bin/bash
set -e

# =============================
# 参数检查
# =============================
[ -z "$PORT" ] && echo "PORT missing" && exit 1
[ -z "$USERNAME" ] && echo "USERNAME missing" && exit 1
[ -z "$PASSWORD" ] && echo "PASSWORD missing" && exit 1

SB_DIR="/usr/local/sb"
BIN="$SB_DIR/sing-box-socks5"
CFG="/etc/sing-box/config.json"

mkdir -p "$SB_DIR" /etc/sing-box

echo "👉 停止旧服务 & 清理残留进程"
if command -v systemctl >/dev/null 2>&1; then
    systemctl stop sing-box-socks5 2>/dev/null || true
else
    rc-service sing-box-socks5 stop 2>/dev/null || true
fi
pkill -9 sing-box 2>/dev/null || true
sleep 1

# 删除旧 OpenRC 脚本避免冲突
rm -f /etc/init.d/sing-box-socks5

# =============================
# 下载 sing-box
# =============================
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    ARCH_NAME="amd64"
elif [[ "$ARCH" =~ ^aarch64 ]]; then
    ARCH_NAME="arm64"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

echo "👉 下载 sing-box $ARCH_NAME"
URL="https://github.com/SagerNet/sing-box/releases/download/v1.12.13/sing-box-1.12.13-linux-$ARCH_NAME.tar.gz"
curl -L -o /tmp/sing-box.tar.gz "$URL"
tar -xf /tmp/sing-box.tar.gz -C /tmp
install -m 755 /tmp/sing-box-*/sing-box "$BIN"
rm -rf /tmp/sing-box*

# =============================
# UDP 检测
# =============================
echo "👉 检测 UDP 是否可用"
UDP_MODE=false
if timeout 1 bash -c "echo >/dev/udp/127.0.0.1/$PORT" 2>/dev/null; then
    UDP_MODE=true
fi

echo "👉 UDP mode: $([ "$UDP_MODE" = true ] && echo 'TCP+UDP' || echo 'TCP-only')"

# =============================
# 生成 socks5 配置
# =============================
cat > "$CFG" <<EOF
{
  "log": { "level": "info" },
  "inbounds": [
    {
      "type": "socks",
      "listen": "0.0.0.0",
      "listen_port": $PORT,
      "udp": $UDP_MODE,
      "users": [
        { "username": "$USERNAME", "password": "$PASSWORD" }
      ]
    }
  ],
  "outbounds": [
    { "type": "direct" }
  ]
}
EOF

# =============================
# systemd / OpenRC 管理
# =============================
if command -v systemctl >/dev/null 2>&1; then
    echo "👉 systemd detected, 创建服务"
    SERVICE="/etc/systemd/system/sing-box-socks5.service"
    cat > "$SERVICE" <<EOF
[Unit]
Description=sing-box Socks5
After=network.target

[Service]
ExecStart=$BIN run -c $CFG
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable sing-box-socks5
    systemctl restart sing-box-socks5
elif command -v rc-service >/dev/null 2>&1; then
    echo "👉 OpenRC detected, 创建服务"
    SERVICE="/etc/init.d/sing-box-socks5"
    cat > "$SERVICE" <<'EORC'
#!/sbin/openrc-run
command="/usr/local/sb/sing-box-socks5"
command_args="run -c /etc/sing-box/config.json"
command_background=true
pidfile="/run/sing-box-socks5.pid"
EORC
    chmod +x "$SERVICE"
    rc-update add sing-box-socks5 default || true
    rc-service sing-box-socks5 restart
fi

# =============================
# 输出链接
# =============================
PUBLIC_IP=$(curl -s https://ipinfo.io/ip)

echo
echo "✅ Socks5 节点已准备好！"
echo "🔗 链接格式（小火箭/Clash可用）："
echo "socks5://$USERNAME:$PASSWORD@$PUBLIC_IP:$PORT"
echo
echo "📦 当前模式： $([ "$UDP_MODE" = true ] && echo 'TCP+UDP' || echo 'TCP-only')"
echo
echo "👉 复制上面链接到客户端中使用即可"
