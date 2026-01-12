#!/bin/sh
# sing-box 中文一键安装脚本（强制输入 PORT USERNAME PASSWORD + 自动放行防火墙）
# 使用方法：
# PORT=端口 USERNAME=账号 PASSWORD=密码 bash <(curl -Ls https://你的GitHub路径/socks5.sh)

# =============================
# 强制检查环境变量
# =============================
if [ -z "$PORT" ] || [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo "❌ 错误：必须指定 PORT / USERNAME / PASSWORD"
    echo "示例：PORT=12806 USERNAME=hshshshs PASSWORD=jdjhdd bash <(curl -Ls https://你的GitHub路径/socks5.sh)"
    exit 1
fi

SB_DIR="/usr/local/sb"
SB_BIN="$SB_DIR/sing-box-socks5"
CONFIG_FILE="$SB_DIR/config.json"

# =============================
# 创建目录 & 下载 sing-box
# =============================
mkdir -p "$SB_DIR"
echo "👉 下载 sing-box 最新版本..."
curl -L -o "$SB_BIN" https://github.com/sing-box/sing-box/releases/download/v1.12.13/sing-box-linux-amd64
chmod +x "$SB_BIN"

# =============================
# 生成 socks5 配置
# =============================
echo "👉 生成 socks5 配置..."
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

# =============================
# 写 OpenRC 服务
# =============================
echo "👉 写 OpenRC 服务..."
cat > /etc/init.d/sing-box-socks5 <<'EOF'
#!/sbin/openrc-run
command=/usr/local/sb/sing-box-socks5
command_args="run -c /usr/local/sb/config.json"
pidfile=/var/run/sing-box-socks5.pid
name=sing-box-socks5
description="sing-box SOCKS5 服务"
EOF
chmod +x /etc/init.d/sing-box-socks5
rc-update add sing-box-socks5 default

# =============================
# 自动放行防火墙端口
# =============================
echo "👉 自动放行防火墙端口 $PORT ..."
iptables -I INPUT -p tcp --dport $PORT -j ACCEPT
echo "✅ 防火墙端口 $PORT 已放行"

# =============================
# 启动服务
# =============================
echo "👉 启动 sing-box 服务..."
rc-service sing-box-socks5 start

# =============================
# 输出小火箭可用链接
# =============================
VPS_IP=$(curl -s https://ifconfig.me)
echo "✅ Socks5 节点已准备好！"
echo "IP: $VPS_IP"
echo "端口: $PORT"
echo "用户名: $USERNAME"
echo "密码: $PASSWORD"
echo ""
echo "📲 小火箭可直接使用的 Socks5 链接："
echo "socks5://$USERNAME:$PASSWORD@$VPS_IP:$PORT"
