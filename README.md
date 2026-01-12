# Socks5 自检版脚本说明（Alpine / OpenRC 支持）

PORT=端口 USERNAME=账号 PASSWORD=密码 bash <(curl -Ls https://raw.githubusercontent.com/qazxue1051289/qazhome/main/socks5.sh) install

本脚本用于快速部署 socks5 节点，特点：
- 强制要求 PORT / USERNAME / PASSWORD，无默认值
- 自动生成 sing-box 配置文件并启动服务
- 自动放行防火墙端口（iptables / ip6tables）
- 显示 IPv4 + IPv6 节点信息
- 支持命令：install | status | link | uninstall
- 自检 VPS TCP/HTTPS 出口，不合格自动退出

用法示例：
PORT=12806 USERNAME=myuser PASSWORD=mypass \
bash <(curl -Ls https://raw.githubusercontent.com/qazxue1051289/qazhome/main/socks5.sh) install

查看状态：
bash <(curl -Ls https://raw.githubusercontent.com/qazxue1051289/qazhome/main/socks5.sh) status

获取节点链接：
PORT=12806 USERNAME=myuser PASSWORD=mypass \
bash <(curl -Ls https://raw.githubusercontent.com/qazxue1051289/qazhome/main/socks5.sh) link

卸载：
bash <(curl -Ls https://raw.githubusercontent.com/qazxue1051289/qazhome/main/socks5.sh) uninstall

自检说明：
脚本在安装前会执行两步自检：
1. TCP 出口检测（1.1.1.1:443）
2. HTTPS 连通性检测（访问 https://www.google.com）
若自检失败，脚本会直接退出，并输出明确原因和建议，不会生成任何节点。

示例输出（VPS 不合适）：
👉 [自检] TCP 出口检测 (1.1.1.1:443)
❌ TCP 443 无法建立连接（超时或被阻断）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
❌ 结论：此 VPS 不适合用作代理节点
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
原因说明：
- ICMP (ping) 可通
- 但 TCP 出口被封锁或严重限速
- socks5 / HTTP / HTTPS 无法正常转发
建议：
- 更换 VPS 商家或线路
- 选择明确支持代理 / 中转的 VPS

可用机型 / 线路说明：
| 机型 / 线路 | 特点 | 注意事项 |
|------------|------|---------|
| VPS 商家自选“支持国际 TCP 出口” | TCP / HTTPS 出口畅通 | ICMP 仅通不行 |
| 官方 CN2 / JP / SG / US 线路 VPS（不含免费 / 特价机） | TCP / HTTPS 出口可用 | 建议先测试 telnet 1.1.1.1 443 |
| 付费 VPS 高速段（非 NAT 小鸡） | IPv4 + IPv6 均可用 | 确认 TCP 出口未限速 |

不适合的机型示例：
- NAT 小鸡 / 特价机 / 测试机
- 仅允许 ICMP ping 可达，TCP/HTTPS 出口被封
- 商家对国际端口限速 / 阻断

注意事项：
- 脚本仅支持 Alpine Linux / OpenRC，Debian/Ubuntu 需改 init 系统
- 必须先安装依赖：
apk add --no-cache busybox-extras curl
- 脚本自检失败后不会安装任何服务
- 节点导入小火箭或其他客户端前，必须保证 VPS TCP 出口可用

自检行为总结：
- TCP/HTTPS 出口畅通 → 脚本安装并生成可用 socks5 节点
- TCP 被封 / HTTPS 被劫持 → 脚本直接退出，并显示人话原因
- 脚本可防止“假成功”节点生成，保证节点导入客户端即用
