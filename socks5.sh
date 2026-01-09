#!/bin/sh
set -e

# 参数检查
[ -z "$PORT" ] && echo "PORT missing" && exit 1
[ -z "$USERNAME" ] && echo "USERNAME missing" && exit 1
[ -z "$PASSWORD" ] && echo "PASSWORD missing" && exit 1

SB_DIR="/usr/local/sb"
BIN="$SB_DIR/sing-box-socks5"
CFG="/etc/sing-box/config.json"

echo "👉 停止旧服务 & 清理残留进程"
rc-service sing-box-socks5 stop 2>/dev/null || true
pkill -9 sing-box 2>/dev/null || true
sleep 1

echo "👉 创建目录"
mkdir -p "$SB_DIR" /etc/sing-box

echo "👉 下载 sing-box 1.12.13"
curl -L -o /tmp/sing-box.tar.gz \
  https://github.com/SagerNet/sing-box/releases/download/v1.12.13/sing-box-1.12.13-linux-amd64.tar.gz
tar -xf /tmp/sing-box.tar.gz -C /tmp
install -m 755 /tmp/sing-box-*/sing-box "$BIN"
rm -rf /tmp/sing-box*

echo "👉 生成 socks5 配置"
cat > "$CFG" <<JSON
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
JSON

echo "👉 写 OpenRC service（不假死）"
cat > /etc/init.d/sing-box-socks5 <<'RC'
#!/sbin/openrc-run
command="/usr/local/sb/sing-box-socks5"
command_args="run -c /etc/sing-box/config.json"
command_background=true
pidfile="/run/sing-box-socks5.pid"
RC

chmod +x /etc/init.d/sing-box-socks5
rc-update add sing-box-socks5 default || true

echo "👉 启动服务"
rc-service sing-box-socks5 start
rc-service sing-box-socks5 status

# 获取公网 IP
PUBLIC_IP=$(curl -s https://ipinfo.io/ip)

echo
echo "✅ Socks5 节点已准备好！"
echo "IP: $PUBLIC_IP"
echo "端口: $PORT"
echo "用户名: $USERNAME"
echo "密码: $PASSWORD"

# 生成小火箭可直接使用的 Socks5 URL
echo
echo "📲 小火箭可直接使用的 Socks5 链接："
echo "socks5://$USERNAME:$PASSWORD@$PUBLIC_IP:$PORT"

echo
echo "🎉 复制上述链接即可在小火箭或支持 Socks5 URL 的客户端中直接导入使用"
