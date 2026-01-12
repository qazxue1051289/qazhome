#!/bin/bash
# ============================================================
# Alpine Linux SSH 自检与修复脚本
# 功能：
# 1. 检查 sshd 是否安装
# 2. 检查配置文件语法
# 3. 启动 sshd 服务
# 4. 放行防火墙端口 22
# 5. 输出最终状态
# ============================================================

echo "─────────────────────────────────────────────"
echo "🚀 SSH 自检与修复脚本开始执行..."
echo "─────────────────────────────────────────────"

# 1️⃣ 检查 sshd 是否安装
if ! command -v sshd >/dev/null 2>&1; then
    echo "⚠️ openssh 未安装，正在安装..."
    apk add --no-cache openssh
    ssh-keygen -A >/dev/null 2>&1
else
    echo "✅ openssh 已安装"
fi

# 2️⃣ 检查 sshd 配置文件语法
echo "▸ 检查 /etc/ssh/sshd_config 语法..."
if sshd -t 2>/dev/null; then
    echo "✅ sshd 配置文件语法正常"
else
    echo "❌ sshd 配置文件语法错误，请检查 /etc/ssh/sshd_config"
fi

# 3️⃣ 启动 sshd 服务
echo "▸ 启动 sshd 服务..."
/etc/init.d/sshd restart >/dev/null 2>&1
sleep 1

# 4️⃣ 检查 sshd 是否在运行
if ps aux | grep '[s]shd' >/dev/null 2>&1; then
    echo "✅ sshd 服务正在运行"
else
    echo "❌ sshd 服务未启动"
fi

# 5️⃣ 检查 22 端口监听
echo "▸ 检查 22 端口监听..."
if netstat -lntp 2>/dev/null | grep -q ':22'; then
    echo "✅ SSH 端口 22 正常监听"
else
    echo "❌ SSH 端口 22 未监听"
fi

# 6️⃣ 放行防火墙端口 22
echo "▸ 放行防火墙端口 22..."
iptables -C INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp --dport 22 -j ACCEPT
ip6tables -C INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null || ip6tables -I INPUT -p tcp --dport 22 -j ACCEPT

# 7️⃣ 显示最终状态
echo "─────────────────────────────────────────────"
echo "🔍 最终状态："
ps aux | grep '[s]shd'
netstat -lntp | grep :22
echo "─────────────────────────────────────────────"
echo "💡 建议：尝试本地连接：ssh localhost"
echo "💡 如果本地可以连接，则远程连接应可用（注意安全组或端口映射）"
echo "─────────────────────────────────────────────"
echo "🎉 SSH 自检与修复完成！"
