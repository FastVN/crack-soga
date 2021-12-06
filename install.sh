#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Lỗi!：${plain} Bạn phải sử dụng người dùng root để chạy tập lệnh này! \n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}Phiên bản hệ thống không được phát hiện, vui lòng liên hệ với tác giả kịch bản! ${plain}\n" && exit 1
fi

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "Phần mềm này không hỗ trợ hệ thống 32-bit (x86)，vui lòng sử dụng hệ thống 64 bit (x86_64)，nếu phát hiện sai, vui lòng liên hệ với tác giả"
    exit 2
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Vui lòng sử dụng CentOS 7 hoặc hệ thống phiên bản cao hơn! ${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Vui lòng sử dụng Ubuntu 16 hoặc hệ thống phiên bản cao hơn! ${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Vui lòng sử dụng Debian 8 hoặc hệ thống phiên bản cao hơn! ${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl tar crontabs socat -y
    else
        apt install wget curl tar cron socat -y
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/soga.service ]]; then
        return 2
    fi
    temp=$(systemctl status soga | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

install_acme() {
    curl https://get.acme.sh | sh
}

install_soga() {
    cd /usr/local/
    if [[ -e /usr/local/soga/ ]]; then
        rm /usr/local/soga/ -rf
    fi

    if  [ $# == 0 ] ;then
        last_version=$(curl -Ls "https://api.github.com/repos/FastVN/crack-soga/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Không phát hiện được phiên bản soga，Giới hạn API Github có thể bị vượt quá, vui lòng thử lại sau，Hoặc chỉ định thủ công phiên bản soga để cài đặt${plain}"
            exit 1
        fi
        echo -e "Phiên bản mới nhất của soga được phát hiện：${last_version}，Bắt đầu cài đặt"
        wget -N --no-check-certificate -O /usr/local/soga.tar.gz https://github.com/FastVN/crack-soga/releases/download/${last_version}/soga-cracked-linux64.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Tải xuống soga không thành công, vui lòng đảm bảo máy chủ của bạn có thể tải xuống tệp Github${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/FastVN/crack-soga/releases/download/${last_version}/soga-cracked-linux64.tar.gz"
        echo -e "Bắt đầu cài đặt soga v$1"
        wget -N --no-check-certificate -O /usr/local/soga.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Tải xuống soga v$1 không thành công, vui lòng đảm bảo rằng phiên bản này tồn tại${plain}"
            exit 1
        fi
    fi

    tar zxvf soga.tar.gz
    rm soga.tar.gz -f
    cd soga
    chmod +x soga
    mkdir /etc/soga/ -p
    rm /etc/systemd/system/soga.service -f
    cp -f soga.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl stop soga
    systemctl enable soga
    echo -e "${green}soga v${last_version}${plain} Quá trình cài đặt hoàn tất và quá trình khởi động đã được thiết lập để bắt đầu tự động"
    if [[ ! -f /etc/soga/soga.conf ]]; then
        cp soga.conf /etc/soga/
        echo -e ""
        echo -e "Để cài đặt mới, vui lòng tham khảo hướng dẫn wiki: https://github.com/sprov065/soga/wiki, cấu hình nội dung cần thiết"
    else
        systemctl start soga
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}soga Khởi động lại thành công${plain}"
        else
            echo -e "${red}Soga có thể không khởi động được. Vui lòng sử dụng nhật ký soga để xem thông tin nhật ký sau này. Nếu không khởi động được, định dạng cấu hình có thể đã bị thay đổi. Vui lòng truy cập wiki để xem: https://github.com/RManLuo/crack -soga-v2ray / wiki${plain}"
        fi
    fi

    if [[ ! -f /etc/soga/blockList ]]; then
        cp blockList /etc/soga/
    fi
    if [[ ! -f /etc/soga/dns.yml ]]; then
        cp dns.yml /etc/soga/
    fi
    curl -o /usr/bin/soga -Ls https://raw.githubusercontent.com/FastVN/crack-soga/master/soga.sh
    chmod +x /usr/bin/soga
    echo -e ""
    echo "soga Cách sử dụng tập lệnh quản lý: "
    echo "------------------------------------------"
    echo "soga              - Menu quản lý màn hình (nhiều chức năng hơn)"
    echo "soga start        - Khởi động soga"
    echo "soga stop         - Dừng soga"
    echo "soga restart      - Khởi động lại soga"
    echo "soga status       - Xem trạng thái soga"
    echo "soga enable       - Thiết lập soga tự khởi động"
    echo "soga disable      - Hủy bỏ soga tự khởi động"
    echo "soga log          - Xem nhật ký soga"
    echo "soga update       - Cập nhật soga"
    echo "soga update x.x.x - Cập nhật phiên bản đã chỉ định của soga"
    echo "soga install      - Cài đặt soga"
    echo "soga uninstall    - Gỡ cài đặt soga"
    echo "soga version      - Xem phiên bản soga"
    echo "------------------------------------------"
}

echo -e "${green}Bắt đầu cài đặt${plain}"
install_base
install_acme
install_soga $1
