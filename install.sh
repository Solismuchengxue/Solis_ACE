#!/bin/bash

# =============================================================================
# SolisACE 交互式安装脚本
# 功能：
#   1. 安装 Klipper extras (ace.py，已含温度传感器)
#   2. 安装配置文件 (ace.cfg) 并引用至 printer.cfg
#   3. 安装 Moonraker 组件 (ace_status.py)
#   4. 配置 Moonraker 扩展及更新管理器
#   5. 安装 Web 仪表板至 nginx（自动部署，独立端口，不影响 Mainsail/Fluidd）
#   6. 重启服务
# 使用 -u 参数卸载所有安装项
# =============================================================================

set -e

# ----------------------------- 全局变量 ----------------------------------
SCRIPT_VERSION="1.2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_USER="${SUDO_USER:-$(id -un)}"
INSTALL_HOME="$(getent passwd "$INSTALL_USER" 2>/dev/null | cut -d: -f6 || echo "$HOME")"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 默认路径（可交互修改）
KLIPPER_HOME="${INSTALL_HOME}/klipper"
KLIPPER_CONFIG_HOME="${INSTALL_HOME}/printer_data/config"
MOONRAKER_HOME="${INSTALL_HOME}/moonraker"
MOONRAKER_CONFIG="${KLIPPER_CONFIG_HOME}/moonraker.conf"
PRINTER_CFG="${KLIPPER_CONFIG_HOME}/printer.cfg"

# 源文件位置
SRC_EXTRAS="${SCRIPT_DIR}/extras"
SRC_MOONRAKER="${SCRIPT_DIR}/moonraker"
SRC_WEB="${SCRIPT_DIR}/webui"
SRC_ACE_CFG="${SCRIPT_DIR}/ace.cfg"
SRC_REQUIREMENTS="${SCRIPT_DIR}/requirements.txt"

# 服务名称
KLIPPER_SERVICE="klipper"
MOONRAKER_SERVICE="moonraker"

# Web 安装状态（由 install_web_nginx 填写）
INSTALL_WEB=0
WEB_DIR=""
WEB_PORT=""

# ----------------------------- 辅助函数 ----------------------------------
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_info()   { echo -e "${BLUE}ℹ ${1}${NC}"; }
print_success(){ echo -e "${GREEN}✓ ${1}${NC}"; }
print_warning(){ echo -e "${YELLOW}⚠ ${1}${NC}"; }
print_error()  { echo -e "${RED}✗ ${1}${NC}"; }

prompt_yes_no() {
    local prompt="$1"
    local response
    while true; do
        read -p "$(echo -e ${BLUE}${prompt}${NC} [y/N]: )" response
        case "$response" in
            [yY][eE][sS]|[yY]) return 0 ;;
            [nN][oO]|[nN]|"")   return 1 ;;
            *) echo "请回答 y 或 n" ;;
        esac
    done
}

prompt_input() {
    local prompt="$1"
    local default="$2"
    local response
    read -p "$(echo -e ${BLUE}${prompt}${NC} [${default}]: )" response
    echo "${response:-$default}"
}

backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        local timestamp=$(date +"%Y%m%d_%H%M%S")
        local backup="${file}.backup_${timestamp}"
        cp "$file" "$backup"
        print_success "已备份: $file → $backup"
        return 0
    fi
    return 1
}

create_symlink() {
    local src="$1"
    local dest="$2"
    local desc="$3"
    
    if [ ! -e "$src" ]; then
        print_error "源文件不存在: $src"
        return 1
    fi
    
    mkdir -p "$(dirname "$dest")"
    if [ -L "$dest" ] || [ -e "$dest" ]; then
        if [ -L "$dest" ]; then
            print_warning "符号链接已存在: $dest → $(readlink "$dest")"
        else
            print_warning "文件/目录已存在: $dest"
        fi
        if prompt_yes_no "是否替换？"; then
            rm -f "$dest"
        else
            print_info "跳过 ${desc}"
            return 1
        fi
    fi
    ln -sf "$src" "$dest"
    print_success "${desc} 符号链接已创建: $dest → $src"
    return 0
}

add_line_to_file_if_missing() {
    local file="$1"
    local line="$2"
    if ! grep -qF "$line" "$file" 2>/dev/null; then
        echo "$line" >> "$file"
        print_success "已添加行至 $file"
    else
        print_info "行已存在于 $file"
    fi
}

ensure_printer_cfg_include() {
    local include_line="[include ace.cfg]"
    if ! grep -qF "$include_line" "$PRINTER_CFG" 2>/dev/null; then
        print_info "正在将 '[include ace.cfg]' 插入 printer.cfg 顶部..."
        backup_file "$PRINTER_CFG"
        sed -i "1i $include_line" "$PRINTER_CFG"
        print_success "已添加引用至 printer.cfg"
    else
        print_success "printer.cfg 已包含 ace.cfg 引用"
    fi
}

