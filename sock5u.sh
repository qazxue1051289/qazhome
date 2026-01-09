#!/bin/bash
set -e

# -----------------------------
# 参数检查
# -----------------------------
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

# 删除可能存在的旧 SysV init 脚本，避免报错
if [ -f /etc/init.d/sing-box-socks5 ]; then
    echo "👉 删除旧的 SysV init 脚本"
    rm -f /etc/init.d/sing-box-socks5
fi

# -----------------------------
# 下载 sing-box
# -----------------------------
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    ARCH_NAME="amd64"
elif [[ "$ARCH" = aarch64* ]]; then
    ARCH_NAME="arm64"
else
    echo "Unsupported architecture: $ARCH" && exit 1
fi

URL="https://github.com/SagerNet/sing-box/releases/download/v1.12.13/sing-box-1.12.13-linux-$ARCH_NAME.tar.gz"

echo "👉 下载 sing-box $ARCH_NAME"
curl -L -o /tmp/sing-box.tar.gz "$URL"
tar -xf /tmp/sing-box.tar.gz -C /tmp
install -m 755 /tmp/sing-box-*/sing-box "$BIN"
rm -rf /tmp/sing-box*

# -----------------------------
# UDP 检测
# -----------------------------
echo "👉 检测 UDP 是否可用"
UDP_TEST_PORT=65530
UDP_MODE=false

# 尝试在本机打开 UDP 套接字测试
if timeout 1 bash -c "echo '' >/dev/udp/127.0.0.1/$UDP_TEST_PORT" 2>/dev/null; then
    UDP_MODE=true
fi

if [ "$UDP_MODE" = true ]; then
    echo "UDP 可用 → 配置 TCP+UDP"
else
    echo "UDP 不可用 → 配置 TCP-only"
fi

# -----------------------------
# 生成配置
# -----------------------------
cat > "$CFG" <<JSON
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
JSON

# -----------------------------
# 创建服务
# -----------------------------
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
    systemctl start sing-box-socks5
    systemctl status sing-box-socks5 --no-pager
elif command -v rc-service >/dev/null 2>&1; then
    echo "👉 OpenRC detected, 创建服务"
    SERVICE="/etc/init.d/sing-box-socks5"
    cat > "$SERVICE" <<'RC'
#!/sbin/openrc-run
command="/usr/local/sb/sing-box-socks5"
command_args="run -c /etc/sing-box/config.json"
command_background=true
pidfile="/run/sing-box-socks5.pid"
RC
    chmod +x "$SERVICE"
    rc-update add sing-box-socks5 default || true
    rc-service sing-box-socks5 start
else
    echo "Unsupported init system" && exit 1
fi

# -----------------------------
# 输出小火箭链接
# -----------------------------
PUBLIC_IP=$(curl -s https://ipinfo.io/ip)

echo
echo "✅ Socks5 节点已准备好！"
echo "IP: $PUBLIC_IP"
echo "端口: $PORT"
echo "用户名: $USERNAME"
echo "密码: $PASSWORD"
echo "模式: $([ "$UDP_MODE" = true ] && echo 'TCP+UDP' || echo 'TCP-only')"
echo
echo "📲 小火箭可直接使用的 Socks5 链接："
echo "socks5://$USERNAME:$PASSWORD@$PUBLIC_IP:$PORT"
echo
echo "🎉 复制上述链接即可在小火箭或支持 Socks5 的客户端直接使用"
