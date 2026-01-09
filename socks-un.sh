#!/bin/sh
set -e

SB_DIR="/usr/local/sb"
CFG="/etc/sing-box/config.json"
SERVICE="/etc/init.d/sing-box-socks5"

echo "👉 停止 Socks5 服务"
rc-service sing-box-socks5 stop 2>/dev/null || true
pkill -9 sing-box 2>/dev/null || true
sleep 1

echo "👉 移除 OpenRC 服务"
rc-update del sing-box-socks5 default 2>/dev/null || true
[ -f "$SERVICE" ] && rm -f "$SERVICE"

echo "👉 删除配置文件"
[ -f "$CFG" ] && rm -f "$CFG"

echo "👉 删除可执行文件"
[ -f "$SB_DIR/sing-box-socks5" ] && rm -f "$SB_DIR/sing-box-socks5"

# 可选：删除目录（如果为空）
rmdir "$SB_DIR" 2>/dev/null || true
rmdir /etc/sing-box 2>/dev/null || true

echo
echo "✅ Socks5 已完全卸载完成！"
