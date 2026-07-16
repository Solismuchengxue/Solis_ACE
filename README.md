# SolisACE

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

为 Anycubic Color Engine Pro（ACE Pro）提供 Klipper 集成。项目面向单台 ACE Pro，支持四槽换料、耗材烘干、槽位映射、无限料盘、温度读取、Moonraker 状态接口和独立 Web 仪表板。

> 当前状态：开发中，仅针对Voron Trident。

## 主要功能

- 四槽自动换料，支持 `T0`–`T3` 与物理槽位映射
- 进料、回退、停泊和送料辅助控制
- 耗材烘干温度与时长控制
- 无限料盘模式，可自定义槽位切换顺序
- 外部耗材传感器与激进停泊模式
- 可选的两阶段同步送料/回退和耗材编码器
- ACE 腔体温度接入 Klipper 温度传感器
- Moonraker 状态接口与 WebSocket 状态更新
- 独立 Web 仪表板，不影响 Mainsail 或 Fluidd

## 使用前准备

需要已正常运行的：

- Klipper 与 Moonraker
- Python 3
- 可使用 `sudo` 的普通 Linux 用户
- 使用 systemd，且服务名为 `klipper` 和 `moonraker`
- Debian/Ubuntu 类系统的 APT 环境；安装脚本会在缺少 nginx 时调用 `apt-get`
- ACE Pro 独立 24V 供电
- ACE Pro 与 Klipper 上位机之间的 USB 数据连接

其他 Linux 环境需要自行准备 nginx，并按实际服务管理方式完成重启。

### 连接 ACE Pro

SolisACE 使用 ACE 机壳上的 **6P MX3.0 USB 从机口**连接 Klipper 上位机。4P 接口是串联下一台 ACE 的主机口，连接上位机不会枚举设备。

| MX3.0 针脚 | 用途 |
|---|---|
| 1 | 24V VCC，**不要接入 USB 线** |
| 2 | GND |
| 3 | USB D- |
| 4 | USB D+ |

![ACE Pro MX3.0 接口](/img/molex.png)

连接后确认设备路径存在：

```bash
ls -l /dev/serial/by-id/
```

默认设备路径为：

```text
/dev/serial/by-id/usb-ANYCUBIC_ACE_1-if00
```

## 安装

```bash
git clone https://github.com/Solismuchengxue/Solis_ACE.git
cd Solis_ACE
./install.sh
```

请使用普通用户运行安装脚本，不要直接以 `root` 用户运行。安装向导会让你确认 Klipper、Moonraker 和打印机配置目录，然后完成：

1. 安装 `pyserial`。
2. 链接 Klipper 扩展与 Moonraker 组件。
3. 复制 `ace.cfg` 并在 `printer.cfg` 中加入引用。
4. 配置 Moonraker 更新管理器。
5. 安装 nginx 并部署 Web 仪表板，默认端口为 `8088`。
6. 询问是否重启 Klipper 与 Moonraker。

如果打印机目录不是默认位置，请在安装向导中填写实际路径。

### 初次配置

安装后打开打印机配置目录中的 `ace.cfg`，至少检查：

```ini
[ace]
serial: /dev/serial/by-id/usb-ANYCUBIC_ACE_1-if00
feed_speed: 25
retract_speed: 25
toolchange_retract_length: 100
max_dryer_temperature: 55
```

其中：

- `serial` 必须与本机实际设备路径一致。
- `toolchange_retract_length` 必须按打印机的真实耗材路径标定。
- 紧齿轮挤出机或长送料路径通常需要启用 `aggressive_parking` 并配置外部耗材传感器。
- 默认 `_ACE_PRE_TOOLCHANGE` 与 `_ACE_POST_TOOLCHANGE` 只输出提示；需要切料、冲刷或擦嘴时，请按自己的打印机尺寸修改宏。

修改后重启 Klipper 与 Moonraker。

## 验证安装

在 Klipper 控制台运行：

