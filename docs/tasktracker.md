# 任务追踪

SolisACE 项目开发任务状态记录。

---

## 已完成任务

### SolisACE：Bug 修复与功能完善（2026-06）

- **状态：** 已完成
- **说明：** 修复继承自 ValgACE 的多个 Bug，并针对单 ACE 实例优化
- **完成内容：**
  - [x] 修复 Moonraker 状态查询（原查询不存在的 `ace_instance_0`）
  - [x] 修复 reactor 计时器取消方式（`.cancel()` → `unregister_timer()`）
  - [x] 添加 `ACE_SET_SLOT` 命令
  - [x] 添加 `ACE_SAVE_INVENTORY` 命令
  - [x] Web 仪表板改为 nginx 自动部署（端口 8088）
  - [x] 修复 `ace-dashboard-config.js` 硬编码 IP
  - [x] 修复 `install.sh` 仓库 URL 和 heredoc 问题
  - [x] 重写 `ace_status.py`，增加安全校验

---

### ValgACE：无限料盘文档更新（2026-03-22）

- **状态：** 已完成
- **说明：** 为无限料盘新参数及自动触发系统添加文档
- **完成内容：**
  - [x] 分析 `extras/ace.py` 变更
  - [x] 更新 `CONFIGURATION.md`：新增 `infinity_spool_debounce`、`infinity_spool_pause_on_no_sensor`
  - [x] 更新 `COMMANDS.md`：添加自动触发系统说明
  - [x] 更新 `README.md`：删除无限料盘不可用说明
  - [x] 创建 `docs/changelog.md`
  - [x] 创建 `docs/tasktracker.md`

---

### ValgACE：激进停泊（2025-12）

- **状态：** 已完成
- **说明：** 实现使用外部耗材传感器的替代停泊算法
- **完成内容：**
  - [x] 添加参数 `aggressive_parking`
  - [x] 添加参数 `max_parking_distance`、`parking_speed`、`extended_park_time`、`max_parking_timeout`
  - [x] 实现基于传感器的停泊算法
  - [x] 实现基于距离的停泊算法
  - [x] 更新文档

---

### ValgACE：槽位映射系统（2025-11）

- **状态：** 已完成
- **说明：** 支持将 Klipper 索引（T0-T3）重新映射到设备物理槽位
- **完成内容：**
  - [x] 实现 `ACE_GET_SLOTMAPPING` 命令
  - [x] 实现 `ACE_SET_SLOTMAPPING` 命令
  - [x] 实现 `ACE_RESET_SLOTMAPPING` 命令
  - [x] 实现 `ACE_GET_CURRENT_INDEX` 命令
  - [x] 实现 `ACE_SET_CURRENT_INDEX` 命令
  - [x] 更新文档

---

### ValgACE：无限料盘自动触发（2026-03）

- **状态：** 已完成
- **说明：** 自动监控活动槽位状态，耗材用尽时自动切换
- **完成内容：**
  - [x] 实现防抖机制确认 empty 状态
  - [x] 添加参数 `infinity_spool_debounce`
  - [x] 添加参数 `infinity_spool_pause_on_no_sensor`
  - [x] 集成外部耗材传感器
  - [x] 自动调用 `ACE_INFINITY_SPOOL`

---

## 计划中的任务

### 组合停泊模式

- **状态：** 未开始
- **说明：** 针对分线器到打印头距离较长的打印机，结合 feed 和 feed assist 两种方式实现组合停泊
- **待办：**
  - [ ] 设计算法
  - [ ] 实现
  - [ ] 测试
  - [ ] 文档

### 多 ACE 实例支持

- **状态：** 未开始（当前仅支持单实例）
- **说明：** 支持同时连接多个 ACE Pro 设备
- **待办：**
  - [ ] 设计多实例架构
  - [ ] 实现实例管理
  - [ ] 更新所有命令以支持 `INSTANCE` 参数
  - [ ] 测试
  - [ ] 文档
