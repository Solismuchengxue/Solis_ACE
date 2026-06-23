# 变更日志

项目所有重要变更均记录于此文件。

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)。

---

## [2026-06] — SolisACE 分支修复与改进

### 新增
- `ACE_SET_SLOT` 命令：为指定槽位设置耗材元数据（颜色、材料类型、温度）
- `ACE_SAVE_INVENTORY` 命令：保存耗材库存（兼容性命令）
- Web 仪表板自动部署到 nginx（端口 8088），无需手动配置 Mainsail/Fluidd

### 修复
- Moonraker `ace_status.py`：修复状态查询一直返回默认值的问题（原因：查询了不存在的 `ace_instance_0` 对象，现改为正确查询 `{"ace": None}`）
- `extras/ace.py`：修复 infinity spool 计时器使用 `.cancel()` 导致的崩溃（Klipper reactor 计时器正确的取消方式是 `reactor.unregister_timer()`）
- `install.sh`：修复 `update_manager` 中的仓库 URL（`SolisACE.git` → `Solis_ACE.git`）
- `install.sh`：修复 heredoc 中 awk `$1` 转义导致 IP 地址显示错误的问题
- `webui/ace-dashboard-config.js`：将 `apiBase` 改为 `http://${window.location.hostname}:7125`（直连 Moonraker），不再依赖 nginx 反向代理；修复打印机在 Ubuntu 远程系统上时无法连接的问题
- `webui/ace_dashboard.nginx.conf`：去除反向代理配置，nginx 仅提供静态文件服务
- `install.sh`：新增 `configure_moonraker_cors()`，自动在 `moonraker.conf` 中添加 CORS 配置（`cors_domains: http://* https://*`），允许浏览器直连 Moonraker

### 变更
- 仓库重命名：`SolisACE` → `Solis_ACE`
- 安装方式统一为 nginx，弃用原 Mainsail/Fluidd 符号链接方式
- `moonraker/ace_status.py` 全面重写，增加输入安全校验
- Web 仪表板连接方式：从 nginx 反向代理改为浏览器直连 Moonraker + CORS

---

## [2026-03-22] — 无限料盘文档更新（ValgACE 上游）

### 新增
- 参数 `infinity_spool_debounce`：确认 empty 状态的防抖时间（默认 2.0 秒）
- 参数 `infinity_spool_pause_on_no_sensor`：无耗材传感器时是否暂停（默认 True）
- 无限料盘自动触发系统说明文档
- 打印期间自动监控活动槽位状态

### 变更
- README 中删除了"无限料盘不可用"的已知问题说明
- 更新 `CONFIGURATION.md`，添加新参数说明
- 更新 `COMMANDS.md`，添加自动触发算法说明

### 修复
- 无限料盘模式现已配合自动触发系统正常工作

---

## [2025-12] — 激进停泊（ValgACE 上游）

### 新增
- 参数 `aggressive_parking`：替代停泊算法
- 参数 `max_parking_distance`：最大停泊进给距离
- 参数 `parking_speed`：停泊进给速度
- 参数 `extended_park_time`：附加停泊超时时间
- 参数 `max_parking_timeout`：停泊最大等待时间
- 通过 `filament_sensor` 参数支持外部耗材传感器

---

## [2025-11] — 槽位映射（ValgACE 上游）

### 新增
- 命令 `ACE_GET_SLOTMAPPING`：查看当前槽位映射
- 命令 `ACE_SET_SLOTMAPPING`：设置索引到槽位的映射
- 命令`ACE_RESET_SLOTMAPPING`：重置映射为默认值
- 命令 `ACE_GET_CURRENT_INDEX`：获取当前工具索引
- 命令 `ACE_SET_CURRENT_INDEX`：手动设置当前工具索引

---

## [2025-10] — 基础版本（ValgACE 上游）

### 新增
- ACE Pro 设备基础控制
- 4 槽位自动换工具
- 耗材烘干管理
- 无限料盘模式（infinity spool）
- 通过 Moonraker 提供 REST API
- ValgACE Dashboard Web 界面
