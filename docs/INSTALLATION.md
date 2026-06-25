# SolisACE 安装指南

## 目录

1. [前提条件](#前提条件)
2. [设备连接](#设备连接)
3. [自动安装](#自动安装)
4. [手动安装](#手动安装)
5. [验证安装](#验证安装)
6. [Moonraker 配置](#moonraker-配置)
7. [更新](#更新)
8. [卸载](#卸载)

---

## 前提条件

### 1. 已安装 Klipper

确保 Klipper 已安装并正常运行，模块需要访问：
- `~/klipper/klippy/extras/` —— Klipper 插件目录
- `~/printer_data/config/` —— 配置文件目录
- Moonraker（可选，用于自动更新）

### 2. Python 依赖

模块需要 `pyserial` 库：

```bash
pip3 install pyserial
```

安装脚本 `install.sh` 会自动安装此依赖。

### 3. USB 连接

确保 ACE Pro 设备已通过 USB 连接到运行 Klipper 的系统。

---

## 设备连接

### 接口针脚说明

ACE Pro 通过 MX3.0 6P 端子连接到标准 USB：

![Molex](/img/molex.png)

**针脚分布：**

- **1** —— 24V（VCC，**请勿接入！** ACE 有独立供电）
- **2** —— GND（地线）
- **3** —— D-（USB 数据负极）
- **4** —— D+（USB 数据正极）

将 MX3.0 端子连接到普通 USB 线即可，无需额外操作。

端子可在电商平台搜索关键词【MX3.0 公壳】（公壳需搭配母端子）。

### 验证连接

物理连接后，验证系统是否识别设备：

```bash
# 查看 USB 设备
lsusb | grep -i anycubic

# 应显示 VID:PID 为 28e9:018a 的设备
# 例如：Bus 001 Device 003: ID 28e9:018a Anycubic ACE
```

若未显示设备：
- 检查 USB 线
- 尝试其他 USB 口
- 确认 ACE 设备已通电

---

## 自动安装

### 第一步：克隆仓库

```bash
cd ~
git clone https://github.com/Solismuchengxue/Solis_ACE.git
cd Solis_ACE
```

### 第二步：运行安装脚本

```bash
chmod +x install.sh
./install.sh
```

### 安装脚本执行内容：

1. ✅ 检查 Klipper 目录是否存在
2. ✅ 创建 `ace.py` 模块的符号链接
3. ✅ 复制 `ace.cfg` 配置文件（若尚不存在）
4. ✅ 安装 Python 依赖（`pyserial`）
5. ✅ 安装 Web 仪表板至 nginx（端口 8088）
6. ✅ 在 `moonraker.conf` 中添加更新管理配置
7. ✅ 重启 Klipper 和 Moonraker 服务

### 安装脚本选项

```bash
./install.sh -v    # 显示版本
./install.sh -h    # 显示帮助
./install.sh -u    # 卸载
```

---

## 手动安装

若自动安装不适用于您的系统，请按以下步骤手动安装：

### 1. 创建模块链接

```bash
ln -sf ~/Solis_ACE/extras/ace.py ~/klipper/klippy/extras/ace.py
```

### 2. 复制配置文件

```bash
cp ~/Solis_ACE/ace.cfg ~/printer_data/config/ace.cfg
nano ~/printer_data/config/ace.cfg
```

### 3. 安装依赖

```bash
# 若使用 Klipper 虚拟环境
~/klippy-env/bin/pip3 install pyserial
# 或
pip3 install pyserial
```

### 4. 添加到 printer.cfg

在 `printer.cfg` 中添加：

```ini
[include ace.cfg]
```

### 5. 安装 Moonraker 组件

```bash
ln -sf ~/Solis_ACE/moonraker/ace_status.py \
    ~/moonraker/moonraker/components/ace_status.py
```

在 `moonraker.conf` 中添加：

```ini
[ace_status]
```

### 6. 重启服务

```bash
sudo systemctl restart klipper
sudo systemctl restart moonraker
```

---

## 验证安装

### 1. 检查 Klipper 日志

```bash
tail -f ~/printer_data/logs/klippy.log
```

应出现以下信息：
- `Connected to ACE at /dev/serial/...`
- `Device info: Anycubic Color Engine Pro V1.x.x`

### 2. 测试 G-code 命令

通过 Mainsail/Fluidd 控制台或 Klipper 控制台执行：

```gcode
ACE_STATUS
```

应返回设备状态信息。

### 3. 测试连接详情

```gcode
ACE_DEBUG METHOD=get_info
```

应返回设备型号和固件版本信息。

### 4. 验证 Python 模块

```bash
python3 -c "import serial; print('pyserial OK')"
```

---

## Moonraker 配置

### 1. ACE Status API（自动安装）

安装脚本 `install.sh` 会自动：
- 创建 `ace_status.py` 组件的符号链接至 `~/moonraker/moonraker/components/`
- 在 `moonraker.conf` 中添加 `[ace_status]` 配置节
- 重启 Moonraker

安装完成后，以下 REST 接口即可使用：
- `GET /server/ace/status` —— 获取 ACE 状态
- `GET /server/ace/slots` —— 获取槽位信息
- `POST /server/ace/command` —— 执行 ACE 命令

示例请求：
```bash
curl -X POST http://<HOST>:7125/server/ace/command \
  -H "Content-Type: application/json" \
  -d '{"command":"ACE_PARK_TO_TOOLHEAD","params":{"INDEX":0}}'
```

详细 API 文档参见 [Moonraker API](MOONRAKER_API.md)。

### 2. Web 仪表板（nginx 自动安装）

安装脚本会自动将 Web 仪表板部署到 nginx，默认端口 **8088**：

```
http://<打印机IP>:8088/ace.html
```

使用 8088 端口以避免与 Mainsail/Fluidd（通常占用 80 端口）冲突。

**连接原理：**

nginx 仅提供静态文件服务，浏览器直接连接 Moonraker（`<打印机IP>:7125`）。  
install.sh 会自动在 `moonraker.conf` 中添加 CORS 配置（`cors_domains: *://*:8088`），仅允许来自仪表板端口的页面访问 Moonraker，其他网站无法访问。

Web 界面主要文件：
- `ace.html` —— 主页面入口
- `ace-dashboard.js` —— 主应用逻辑
- `ace-dashboard.css` —— 样式表
- `ace-dashboard-config.js` —— API 配置

**API 地址说明：**

`ace-dashboard-config.js` 默认使用 `window.location.hostname + ':7125'` 自动指向 Moonraker，无需手动修改。  
若需自定义，编辑 `ace-dashboard-config.js`：

```javascript
apiBase: 'http://192.168.1.100:7125',  // 替换为实际 IP
```

### 3. 自动更新（update_manager）

安装脚本会自动在 `moonraker.conf` 中添加：

```ini
[update_manager SolisACE]
type: git_repo
path: ~/Solis_ACE
origin: https://github.com/Solismuchengxue/Solis_ACE.git
primary_branch: main
managed_services: klipper
```

更新可通过 Mainsail/Fluidd 的 Update Manager 界面执行。

---

## 安装后配置

### 配置串口

编辑 `ace.cfg`：

```ini
[ace]
serial: /dev/serial/by-id/usb-ANYCUBIC_ACE_1-if00
baud: 115200
```

**说明：** 建议使用 `/dev/serial/by-id/` 路径，设备重插后路径不变。用 `ls /dev/serial/by-id/` 找到 ACE 对应的条目后填入。

### 基础参数配置

```ini
feed_speed: 25                    # 进给速度（10-25 mm/s）
retract_speed: 25                 # 回退速度（10-25 mm/s）
park_hit_count: 5                 # 停泊稳定检测次数
toolchange_retract_length: 100    # 换工具回退长度（mm）
```

完整参数说明见 [配置参考](CONFIGURATION.md)。

---

## 更新

### 通过 Moonraker 自动更新

若已配置 `update_manager`，通过界面更新：
- Mainsail：Settings → Machine → Update Manager
- Fluidd：Settings → Machine → Update Manager

### 手动更新

```bash
cd ~/Solis_ACE
git pull
./install.sh
```

---

## 卸载

### 自动卸载

```bash
cd ~/Solis_ACE
./install.sh -u
```

卸载脚本会：
- 删除 Klipper 模块符号链接
- 删除 Moonraker 组件符号链接
- 移除 nginx 站点配置
- 重载 nginx
- 从 `moonraker.conf` 移除更新管理配置

### 手动卸载

1. **删除模块链接：**
```bash
rm ~/klipper/klippy/extras/ace.py
rm ~/moonraker/moonraker/components/ace_status.py
```

2. **清理配置：**
```ini
# 从 printer.cfg 删除：
# [include ace.cfg]

# 从 moonraker.conf 删除：
# [ace_status]
# [update_manager SolisACE]
```

3. **删除 nginx 站点：**
```bash
sudo rm /etc/nginx/sites-enabled/ace-dashboard
sudo rm /etc/nginx/sites-available/ace-dashboard
sudo systemctl reload nginx
```

4. **重启服务：**
```bash
sudo systemctl restart klipper
sudo systemctl restart moonraker
```

---

## 安装问题排查

### 问题：找不到 Klipper 安装目录

**解决方法：**
- 确认 Klipper 安装在 `~/klipper` 目录
- 若目录不同，请使用手动安装

### 问题：pyserial 未找到

**解决方法：**
```bash
pip3 install pyserial
# 或 Klipper 虚拟环境：
~/klippy-env/bin/pip3 install pyserial
```

### 问题：权限被拒绝

**解决方法：**
- 不要以 root 运行安装脚本
- 确认当前用户有 Klipper 目录写入权限
- 将用户加入 `dialout` 组：`sudo usermod -a -G dialout $USER`

### 问题：设备未被识别

**解决方法：**
- 检查 USB 连接
- 确认设备已通电
- 执行 `lsusb` 查找设备
- 在配置中明确指定串口路径

---

## 下一步

安装成功后：

1. ✅ 阅读 [用户指南](USER_GUIDE.md)
2. ✅ 查阅 [命令参考](COMMANDS.md)
3. ✅ 根据需要调整 [配置参数](CONFIGURATION.md)
4. ✅ 访问 Web 仪表板：`http://<打印机IP>:8088/ace.html`
5. ✅ 测试基础命令
6. ✅ 测试连接管理命令：`ACE_CONNECT`、`ACE_DISCONNECT`、`ACE_CONNECTION_STATUS`
7. ✅ 如使用外部耗材传感器，测试 `ACE_CHECK_FILAMENT_SENSOR`

---

*最后更新：2026*
