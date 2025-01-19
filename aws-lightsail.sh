#!/bin/bash

# Server酱开关，0为关闭，1为开启
NOTIFICATION=0
# Server酱API
SERVERCHAN_KEY='YOUR_SERVERCHAN_KEY'

# 区域作为脚本的第一个参数
REGION=$1
# Ping检测次数
PINGTIMES=5

readonly NOTIFICATION
readonly SERVERCHAN_KEY
readonly REGION
readonly PINGTIMES

# 根据系统定义Ping检测结果关键字
case $(uname) in
    "Darwin")
        CHECK_PING="100.0% packet loss"
        ;;
    "Linux")
        CHECK_PING="100% packet loss"
        ;;
    *)
        echo -e "Unsupported System"
        exit 1
        ;;
esac

echo -e '*****************************************************************'
echo -e '***************************** START *****************************'
echo -e '*****************************************************************'

# 主函数
function main {
    # 获取静态 IP 列表
    local ipjson=$(aws lightsail --region "$REGION" get-static-ips)
    
    # 获取静态 IP 数量
    local NUM_IP=$(echo "$ipjson" | jq -r '.staticIps | length')
    if [[ $NUM_IP -eq 0 ]]; then
        echo "No static IPs found in region $REGION."
        exit 0
    fi

    # 遍历每个静态 IP
    for (( i = 0; i < NUM_IP; i++ )); do
        echo -e "========================= seq $i start ========================="
        
        # 获取静态 IP 的各项信息
        local OLD_IP=$(echo "$ipjson" | jq -r ".staticIps[$i].ipAddress")
        local INSTANCE_NAME=$(echo "$ipjson" | jq -r ".staticIps[$i].attachedTo")
        local STATIC_IP_NAME=$(echo "$ipjson" | jq -r ".staticIps[$i].name")
        
        echo -e "1. Checking VPS with IP: $OLD_IP"
        
        # 检测 IP 是否存活
        ping -c "$PINGTIMES" "$OLD_IP" > "temp.$OLD_IP.txt" 2>&1
        if grep -q "$CHECK_PING" "temp.$OLD_IP.txt"; then
            echo -e "2. This VPS is dead, process starts"
            
            # 删除原静态 IP
            aws lightsail --region "$REGION" release-static-ip --static-ip-name "$STATIC_IP_NAME"
            
            # 新建静态 IP
            aws lightsail --region "$REGION" allocate-static-ip --static-ip-name "$STATIC_IP_NAME"
            
            # 绑定静态 IP
            aws lightsail --region "$REGION" attach-static-ip --static-ip-name "$STATIC_IP_NAME" --instance-name "$INSTANCE_NAME"
            
            # 获取新 IP 地址
            local instancejson=$(aws lightsail --region "$REGION" get-instance --instance-name "$INSTANCE_NAME")
            local NEW_IP=$(echo "$instancejson" | jq -r '.instance.publicIpAddress')
            
            # 发送通知
            if [[ $NOTIFICATION -eq 1 ]]; then
                text="IP地址已更换"
                desp="您在${REGION}的${INSTANCE_NAME}服务器IP:${OLD_IP}已更换至${NEW_IP}。"
                notification "${text}" "${desp}"
            fi
        else
            echo -e "2. This IP is alive, nothing happened"
        fi
        
        rm -rf "temp.$OLD_IP.txt"
    done
}

# 发送 Server 酱通知
function notification {
    local json=$(curl -s "https://sc.ftqq.com/$SERVERCHAN_KEY.send" --data-urlencode "text=$1" --data-urlencode "desp=$2")
    local errno=$(echo "$json" | jq .errno)
    local errmsg=$(echo "$json" | jq .errmsg)
    if [[ $errno -eq 0 ]]; then
        echo -e 'Notice sent successfully'
    else
        echo -e 'Notice send failed'
        echo -e "Error message: $errmsg"
    fi
}

main "$REGION"

echo -e '*****************************************************************'
echo -e '****************************** END ******************************'
echo -e '*****************************************************************'

exit 0