```gcode
ACE_CONNECTION_STATUS
ACE_STATUS
ACE_DEBUG METHOD=get_info
```

能够看到连接状态、设备信息和四个槽位状态，即表示基础通信正常。

## 日常使用

### Web 仪表板

安装脚本默认将仪表板部署到：

```text
http://<打印机IP>:8088/ace.html
```

![SolisACE Web 仪表板](/img/valgace-web.png)

仪表板可用于查看设备与槽位状态、进料、回退、停泊、设置耗材信息以及控制烘干。

### 常用命令

```gcode
ACE_STATUS                              # 查看设备状态
ACE_CHANGE_TOOL TOOL=0                  # 换到 T0 对应的槽位
ACE_CHANGE_TOOL TOOL=-1                 # 卸载当前耗材
ACE_PARK_TO_TOOLHEAD INDEX=0            # 将槽位 0 的耗材送到打印头
ACE_FEED INDEX=0 LENGTH=50 SPEED=25     # 进料 50 mm
ACE_RETRACT INDEX=0 LENGTH=50 SPEED=25  # 回退 50 mm
ACE_START_DRYING TEMP=50 DURATION=120   # 50°C 烘干 120 分钟
ACE_STOP_DRYING                         # 停止烘干
ACE_SET_SLOTMAPPING INDEX=0 SLOT=1      # 将 T0 映射到物理槽位 1
ACE_INFINITY_SPOOL                      # 手动触发无限料盘换料
ACE_RECONNECT                           # 重新连接 ACE
ACE_GET_HELP                            # 查看全部命令
```

## 更新与卸载

已配置 Moonraker 更新管理器时，可在 Mainsail 或 Fluidd 中拉取 SolisACE 更新。也可以在仓库目录手动更新：

```bash
git pull
sudo systemctl restart klipper moonraker
```

Klipper 扩展和 Moonraker 组件通过符号链接安装，拉取代码并重启对应服务后即可生效。`ace.cfg` 和 Web 仪表板是复制安装的，不会随 `git pull` 自动更新：

- 更新涉及 Moonraker 组件时，需要手动重启 Moonraker；更新管理器默认只管理 Klipper 服务。
- 更新涉及 `ace.cfg` 时，先备份并比较打印机配置目录中的用户配置。重新运行安装脚本会覆盖已安装的 `ace.cfg`。
- 更新涉及 `webui/` 时，需要重新运行安装脚本部署 Web 文件。

卸载：

```bash
./install.sh -u
```

卸载脚本会移除程序链接和 nginx 站点配置；`ace.cfg`、`printer.cfg` 与 `moonraker.conf` 中的相关配置需要按提示手动清理。

## 使用文档

| 文档 | 用途 |
|---|---|
| [安装指南](docs/INSTALLATION.md) | 完整安装、更新与卸载步骤 |
| [用户指南](docs/USER_GUIDE.md) | 换料、送料、烘干和无限料盘操作 |
| [命令参考](docs/COMMANDS.md) | 全部 G-code 命令及参数 |
| [配置参考](docs/CONFIGURATION.md) | 配置项、宏与推荐值 |
| [故障排除](docs/TROUBLESHOOTING.md) | 连接、槽位、烘干与 Web 问题排查 |
| [温度传感器](docs/ACE_TEMPERATURE_SENSOR.md) | 在 Klipper 中使用 ACE 腔体温度 |

遇到问题可在 [GitHub Issues](https://github.com/Solismuchengxue/Solis_ACE/issues) 反馈。

## 致谢与许可

本项目基于 [ValgACE](https://github.com/agrloki/ValgACE)，并参考了 [DuckACE](https://github.com/utkabobr/DuckACE)、[BunnyACE](https://github.com/BlackFrogKok/BunnyACE) 和 [acepro-mmu-dashboard](https://github.com/ducati1198/acepro-mmu-dashboard)。

项目使用 [GNU GPL v3](LICENSE.md) 许可。
