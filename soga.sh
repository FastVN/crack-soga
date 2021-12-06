#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

version="v1.0.0"

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

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [默认$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Có khởi động lại soga không?" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Nhấn enter để quay lại menu chính: ${plain}" && read temp
    show_menu
}

install() {
    bash < <(curl -Ls https://raw.githubusercontent.com/FastVN/crack-soga/main/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    if [[ $# == 0 ]]; then
        echo && echo -n -e "Nhập phiên bản được chỉ định (phiên bản mới nhất mặc định): " && read version
    else
        version=$2
    fi
#    confirm "Chức năng này sẽ buộc cài đặt lại phiên bản mới nhất hiện tại, dữ liệu sẽ không bị mất, có tiếp tục không?" "n"
#    if [[ $? != 0 ]]; then
#        echo -e "${red}Đã hủy${plain}"
#        if [[ $1 != 0 ]]; then
#            before_show_menu
#        fi
#        return 0
#    fi
    bash < <(curl -Ls https://raw.githubusercontent.com/FastVN/crack-soga/main/install.sh) $version
    if [[ $? == 0 ]]; then
        echo -e "${green}Hoàn thành cập nhật，tự động khởi động lại soga，vui lòng sử dụng soga status kiểm tra tình hình khởi động${plain}"
        exit
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

uninstall() {
    confirm "Chắc chắn để gỡ cài đặt soga ?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop soga
    systemctl disable soga
    rm /etc/systemd/system/soga.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/soga/ -rf
    rm /usr/local/soga/ -rf

    echo ""
    echo -e "Gỡ cài đặt thành công, nếu bạn muốn xóa tập lệnh này, hãy thoát tập lệnh và chạy ${green}rm /usr/bin/soga -f${plain} Xóa bỏ"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}soga đã chạy rồi, không cần khởi động lại, nếu cần khởi động lại, vui lòng chọn khởi động lại${plain}"
    else
        systemctl start soga
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}soga Bắt đầu thành công, vui lòng sử dụng soga status kiểm tra tình hình khởi động${plain}"
        else
            echo -e "${red}Soga có thể không khởi động được, vui lòng sử dụng nhật ký soga để xem thông tin nhật ký${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    systemctl stop soga
    sleep 2
    check_status
    if [[ $? == 1 ]]; then
        echo -e "${green}Đã dừng soga thành công${plain}"
    else
        echo -e "${red}Không dừng được Soga. Có thể do thời gian dừng vượt quá hai giây. Vui lòng kiểm tra thông tin nhật ký.${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart soga
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}Soga đã khởi động lại thành công, vui lòng sử dụng trạng thái soga để kiểm tra tình hình khởi động${plain}"
    else
        echo -e "${red}Soga có thể không khởi động được, vui lòng sử dụng nhật ký soga để xem thông tin nhật ký${plain}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status soga --no-pager -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable soga
    if [[ $? == 0 ]]; then
        echo -e "${green}soga được thiết lập để bắt đầu thành công sau khi khởi động${plain}"
    else
        echo -e "${red}soga không đặt được chế độ tự khởi động sau khi bật nguồn${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable soga
    if [[ $? == 0 ]]; then
        echo -e "${green}Hủy khởi động và tự khởi động soga thành công${plain}"
    else
        echo -e "${red}soga hủy khởi động và tự khởi động lỗi${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u soga.service -e --no-pager
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

install_bbr() {
    bash <(curl -L -s https://github.com/sprov065/blog/raw/master/bbr.sh)
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}Cài đặt thành công bbr, vui lòng khởi động lại máy chủ${plain}"
    else
        echo ""
        echo -e "${red}Không tải được tập lệnh cài đặt bbr, vui lòng kiểm tra xem máy có thể kết nối với Github không${plain}"
    fi

    before_show_menu
}

update_shell() {
    wget -O /usr/bin/soga -N --no-check-certificate https://github.com/RManLuo/crack-soga-v2ray/raw/master/soga.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}Không tải được script xuống, vui lòng kiểm tra xem máy có thể kết nối với Github không${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/soga
        echo -e "${green}Tập lệnh nâng cấp thành công, vui lòng chạy lại tập lệnh${plain}" && exit 0
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

check_enabled() {
    temp=$(systemctl is-enabled soga)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1;
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${red}soga đã được cài đặt, vui lòng không cài đặt nhiều lần${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${red}Vui lòng cài đặt soga trước${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
        0)
            echo -e "Trạng thái soga: ${green}Đã chạy${plain}"
            show_enable_status
            ;;
        1)
            echo -e "Trạng thái soga: ${yellow}Không chạy${plain}"
            show_enable_status
            ;;
        2)
            echo -e "Trạng thái soga: ${red}Chưa cài đặt${plain}"
    esac
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Có tự động khởi động sau khi khởi động không: ${green}Có${plain}"
    else
        echo -e "Có tự động khởi động sau khi khởi động không: ${red}Không${plain}"
    fi
}

show_soga_version() {
    echo -n "Phiên bản soga："
    /usr/local/soga/soga -v
    echo ""
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_usage() {
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

show_menu() {
    echo -e "
  ${green}Tập lệnh quản lý back-end soga，${plain}${red}不适用于docker${plain}
--- https://github.com/FastVN/crack-soga-v2ray ---
  ${green}0.${plain} Tập lệnh thoát
————————————————
  ${green}1.${plain} Cài đặt soga
  ${green}2.${plain} Cập nhật soga
  ${green}3.${plain} Gỡ cài đặt soga
————————————————
  ${green}4.${plain} Bắt đầu soga
  ${green}5.${plain} Dừng soga
  ${green}6.${plain} Khởi động lại soga
  ${green}7.${plain} Xem trạng thái soga
  ${green}8.${plain} Xem nhật ký soga
————————————————
  ${green}9.${plain} Đặt soga để bắt đầu tự động sau khi khởi động
 ${green}10.${plain} Hủy khởi động soga sau khi khởi động
————————————————
 ${green}11.${plain} 一Key cài đặt bbr (hạt nhân mới nhất)
 ${green}12.${plain} Xem phiên bản soga
 "
    show_status
    echo && read -p "Vui lòng nhập lựa chọn [0-12]: " num

    case "${num}" in
        0) exit 0
        ;;
        1) check_uninstall && install
        ;;
        2) check_install && update
        ;;
        3) check_install && uninstall
        ;;
        4) check_install && start
        ;;
        5) check_install && stop
        ;;
        6) check_install && restart
        ;;
        7) check_install && status
        ;;
        8) check_install && show_log
        ;;
        9) check_install && enable
        ;;
        10) check_install && disable
        ;;
        11) install_bbr
        ;;
        12) check_install && show_soga_version
        ;;
        *) echo -e "${red}Vui lòng nhập số chính xác [0-12]${plain}"
        ;;
    esac
}


if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0
        ;;
        "stop") check_install 0 && stop 0
        ;;
        "restart") check_install 0 && restart 0
        ;;
        "status") check_install 0 && status 0
        ;;
        "enable") check_install 0 && enable 0
        ;;
        "disable") check_install 0 && disable 0
        ;;
        "log") check_install 0 && show_log 0
        ;;
        "update") check_install 0 && update 0 $2
        ;;
        "install") check_uninstall 0 && install 0
        ;;
        "uninstall") check_install 0 && uninstall 0
        ;;
        "version") check_install 0 && show_soga_version 0
        ;;
        *) show_usage
    esac
else
    show_menu
fi
