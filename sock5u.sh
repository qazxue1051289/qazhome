#!/bin/bash
set -e

# =============================
# 参数检查
# =============================
[ -z "$PORT" ] && echo "❌ PORT missing" && exit 1
[ -z "$USERNAME" ] && echo "❌ USERNAME missing" && exit 1
[ -z "$PASSWORD" ] && echo "❌ PASSWORD missing" && exit 1

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
    echo "❌ Unsupported architecture: $ARCH"
    exit 1
fi

echo "👉 下载 sing-box $ARCH_NAME"
URL="https://github.com/SagerNet/sing-box/releases/download/v1.12.13/sing-box-1.12.13-linux-$ARCH_NAME.tar.gz"
curl -L -o /tmp/sing-box.tar.gz "$URL"
tar -xf /tmp/sing-box.tar.gz -C /tmp
install -m 755 /tmp/sing-box-*/sing-box "$BIN"
rm -rf /tmp/sing-box*

# =============================
# 生成 TCP-only socks5 配置
# =============================
cat > "$CFG" <<EOF
{
  "log": { "level": "info" },
  "inbounds": [
    {
      "type": "socks",
      "listen": "0.0.0.0",
      "listen_port": $PORT,
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
# 创建 systemd / OpenRC 服务
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
# 测试端口是否监听
# =============================
sleep 1
if ! ss -lnt | grep -q "$PORT"; then
    echo "⚠️ 端口 $PORT 没有被监听，请检查 VPS 防火墙或端口是否被占用！"
fi

# =============================
# 输出小火箭链接
# =============================
PUBLIC_IP=$(curl -s https://ipinfo.io/ip)

echo
echo "✅ TCP-only Socks5 节点已准备好！"
echo "IP: $PUBLIC_IP"
echo "端口: $PORT"
echo "用户名: $USERNAME"
echo "密码: $PASSWORD"
echo
echo "📲 小火箭可直接使用的 Socks5 链接："
echo "socks5://$USERNAME:$PASSWORD@$PUBLIC_IP:$PORT"
echo
echo "🎉 复制上面链接到客户端中使用即可"
