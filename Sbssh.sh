#!/bin/bash
# ========================================
# Sing-box 清理并恢复 SSH 服务脚本
# 适用于 Alpine Linux
# ========================================

echo "─────────────────────────────────────────────"
echo "🚀 开始清理 sing-box 并恢复 SSH 服务..."
echo "─────────────────────────────────────────────"

# 1️⃣ 停止 sing-box 服务
echo "▸ 停止 sing-box 服务..."
rc-service sing-box-socks5 stop 2>/dev/null

# 2️⃣ 杀掉所有 sing-box 进程
echo "▸ 杀掉 sing-box 进程..."
pkill -f sing-box 2>/dev/null

# 3️⃣ 删除 sing-box 文件与配置
echo "▸ 删除 sing-box 文件与配置..."
rm -f /usr/local/sb/sing-box-socks5
rm -f /usr/local/bin/sing-box
rm -rf /usr/local/sb
rm -rf /etc/init.d/sing-box-socks5

# 4️⃣ 删除开机自启
echo "▸ 删除 sing-box 开机自启..."
rc-update del sing-box-socks5 2>/dev/null

# 5️⃣ 清理防火墙端口 12800-12900
echo "▸ 清理防火墙端口 12800-12900..."
for port in $(seq 12800 12900); do
  iptables -D INPUT -p tcp --dport $port -j ACCEPT 2>/dev/null
  ip6tables -D INPUT -p tcp --dport $port -j ACCEPT 2>/dev/null
done

# 6️⃣ 安装并启动 SSH
echo "▸ 确认 SSH 服务..."
if ! command -v sshd >/dev/null 2>&1; then
  echo "⚠️ openssh 未安装，正在安装..."
  apk add --no-cache openssh
fi

# 生成 host key
ssh-keygen -A >/dev/null 2>&1

# 启动 SSH 服务
echo "▸ 启动 SSH 服务..."
/etc/init.d/sshd start 2>/dev/null

# 7️⃣ 检查端口监听
echo "▸ 检查 SSH 端口监听..."
if netstat -lntp 2>/dev/null | grep -q ':22'; then
  echo "✅ SSH 服务已启动，端口 22 正常监听"
else
  echo "❌ SSH 端口 22 未监听，请检查 /etc/ssh/sshd_config"
fi

# 8️⃣ 显示 sing-box 残留进程
echo "▸ 检查 sing-box 残留进程..."
if ps aux | grep '[s]ing-box' >/dev/null 2>&1; then
  echo "❌ 仍有 sing-box 进程，请手动检查"
else
  echo "✅ 未检测到 sing-box 进程"
fi

echo "─────────────────────────────────────────────"
echo "🎉 sing-box 已清理完毕，SSH 服务应可正常使用"
echo "─────────────────────────────────────────────"
