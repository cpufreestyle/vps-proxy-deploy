# VPS 翻墙部署工具

在 AWS Lightsail / EC2 或 GCP 上一键部署代理服务，客户端导入链接即可上网。

## 文件说明

- `vps-setup.sh` — 一键部署脚本（Xray-core + VLESS-Reality + BBR）
- `README.md` — 本文件

## 部署

SSH 登入服务器后执行：

```bash
sudo bash vps-setup.sh
```

自定义端口和伪装域名（可选）：

```bash
PORT=443 DEST_HOST=www.microsoft.com sudo -E bash vps-setup.sh
```

脚本会自动完成：

1. 安装 Xray-core
2. 开启 BBR 拥塞控制
3. 生成 UUID 与 Reality 密钥对
4. 写入配置并启动 Xray（systemd 托管）
5. 输出 vless 分享链接，并保存到服务器 `/root/vless-link.txt`

## 支持系统

- Ubuntu 20.04 / 22.04 / 24.04
- Debian 11 / 12

## 防火墙

部署后必须在云控制台放行入站端口（默认 TCP 443）：

- AWS Lightsail：实例页 → Networking → IPv4 Firewall → Add rule
- AWS EC2：安全组 → 入站规则 → 自定义 TCP → 443
- GCP：VPC 网络 → 防火墙 → 新建规则

## 客户端

把脚本输出的 `vless://...` 链接导入任一客户端即可：

- Windows: v2rayN
- Android: v2rayNG
- iOS: Shadowrocket / sing-box
- 跨平台: sing-box、clash-verge-rev

## 排障

```bash
# 查看 Xray 日志
journalctl -u xray -n 50 --no-pager

# 确认端口监听
ss -tln | grep 443

# 确认 BBR 生效
sysctl net.ipv4.tcp_congestion_control
```

常见问题：

- 客户端连不上：先检查云控制台防火墙是否放行端口
- 提示证书错误：确认 `sni` 参数与脚本里的 `DEST_HOST` 一致
- IP 被墙：更换服务器 IP 后重新运行脚本

## 协议说明

VLESS + XTLS-Vision + Reality，`dest` 指向真实网站（默认 `www.microsoft.com`），
在没有真实证书的情况下借用目标网站的 TLS 握手特征，抗主动探测。

## 许可

MIT

