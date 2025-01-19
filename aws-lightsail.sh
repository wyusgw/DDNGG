#!/bin/bash

# 设置相关变量
INSTANCE_NAME="ubuntu-1"
REGION="ap-southeast-1"  # 修改为您的 AWS Lightsail 区域
STATIC_IP_NAME="MyStaticIP"  # 修改为当前的静态 IP 名称

# 获取当前的静态 IP 地址
get_current_ip() {
  CURRENT_IP=$(aws lightsail get-static-ips --region $REGION --query "staticIps[?name=='$STATIC_IP_NAME'].ipAddress" --output text)
  if [ "$CURRENT_IP" == "None" ]; then
    echo "未找到当前静态 IP，请检查 STATIC_IP_NAME 是否正确。"
    exit 1
  fi
  echo "当前静态 IP: $CURRENT_IP"
}

# 释放当前静态 IP 地址
release_static_ip() {
  echo "正在释放当前静态 IP ($CURRENT_IP)..."
  aws lightsail release-static-ip --static-ip-name $STATIC_IP_NAME --region $REGION
  if [ $? -ne 0 ]; then
    echo "释放静态 IP 失败，请检查权限或配置。"
    exit 1
  fi
}

# 分配新的静态 IP 地址
allocate_new_static_ip() {
  echo "正在分配新的静态 IP..."
  NEW_IP=$(aws lightsail allocate-static-ip --region $REGION --query "staticIp.ipAddress" --output text)
  if [ "$NEW_IP" == "None" ]; then
    echo "分配新的静态 IP 失败，请检查权限或配置。"
    exit 1
  fi
  echo "新的静态 IP 已分配: $NEW_IP"
}

# 绑定新的静态 IP 到实例
attach_new_static_ip() {
  echo "正在将新的静态 IP ($NEW_IP) 绑定到实例..."
  aws lightsail attach-static-ip --static-ip-name $NEW_IP --instance-name $INSTANCE_NAME --region $REGION
  if [ $? -ne 0 ]; then
    echo "绑定新的静态 IP 失败，请检查权限或配置。"
    exit 1
  fi
  echo "新的静态 IP 已成功绑定到实例."
}

# 主逻辑
get_current_ip
release_static_ip
allocate_new_static_ip
attach_new_static_ip

# 输出更换后的静态 IP
echo "静态 IP 已成功更换."
echo "旧静态 IP: $CURRENT_IP"
echo "新静态 IP: $NEW_IP"