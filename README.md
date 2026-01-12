# Sing-Box 一键安装/升级/管理脚本 🌐

📌 **功能特点**  

- 强制输入 `PORT`、`USERNAME`、`PASSWORD`，无默认值  
- 自动安装 / 升级最新 sing-box 二进制  
- 自动放行防火墙端口  
- 输出 **IPv4 + IPv6 小火箭链接**  
- 查看已布置节点信息  
- 卸载服务与清理文件  

---

## 安装 / 升级 sing-box 🚀

```bash

PORT=端口 USERNAME=账号 PASSWORD=密码 bash <(curl -Ls https://你的GitHub路径/socks5.sh) install

# 请务必替换端口、用户名、密码如以下:
PORT=12805 USERNAME=fsst PASSWORD=jbvcd bash <(curl -Ls https://raw.githubusercontent.com/qazxue1051289/qazhome/main/socks5.sh) install
执行后示例输出：
👉 自动放行防火墙端口 12805 ...
✅ 防火墙端口 12805 已放行
👉 启动 sing-box 服务...
* WARNING: sing-box-socks5 has already been started
✅ Socks5 节点已准备好！

📌 当前节点信息：
端口: 12805
用户名: fsst
密码: jbvcd

🌐 小火箭 IPv4 链接：
socks5://fsst:jbvcd@123.45.67.89:12805

🌐 小火箭 IPv6 链接：
socks5://fsst:jbvcd@[2603:c021:8019:417e:0:bdce:1f5e:cba]:12805

卸载 sing-box:
bash <(curl -Ls https://raw.githubusercontent.com/qazxue1051289/qazhome/main/socks5.sh) uninstall