# ----------------------------- 安装步骤 ----------------------------------
install_requirements() {
    print_header "0. 安装 Python 依赖"
    local pip_cmd="pip3"
    if [ -d "${INSTALL_HOME}/klippy-env" ]; then
        pip_cmd="${INSTALL_HOME}/klippy-env/bin/pip3"
    fi

    # 检查 pyserial 是否已安装
    if $pip_cmd show pyserial &>/dev/null; then
        print_success "pyserial 已安装，跳过依赖安装"
        return
    fi

    if [ ! -f "$SRC_REQUIREMENTS" ]; then
        print_warning "未找到 requirements.txt，跳过依赖安装"
        return
    fi

    print_info "使用 $pip_cmd 安装 pyserial..."
    if $pip_cmd install -r "$SRC_REQUIREMENTS" --quiet; then
        print_success "依赖安装完成"
    else
        print_error "依赖安装失败，请检查网络或手动安装 pyserial"
        exit 1
    fi
}

install_klipper_extras() {
    print_header "1. 安装 Klipper 扩展"
    create_symlink "$SRC_EXTRAS/ace.py" "$KLIPPER_HOME/klippy/extras/ace.py" "ace.py"
    # temperature_ace 已并入 ace.py；清理旧版可能残留的独立模块软链
    rm -f "$KLIPPER_HOME/klippy/extras/temperature_ace.py" 2>/dev/null
}

install_config() {
    print_header "2. 安装配置文件"
    if [ ! -f "$SRC_ACE_CFG" ]; then
        print_error "未找到 ace.cfg: $SRC_ACE_CFG"
        return 1
    fi
    if [ -f "$KLIPPER_CONFIG_HOME/ace.cfg" ]; then
        print_warning "ace.cfg 已存在，将备份后覆盖"
        backup_file "$KLIPPER_CONFIG_HOME/ace.cfg"
    fi
    cp "$SRC_ACE_CFG" "$KLIPPER_CONFIG_HOME/"
    print_success "ace.cfg 已复制到 $KLIPPER_CONFIG_HOME"
    ensure_printer_cfg_include
}

install_moonraker_component() {
    print_header "3. 安装 Moonraker 组件"
    create_symlink "$SRC_MOONRAKER/ace_status.py" "$MOONRAKER_HOME/moonraker/components/ace_status.py" "ace_status.py"
    
    print_info "检查 moonraker.conf 中的 [ace_status]..."
    if ! grep -qi '^[[:space:]]*\[ace_status\]' "$MOONRAKER_CONFIG" 2>/dev/null; then
        backup_file "$MOONRAKER_CONFIG"
        echo -e "\n[ace_status]" >> "$MOONRAKER_CONFIG"
        print_success "已添加 [ace_status] 到 moonraker.conf"
    else
        print_success "[ace_status] 已存在于 moonraker.conf"
    fi
}

add_update_manager() {
    print_header "4. 添加更新管理器"
    local updater_section="[update_manager SolisACE]
type: git_repo
path: ${SCRIPT_DIR}
primary_branch: main
origin: https://github.com/Solismuchengxue/Solis_ACE.git
managed_services: klipper"
    
    if grep -qF "[update_manager SolisACE]" "$MOONRAKER_CONFIG" 2>/dev/null; then
        print_success "更新管理器已存在"
    else
        backup_file "$MOONRAKER_CONFIG"
        echo -e "\n$updater_section" >> "$MOONRAKER_CONFIG"
        print_success "已添加更新管理器配置"
    fi
}

configure_moonraker_cors() {
    local port="$1"
    print_info "配置 Moonraker CORS（允许 Web 仪表板端口 ${port} 访问 Moonraker）..."

    if grep -q 'cors_domains' "$MOONRAKER_CONFIG" 2>/dev/null; then
        print_warning "moonraker.conf 中已存在 cors_domains，跳过自动配置"
        print_warning "如仪表板无法连接，请在 [authorization] cors_domains 下手动添加:"
        echo "    http://*"
        echo "    https://*"
        return 0
    fi

    backup_file "$MOONRAKER_CONFIG"

    if grep -q '^\[authorization\]' "$MOONRAKER_CONFIG" 2>/dev/null; then
        # [authorization] 段已存在，在其后插入 cors_domains
        python3 - "$MOONRAKER_CONFIG" "$port" << 'PYEOF'
import sys
path, port = sys.argv[1], sys.argv[2]
with open(path) as f:
    lines = f.readlines()
out = []
for line in lines:
    out.append(line)
    if line.strip() == '[authorization]':
        out.append('cors_domains:\n')
        out.append('    *://*:' + port + '\n')
with open(path, 'w') as f:
    f.writelines(out)
PYEOF
        print_success "已在 [authorization] 段添加 cors_domains（仅允许端口 ${port}）"
    else
        # 无 [authorization] 段，追加到文件末尾
        cat >> "$MOONRAKER_CONFIG" << ENDCORS

[authorization]
cors_domains:
    *://*:${port}
ENDCORS
        print_success "已添加 Moonraker CORS 配置（仅允许端口 ${port}）"
    fi
}

