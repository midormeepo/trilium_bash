#!/bin/bash

# INSTALL_PATH='/opt/trilium'
VERSION='latest'

if [ ! -n "$2" ]; then
  INSTALL_PATH='/opt/trilium'
else
  if [[ $2 == */ ]]; then
    INSTALL_PATH=${2%?}
  else
    INSTALL_PATH=$2
  fi
  if ! [[ $INSTALL_PATH == */trilium ]]; then
    INSTALL_PATH="$INSTALL_PATH/trilium"
  fi
fi

RED_COLOR='\e[1;31m'
GREEN_COLOR='\e[1;32m'
YELLOW_COLOR='\e[1;33m'
BLUE_COLOR='\e[1;34m'
PINK_COLOR='\e[1;35m'
SHAN='\e[1;33;5m'
RES='\e[0m'
clear

# Get platform
if command -v arch >/dev/null 2>&1; then
  platform=$(arch)
else
  platform=$(uname -m)
fi

ARCH="UNKNOWN"

if [ "$platform" = "x86_64" ]; then
  ARCH=amd64
elif [ "$platform" = "aarch64" ]; then
  ARCH=arm64
fi

if [ "$(id -u)" != "0" ]; then
  echo -e "\r\n${RED_COLOR}出错了，请使用 root 权限重试！${RES}\r\n" 1>&2
  exit 1
elif [ "$ARCH" == "UNKNOWN" ]; then
  echo -e "\r\n${RED_COLOR}出错了${RES}，一键安装目前仅支持 x86_64和arm64 平台。"
  exit 1
elif ! command -v systemctl >/dev/null 2>&1; then
  echo -e "\r\n${RED_COLOR}出错了${RES}，无法确定你当前的 Linux 发行版。\r\n建议手动安装。"
  exit 1
else
  if command -v netstat >/dev/null 2>&1; then
    check_port=$(netstat -lnp | grep 8080 | awk '{print $7}' | awk -F/ '{print $1}')
  else
    echo -e "${GREEN_COLOR}端口检查 ...${RES}"
    if command -v yum >/dev/null 2>&1; then
      yum install net-tools -y >/dev/null 2>&1
      check_port=$(netstat -lnp | grep 8080 | awk '{print $7}' | awk -F/ '{print $1}')
    else
      apt-get update >/dev/null 2>&1
      apt-get install net-tools -y >/dev/null 2>&1
      check_port=$(netstat -lnp | grep 8080 | awk '{print $7}' | awk -F/ '{print $1}')
    fi
  fi
fi

CHECK() {
  if [ -d "$INSTALL_PATH" ]; then
    echo "此位置已经安装，请选择其他位置，或使用更新命令"
    exit 0
  fi
  if [ $check_port ]; then
    kill -9 $check_port
  fi
  if [ ! -d "$INSTALL_PATH/" ]; then
    mkdir -p $INSTALL_PATH
  else
    rm -rf $INSTALL_PATH && mkdir -p $INSTALL_PATH
  fi
}
# "https://api.github.com/repos/Nriver/trilium-translation/releases/latest"
# *trilium-cn-linux-x64-server.zip


# https://api.github.com/repos/TriliumNext/Notes/releases/latest



