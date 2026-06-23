# SolisACE 文档索引

欢迎阅读 SolisACE 项目文档。SolisACE 是基于 ValgACE 的个人分支，用于在 Klipper 中驱动 Anycubic Color Engine Pro 设备。

## 文档结构

### 主要文档

- **[README.md](../README.md)** - 项目主页，包含功能概览和快速开始
- **[安装指南](INSTALLATION.md)** - 详细的安装步骤
- **[用户指南](USER_GUIDE.md)** - 使用说明
- **[命令参考](COMMANDS.md)** - 全部 G-code 命令列表
- **[配置参考](CONFIGURATION.md)** - 所有配置参数说明
- **[故障排除](TROUBLESHOOTING.md)** - 常见问题与解决方案

### 技术文档

- **[通信协议](PROTOCOL.md)** - ACE Pro 通信协议技术说明
- **[Moonraker API](MOONRAKER_API.md)** - REST API 与 WebSocket 集成文档
- **[ACE 温度传感器](ACE_TEMPERATURE_SENSOR.md)** - 将 ACE 温度接入 Klipper 传感器系统

### 变更历史

- **[Changelog](changelog.md)** - 版本变更记录
- **[任务追踪](tasktracker.md)** - 开发任务状态

### 原始俄语文档

- **[ru/](ru/)** - ValgACE 原始俄语文档（参考原文）

## 快速导航

### 新用户

1. 阅读 [README.md](../README.md) 了解项目概况
2. 按照 [安装指南](INSTALLATION.md) 完成安装
3. 阅读 [用户指南](USER_GUIDE.md) 学习基本用法
4. 查阅 [命令参考](COMMANDS.md) 了解所有命令

### 进阶用户

- [配置参考](CONFIGURATION.md) — 细化参数调整
- [故障排除](TROUBLESHOOTING.md) — 问题诊断
- [Moonraker API](MOONRAKER_API.md) — REST API 集成

### 开发者

- Klipper 插件源码：`extras/ace.py`
- Moonraker 组件：`moonraker/ace_status.py`
- ACE 温度传感器：已并入 `extras/ace.py`（`temperature_ace` sensor_type）
- 通信协议：[PROTOCOL.md](PROTOCOL.md)
- 前端界面：`webui/`，默认端口 8088

## 文档说明

本目录下的中文文档由 ValgACE 俄语原始文档翻译而来，并针对 SolisACE 的实际功能进行了校对和修订。如发现与代码不一致之处，请以代码为准。

---

*最后更新：2026*
