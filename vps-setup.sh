#!/usr/bin/env bash
# ============================================================
# 美国 VPS 一键部署: Xray (VLESS + XTLS-Vision + Reality) + BBR
# 适用系统: Ubuntu 20.04 / 22.04 / 24.04, Debian 11 / 12
# 用法:   sudo bash vps-setup.sh
# 可选:   PORT=443 DEST_HOST=www.microsoft.com sudo -E bash vps-setup.sh
# ============================================================
set -euo pipefail

PORT="${PORT:-443}"
DEST_HOST="${DEST_HOST:-www.microsoft.com}"

if [ "$(id -u)" -ne 0 ]; then
  echo "请使用 root 运行: sudo bash vps-setup.sh"
  exit 1
fi

echo "==> [1/5] 安装 Xray-core"
if ! command -v curl >/dev/null 2>&1 || ! command -v openssl >/dev/null 2>&1; then
  apt-get update -qq
  apt-get install -y -qq curl openssl ca-certificates
fi
bash -c "$(curl -Ls https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)" install

echo "==> [2/5] 开启 BBR 拥塞控制"
modprobe tcp_bbr 2>/dev/null || true
sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1 || true
sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1 || true
if ! grep -q '^net.core.default_qdisc' /etc/sysctl.conf 2>/dev/null; then
  echo 'net.core.default_qdisc=fq' >> /etc/sysctl.conf
fi
if ! grep -q '^net.ipv4.tcp_congestion_control' /etc/sysctl.conf 2>/dev/null; then
  echo 'net.ipv4.tcp_congestion_control=bbr' >> /etc/sysctl.conf
fi

echo "==> [3/5] 生成 UUID 与 Reality 密钥对"
UUID="$(/usr/local/bin/xray uuid)"
KEYOUT="$(/usr/local/bin/xray x25519 || true)"
# Xray 不同版本输出字段名不同: 新版为 PrivateKey/Password, 旧版为 Private key/Public key
PRIVATE_KEY="$(printf '%s\n' "$KEYOUT" | grep -i 'private' | sed -n 's/.*:[[:space:]]*//p' | head -n 1 || true)"
PUBLIC_KEY="$(printf '%s\n' "$KEYOUT" | grep -i 'public' | sed -n 's/.*:[[:space:]]*//p' | head -n 1 || true)"
if [ -z "$PUBLIC_KEY" ]; then
  PUBLIC_KEY="$(printf '%s\n' "$KEYOUT" | grep -i 'password' | sed -n 's/.*:[[:space:]]*//p' | head -n 1 || true)"
fi
if [ -z "$UUID" ] || [ -z "$PRIVATE_KEY" ] || [ -z "$PUBLIC_KEY" ]; then
  echo "密钥生成失败, 请检查 Xray 安装: /usr/local/bin/xray version"
  exit 1
fi
SHORT_ID="$(openssl rand -hex 8)"
SERVER_IP="$(curl -s --max-time 5 https://api.ipify.org || true)"
if [ -z "$SERVER_IP" ]; then
  SERVER_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
fi

echo "==> [4/5] 写入配置并启动 Xray"
cat > /usr/local/etc/xray/config.json <<JSON
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": ${PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          { "id": "${UUID}", "flow": "xtls-rprx-vision" }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "dest": "${DEST_HOST}:443",
          "xver": 0,
          "serverNames": ["${DEST_HOST}"],
          "privateKey": "${PRIVATE_KEY}",
          "shortIds": ["${SHORT_ID}"]
        }
      },
      "sniffing": { "enabled": true, "destOverride": ["http", "tls", "quic"] }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "tag": "direct" },
    { "protocol": "blackhole", "tag": "block" }
  ]
}
JSON

systemctl enable xray >/dev/null 2>&1 || true
systemctl restart xray
sleep 1
if ss -tln 2>/dev/null | grep -q ":${PORT} "; then
  echo "端口 ${PORT} 监听正常"
else
  echo "警告: 未检测到 ${PORT} 监听, 请查看日志: journalctl -u xray -n 50 --no-pager"
fi

echo "==> [5/5] 部署完成, 请保存以下信息"
SHARE_LINK="vless://${UUID}@${SERVER_IP}:${PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${DEST_HOST}&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp#US-Reality"

# 保存链接到固定路径, 便于外部脚本读取
mkdir -p /root
printf '%s\n' "${SHARE_LINK}" > /root/vless-link.txt
chmod 600 /root/vless-link.txt

cat > /root/vps-info.txt <<INFO2
服务器 IP  : ${SERVER_IP}
端口       : ${PORT}
UUID       : ${UUID}
Flow       : xtls-rprx-vision
传输       : tcp
SNI        : ${DEST_HOST}
PublicKey  : ${PUBLIC_KEY}
ShortId    : ${SHORT_ID}
指纹       : chrome
分享链接   : ${SHARE_LINK}
INFO2
chmod 600 /root/vps-info.txt

cat <<INFO
--------------------------------------------------
服务器 IP  : ${SERVER_IP}
端口       : ${PORT}
UUID       : ${UUID}
Flow       : xtls-rprx-vision
传输       : tcp
SNI        : ${DEST_HOST}
PublicKey  : ${PUBLIC_KEY}
ShortId    : ${SHORT_ID}
指纹       : chrome
--------------------------------------------------
分享链接 (v2rayN / v2rayNG / Shadowrocket / sing-box 可直接导入):
${SHARE_LINK}
--------------------------------------------------
提醒:
1. 到云控制台放行 TCP ${PORT} 入站 (安全组 / 防火墙)
2. 客户端导入上面的分享链接即可上网
3. 若 IP 已被墙, 更换 IP 后重新运行本脚本
INFO
