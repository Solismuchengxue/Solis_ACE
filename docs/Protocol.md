# Anycubic ACE Pro 通信协议

## 传输层

ACE Pro 通过 USB CDC 设备进行通信，无流控，无数据完整性校验。设备似乎使用单个环形缓冲区同时处理输入和输出，发包速度过快可能导致数据丢失。在收到上一条命令响应之前发送新包，可能造成设备回传数据的丢失。

单次发送的安全最大数据量为 **1024 字节**，此值未来可能变更。

---

## 帧格式

每条 JSON 命令被打包成以下帧格式：

| 字段 | 长度 | 说明 |
|------|------|------|
| 帧头 | 2 字节 | `0xFF 0xAA` |
| 有效载荷长度 | 2 字节 | 小端序（little-endian） |
| JSON 数据 | N 字节 | 有效载荷本体 |
| CRC-16/MCRF4XX | 2 字节 | JSON 数据的 CRC，小端序 |
| 保留字节 | 任意 | 忽略（不建议添加） |
| 帧尾 | 1 字节 | `0xFE` |

**注意事项：**
- 若完整帧未在 3 秒内发送完毕，ACE 会断开并重新连接；无论帧长度或 CRC 是否有效。
- Keepalive 忽略来自上次连接的数据；帧可以跨连接拆分传输。
- 帧头为 2 字节，若其中一字节损坏，帧会被忽略；但若帧内部包含 `0xFF 0xAA` 字节序列，ACE 可能会暂时挂起并尝试读取超长帧。
- 若意外（或故意）请求超过 1024 字节的帧，ACE 似乎会进入不可恢复的挂起状态，无论发送多少后续数据都无法恢复。

---

## RPC 协议

> **警告：** 以下内容未经过完整验证，可能存在错误。

### 请求格式

每条发送到 ACE Pro 的请求包含以下 JSON 字段：

```json
{
  "id": 1,
  "method": "method_name",
  "params": {}
}
```

| 字段 | 说明 |
|------|------|
| `id` | 消息序号 |
| `method` | 方法名称字符串 |
| `params` | 方法专用参数字典（为空时可省略） |

### 响应格式

ACE 返回的每条响应包含以下 JSON 字段：

```json
{
  "id": 1,
  "result": {},
  "code": 0,
  "msg": "success"
}
```

| 字段 | 说明 |
|------|------|
| `id` | 对应请求的消息序号 |
| `result` | 方法专用返回数据字典 |
| `code` | 方法专用返回代码 |
| `msg` | 方法专用消息 |

**重要：** 在发送请求并读取响应期间，必须锁定对 ACE 的访问。若存在后台线程定期发送保活命令，此问题容易被忽视。

---

## 方法列表

本节记录可调用的 RPC 方法及返回数据。未知值以静态样例表示。

> 这不是完整的 API 文档，因为我们不控制固件，ACE 未来版本可能有所变化。

---

### `enable_rfid`

启用 RFID 读取。

**请求参数：** 无

**响应：**
```json
{ "msg": "success", "code": 0 }
```

---

### `disable_rfid`

禁用 RFID 读取。

**请求参数：** 无

**响应：**
```json
{ "msg": "success", "code": 0 }
```

---

### `get_info`

获取设备信息。

**请求参数：** 无

**响应 result 字段：**
```json
{
  "id": 0,
  "slots": 4,
  "model": "Anycubic Color Engine Pro",
  "firmware": "V1.3.82",
  "boot_firmware": "V1.0.1"
}
```

---

### `get_filament_info`

获取指定槽位的耗材信息。

**请求参数：**

| 参数 | 说明 |
|------|------|
| `index` | 槽位编号 |

**响应 result 字段：**
```json
{
  "index": 0,
  "sku": "ABCDEF-01",
  "brand": "FakeBrand",
  "type": "PLA",
  "color": [0, 0, 0],
  "rfid": 2,
  "extruder_temp": { "min": 190, "max": 230 },
  "hotbed_temp": { "min": 50, "max": 70 },
  "diameter": 1.75,
  "total": 330,
  "current": 0
}
```

**`rfid` 字段值：**
- `0` —— 未找到信息
- `1` —— 识别失败
- `2` —— 已识别
- `3` —— 识别中