DOWNLOAD(){
  cd /opt
  echo -e "${GREEN_COLOR}下载 trilium $VERSION ...${RES}"
    release_url=$(curl -s "https://api.github.com/repos/TriliumNext/Notes/releases/latest" | grep "browser_download_url.*server-linux-x64.tar.xz" | cut -d : -f 2,3 | tr -d \")
    curl -L -o trilium.tar.xz $release_url $CURL_BAR;

  if [ -f "trilium.tar.xz" ]; then
    echo -e "${GREEN_COLOR}下载成功 ${RES}"
  else
    echo -e "${RED_COLOR}下载 trilium 失败！${RES}"
    exit 1
  fi
}

INSTALL() {
  cd /opt
  # 下载 trilium 程序
  DOWNLOAD

  # echo -e "${GREEN_COLOR}解压压缩包 ...${RES}"
  # unzip trilium.zip >/dev/null 2>&1;

  echo -e "${GREEN_COLOR}解压压缩包 ...${RES}"
  tar -xvJf trilium.tar.xz -C /opt >/dev/null 2>&1;


  echo -e "${GREEN_COLOR}删除旧版本 ...${RES}"
  rm -rf trilium >/dev/null 2>&1;

  echo -e "${GREEN_COLOR}正在更新 ...${RES}"
  sudo mv trilium-linux-x64-server $INSTALL_PATH

  echo -e "\r\n${GREEN_COLOR}启动 trilium 进程${RES}"
  systemctl start trilium

  # 删除临时文件
  echo -e "\r\n${GREEN_COLOR}删除临时文件${RES}"
  rm -f trilium.tar.xz

}

INIT() {
  # cd $INSTALL_PATH
  # if [ -f "trilium.sh" ]; then
  #   echo -e "\r\n${GREEN_COLOR}正在注册开机自启${RES}\r\n"
  # else
  #   echo -e "\r\n${RED_COLOR}出错了${RES}，当前系统未安装 trilium\r\n"
  #   exit 1
  # fi

  # 创建 systemd
  
  cat >/etc/systemd/system/trilium.service <<EOF
[Unit]
Description=Trilium Daemon
After=syslog.target network.target

[Service]
Type=simple
ExecStart=$INSTALL_PATH/trilium.sh
WorkingDirectory=$INSTALL_PATH
   
TimeoutStopSec=20
Restart=always
   
[Install]
WantedBy=multi-user.target
EOF

  # 添加开机启动
  systemctl daemon-reload
  systemctl enable trilium >/dev/null 2>&1
}

SUCCESS() {
  clear
  echo "trilium 安装成功！"
  echo -e "\r\n访问地址：${GREEN_COLOR}http://YOUR_IP:8080/${RES}\r\n"
  
  echo -e "启动服务中"
  systemctl restart trilium

  echo
  echo -e "查看状态：${GREEN_COLOR}systemctl status trilium${RES}"
  echo -e "启动服务：${GREEN_COLOR}systemctl start trilium${RES}"
  echo -e "重启服务：${GREEN_COLOR}systemctl restart trilium${RES}"
  echo -e "停止服务：${GREEN_COLOR}systemctl stop trilium${RES}"
  echo -e "\r\n温馨提示：如果端口无法正常访问，请检查 \033[36m服务器安全组、本机防火墙、trilium状态\033[0m"
  echo
}

UNINSTALL() {
  echo -e "\r\n${GREEN_COLOR}卸载 trilium ...${RES}\r\n"
  echo -e "${GREEN_COLOR}停止进程${RES}"
  systemctl disable trilium >/dev/null 2>&1
  systemctl stop trilium >/dev/null 2>&1
  echo -e "${GREEN_COLOR}清除残留文件${RES}"
  rm -rf $INSTALL_PATH /etc/systemd/system/trilium.service
  rm -f /lib/systemd/system/trilium.service
  systemctl daemon-reload
  echo -e "\r\n${GREEN_COLOR}trilium 已在系统中移除！数据库则请自行删除！${RES}\r\n"
}

UPDATE() {
  cd /opt
  if [ ! -d "$INSTALL_PATH" ]; then
    echo -e "\r\n${RED_COLOR}出错了${RES}，当前系统未安装 trilium\r\n"
    exit 1
  else
    echo
    echo -e "${GREEN_COLOR}停止 trilium 进程${RES}\r\n"
    systemctl stop trilium

    echo -e "${GREEN_COLOR}删除旧版本 ...${RES}"
    rm -rf trilium >/dev/null 2>&1;

    DOWNLOAD

    echo -e "${GREEN_COLOR}解压压缩包 ...${RES}"
    tar -xvJf trilium.tar.xz -C /opt >/dev/null 2>&1;


    echo -e "${GREEN_COLOR}删除旧版本 ...${RES}"
    rm -rf trilium >/dev/null 2>&1;

    echo -e "${GREEN_COLOR}正在更新 ...${RES}"
    sudo mv trilium-linux-x64-server $INSTALL_PATH

    echo -e "\r\n${GREEN_COLOR}启动 trilium 进程${RES}"
    systemctl start trilium
    echo -e "\r\n${GREEN_COLOR}trilium 已更新到最新稳定版！${RES}\r\n"
    # 删除临时文件
    echo -e "\r\n${GREEN_COLOR}删除临时文件${RES}"
    rm -f trilium.tar.xz
  fi
}

# CURL 进度显示
if curl --help | grep progress-bar >/dev/null 2>&1; then # $CURL_BAR
  CURL_BAR="--progress-bar"
fi

# The temp directory must exist
if [ ! -d "/tmp" ]; then
  mkdir -p /tmp
fi

# Fuck bt.cn (BT will use chattr to lock the php isolation config)
chattr -i -R $INSTALL_PATH >/dev/null 2>&1

if [ "$1" = "uninstall" ]; then
  UNINSTALL
elif [ "$1" = "update" ]; then
  UPDATE
elif [ "$1" = "install" ]; then
  CHECK
  INSTALL
  INIT
  if [ -d "$INSTALL_PATH" ]; then
    SUCCESS
  else
    echo -e "${RED_COLOR} 安装失败${RES}"
  fi
else
  echo -e "${RED_COLOR} 错误的命令${RES}"
fi