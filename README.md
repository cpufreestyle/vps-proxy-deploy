# 美国云服务器 (AWS / GCP) 科学上网部署指南

用你已有的 AWS / GCP 美国区资源，部署一台 VLESS + XTLS-Vision + Reality 代理服务，
供电脑 / 手机"上外网"。全程约 15 分钟。

> 如果你只是想要一台能访问海外网站的服务器：直接开机即用，不需要本指南。
> 本指南用于：把这台美国服务器当作代理，给国内或其它网络的设备使用。

## 1. 选机器

| 平台 | 配置 | 费用 | 说明 |
| --- | --- | --- | --- |
| GCP | e2-micro (1C1G/30G) | 永久免费 | 仅限 us-west1 / us-central1 / us-east1 |
| AWS EC2 | t3.micro (1C1G) | 免费 12 个月, 750 小时/月 | 需在账号创建后 12 个月内 |
| AWS Lightsail | 1C/512MB 或 1C/1G | $3.5/月起 | 最省心, 含 1TB 月流量 |

- 区域优先美国西海岸: `us-west-1` (俄勒冈) 或 `us-west-2`，国内延迟通常比东海岸低 30-60ms
- 系统选择 Ubuntu 22.04 LTS

## 2. 创建实例

### GCP (推荐, 永久免费)

1. 控制台 -> Compute Engine -> VM 实例 -> 创建实例
2. 区域选 `us-west1-b`，机器类型 `e2-micro`，启动磁盘 Ubuntu 22.04 LTS (30GB)
3. 记下"外部 IP"

命令行方式:

```bash
gcloud compute instances create proxy \
  --zone=us-west1-b \
  --machine-type=e2-micro \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --tags=proxy-server

gcloud compute firewall-rules create allow-proxy-443 \
  --allow=tcp:443 \
  --target-tags=proxy-server
```

### AWS EC2

1. EC2 -> 启动实例 -> Ubuntu Server 22.04 LTS，类型 `t3.micro` (标注 Free tier)
2. 密钥对: 新建 RSA `.pem` 并保存好，SSH 登录要用
3. 安全组: SSH(22) 来源选"我的 IP"; 自定义 TCP 端口 443，来源 `0.0.0.0/0`
4. 区域建议 `us-west-2` (俄勒冈)
5. 记下公网 IPv4 地址

## 3. 部署 Xray (Reality)

SSH 登上服务器后执行:

```bash
sudo -i
# Windows 上传脚本: scp -i 你的密钥.pem vps-setup.sh ubuntu@服务器IP:~
bash vps-setup.sh
```

脚本自动完成: 安装 Xray-core -> 开启 BBR -> 生成 UUID / Reality 密钥 -> 写入配置并启动 -> 打印分享链接。

## 4. 客户端

| 平台 | 软件 |
| --- | --- |
| Windows | v2rayN |
| Android | v2rayNG / sing-box |
| iOS | Shadowrocket / Streisand |
| macOS | V2rayXS / clash-verge-rev |

导入脚本输出的 `vless://...` 分享链接即可。

## 5. 排障

- 连不上: 确认云控制台安全组/防火墙已放行 TCP 443; 检查 `systemctl status xray` 与 `ss -tlnp | grep 443`
- 看日志: `journalctl -u xray -n 50 --no-pager`
- IP 被墙: AWS/GCP 的 IP 段常被重点关照，换 IP (AWS 换弹性 IP / GCP 换静态 IP) 后重跑脚本
- 速度慢: `sysctl net.ipv4.tcp_congestion_control` 应返回 `bbr`; 换西海岸机房; 伪装目标可换成同生态站点 (AWS 上用 `www.amazon.com`，即 `DEST_HOST=www.amazon.com`)

## 6. 注意事项

- 遵守中国大陆及服务器所在地的法律法规; 个人自用可以，不要向他人提供或售卖代理服务
- 遵守 AWS / GCP 服务条款，超出免费额度会产生费用
- 安全: SSH 仅用密钥登录并关闭密码登录; 只开放必要端口; 定期更新系统