**温度字典格式：**
```json
{ "min": <°C 整数>, "max": <°C 整数> }
```

---

### `get_status`

获取设备当前状态。

**请求参数：** 无

**响应 result 字段：**
```json
{
  "status": "ready",
  "action": "feeding",
  "dryer_status": {
    "status": "stop",
    "target_temp": 60,
    "duration": 300,
    "remain_time": 50
  },
  "temp": 25,
  "enable_rfid": 1,
  "fan_speed": 7000,
  "feed_assist_count": 0,
  "cont_assist_time": 0.0,
  "slots": [...]
}
```

**字段说明：**

| 字段 | 可能值 | 说明 |
|------|--------|------|
| `status` | `"ready"`、`"busy"` | 设备状态 |
| `action` | `"feeding"`、`"unwinding"`、`"shifting"` | 当前动作 |
| `cont_assist_time` | 浮点数 | 连续送料时间（毫秒） |

**槽位对象：**
```json
{
  "index": 0,
  "status": "ready",
  "sku": "ABCDEF-01",
  "brand": "FakeBrand",
  "type": "PLA",
  "color": [0, 0, 0],
  "rfid": 2
}
```

---

### `drying`

启动烘干。

**请求参数：**

| 参数 | 示例值 | 说明 |
|------|--------|------|
| `temp` | 50 | 烘干温度（°C） |
| `fan_speed` | 7000 | 风扇转速（RPM） |
| `duration` | 240 | 烘干时间（分钟） |

**响应：**
```json
{ "msg": "drying", "code": 0 }
```

---

### `drying_stop`

停止烘干。

**请求参数：** 无

**响应：**
```json
{ "msg": "success", "code": 0 }
```

---

### `unwind_filament`

回退耗材（对应 G-code `ACE_RETRACT`）。

**请求参数：**

| 参数 | 示例值 | 说明 |
|------|--------|------|
| `index` | 0 | 槽位编号 |
| `length` | 300 | 回退长度（mm） |
| `speed` | 15 | 回退速度（mm/s） |
| `mode` | 0 | 模式：0=普通，1=增强 |

**响应：**
```json
{ "msg": "success", "code": 0 }
```

---

### `update_unwinding_speed`

运行中更新回退速度。

**请求参数：**

| 参数 | 示例值 |
|------|--------|
| `index` | 0 |
| `speed` | 15 |

**响应：**
```json
{ "msg": "success", "code": 0 }
```

---

### `stop_unwind_filament`

停止回退。

**请求参数：**

| 参数 | 说明 |
|------|------|
| `index` | 槽位编号 |

**响应：**
```json
{ "msg": "success", "code": 0 }
```

---

### `feed_filament`

进给耗材（对应 G-code `ACE_FEED`）。

**请求参数：**

| 参数 | 示例值 | 说明 |
|------|--------|------|
| `index` | 0 | 槽位编号 |
| `length` | 2000 | 进给长度（mm） |
| `speed` | 25 | 进给速度（mm/s） |

**响应：**
```json
{ "msg": "success", "code": 0 }
```

---

### `update_feeding_speed`

运行中更新进给速度。

**请求参数：**

| 参数 | 示例值 |
|------|--------|
| `index` | 0 |
| `speed` | 25 |

**响应：**
```json
{ "msg": "success", "code": 0 }
```

---

### `stop_feed_filament`

停止进给。

**请求参数：**

| 参数 | 说明 |
|------|------|
| `index` | 槽位编号 |

**响应：**
```json
{ "msg": "success", "code": 0 }
```

---

### `start_feed_assist`

启动 feed assist（送料助手）。

**请求参数：**

| 参数 | 说明 |
|------|------|
| `index` | 槽位编号 |

**响应：**
```json
{ "msg": "success", "code": 0 }
```

---

### `stop_feed_assist`

停止 feed assist。

**请求参数：**

| 参数 | 说明 |
|------|------|
| `index` | 槽位编号 |

**响应：**
```json
{ "msg": "", "code": 0 }
```

---

## 实现说明

- 所有 JSON 命令均需打包到上述帧格式中再发送
- CRC 算法：CRC-16/MCRF4XX
- 发送速率不宜过快，建议等待响应后再发送下一条命令
- 保活机制应在独立线程中运行，但需与主命令发送互斥

---

*最后更新：2026*
