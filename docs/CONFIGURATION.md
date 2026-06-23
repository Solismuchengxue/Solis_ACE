# SolisACE 配置参考

所有 SolisACE 模块配置参数的详细说明。

## 目录

1. [基础配置](#基础配置)
2. [连接参数](#连接参数)
3. [超时参数](#超时参数)
4. [运行参数](#运行参数)
5. [G-code 宏](#g-code-宏)
6. [配置示例](#配置示例)

---

## 基础配置

### `[ace]` 配置节

所有参数均在 `ace.cfg` 文件的 `[ace]` 节中配置。

`ace.cfg` 已包含完整的参数说明、现成 G-code 宏，以及注释态的完整换料动作示例，可直接复制使用并按需修改。

**最小配置：**
```ini
[ace]
serial: /dev/serial/by-id/usb-ANYCUBIC_ACE_1-if00
baud: 115200
```

---

## 连接参数

### `serial`

ACE 设备的串口路径。

**类型：** 字符串  
**默认值：** 按 VID/PID 自动搜索，或 `/dev/ttyACM0`

**示例：**
```ini
serial: /dev/serial/by-id/usb-ANYCUBIC_ACE_1-if00
serial: /dev/ttyACM0
serial: /dev/ttyUSB0
```

**建议：**
- 使用 `/dev/serial/by-id/` 路径，设备重新插拔后路径不变
- 模块会按 VID/PID `0x28e9:0x018a` 自动检测设备
- 若自动检测可用，可不填此项

**自动搜索条件：**
- VID/PID：`0x28e9:0x018a`
- 端口描述包含："ACE"、"BunnyAce"、"DuckAce"

---

### `baud`

与设备通信的波特率。

**类型：** 整数  
**默认值：** `115200`

```ini
baud: 115200
```

---

## 超时参数

### `response_timeout`

等待设备响应的超时时间（秒）。

**类型：** 浮点数  
**默认值：** `2.0`

```ini
response_timeout: 2.0
```

**建议：** 不建议低于 1.0 秒。

---

### `read_timeout`

从串口读取数据的超时时间（秒）。

**类型：** 浮点数  
**默认值：** `0.1`

```ini
read_timeout: 0.1
```

---

### `write_timeout`

向串口写入数据的超时时间（秒）。

**类型：** 浮点数  
**默认值：** `0.5`

```ini
write_timeout: 0.5
```

---

### `max_queue_size`

命令队列最大长度。

**类型：** 整数  
**默认值：** `20`

```ini
max_queue_size: 20
```

**说明：** 队列满时旧命令会以 "Queue overflow" 错误被丢弃。

---

## 运行参数

### `feed_speed`

默认进给速度（毫米/秒）。

**类型：** 整数  
**默认值：** `50`（代码），`25`（推荐配置）  
**建议范围：** 10-25（制造商推荐）

```ini
feed_speed: 25
```

---

### `retract_speed`

默认回退速度（毫米/秒）。

**类型：** 整数  
**默认值：** `50`（代码），`25`（推荐配置）  
**建议范围：** 10-25

```ini
retract_speed: 25
```

---

### `retract_mode`

回退模式。

**类型：** 整数  
**默认值：** `0`

**可选值：**
- `0` —— 普通模式
- `1` —— 增强模式（对某些耗材更可靠）

```ini
retract_mode: 0
```

---

### `toolchange_retract_length`

换工具时回退耗材的长度（毫米）。

**类型：** 整数  
**默认值：** `100`

```ini
toolchange_retract_length: 100
```

---

### `park_hit_count`

判断停泊完成所需的稳定检测次数。

**类型：** 整数  
**默认值：** `5`

```ini
park_hit_count: 5
```

**工作原理：**
- 停泊时模块跟踪 `feed_assist_count` 计数
- 计数连续 `park_hit_count` 次不变时视为停泊完成
- 值越小 → 完成越快（但可靠性降低）
- 值越大 → 越可靠（但耗时更长）

**建议：**
- 从默认值 5 开始
- 若停泊过早结束 → 增大此值
- 若停泊始终不完成 → 减小此值（不建议低于 3）

---

### `aggressive_parking`

使用外部耗材传感器的替代停泊算法。

**类型：** 布尔值  
**默认值：** `False`

```ini
aggressive_parking: True
```

**工作原理：**
- 启用后开始进给耗材
- 传感器检测到耗材时切换为标准停泊算法
- 适合进料路径较长的打印机

**前提条件：** 必须通过 `filament_sensor` 参数配置外部耗材传感器。

---

### `max_parking_distance`

激进停泊模式下的最大进给距离（毫米）。

**类型：** 整数  
**默认值：** `100`

```ini
max_parking_distance: 100
```

---

### `parking_speed`

激进停泊模式下的进给速度（毫米/秒）。

**类型：** 整数  
**默认值：** `10`

```ini
parking_speed: 10
```

---

### `extended_park_time`

传感器停泊超时的附加时间（秒）。

**类型：** 整数  
**默认值：** `10`

```ini
extended_park_time: 10
```

---

### `max_parking_timeout`

换工具停泊操作的最大等待时间（秒）。

**类型：** 整数  
**默认值：** `60`

```ini
max_parking_timeout: 60
```

---

### `max_dryer_temperature`

烘干机最高温度（°C）。

**类型：** 整数  
**默认值：** `55`

```ini
max_dryer_temperature: 55
```

**说明：** 超过 60°C 未经测试，可能不安全。此值为 `ACE_START_DRYING` 命令的 `TEMP` 参数上限。

---

### `disable_assist_after_toolchange`

换工具后是否自动关闭 feed assist。

**类型：** 布尔值  
**默认值：** `True`

```ini
disable_assist_after_toolchange: True
```

---

### `infinity_spool_mode`

无限料盘模式（耗材用尽时自动切换槽位）。

**类型：** 布尔值  
**默认值：** `False`

```ini
infinity_spool_mode: True
```

**前提条件：**
- 通过 `ACE_SET_INFINITY_SPOOL_ORDER` 设置槽位顺序
- 顺序中至少一个槽位处于 `ready` 状态

**相关变量：**
- `ace_infsp_order` —— 槽位顺序字符串
- `ace_infsp_position` —— 当前顺序位置（0-3）

---

### `infinity_spool_debounce`

自动监控时确认 `empty` 状态的防抖时间（秒）。

**类型：** 浮点数  
**默认值：** `2.0`

```ini
infinity_spool_debounce: 2.0
```

**工作原理：**
- 检测到 `empty` 后启动防抖计时器
- 状态需在指定时间内持续保持 `empty`
- 防止状态瞬变引起误触发

**建议：**
- `1.0-2.0` —— 稳定工作
- `3.0-5.0` —— 传感器不稳定或槽位有问题时使用

---

### `infinity_spool_pause_on_no_sensor`

无传感器时无限料盘触发方式。

**类型：** 布尔值  
**默认值：** `True`

```ini
infinity_spool_pause_on_no_sensor: True
```

**行为：**
- `True` —— 无传感器时，检测到空槽后暂停打印，等待用户手动确认
- `False` —— 无传感器时，确认空槽后立即自动切换槽位

**建议：** 大多数用户使用 `True`（安全模式）；需要全自动打印时使用 `False`。

---

### `filament_sensor`

外部耗材传感器的名称。

**类型：** 字符串  
**默认值：** 未设置

```ini
filament_sensor: my_filament_sensor
```

**功能：**
- 将外部传感器与 ACE 模块集成
- 可通过 `ACE_CHECK_FILAMENT_SENSOR` 查询传感器状态
- 在 ACE 状态信息中包含传感器数据
- 可用于宏和自动化逻辑

**说明：** 名称需与 Klipper 配置中定义的传感器名称一致，例如 `[filament_switch_sensor my_filament_sensor]`。

---

### `set_pause_macro_name`

打印期间连接丢失时调用的宏名称。

**类型：** 字符串  
**默认值：** `PAUSE`

```ini
set_pause_macro_name: PAUSE
```

**工作原理：**
- 打印期间与 ACE 设备失去连接时调用此宏
- 可安全停止打印，防止出现问题
- 可指定自定义暂停宏名称

---

## 状态字段说明

模块通过 `get_status` 方法返回额外状态字段：

| 字段 | 说明 |
|------|------|
| `feed_assist_slot` | 当前激活 feed assist 的槽位索引（-1 表示未激活） |
| `filament_sensor` | 外部耗材传感器状态（如已配置） |
| `slot_mapping` | 当前索引到槽位的映射关系 |

---

## G-code 宏

### 必须定义的宏

#### `_ACE_PRE_TOOLCHANGE`

换工具前执行。

**参数：**
- `FROM` —— 上一个工具索引（-1 表示无）
- `TO` —— 新工具索引

**示例：**
```gcode
[gcode_macro _ACE_PRE_TOOLCHANGE]
gcode:
    SET_HEATER_TEMPERATURE HEATER=extruder TARGET=220
    TEMPERATURE_WAIT SENSOR=extruder MINIMUM=220
    SAVE_GCODE_STATE NAME=FILAMENT_CHANGE_STATE
    {% if params.FROM is defined and params.FROM|int != -1 %}
        ACE_DISABLE_FEED_ASSIST INDEX={params.FROM|int}
    {% endif %}
    G1 X-8 Y0 F7800
```

#### `_ACE_POST_TOOLCHANGE`

换工具后执行。

**参数：**
- `FROM` —— 上一个工具索引
- `TO` —— 新工具索引

**示例：**
```gcode
[gcode_macro _ACE_POST_TOOLCHANGE]
gcode:
    {% if params.TO is defined and params.TO|int != -1 %}
        G91
        G1 E100 F300
        G90
    {% endif %}
    {% if params.TO is defined and params.TO|int != -1 %}
        ACE_ENABLE_FEED_ASSIST INDEX={params.TO|int}
    {% endif %}
    RESTORE_GCODE_STATE NAME=FILAMENT_CHANGE_STATE MOVE=1 MOVE_SPEED=1500
```

#### `_ACE_ON_EMPTY_ERROR`

检测到空槽时执行。

**参数：**
- `INDEX` —— 空槽编号

**示例：**
```gcode
[gcode_macro _ACE_ON_EMPTY_ERROR]
gcode:
    {action_respond_info("Spool is empty")}
    {% if printer.idle_timeout.state == "Printing" %}
        PAUSE
    {% endif %}
```

### 无限料盘可选宏

#### `_ACE_PRE_INFINITYSPOOL`

无限料盘切换前执行。无参数。

#### `_ACE_POST_INFINITYSPOOL`

无限料盘切换后执行。无参数。

#### `SET_INFINITY_SPOOL_ORDER`

便捷设置无限料盘槽位顺序。

```gcode
[gcode_macro SET_INFINITY_SPOOL_ORDER]
gcode:
    {% if params.ORDER is defined %}
        ACE_SET_INFINITY_SPOOL_ORDER ORDER={params.ORDER}
    {% else %}
        RESPOND TYPE=error MSG="ORDER parameter required"
    {% endif %}
```

#### `RESET_INFINITY_SPOOL`

重置无限料盘位置。

```gcode
[gcode_macro RESET_INFINITY_SPOOL]
gcode:
    SAVE_VARIABLE VARIABLE=ace_infsp_position VALUE=0
```

---

## 配置示例

### 最小配置

```ini
[ace]
serial: /dev/serial/by-id/usb-ANYCUBIC_ACE_1-if00
baud: 115200
```

---

### 标准配置

```ini
[ace]
serial: /dev/serial/by-id/usb-ANYCUBIC_ACE_1-if00
baud: 115200

# 运行参数
feed_speed: 25
retract_speed: 25
retract_mode: 0
toolchange_retract_length: 100
park_hit_count: 5
max_dryer_temperature: 55
disable_assist_after_toolchange: True
infinity_spool_mode: False

# 命令队列
max_queue_size: 20
```

---

### 无限料盘配置

```ini
[ace]
serial: /dev/serial/by-id/usb-ANYCUBIC_ACE_1-if00
baud: 115200

# 开启无限料盘模式
infinity_spool_mode: True
infinity_spool_debounce: 2.0
infinity_spool_pause_on_no_sensor: False  # 无传感器时自动切换

# 建议同时配置外部耗材传感器
filament_sensor: my_filament_sensor

# 运行参数
feed_speed: 25
retract_speed: 25
toolchange_retract_length: 100
park_hit_count: 5
disable_assist_after_toolchange: True
```

设置完成后指定槽位顺序：
```gcode
ACE_SET_INFINITY_SPOOL_ORDER ORDER="0,1,2,3"
```

---

### 激进停泊配置

```ini
[ace]
serial: /dev/serial/by-id/usb-ANYCUBIC_ACE_1-if00
baud: 115200

# 必须配置外部传感器
filament_sensor: my_filament_sensor

# 激进停泊
aggressive_parking: True
max_parking_distance: 100
parking_speed: 10
extended_park_time: 10
max_parking_timeout: 60

feed_speed: 25
retract_speed: 25
park_hit_count: 5
```

外部传感器 Klipper 配置示例：
```ini
[filament_switch_sensor my_filament_sensor]
switch_pin: <your_pin>
pause_on_runout: False  # 由 ACE 模块控制
```

---

### 高性能配置

```ini
[ace]
serial: /dev/serial/by-id/usb-ANYCUBIC_ACE_1-if00
baud: 115200

# 更快的超时
response_timeout: 1.5
read_timeout: 0.05
write_timeout: 0.3

# 更快的停泊
park_hit_count: 3
```

---

## 配置验证

修改配置后的检查步骤：

1. **重启 Klipper：**
```bash
sudo systemctl restart klipper
```

2. **检查日志：**
```bash
tail -f ~/printer_data/logs/klippy.log | grep -i ace
```

3. **验证连接：**
```gcode
ACE_STATUS
ACE_DEBUG METHOD=get_info
```

---

## 针对不同打印机的建议

**Voron Trident（SolisACE 主测试机型）：**
- 使用标准配置
- 进料路径较长时可考虑 `aggressive_parking: True`
- 根据实际情况调整 `park_hit_count`

**其他打印机：**
- 从标准配置开始
- 停泊不稳定时增大 `park_hit_count`
- 停泊太慢时减小 `park_hit_count`

---

## 针对不同耗材的建议

| 耗材类型 | 建议配置 |
|---------|---------|
| PLA | 默认配置，`retract_mode: 0` |
| TPU / 柔性 | `retract_mode: 1`，降低进给/回退速度 |
| ABS / PETG | 默认配置，可能需增大 `toolchange_retract_length` |

---

*最后更新：2026*
