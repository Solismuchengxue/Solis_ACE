# ACE 温度传感器

## 描述

`temperature_ace` 模块将 ACE 设备的温度集成到 Klipper 标准温度传感器系统中，使其可以通过 Mainsail、Fluidd、KlipperScreen 等界面监控，并在宏中使用。

## 功能

- ✅ 在 Web 界面中显示 ACE 温度
- ✅ 监控最低和最高温度
- ✅ 在 G-code 宏中使用温度值
- ✅ 过热保护（自动 shutdown）
- ✅ 温度统计日志
- ✅ Moonraker API 集成

## 安装

### 1. 文件已就位

温度传感器已并入核心扩展 `extras/ace.py`（install.sh 自动安装），无需单独的模块文件。

### 2. 配置温度传感器

`temperature_ace` 传感器工厂会**随 `[ace]` 自动注册**，因此**无需**再单独写 `[temperature_ace]` 段。`ace.cfg` 里已有 `[ace]`，直接添加温度传感器即可：

```ini
[temperature_sensor ace_chamber]
sensor_type: temperature_ace
min_temp: 0
max_temp: 70
```

> **顺序要求：** `[temperature_sensor]` 必须位于 `[ace]` 之后（`ace.cfg` 中已是此顺序）。
>
> **从旧版升级：** 若你之前在配置里写过 `[temperature_ace]`，升级后请**删除该行**，否则 Klipper 会因找不到独立模块而报错。

### 3. 重启 Klipper

```gcode
RESTART
```

## 配置

### 基础配置

```ini
[temperature_sensor ace_chamber]
sensor_type: temperature_ace  # 传感器类型（必填）
min_temp: 0                   # 最低允许温度（°C）
max_temp: 70                  # 最高允许温度（°C）
```

### 参数说明

| 参数 | 必填 | 说明 | 默认值 |
|------|------|------|--------|
| `sensor_type` | ✅ | 传感器类型 | `temperature_ace` |
| `min_temp` | ✅ | 最低允许温度（°C） | — |
| `max_temp` | ✅ | 最高允许温度（°C） | — |

### 推荐值

```ini
# 用于腔体监控
min_temp: 0
max_temp: 70

# 用于烘干机监控
min_temp: 0
max_temp: 60  # ACE 最高烘干温度为 55°C
```

**警告：** 温度超出 `min_temp`/`max_temp` 范围时，Klipper 会执行 **紧急停机（emergency shutdown）**！

## 使用方法

### 在 Web 界面中查看

配置完成后，ACE 温度会出现在：

**Mainsail / Fluidd：**
- 主面板"温度"区域
- 实时温度曲线图
- 温度历史记录

**KlipperScreen：**
- 主屏幕
- 温度菜单

### 在 G-code 宏中使用

```gcode
[gcode_macro CHECK_CHAMBER_TEMP]
gcode:
    {% set ace_temp = printer["temperature_sensor ace_chamber"].temperature %}
    M118 ACE temperature: {ace_temp}°C
```

### 访问统计数据

```gcode
[gcode_macro ACE_TEMP_STATS]
gcode:
    {% set sensor = printer["temperature_sensor ace_chamber"] %}
    {% set current = sensor.temperature %}
    {% set min = sensor.measured_min_temp %}
    {% set max = sensor.measured_max_temp %}

    M118 Current: {current}°C
    M118 Min: {min}°C
    M118 Max: {max}°C
```

## 使用示例

### 示例 1：腔体温度监控

```ini
[temperature_sensor ace_chamber]
sensor_type: temperature_ace
min_temp: 0
max_temp: 70
```

```gcode
[gcode_macro START_PRINT]
gcode:
    {% set chamber_temp = printer["temperature_sensor ace_chamber"].temperature %}
    M118 Starting print, chamber temperature: {chamber_temp}°C
```

### 示例 2：过热警告

```ini
[temperature_sensor ace_monitor]
sensor_type: temperature_ace
min_temp: 0
max_temp: 65  # 超过此温度时 shutdown
```

```gcode
[gcode_macro MONITOR_ACE_TEMP]
gcode:
    {% set temp = printer["temperature_sensor ace_monitor"].temperature %}

    {% if temp > 55 %}
        M118 Warning: ACE temperature high ({temp}°C)
        ACE_STOP_DRYING
    {% elif temp > 60 %}
        M118 Critical: ACE temperature critical ({temp}°C)!
        PAUSE
    {% endif %}
```

### 示例 3：定时监控

```gcode
[delayed_gcode ace_temp_monitor]
initial_duration: 60.0
gcode:
    {% set sensor = printer["temperature_sensor ace_chamber"] %}
    {% set temp = sensor.temperature %}
    {% set min = sensor.measured_min_temp %}
    {% set max = sensor.measured_max_temp %}

    M118 ACE: {temp}°C (Min: {min}°C, Max: {max}°C)

    # 每 5 分钟继续监控
    UPDATE_DELAYED_GCODE ID=ace_temp_monitor DURATION=300
```

### 示例 4：条件启动打印

```gcode
[gcode_macro SMART_START_PRINT]
gcode:
    {% set target_chamber = params.CHAMBER|default(30)|float %}
    {% set chamber_temp = printer["temperature_sensor ace_chamber"].temperature %}

    {% if chamber_temp < target_chamber %}
        M118 Chamber too cold ({chamber_temp}°C), waiting...
        TEMPERATURE_WAIT SENSOR="temperature_sensor ace_chamber" MINIMUM={target_chamber}
    {% endif %}

    M118 Chamber ready ({chamber_temp}°C)
```

### 示例 5：与烘干集成

