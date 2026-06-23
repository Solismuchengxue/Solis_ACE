# SolisACE

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

**SolisACE** 是 [ValgACE](https://github.com/agrloki/ValgACE) 的个人修改版，为 Anycubic Color Engine Pro (ACE Pro) 自动换料装置提供完整的 Klipper 集成支持。

**状态：** 开发中 · 基于单 ACE 实例优化 · 仓库：[Solismuchengxue/Solis_ACE](https://github.com/Solismuchengxue/Solis_ACE)

---

## 目录

- [功能](#功能)
- [系统要求](#系统要求)
- [快速开始](#快速开始)
- [设备连接](#设备连接)
- [Web 仪表板](#web-仪表板)
- [主要命令](#主要命令)
- [REST API](#rest-api)
- [文档](#文档)
- [致谢](#致谢)

---

## 功能

**换料管理**
- 4 槽位自动换色
- 可调速度的进料与回退
- 自动停泊到喷嘴
- 无限料盘模式（infinity spool），支持自定义槽位顺序与自动触发

**干燥管理**
- 可编程耗材烘干
- 温度与时间控制

**槽位映射**
- 将 Klipper 工具索引（T0–T3）重新映射到设备物理槽位
- `ACE_GET_SLOTMAPPING` / `ACE_SET_SLOTMAPPING` / `ACE_RESET_SLOTMAPPING`

**连接管理**
- 外部耗材传感器支持
- 错误自动恢复重连（`ACE_RECONNECT`）
- 可自定义暂停宏

**激进停泊（Aggressive Parking）**
- 基于耗材传感器的替代停泊算法
- 适合进料路径较长的打印机

**Klipper 集成**
- 完整 G-code 宏支持
- 异步命令处理
- 温度传感器集成（`temperature_ace`）

**Moonraker 集成**
- REST API 获取 ACE 状态与执行命令
- WebSocket 实时状态推送

---

## 系统要求

- **Klipper** + **Moonraker**（已安装并正常运行）
- **Python 3** + **pyserial**（install.sh 自动安装）
- **nginx**（用于 Web 仪表板，install.sh 自动安装）
- **USB**（ACE Pro 通过 USB CDC 连接）

---

## 快速开始

```bash
# 克隆仓库
git clone https://github.com/Solismuchengxue/Solis_ACE.git
cd Solis_ACE

# 运行安装脚本（交互式）
./install.sh
```

install.sh 会自动完成：
1. 安装 Python 依赖（`pyserial`）
2. 创建 Klipper 扩展符号链接（`ace.py`，已含温度传感器）
3. 复制配置文件（`ace.cfg`）并添加至 `printer.cfg`
4. 安装 Moonraker 组件（`ace_status.py`）并配置更新管理器
5. 部署 Web 仪表板到 nginx（默认端口 8088）
6. 在 `moonraker.conf` 中配置 CORS（允许仪表板直连 Moonraker）
7. 重启 Klipper 和 Moonraker

安装完成后，在 Klipper 控制台验证：

```gcode
ACE_STATUS
ACE_DEBUG METHOD=get_info
```

---

## 设备连接

ACE Pro 通过 MX3.0 6P 端子连接标准 USB：

![Molex](/.github/img/molex.png)

| 针脚 | 说明 |
|------|------|
| 1 | 24V VCC — **勿接！** ACE 有独立供电 |
| 2 | GND |
| 3 | D-（USB 数据负极） |
| 4 | D+（USB 数据正极） |

将 MX3.0 端子连接到普通 USB 线即可。端子可在电商搜索【MX3.0 公壳】。

![MX3.0](/.github/img/MX3.0Male shell+ female terminal.png)

---

## Web 仪表板

![Web](/.github/img/valgace-web.png)

install.sh 自动将 Web 仪表板部署到 nginx，默认端口 **8088**：

```
http://<打印机IP>:8088/ace.html
```

**连接方式：** 浏览器直连 Moonraker（`打印机IP:7125`），nginx 仅提供静态文件服务。install.sh 已自动配置 Moonraker CORS。

主要功能：
- 实时设备状态
- 槽位管理（进料、回退、停泊）
- 干燥控制
- WebSocket 实时更新

---

## 主要命令

```gcode
ACE_STATUS                              # 查看设备状态
ACE_CHANGE_TOOL TOOL=0                  # 换到槽位 0
ACE_CHANGE_TOOL TOOL=-1                 # 卸载耗材
ACE_PARK_TO_TOOLHEAD INDEX=0            # 停泊到喷嘴
ACE_FEED INDEX=0 LENGTH=50 SPEED=25     # 进给
ACE_RETRACT INDEX=0 LENGTH=50 SPEED=25  # 回退
ACE_START_DRYING TEMP=50 DURATION=120   # 开始烘干
ACE_STOP_DRYING                         # 停止烘干
ACE_INFINITY_SPOOL                      # 无限料盘切换
ACE_SET_SLOTMAPPING INDEX=0 SLOT=1      # 槽位映射
ACE_RECONNECT                           # 重新连接
ACE_GET_HELP                            # 查看所有命令
```

完整命令列表见 [命令参考](docs/COMMANDS.md)。

---

## REST API

```bash
# 获取 ACE 状态
curl http://<打印机IP>:7125/server/ace/status

# 执行命令
curl -X POST http://<打印机IP>:7125/server/ace/command \
  -H "Content-Type: application/json" \
  -d '{"command":"ACE_PARK_TO_TOOLHEAD","params":{"INDEX":0}}'
```

详见 [Moonraker API 文档](docs/MOONRAKER_API.md)。

---

## 文档

| 文档 | 说明 |
|------|------|
| [安装指南](docs/INSTALLATION.md) | 详细安装步骤 |
| [用户指南](docs/USER_GUIDE.md) | 使用方法 |
| [命令参考](docs/COMMANDS.md) | 所有 G-code 命令 |
| [配置参考](docs/CONFIGURATION.md) | 全部配置参数 |
| [Moonraker API](docs/MOONRAKER_API.md) | REST API 说明 |
| [故障排除](docs/TROUBLESHOOTING.md) | 常见问题 |
| [通信协议](docs/PROTOCOL.md) | ACE 二进制协议 |
| [温度传感器](docs/ACE_TEMPERATURE_SENSOR.md) | temperature_ace 模块 |
| [变更日志](docs/changelog.md) | 版本历史 |

---

## 支持

- **Telegram：** [perdoling3d](https://t.me/perdoling3d/45834) · [ERCFcrealityACEpro](https://t.me/ERCFcrealityACEpro/21334)
- **GitHub Issues：** [Solismuchengxue/Solis_ACE](https://github.com/Solismuchengxue/Solis_ACE/issues)
- **演示视频：** [YouTube](https://youtu.be/hozubbjeEw8)

---

## 致谢

- [ValgACE](https://github.com/agrloki/ValgACE) by agrloki — 本项目的基础
- [DuckACE](https://github.com/utkabobr/DuckACE) by utkabobr
- [BunnyACE](https://github.com/BlackFrogKok/BunnyACE) by BlackFrogKok
- [acepro-mmu-dashboard](https://github.com/ducati1198/acepro-mmu-dashboard) by ducati1198

## 许可证

[GNU GPL v3](LICENSE.md)
