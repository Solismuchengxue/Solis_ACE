# SolisACE 命令参考

Anycubic Color Engine Pro 设备的全部可用 G-code 命令。

## 目录

1. [信息查询命令](#信息查询命令)
2. [工具管理](#工具管理)
3. [耗材控制](#耗材控制)
4. [Feed Assist（送料助手）](#feed-assist送料助手)
5. [烘干管理](#烘干管理)
6. [槽位映射](#槽位映射)
7. [索引管理](#索引管理)
8. [连接管理](#连接管理)
9. [无限料盘模式](#无限料盘模式)
10. [耗材元数据](#耗材元数据)
11. [调试命令](#调试命令)
12. [命令别名](#命令别名)

---

## 信息查询命令

### `ACE_STATUS`

获取设备完整状态。

**语法：**
```gcode
ACE_STATUS
```

**返回内容：**
- 设备状态（`ready`、`busy`、`disconnected`）
- 烘干机状态
- 烘干机温度
- 全部槽位信息（0-3）
- 当前 feed assist 计数
- 当前 feed assist 活动槽位（`feed_assist_slot`）
- 外部耗材传感器状态（如已配置）
- 索引到槽位映射（`slot_mapping`）

**示例：**
```gcode
ACE_STATUS
```

**返回示例：**
```json
{
  "status": "ready",
  "temp": 25,
  "dryer": {
    "status": "stop",
    "target_temp": 0,
    "duration": 0,
    "remain_time": 0
  },
  "slots": [
    {
      "index": 0,
      "status": "ready",
      "type": "PLA",
      "color": [255, 0, 0]
    }
  ]
}
```

---

### `ACE_FILAMENT_INFO`

获取指定槽位的耗材信息（需要 RFID 标签）。

**语法：**
```gcode
ACE_FILAMENT_INFO INDEX=<0-3>
```

**参数：**
- `INDEX`（必填）—— 槽位编号（0-3）

**返回内容：**
- RFID 标签中的耗材信息：
  - `sku` —— 料号
  - `brand` —— 品牌
  - `type` —— 材料类型（PLA、ABS、PETG 等）
  - `color` —— 颜色 [R, G, B]
  - `diameter` —— 直径（通常为 1.75）
  - `extruder_temp` —— 挤出机温度范围（min/max）
  - `hotbed_temp` —— 热床温度范围（min/max）
  - `total` —— 总长度（米）
  - `current` —— 剩余长度（米）

**说明：** 仅适用于带 RFID 标签的耗材，普通耗材无法获取此信息。

---

### `ACE_GET_HELP`

获取所有 ACE 命令的帮助列表。

**语法：**
```gcode
ACE_GET_HELP
```

**说明：** 输出所有可用 ACE 命令及其简短描述，按类别分组。

---

### `ACE_CHECK_FILAMENT_SENSOR`

检查外部耗材传感器状态（如已配置）。

**语法：**
```gcode
ACE_CHECK_FILAMENT_SENSOR
```

**说明：** 仅在配置文件中设置了 `filament_sensor` 参数时有效。

---

## 工具管理

### `ACE_CHANGE_TOOL`

换工具（自动加载/卸载耗材）。

**语法：**
```gcode
ACE_CHANGE_TOOL TOOL=<编号>
```

**参数：**
- `TOOL`（必填）—— 工具编号：
  - `-1` —— 卸载当前耗材
  - `0-3` —— 从对应槽位加载耗材

**执行流程：**
1. 检查当前工具
2. 执行宏 `_ACE_PRE_TOOLCHANGE`
3. 回退当前耗材（如有）
4. 等待槽位就绪
5. 将新耗材停泊到喷嘴
6. 执行宏 `_ACE_POST_TOOLCHANGE`

**示例：**
```gcode
ACE_CHANGE_TOOL TOOL=0    # 加载槽位 0
ACE_CHANGE_TOOL TOOL=2    # 加载槽位 2
ACE_CHANGE_TOOL TOOL=-1   # 卸载当前耗材
```

**说明：**
- 命令自动检查槽位就绪状态
- 若槽位为空，将调用宏 `_ACE_ON_EMPTY_ERROR`
- 整个过程为异步执行，不阻塞打印

---

### `ACE_PARK_TO_TOOLHEAD`

将指定槽位的耗材停泊到喷嘴。

**语法：**
```gcode
ACE_PARK_TO_TOOLHEAD INDEX=<0-3>
```

**参数：**
- `INDEX`（必填）—— 槽位编号（0-3）

**执行流程：**
1. 检查槽位就绪状态
2. 为该槽位启动 feed assist
3. 监控 `feed_assist_count` 计数
4. 计数稳定后自动判定停泊完成
5. 自动停止 feed assist

**停泊原理：**
- 耗材从 ACE 向喷嘴方向进给
- 到达喷嘴时 `feed_assist_count` 计数递增
- 计数连续 N 次不变时视为停泊完成
- 稳定检测次数通过 `park_hit_count` 配置（默认 5）

**说明：**
- 同一时间只能执行一次停泊
- 若槽位为空，将调用 `_ACE_ON_EMPTY_ERROR`

---

## 耗材控制

### `ACE_FEED`

从指定槽位进给耗材。

**语法：**
```gcode
ACE_FEED INDEX=<0-3> LENGTH=<长度> SPEED=<速度>
```

**参数：**
- `INDEX`（必填）—— 槽位编号（0-3）
- `LENGTH`（必填）—— 进给长度（毫米，最小 1）
- `SPEED`（可选）—— 进给速度（毫米/秒，默认使用配置值）

**示例：**
```gcode
ACE_FEED INDEX=0 LENGTH=50 SPEED=25
ACE_FEED INDEX=2 LENGTH=100        # 使用默认速度
```

---

### `ACE_RETRACT`

回退耗材到槽位。

**语法：**
```gcode
ACE_RETRACT INDEX=<0-3> LENGTH=<长度> SPEED=<速度> MODE=<模式>
```

**参数：**
- `INDEX`（必填）—— 槽位编号（0-3）
- `LENGTH`（必填）—— 回退长度（毫米，最小 1）
- `SPEED`（可选）—— 回退速度（毫米/秒，默认使用配置值）
- `MODE`（可选）—— 回退模式：
  - `0` —— 普通模式（默认）
  - `1` —— 增强模式

**示例：**
```gcode
ACE_RETRACT INDEX=0 LENGTH=50 SPEED=25
ACE_RETRACT INDEX=2 LENGTH=100 MODE=1
```

---

### `ACE_STOP_FEED`

停止进给耗材。

**语法：**
```gcode
ACE_STOP_FEED INDEX=<0-3>
```

**参数：**
- `INDEX`（必填）—— 槽位编号（0-3）

---

### `ACE_STOP_RETRACT`

停止回退耗材。

**语法：**
```gcode
ACE_STOP_RETRACT INDEX=<0-3>
```

**参数：**
- `INDEX`（必填）—— 槽位编号（0-3）

---

### `ACE_UPDATE_FEEDING_SPEED`

在运行中修改进给速度。

**语法：**
```gcode
ACE_UPDATE_FEEDING_SPEED INDEX=<0-3> SPEED=<速度>
```

**参数：**
- `INDEX`（必填）—— 槽位编号（0-3）
- `SPEED`（必填）—— 新速度（毫米/秒，最小 1）

---

### `ACE_UPDATE_RETRACT_SPEED`

在运行中修改回退速度。

**语法：**
```gcode
ACE_UPDATE_RETRACT_SPEED INDEX=<0-3> SPEED=<速度>
```

**参数：**
- `INDEX`（必填）—— 槽位编号（0-3）
- `SPEED`（必填）—— 新速度（毫米/秒，最小 1）

---

## Feed Assist（送料助手）

### `ACE_ENABLE_FEED_ASSIST`

为指定槽位启用送料助手。

**语法：**
```gcode
ACE_ENABLE_FEED_ASSIST INDEX=<0-3>
```

**说明：**
- 启用自动送料机制，维持打印期间的耗材张力
- 通常由停泊过程自动调用
- 换工具后是否自动关闭取决于 `disable_assist_after_toolchange` 配置

---

### `ACE_DISABLE_FEED_ASSIST`

为指定槽位禁用送料助手。

**语法：**
```gcode
ACE_DISABLE_FEED_ASSIST INDEX=<0-3>
```

**说明：** 若不指定 `INDEX`，则使用当前活动槽位。

---

## 烘干管理

### `ACE_START_DRYING`

启动耗材烘干。

**语法：**
```gcode
ACE_START_DRYING TEMP=<温度> DURATION=<时间>
```

**参数：**
- `TEMP`（必填）—— 烘干温度（°C），范围 20-55，受 `max_dryer_temperature` 限制
- `DURATION`（可选）—— 持续时间（分钟），默认 240，最大 240

**示例：**
```gcode
ACE_START_DRYING TEMP=50 DURATION=120    # 50°C 烘干 2 小时
ACE_START_DRYING TEMP=45                 # 45°C 烘干 4 小时（默认）
```

**行为：**
- 加热器启动
- 风扇以 7000 RPM 运转
- 维持目标温度
- 时间到达后风扇继续运转直至冷却完成

---

### `ACE_STOP_DRYING`

停止烘干。

**语法：**
```gcode
ACE_STOP_DRYING
```

**说明：** 停止加热器，风扇继续运转至完全冷却。

---

## 槽位映射

将 Klipper 工具索引（T0-T3）重新映射到设备物理槽位。

### `ACE_GET_SLOTMAPPING`

查看当前槽位映射。

**语法：**
```gcode
ACE_GET_SLOTMAPPING
```

**输出示例：**
```
Slot Mapping:
  T0 (index 0) -> Slot 0
  T1 (index 1) -> Slot 1
  T2 (index 2) -> Slot 2
  T3 (index 3) -> Slot 3
```

默认为直接映射（0→0、1→1、2→2、3→3）。

---

### `ACE_SET_SLOTMAPPING`

设置索引到槽位的映射。

**语法：**
```gcode
ACE_SET_SLOTMAPPING INDEX=<0-3> SLOT=<0-3>
```

**参数：**
- `INDEX`（必填）—— Klipper 工具索引（T0-T3）
- `SLOT`（必填）—— 设备物理槽位编号

**示例：**
```gcode
# 标准映射
ACE_SET_SLOTMAPPING INDEX=0 SLOT=0

# 非标准映射：T0 使用物理槽位 2
ACE_SET_SLOTMAPPING INDEX=0 SLOT=2

# 交换 T0 和 T1
ACE_SET_SLOTMAPPING INDEX=0 SLOT=1
ACE_SET_SLOTMAPPING INDEX=1 SLOT=0
```

**说明：** 修改立即生效，重启 Klipper 后失效；如需永久保存请修改配置文件。

---

### `ACE_RESET_SLOTMAPPING`

重置槽位映射为默认值（0→0、1→1、2→2、3→3）。

**语法：**
```gcode
ACE_RESET_SLOTMAPPING
```

---

## 索引管理

### `ACE_GET_CURRENT_INDEX`

获取当前工具索引值。

**语法：**
```gcode
ACE_GET_CURRENT_INDEX
```

**输出示例：**
```
Current tool index: 2
```

---

### `ACE_SET_CURRENT_INDEX`

手动设置当前工具索引。

**语法：**
```gcode
ACE_SET_CURRENT_INDEX INDEX=<值>
```

**参数：**
- `INDEX`（必填）—— 工具索引（-1 到 3）：
  - `-1` —— 无活动工具（耗材已卸载）
  - `0-3` —— 当前活动工具编号

**说明：** 用于错误恢复，正常使用时无需手动调用。

---

## 连接管理

### `ACE_DISCONNECT`

强制断开与 ACE 设备的连接。

**语法：**
```gcode
ACE_DISCONNECT
```

**说明：** 断开后可使用 `ACE_CONNECT` 重新连接。

---

### `ACE_CONNECT`

连接 ACE 设备。

**语法：**
```gcode
ACE_CONNECT
```

**说明：** Klipper 启动时自动连接；此命令用于 `ACE_DISCONNECT` 后手动重连。

---

### `ACE_RECONNECT`

重置连接错误标志并尝试重新连接。

**语法：**
```gcode
ACE_RECONNECT
```

**适用场景：**
- 连接丢失后恢复
- 出现连接错误后重试
- 无需重启 Klipper 即可恢复连接

---

### `ACE_CONNECTION_STATUS`

检查与 ACE 设备的连接状态。

**语法：**
```gcode
ACE_CONNECTION_STATUS
```

**输出示例（连接丢失时）：**
```
ACE: Connection lost flag is set (attempts: 5/10)
Try ACE_RECONNECT to reset the connection
```

---

## 无限料盘模式

### `ACE_SET_INFINITY_SPOOL_ORDER`

设置无限料盘模式的槽位切换顺序。

**语法：**
```gcode
ACE_SET_INFINITY_SPOOL_ORDER ORDER="<顺序>"
```

**参数：**
- `ORDER`（必填）—— 槽位顺序，格式为 `"0,1,2,3"` 或 `"0,1,none,3"`
  - 使用数字 0-3 指定槽位
  - 使用 `none` 跳过空槽位
  - 必须包含恰好 4 个元素

**示例：**
```gcode
# 顺序切换：0 → 1 → 2 → 3
ACE_SET_INFINITY_SPOOL_ORDER ORDER="0,1,2,3"

# 跳过槽位 2：0 → 1 → 3
ACE_SET_INFINITY_SPOOL_ORDER ORDER="0,1,none,3"

# 自定义顺序：2 → 0 → 1 → 3
ACE_SET_INFINITY_SPOOL_ORDER ORDER="2,0,1,3"
```

**行为：**
- 将顺序保存到变量 `ace_infsp_order`
- 重置当前位置（从头开始）

---

### `ACE_INFINITY_SPOOL`

耗材用尽时自动切换到下一个槽位。

**语法：**
```gcode
ACE_INFINITY_SPOOL
```

**前提条件：**
- 配置中 `infinity_spool_mode: True`
- 已通过 `ACE_SET_INFINITY_SPOOL_ORDER` 设置顺序
- 顺序中至少有一个槽位处于 `ready` 状态

**执行流程：**
1. 验证 infinity_spool_mode 已开启
2. 从变量 `ace_infsp_order` 读取顺序
3. 在顺序中查找当前活动槽位
4. 找到下一个有效槽位（跳过 `none`）
5. 检查下一槽位是否就绪
6. 执行宏 `_ACE_PRE_INFINITYSPOOL`
7. 将新耗材停泊到喷嘴
8. 执行宏 `_ACE_POST_INFINITYSPOOL`
9. 保存新的顺序位置

**相关变量：**
- `ace_infsp_order` —— 槽位顺序字符串，如 `"0,1,none,3"`
- `ace_infsp_position` —— 当前在顺序中的位置（0-3）

---

### 无限料盘自动触发

开启 `infinity_spool_mode` 后，模块在打印期间会自动监控活动槽位状态。

**工作算法：**

1. **检测 empty 状态：**
   - 每 0.5 秒监控活动槽位状态
   - 检测到 `empty` 时启动防抖计时器

2. **确认 empty 状态：**
   - 经过 `infinity_spool_debounce` 秒后再次检查
   - 若状态仍为 `empty`，触发切换流程

3. **切换槽位：**
   - **有耗材传感器**：监控传感器直至触发，然后调用 `ACE_INFINITY_SPOOL`
   - **无耗材传感器**：
     - `infinity_spool_pause_on_no_sensor=True` —— 暂停打印
     - `infinity_spool_pause_on_no_sensor=False` —— 立即调用 `ACE_INFINITY_SPOOL`

---

### `RESET_INFINITY_SPOOL`

重置无限料盘顺序位置（从头开始）。

**语法：**
```gcode
RESET_INFINITY_SPOOL
```

**说明：** 将 `ace_infsp_position` 重置为 0。

---

## 耗材元数据

> **SolisACE 新增命令**（ValgACE 原版中没有）

### `ACE_SET_SLOT`

为指定槽位设置耗材元数据（颜色、材料类型等）。

**语法：**
```gcode
ACE_SET_SLOT INDEX=<槽位> COLOR=<R,G,B> MATERIAL=<材料> TEMP=<温度>
```

或通过工具索引：

```gcode
ACE_SET_SLOT T=<工具索引> COLOR=<R,G,B> MATERIAL=<材料> TEMP=<温度>
```

**参数：**
- `INDEX`（INDEX 与 T 二选一）—— 物理槽位编号（0-3）
- `T`（INDEX 与 T 二选一）—— Klipper 工具索引（0-3），内部转换为物理槽位
- `INSTANCE`（可选）—— 保留参数，当前忽略
- `COLOR`（可选）—— 颜色，格式 `"R,G,B"`，各分量 0-255，默认 `"0,0,0"`
- `MATERIAL`（可选）—— 材料类型字符串（如 `"PLA"`、`"PETG"`）
- `TEMP`（可选）—— 打印温度（°C），范围 0-400
- `FILAMENT_SETTINGS_ID`（可选）—— 切片器耗材配置 ID

**示例：**
```gcode
ACE_SET_SLOT INDEX=0 COLOR=255,0,0 MATERIAL=PLA TEMP=220
ACE_SET_SLOT T=1 COLOR=0,255,0 MATERIAL=PETG TEMP=240
```

---

### `ACE_SAVE_INVENTORY`

保存当前耗材库存状态（保留兼容性命令）。

**语法：**
```gcode
ACE_SAVE_INVENTORY
```

**说明：** 接受 `INSTANCE` 参数但忽略，仅输出确认信息。

---

## 调试命令

### `ACE_DEBUG`

直接调用 ACE 设备 RPC 方法进行调试。

**语法：**
```gcode
ACE_DEBUG METHOD=<方法> PARAMS=<参数>
```

**参数：**
- `METHOD`（必填）—— RPC 方法名：
  - `get_info` —— 获取设备信息
  - `get_status` —— 获取设备状态
  - `get_filament_info` —— 获取耗材信息
- `PARAMS`（可选）—— JSON 格式参数（默认 `{}`）

**示例：**
```gcode
ACE_DEBUG METHOD=get_info
ACE_DEBUG METHOD=get_status
ACE_DEBUG METHOD=get_filament_info PARAMS={"index":0}
```

---

## 命令别名

### `T0`、`T1`、`T2`、`T3`

快速换工具。

```gcode
T0  # 等同于 ACE_CHANGE_TOOL TOOL=0
T1  # 等同于 ACE_CHANGE_TOOL TOOL=1
T2  # 等同于 ACE_CHANGE_TOOL TOOL=2
T3  # 等同于 ACE_CHANGE_TOOL TOOL=3
```

### `TR`

卸载当前耗材。

```gcode
TR  # 等同于 ACE_CHANGE_TOOL TOOL=-1
```

---

## G-code 宏

`ace.cfg` 中定义了以下宏，可根据打印机配置自定义。

### 必须定义的宏

| 宏名 | 调用时机 | 参数 |
|------|----------|------|
| `_ACE_PRE_TOOLCHANGE` | 换工具前 | `FROM`（旧工具索引）、`TO`（新工具索引） |
| `_ACE_POST_TOOLCHANGE` | 换工具后 | `FROM`、`TO` |
| `_ACE_ON_EMPTY_ERROR` | 检测到空槽时 | `INDEX`（空槽编号） |

### 无限料盘相关宏

| 宏名 | 说明 |
|------|------|
| `_ACE_PRE_INFINITYSPOOL` | 无限料盘切换前执行 |
| `_ACE_POST_INFINITYSPOOL` | 无限料盘切换后执行 |
| `SET_INFINITY_SPOOL_ORDER ORDER="..."` | 便捷设置槽位顺序 |
| `RESET_INFINITY_SPOOL` | 重置顺序位置到起点 |

---

## 使用示例

### 换工具

```gcode
ACE_CHANGE_TOOL TOOL=0
# 或通过别名
T0
```

### 进给与回退

```gcode
# 从槽位 0 进给 50mm
ACE_FEED INDEX=0 LENGTH=50 SPEED=25

# 回退 30mm
ACE_RETRACT INDEX=0 LENGTH=30 SPEED=20
```

### 烘干耗材

```gcode
ACE_START_DRYING TEMP=50 DURATION=120
ACE_STOP_DRYING
```

### 无限料盘

```gcode
ACE_SET_INFINITY_SPOOL_ORDER ORDER="0,1,2,3"
ACE_INFINITY_SPOOL    # 耗材用尽时调用
RESET_INFINITY_SPOOL  # 重置顺序位置
```

### 连接诊断

```gcode
ACE_CONNECTION_STATUS
ACE_RECONNECT
ACE_DISCONNECT
ACE_CONNECT
```

---

## 错误处理

所有命令通过以下方式返回错误信息：
- G-code 控制台消息
- Klipper 日志（`~/printer_data/logs/klippy.log`）
- `ACE_STATUS` 命令输出

**常见错误：**
- `ACE Error: Slot is not ready` —— 槽位为空或未就绪
- `ACE Error: Parking failed` —— 停泊失败
- `ACE Error: Connection lost` —— 与设备失去连接

---

*最后更新：2026*