```gcode
[gcode_macro START_DRYING_MONITORED]
gcode:
    {% set TEMP = params.TEMP|default(50)|int %}
    {% set DURATION = params.DURATION|default(120)|int %}

    M118 Starting drying at {TEMP}°C for {DURATION} minutes
    ACE_START_DRYING TEMP={TEMP} DURATION={DURATION}

    UPDATE_DELAYED_GCODE ID=drying_monitor DURATION=60

[delayed_gcode drying_monitor]
gcode:
    {% set dryer = printer.ace._info.dryer %}
    {% set temp = printer["temperature_sensor ace_chamber"].temperature %}

    {% if dryer.status == 'run' %}
        M118 Drying: {temp}°C / {dryer.target_temp}°C (remaining: {dryer.remain_time/60}min)
        UPDATE_DELAYED_GCODE ID=drying_monitor DURATION=60
    {% else %}
        M118 Drying complete
    {% endif %}
```

## 技术细节

### 工作原理

1. **注册传感器：**
   - 模块在 `heaters` 系统中注册为传感器工厂（sensor factory）
   - 创建 `temperature_ace <名称>` 对象

2. **定期读取：**
   - 每秒读取一次（`ACE_REPORT_TIME = 1.0`）
   - 从 ACE 模块的 `ace._info['temp']` 读取温度
   - 通过回调通知 Klipper

3. **统计追踪：**
   - 启动以来的最低温度
   - 启动以来的最高温度
   - 当前温度

4. **范围保护：**
   - 检查 `min_temp` 和 `max_temp`
   - 超出范围时触发紧急停机

### 温度数据来源

温度读取自：
```python
ace._info['temp']
```

此值由 ACE 模块通过以下方式更新：
- 常规模式下每 1 秒发送 `get_status` 请求
- 停泊过程中每 0.2 秒发送请求（高频模式）

### 更新频率

| 操作 | 间隔 |
|------|------|
| ACE 数据读取 | 每 1 秒（`_writer_loop`） |
| 传感器更新 | 每 1 秒（`ACE_REPORT_TIME`） |
| UI 显示刷新 | 1-2 秒（取决于 UI 设置） |

### 精度

- **分辨率：** 1°C（设备返回整数值）
- **精度：** 取决于 ACE 传感器（约 ±1-2°C）
- **范围：** 0-70°C

## Moonraker API

温度可通过 Moonraker API 获取：

```bash
# HTTP GET 请求
curl http://localhost:7125/printer/objects/query?temperature_sensor
```

**响应：**
```json
{
  "result": {
    "status": {
      "temperature_sensor": {
        "ace_chamber": {
          "temperature": 28.0,
          "measured_min_temp": 24.5,
          "measured_max_temp": 55.3
        }
      }
    }
  }
}
```

## 故障排除

### 问题：温度始终为 0

**原因：**
1. ACE 模块未加载
2. ACE 设备未连接
3. 未收到设备状态

**解决方法：**
```gcode
ACE_STATUS
ACE_DEBUG METHOD=get_status
```

检查日志中是否有：
```
ACE temperature sensor: ACE module found
```

### 问题：温度不更新

**原因：** ACE 模块未收到状态更新，或串口连接有问题。

**解决方法：**
```gcode
ACE_STATUS
# 确认 ACE 正常接收更新
```

### 问题：因温度触发 Klipper shutdown

**症状：**
```
ACE temperature 71.0 above maximum temperature of 70.0
```

**解决方法：**
```ini
[temperature_sensor ace_chamber]
sensor_type: temperature_ace
min_temp: 0
max_temp: 75  # 增大上限
```

### 问题：多个传感器显示相同值

**这是正常现象。** 所有 `temperature_ace` 类型的传感器读取同一个数据源（ACE 设备只有一个温度传感器）。

若需要不同的保护阈值，可创建多个传感器：
```ini
[temperature_sensor ace_chamber]
sensor_type: temperature_ace
min_temp: 0
max_temp: 70  # 较宽松的限制

[temperature_sensor ace_dryer]
sensor_type: temperature_ace
min_temp: 0
max_temp: 60  # 更严格的限制
```

## 与其他模块集成

### 与 temperature_fan 集成

根据 ACE 温度自动控制风扇：

```ini
[temperature_fan ace_cooling_fan]
sensor_type: temperature_ace
pin: PB15
min_temp: 0
max_temp: 70
target_temp: 40.0
max_speed: 1.0
min_speed: 0.3
control: watermark
```

### 与 gcode_macro 集成

```gcode
[gcode_macro WAIT_FOR_CHAMBER]
gcode:
    {% set target = params.TARGET|default(30)|float %}
    TEMPERATURE_WAIT SENSOR="temperature_sensor ace_chamber" MINIMUM={target}
    M118 Chamber ready!
```

## 传感器对比

| 传感器 | 数据来源 | 更新频率 | 用途 |
|--------|----------|---------|------|
| `temperature_ace` | ACE 设备 | 1 秒 | ACE 内部温度 |
| `temperature_host` | Raspberry Pi | 1 秒 | 主机温度 |
| `temperature_mcu` | MCU | 0.3 秒 | 微控制器温度 |
| `thermistor` | ADC 引脚 | 0.3 秒 | 热床、热端等 |

## 限制

1. **单设备** —— 仅支持一个 ACE 设备，所有传感器读取同一数据源
2. **只读** —— 仅显示温度，无法通过此传感器控制 ACE 温度
3. **依赖 ACE 模块** —— 需要正常工作的 `ace.py`；若 ACE 未连接则温度为 0
4. **分辨率** —— 设备返回整数值，不支持小数温度

---

**版本：** 1.0  
**作者：** ValgACE Project / SolisACE Fork  
**许可：** GNU GPLv3
