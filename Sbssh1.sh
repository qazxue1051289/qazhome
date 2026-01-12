#!/bin/bash
# ============================================================
# Alpine Linux SSH 自检与修复 + sing-box 清理 + 可达性测试
# ============================================================

echo "─────────────────────────────────────────────"
echo "🚀 SSH 自检 & 修复脚本开始执行..."
echo "─────────────────────────────────────────────"

# -----------------------
# 1️⃣ 清理 sing-box
# -----------------------
echo "▸ 停止 sing-box 服务..."
rc-service sing-box-socks5 stop 2>/dev/null

echo "▸ 杀掉 sing-box 进程..."
pkill -f sing-box 2>/dev/null

echo "▸ 删除 sing-box 文件与配置..."
rm -f /usr/local/sb/sing-box-socks5
rm -f /usr/local/bin/sing-box
rm -rf /usr/local/sb
rm -rf /etc/init.d/sing-box-socks5

echo "▸ 删除 sing-box 开机自启..."
rc-update del sing-box-socks5 2>/dev/null

echo "▸ 清理防火墙端口 12800-12900..."
for port in $(seq 12800 12900); do
  iptables -D INPUT -p tcp --dport $port -j ACCEPT 2>/dev/null
  ip6tables -D INPUT -p tcp --dport $port -j ACCEPT 2>/dev/null
done

# -----------------------
# 2️⃣ 安装并启动 SSH
# -----------------------
echo "▸ 检查 SSH 服务..."
if ! command -v sshd >/dev/null 2>&1; then
    echo "⚠️ openssh 未安装，正在安装..."
    apk add --no-cache openssh
    ssh-keygen -A >/dev/null 2>&1
else
    echo "✅ openssh 已安装"
fi

echo "▸ 检查 /etc/ssh/sshd_config 语法..."
if sshd -t 2>/dev/null; then
    echo "✅ sshd 配置文件语法正常"
else
    echo "❌ sshd 配置文件语法错误，请检查 /etc/ssh/sshd_config"
fi

echo "▸ 启动 SSH 服务..."
/etc/init.d/sshd restart >/dev/null 2>&1
sleep 1

# -----------------------
# 3️⃣ 放行端口
# -----------------------
echo "▸ 放行防火墙端口 22..."
iptables -C INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp --dport 22 -j ACCEPT
ip6tables -C INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null || ip6tables -I INPUT -p tcp --dport 22 -j ACCEPT

# -----------------------
# 4️⃣ 输出状态
# -----------------------
echo "─────────────────────────────────────────────"
echo "🔍 sshd 进程:"
ps aux | grep '[s]shd'
echo "─────────────────────────────────────────────"
echo "🔍 SSH 端口监听:"
netstat -lntp 2>/dev/null | grep :22
echo "─────────────────────────────────────────────"

# -----------------------
# 5️⃣ 测试本地 SSH
# -----------------------
echo "🔍 测试本地 SSH 连接..."
if ssh -o ConnectTimeout=3 localhost echo ok 2>/dev/null; then
    echo "✅ 本地 SSH 可用"
else
    echo "❌ 本地 SSH 不可用"
fi

# -----------------------
# 6️⃣ 测试远程可达性
# -----------------------
VPS_IP=$(ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | head -n1)
echo "🔍 测试远程可达性: $VPS_IP:22 ..."
if command -v nc >/dev/null 2>&1; then
    if nc -z -w3 $VPS_IP 22 >/dev/null 2>&1; then
        echo "✅ 远程端口 22 可达"
    else
        echo "❌ 远程端口 22 不可达，请检查安全组/云防火墙"
    fi
else
    echo "⚠️ 未安装 nc，无法测试远程端口"
fi

echo "─────────────────────────────────────────────"
echo "🎉 SSH 自检 & 修复完成！"
echo "💡 请尝试从远程客户端连接: ssh root@$VPS_IP"
echo "─────────────────────────────────────────────"