install_web_nginx() {
    print_header "5. 安装 Web 仪表板 (nginx)"

    if [ ! -d "$SRC_WEB" ]; then
        print_error "Web 源目录不存在: $SRC_WEB"
        return 1
    fi

    # 确保 nginx 已安装
    if ! command -v nginx >/dev/null 2>&1; then
        print_warning "nginx 未安装，正在通过 apt 安装..."
        sudo apt-get update -qq && sudo apt-get install -y nginx \
            || { print_error "nginx 安装失败，请手动安装后重试"; return 1; }
    fi

    # 部署目录和端口（避免与 Mainsail/Fluidd 的 80 端口冲突）
    local web_dir web_port
    web_dir=$(prompt_input "Web 文件部署目录" "/home/${INSTALL_USER}/ace-dashboard")
    web_port=$(prompt_input "nginx 监听端口 (避免与 Mainsail/Fluidd 冲突，建议 8088)" "8088")

    # 创建部署目录并复制文件
    sudo mkdir -p "$web_dir"
    local web_files=("ace.html" "ace-dashboard.js" "ace-dashboard.css" "ace-dashboard-config.js" "favicon.svg")
    for file in "${web_files[@]}"; do
        [ -f "$SRC_WEB/$file" ] && sudo cp "$SRC_WEB/$file" "$web_dir/$file"
    done
    sudo chown -R "${INSTALL_USER}:${INSTALL_USER}" "$web_dir"
    sudo chmod -R 755 "$web_dir"
    print_success "Web 文件已复制到 $web_dir"

    # 从模板生成 nginx 站点配置（替换路径和端口）
    local nginx_conf="/etc/nginx/sites-available/ace-dashboard"
    sudo cp "$SRC_WEB/ace_dashboard.nginx.conf" "$nginx_conf"
    sudo sed -i "s|/home/pi/ace-dashboard|${web_dir}|g" "$nginx_conf"
    sudo sed -i "s|listen 8088;|listen ${web_port};|g" "$nginx_conf"

    # 启用站点
    sudo ln -sf "$nginx_conf" /etc/nginx/sites-enabled/ace-dashboard

    # 测试并重载
    if sudo nginx -t; then
        sudo systemctl reload nginx
        local host_ip
        host_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
        print_success "nginx 已配置并重载"
        print_success "仪表板地址: http://${host_ip:-<打印机IP>}:${web_port}/ace.html"
        INSTALL_WEB=1
        WEB_DIR="$web_dir"
        WEB_PORT="$web_port"
    else
        print_error "nginx 配置测试失败，请检查 $nginx_conf"
        return 1
    fi

    # 配置 Moonraker CORS，允许浏览器从 nginx 端口直连 Moonraker
    configure_moonraker_cors "$web_port"
}

restart_services() {
    print_header "6. 重启服务"
    if prompt_yes_no "是否立即重启 Klipper 和 Moonraker 服务？"; then
        sudo systemctl restart $KLIPPER_SERVICE && print_success "Klipper 已重启"
        sudo systemctl restart $MOONRAKER_SERVICE && print_success "Moonraker 已重启"
    else
        print_warning "请稍后手动重启服务:"
        echo "  sudo systemctl restart klipper moonraker"
    fi
}

