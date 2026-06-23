# SolisACE 用户指南

通过 Klipper 管理 Anycubic Color Engine Pro 设备的完整使用说明。

## 目录

1. [介绍](#介绍)
2. [基本概念](#基本概念)
3. [Web 仪表板](#web-仪表板)
4. [初次使用](#初次使用)
5. [换工具](#换工具)
6. [耗材管理](#耗材管理)
7. [停泊耗材](#停泊耗材)
8. [烘干管理](#烘干管理)
9. [无限料盘模式](#无限料盘模式)
10. [连接管理](#连接管理)
11. [切片器集成](#切片器集成)
12. [典型使用场景](#典型使用场景)

---

## 介绍

SolisACE 通过 Klipper G-code 命令提供对 Anycubic Color Engine Pro 设备的完整控制。本指南帮助您掌握模块的全部功能。

### 您将学到

- 如何检查设备连接状态
- 如何加载和卸载耗材
- 如何使用自动换工具功能
- 如何配置耗材烘干
- 如何与切片器集成实现多色打印

---

## 基本概念

### 槽位（Slots）

ACE Pro 支持 **4 个耗材槽位**：
- **编号：** 0、1、2、3
- **状态：** 每个槽位为 `ready`（就绪）或 `empty`（空）

### 工具（Tools）

- **TOOL=-1：** 卸载耗材（无工具）
- **TOOL=0-3：** 从对应槽位加载耗材

### 停泊（Parking）

将耗材从 ACE 进给到打印机喷嘴的过程。通过检测耗材碰到喷嘴限位开关的计数来判断停泊完成。

### Feed Assist（送料助手）

自动维持打印期间耗材张力的送料辅助机制。

---

## Web 仪表板

SolisACE 提供现代化的 Web 仪表板，可在浏览器中管理 ACE 设备。安装后默认通过 nginx 在端口 8088 提供服务：

```
http://<打印机IP>:8088/ace.html
```

### 仪表板功能

#### 状态监控

- **设备状态** —— 实时显示型号、固件、温度、风扇状态
- **连接指示** —— 显示 WebSocket 连接状态
- **自动刷新** —— 状态每隔几秒自动更新

#### 槽位管理

每个槽位可执行以下操作：

- **加载** —— 从该槽位加载耗材（`ACE_CHANGE_TOOL`）
- **停泊** —— 将耗材停泊到热端（`ACE_PARK_TO_TOOLHEAD`）
- **助手** —— 开/关该槽位的 feed assist（`ACE_ENABLE/DISABLE_FEED_ASSIST`）
- **进给** —— 弹出对话框进给指定长度的耗材
- **回退** —— 弹出对话框回退指定长度的耗材

#### 烘干管理

- 设置目标温度（20-55°C）
- 设置烘干时长（分钟）
- 启动/停止烘干
- 显示剩余时间

#### 快捷操作

- **卸载耗材** —— 快速卸载当前耗材
- **刷新状态** —— 手动刷新设备状态

### 仪表板配置

编辑 `webui/ace-dashboard-config.js` 可修改以下设置：
- Moonraker API 地址
- 刷新间隔
- 命令默认值

---

## 初次使用

### 第一步：检查连接

安装并配置完成后，验证连接：

```gcode
ACE_STATUS
```

应返回设备状态。若显示 `disconnected`，请检查：
- USB 连接
- `ace.cfg` 中的串口配置
- Klipper 日志

### 第二步：获取设备信息

```gcode
ACE_DEBUG METHOD=get_info
```

应返回：
- 设备型号
- 固件版本
- 槽位数量

### 第三步：检查槽位状态

```gcode
ACE_STATUS
```

查看槽位信息，状态为 `ready` 的槽位可正常使用。

---

## 换工具

### 加载耗材

**基础方式：**
```gcode
ACE_CHANGE_TOOL TOOL=0
```

**通过别名：**
```gcode
T0  # 等效于上面的命令
```

**执行流程：**
1. 检查当前工具
2. 若有其他工具已加载 → 先回退旧耗材
3. 等待旧槽位就绪
4. 将新耗材停泊到喷嘴
5. 完成，可以开始打印

### 卸载耗材

```gcode
ACE_CHANGE_TOOL TOOL=-1
# 或别名：
TR
```

### 从一个槽位切换到另一个

```gcode
# 当前：T0，目标：T2
ACE_CHANGE_TOOL TOOL=2
```

模块会自动：
- 回退槽位 0 的耗材
- 等待槽位 0 就绪
- 加载槽位 2 的耗材
- 将耗材停泊到喷嘴

---

## 耗材管理

### 进给耗材

```gcode
ACE_FEED INDEX=0 LENGTH=50 SPEED=25
```

**参数：**
- `INDEX` —— 槽位编号（0-3）
- `LENGTH` —— 进给长度（mm）
- `SPEED` —— 进给速度（mm/s，可选）

### 回退耗材

```gcode
ACE_RETRACT INDEX=0 LENGTH=50 SPEED=25 MODE=0
```

**参数：**
- `INDEX` —— 槽位编号（0-3）
- `LENGTH` —— 回退长度（mm）
- `SPEED` —— 回退速度（mm/s，可选）
- `MODE` —— 模式（0=普通，1=增强）

### 运行中修改速度

```gcode
# 开始进给
ACE_FEED INDEX=0 LENGTH=200 SPEED=20

# 减速进给
ACE_UPDATE_FEEDING_SPEED INDEX=0 SPEED=15

# 停止进给
ACE_STOP_FEED INDEX=0
```

### 停止操作

```gcode
ACE_STOP_FEED INDEX=0      # 停止进给
ACE_STOP_RETRACT INDEX=0   # 停止回退
```

---

## 停泊耗材

### 手动停泊

```gcode
ACE_PARK_TO_TOOLHEAD INDEX=0
```

**执行过程：**
- 为指定槽位启动 feed assist
- 耗材开始向喷嘴方向进给
- 模块通过计数器检测耗材是否到达喷嘴
- 计数稳定后停泊完成，自动停止 feed assist

**查看停泊状态：**
```gcode
ACE_STATUS
# 关注 feed_assist_count 值，停泊过程中应持续增大
```

### 自动停泊

以下操作会自动触发停泊：
- 换工具（`ACE_CHANGE_TOOL`）
- 无限料盘切换（`ACE_INFINITY_SPOOL`）

---

## 烘干管理

### 启动烘干

```gcode
ACE_START_DRYING TEMP=50 DURATION=120
```

**参数：**
- `TEMP` —— 温度（°C），范围 20-55
- `DURATION` —— 持续时间（分钟），最大 240

**示例：**
```gcode
ACE_START_DRYING TEMP=50 DURATION=120   # 50°C 烘干 2 小时
ACE_START_DRYING TEMP=45 DURATION=240   # 45°C 烘干 4 小时（最长）
```

**执行过程：**
- 加热器启动
- 风扇以 7000 RPM 运转
- 维持目标温度
- 时间到后风扇继续运转至完全冷却

### 查看烘干状态

```gcode
ACE_STATUS
```

关注 `dryer` 部分：
```json
{
  "dryer": {
    "status": "drying",
    "target_temp": 50,
    "duration": 240,
    "remain_time": 120
  },
  "temp": 48
}
```

### 停止烘干

```gcode
ACE_STOP_DRYING
```

风扇继续运转至加热器完全冷却。

---

## 无限料盘模式

### 配置

在 `ace.cfg` 中启用：
```ini
infinity_spool_mode: True
```

### 设置槽位切换顺序

使用前必须设置顺序：

```gcode
# 顺序切换：0 → 1 → 2 → 3
ACE_SET_INFINITY_SPOOL_ORDER ORDER="0,1,2,3"

# 跳过空槽位 2：0 → 1 → 3
ACE_SET_INFINITY_SPOOL_ORDER ORDER="0,1,none,3"

# 自定义顺序：2 → 0 → 1 → 3
ACE_SET_INFINITY_SPOOL_ORDER ORDER="2,0,1,3"
```

**顺序规则：**
- 使用数字 `0-3` 指定槽位
- 使用 `none` 跳过槽位
- 必须包含恰好 4 个元素

### 手动触发切换

当打印中耗材用尽时：

```gcode
ACE_INFINITY_SPOOL
```

**执行流程：**
1. 从变量 `ace_infsp_order` 读取顺序
2. 在顺序中找到当前活动槽位
3. 确定下一个有效槽位（跳过 `none`）
4. 检查下一槽位是否就绪
5. 执行宏 `_ACE_PRE_INFINITYSPOOL`
6. 将新耗材停泊到喷嘴
7. 执行宏 `_ACE_POST_INFINITYSPOOL`
8. 保存新的顺序位置

**特性：**
- 顺序保存在 `save_variables` 中，重启后保留
- 到达最后一个槽位后循环回到第一个
- 标记为 `none` 的槽位自动跳过
- 可随时通过 `ACE_SET_INFINITY_SPOOL_ORDER` 修改顺序

### 自动触发

开启 `infinity_spool_mode` 后，模块会在打印期间自动监控活动槽位。检测到 `empty` 状态并经过 `infinity_spool_debounce` 秒确认后，自动触发切换。详见 [配置参考](CONFIGURATION.md#infinity_spool_debounce)。

### 重置顺序位置

```gcode
RESET_INFINITY_SPOOL
```

将当前位置重置为顺序起点。

---

## 连接管理

### `ACE_CONNECT`

连接到 ACE 设备（设备被断开后使用）。

```gcode
ACE_CONNECT
```

### `ACE_DISCONNECT`

强制断开与 ACE 设备的连接。

```gcode
ACE_DISCONNECT
```

### `ACE_CONNECTION_STATUS`

检查当前连接状态。

```gcode
ACE_CONNECTION_STATUS
```

### `ACE_RECONNECT`

重置连接错误标志并重新连接。

```gcode
ACE_RECONNECT
```

### `ACE_CHECK_FILAMENT_SENSOR`

检查外部耗材传感器状态（需在配置中定义 `filament_sensor`）。

```gcode
ACE_CHECK_FILAMENT_SENSOR
```

---

## 切片器集成

### PrusaSlicer / SuperSlicer

在打印机设置中添加换工具宏：

**打印开始：**
```gcode
T0  ; 加载槽位 0
G28 ; 归零
```

**颜色/材料切换：**
```gcode
T1  ; 切换到槽位 1
```

**PrusaSlicer 设置路径：**
1. 打印机设置 → 自定义 G-code
2. 换工具 G-code：`T[current_extruder]`

### Cura

1. 扩展 → 后处理 → 修改 G-Code
2. 添加脚本 → 换工具
3. 在"换工具 G-code"字段填入：`T[tool]`

### OrcaSlicer

同 PrusaSlicer，使用 `T0-T3` 宏切换工具。

---

## 典型使用场景

### 场景 1：首次加载耗材

```gcode
# 1. 检查设备状态
ACE_STATUS

# 2. 加载槽位 0 的耗材
T0

# 3. 确认耗材已加载
ACE_STATUS
```

### 场景 2：多色打印

**准备：**
```gcode
T0  # 红色
T1  # 蓝色
T2  # 黄色
```

在切片器中通过 `T0-T3` 宏控制颜色切换。

### 场景 3：打印前烘干耗材

```gcode
# 1. 启动烘干 2 小时
ACE_START_DRYING TEMP=50 DURATION=120

# 2. 定期检查状态
ACE_STATUS

# 3. 烘干完成后加载耗材
T0
```

### 场景 4：处理空槽位

```gcode
# 1. 检测到空槽（通过 _ACE_ON_EMPTY_ERROR 宏自动暂停打印）

# 2. 从其他槽位加载新耗材
T1  # 从槽位 1 加载

# 3. 继续打印
RESUME
```

### 场景 5：无限料盘

**配置：**
```ini
# ace.cfg
infinity_spool_mode: True
```

**使用：**
```gcode
# 1. 设置切换顺序
ACE_SET_INFINITY_SPOOL_ORDER ORDER="0,1,2,3"

# 2. 耗材用尽时手动调用（或自动触发）
ACE_INFINITY_SPOOL

# 3. 需要从头开始时重置
RESET_INFINITY_SPOOL
```

### 场景 6：手动进给/回退（清洁/排故）

```gcode
# 进给耗材
ACE_FEED INDEX=0 LENGTH=100 SPEED=20

# 回退耗材
ACE_RETRACT INDEX=0 LENGTH=100 SPEED=25
```

---

## 监控与诊断

### 查看设备状态

```gcode
ACE_STATUS
```

**关注字段：**
- `status` —— 设备状态（`ready`、`busy`、`disconnected`）
- `slots` —— 各槽位信息
- `dryer` —— 烘干机状态
- `temp` —— 当前温度

### 查看耗材信息（需要 RFID）

```gcode
ACE_FILAMENT_INFO INDEX=0
```

### 调试命令

```gcode
ACE_DEBUG METHOD=get_info    # 设备信息
ACE_DEBUG METHOD=get_status  # 设备状态
```

### 查看日志

```bash
# Klipper 日志（带 ACE 过滤）
tail -f ~/printer_data/logs/klippy.log | grep -i ace
```

---

## 使用建议

### 打印前

1. ✅ 检查所有槽位状态：`ACE_STATUS`
2. ✅ 确认所需槽位已装料且就绪
3. ✅ 如需烘干，提前启动
4. ✅ 加载所需工具：`T0`（或其他编号）

### 打印中

- 不要干预自动换工具流程
- 通过 Web 仪表板监控状态
- 出现错误时查看日志

### 打印后

- 可选择卸载耗材：`TR`
- 如需可进行耗材烘干
- 检查设备状态：`ACE_STATUS`

---

## 常见问题

**Q：如何知道当前加载的是哪个工具？**

A：使用 `ACE_GET_CURRENT_INDEX` 查看当前工具索引，或在日志中查找相关记录。

**Q：能否只使用部分槽位？**

A：可以，仅使用所需槽位即可。其余槽位空置不影响功能。

**Q：停泊不完成怎么办？**

A：
1. 检查槽位就绪状态：`ACE_STATUS`
2. 增大 `park_hit_count` 配置值
3. 检查日志中是否有错误信息

**Q：如何使用无限料盘模式？**

A：
1. 在配置中启用：`infinity_spool_mode: True`
2. 设置槽位顺序：`ACE_SET_INFINITY_SPOOL_ORDER ORDER="0,1,2,3"`
3. 耗材用尽时调用：`ACE_INFINITY_SPOOL`
4. 空槽位使用 `none`：`ORDER="0,1,none,3"`

---

*最后更新：2026*
