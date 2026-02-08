#!/bin/bash

# 获取局域网 IP
IP_ADDR=$(ip route get 1 | awk '{print $7;exit}')
PORT=5000

echo "------------------------------------------"
echo "Piko 局域网分享工具正在启动... (｡◕‿◕｡)"
echo "访问地址: http://$IP_ADDR:$PORT"
echo "------------------------------------------"

# 检查 Flask 是否安装
if ! python3 -c "import flask" &> /dev/null; then
    echo "检测到未安装 Flask，正在尝试安装..."
    pip install flask
fi

# 启动应用
python3 app.py