# ----------------------------- 卸载流程 ----------------------------------
uninstall_all() {
    print_header "卸载 SolisACE"
    
    print_info "正在移除 Klipper 扩展符号链接..."
    rm -f "$KLIPPER_HOME/klippy/extras/ace.py" 2>/dev/null && print_success "已移除 ace.py"
    rm -f "$KLIPPER_HOME/klippy/extras/temperature_ace.py" 2>/dev/null && print_success "已移除 temperature_ace.py"
    
    print_info "正在移除 Moonraker 组件符号链接..."
    rm -f "$MOONRAKER_HOME/moonraker/components/ace_status.py" 2>/dev/null && print_success "已移除 ace_status.py"
    
    print_info "正在移除 nginx 站点配置..."
    sudo rm -f /etc/nginx/sites-enabled/ace-dashboard 2>/dev/null && \
        print_success "已移除 /etc/nginx/sites-enabled/ace-dashboard"
    sudo rm -f /etc/nginx/sites-available/ace-dashboard 2>/dev/null && \
        print_success "已移除 /etc/nginx/sites-available/ace-dashboard"
    if command -v nginx >/dev/null 2>&1; then
        sudo nginx -t 2>/dev/null && sudo systemctl reload nginx && \
            print_success "nginx 已重载" || true
    fi
    print_info "Web 文件目录（如 ~/ace-dashboard）需手动删除。"
    
    print_info "注意：配置文件及 printer.cfg/moonraker.conf 中的引用需要手动移除："
    echo "  - $KLIPPER_CONFIG_HOME/ace.cfg"
    echo "  - printer.cfg 中的 '[include ace.cfg]'"
    echo "  - moonraker.conf 中的 '[ace_status]' 及 '[update_manager SolisACE]' 段落"
    
    if prompt_yes_no "是否立即重启服务？"; then
        sudo systemctl restart $KLIPPER_SERVICE $MOONRAKER_SERVICE
        print_success "服务已重启"
    fi
}

# ----------------------------- 主流程 ----------------------------------
show_help() {
    cat << EOF
用法: $0 [选项]

选项:
  -u          卸载 SolisACE
  -h          显示此帮助信息
  -v          显示版本信息

不带选项运行时将启动交互式安装向导。
EOF
}

show_version() {
    echo "SolisACE 安装脚本 v${SCRIPT_VERSION}"
}

# 解析命令行参数
UNINSTALL=0
while getopts "uhv" opt; do
    case $opt in
        u) UNINSTALL=1 ;;
        h) show_help; exit 0 ;;
        v) show_version; exit 0 ;;
        *) show_help; exit 1 ;;
    esac
done

# 检查是否以 root 运行
if [ "$EUID" -eq 0 ] && [ "$(uname -m)" != "mips" ]; then
    print_error "请勿以 root 用户运行此脚本。"
    exit 1
fi

# 执行相应操作
if [ "$UNINSTALL" -eq 1 ]; then
    uninstall_all
    exit 0
fi

# 交互式安装
print_header "SolisACE 交互式安装向导 v${SCRIPT_VERSION}"

# 确认或修改默认路径
print_info "检测到以下默认路径，如有不符请修改："
KLIPPER_HOME=$(prompt_input "Klipper 安装目录" "$KLIPPER_HOME")
KLIPPER_CONFIG_HOME=$(prompt_input "Klipper 配置目录" "$KLIPPER_CONFIG_HOME")
MOONRAKER_HOME=$(prompt_input "Moonraker 安装目录" "$MOONRAKER_HOME")
MOONRAKER_CONFIG="${KLIPPER_CONFIG_HOME}/moonraker.conf"
PRINTER_CFG="${KLIPPER_CONFIG_HOME}/printer.cfg"

# 验证关键路径
if [ ! -d "$KLIPPER_HOME/klippy/extras" ]; then
    print_error "Klipper extras 目录不存在: $KLIPPER_HOME/klippy/extras"
    exit 1
fi
if [ ! -d "$MOONRAKER_HOME/moonraker/components" ]; then
    print_error "Moonraker components 目录不存在: $MOONRAKER_HOME/moonraker/components"
    exit 1
fi

# 执行安装步骤
install_requirements
install_klipper_extras
install_config
install_moonraker_component
add_update_manager
install_web_nginx

restart_services

print_header "安装成功完成！"
_HOST_IP=$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -v '^$' | head -1)
if [ "${INSTALL_WEB:-0}" -eq 1 ]; then
    _WEB_SUMMARY="已安装 (nginx, 端口 ${WEB_PORT:-8088})
                    文件位于: ${WEB_DIR:-~/ace-dashboard}
                    访问地址: http://${_HOST_IP:-<打印机IP>}:${WEB_PORT:-8088}/ace.html"
else
    _WEB_SUMMARY="未安装"
fi
cat << EOF

SolisACE 已成功安装。

- Klipper 扩展:     $KLIPPER_HOME/klippy/extras/ace.py（已含温度传感器）
- Moonraker 扩展:   $MOONRAKER_HOME/moonraker/components/ace_status.py
- Web 仪表板:       $_WEB_SUMMARY
- 配置文件:         $KLIPPER_CONFIG_HOME/ace.cfg
                    $KLIPPER_CONFIG_HOME/printer.cfg (包含 [include ace.cfg])
                    $KLIPPER_CONFIG_HOME/moonraker.conf (包含 [ace_status] 及 [update_manager SolisACE])

如需卸载，请运行: $0 -u

EOF