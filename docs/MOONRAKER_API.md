# SolisACE Moonraker API 扩展

`ace_status.py` 组件的详细文档——通过 REST API 和 WebSocket 访问 ACE 状态的 Moonraker 扩展。

## 目录

1. [描述](#描述)
2. [安装](#安装)
3. [组件架构](#组件架构)
4. [API 接口](#api-接口)
5. [命令详细说明](#命令详细说明)
6. [WebSocket 订阅](#websocket-订阅)
7. [使用示例](#使用示例)
8. [故障排除](#故障排除)

---

## 描述

`ace_status.py` 组件扩展了 Moonraker 的功能，为 ACE（Anycubic Color Engine Pro）设备提供 REST API 接口，支持：

- ✅ 通过 HTTP REST API 获取 ACE 设备状态
- ✅ 通过 HTTP 请求执行 ACE 命令
- ✅ 通过 WebSocket 订阅状态更新
- ✅ 与 Web 界面（Mainsail、Fluidd、自定义前端）集成

组件遵循 Moonraker API 模式，使用标准机制与 Klipper 集成。

---

## 安装

### 自动安装（推荐）

执行 `install.sh` 脚本时自动完成：

```bash
cd ~/Solis_ACE
./install.sh
```

**脚本执行内容：**

1. **创建符号链接：**
   ```bash
   ~/moonraker/moonraker/components/ace_status.py → ~/Solis_ACE/moonraker/ace_status.py
   ```

2. **在 `moonraker.conf` 中添加：**
   ```ini
   [ace_status]
   ```

3. **重启 Moonraker：**
   ```bash
   sudo systemctl restart moonraker
   ```

### 手动安装

1. **复制文件：**
   ```bash
   cp ~/Solis_ACE/moonraker/ace_status.py \
       ~/moonraker/moonraker/components/ace_status.py
   ```

2. **在 `moonraker.conf` 中添加：**
   ```ini
   [ace_status]
   ```

3. **重启 Moonraker：**
   ```bash
   sudo systemctl restart moonraker
   ```

### 验证安装

检查 Moonraker 日志：
```bash
tail -f ~/printer_data/logs/moonraker.log | grep -i ace
```

应出现：
```
ACE Status API extension loaded
```

测试接口是否可用：
```bash
curl http://localhost:7125/server/ace/status
```

---

## 组件架构

### `AceStatus` 类结构

组件由单一 `AceStatus` 类组成，负责：

1. **初始化** —— Moonraker 加载时执行
2. **注册接口** —— 向 Moonraker API 注册端点
3. **订阅事件** —— 监听打印机状态更新事件
4. **缓存数据** —— 存储最近一次已知状态

### 数据获取策略

组件采用多层次数据获取策略：

1. **通过 `query_objects({"ace": None})`** —— 直接从 Klipper `ace` 模块查询数据
2. **回退到缓存** —— 使用最近一次已知状态
3. **默认结构** —— 若无数据，返回空的合法 JSON 结构

### 命令参数格式

支持三种参数传递方式：

1. **JSON body（推荐）：**
   ```json
   {"command": "ACE_CHANGE_TOOL", "params": {"TOOL": 0}}
   ```

2. **Query 参数：**
   ```
   ?command=ACE_CHANGE_TOOL&TOOL=0
   ```

3. **混合格式：**
   ```
   ?command=ACE_CHANGE_TOOL&params={"TOOL":0}
   ```

---

## API 接口

### GET /server/ace/status

获取 ACE 设备完整状态。

**请求：**
```bash
curl http://localhost:7125/server/ace/status
```

**响应：**
```json
{
  "result": {
    "status": "ready",
    "model": "Anycubic Color Engine Pro",
    "firmware": "V1.3.84",
    "dryer": {
      "status": "stop",
      "target_temp": 0,
      "duration": 0,
      "remain_time": 0
    },
    "temp": 25,
    "fan_speed": 7000,
    "enable_rfid": 1,
    "slots": [
      {
        "index": 0,
        "status": "ready",
        "type": "PLA",
        "color": [255, 0, 0],
        "sku": "PLA-RED-01",
        "rfid": 2
      },
      {
        "index": 1,
        "status": "ready",
        "type": "PLA",
        "color": [0, 255, 0],
        "sku": "",
        "rfid": 0
      },
      {
        "index": 2,
        "status": "empty",
        "type": "",
        "color": [0, 0, 0],
        "sku": "",
        "rfid": 0
      },
      {
        "index": 3,
        "status": "ready",
        "type": "PETG",
        "color": [0, 0, 255],
        "sku": "",
        "rfid": 1
      }
    ]
  }
}
```

**响应字段说明：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `status` | string | 设备状态：`"ready"`、`"busy"`、`"unknown"` |
| `model` | string | 设备型号 |
| `firmware` | string | 固件版本 |
| `dryer` | object | 烘干机状态（见下） |
| `temp` | number | 当前烘干机温度（°C） |
| `fan_speed` | number | 风扇转速（RPM） |
| `enable_rfid` | number | RFID 是否开启（1/0） |
| `slots` | array | 槽位信息数组（见下） |

**`dryer` 对象：**
```json
{
  "status": "stop" | "drying",
  "target_temp": 0-55,
  "duration": 0-1440,
  "remain_time": 0-1440
}
```

**槽位对象：**
```json
{
  "index": 0-3,
  "status": "ready" | "empty" | "busy",
  "type": "PLA" | "PETG" | "ABS" | ...,
  "color": [R, G, B],
  "sku": "string",
  "rfid": 0-3
}
```

**RFID 状态值：**
- `0` —— 未找到
- `1` —— 识别失败
- `2` —— 已识别
- `3` —— 识别中

---

### GET /server/ace/slots

仅获取槽位信息。

**请求：**
```bash
curl http://localhost:7125/server/ace/slots
```

**响应：**
```json
{
  "result": {
    "slots": [
      {
        "index": 0,
        "status": "ready",
        "type": "PLA",
        "color": [255, 0, 0],
        "sku": "",
        "rfid": 2
      }
    ]
  }
}
```

---

### POST /server/ace/command

通过 REST API 执行 ACE 命令。

**方法：** `POST`  
**Content-Type：** `application/json`（JSON body）或 query 参数

**JSON body 格式：**
```json
{
  "command": "ACE_COMMAND_NAME",
  "params": {
    "PARAM1": "value1",
    "PARAM2": "value2"
  }
}
```

**成功响应：**
```json
{
  "result": {
    "success": true,
    "message": "Command ACE_COMMAND_NAME executed successfully",
    "command": "ACE_COMMAND_NAME PARAM1=value1 PARAM2=value2"
  }
}
```

**失败响应：**
```json
{
  "result": {
    "success": false,
    "error": "Error message",
    "command": "ACE_COMMAND_NAME PARAM1=value1"
  }
}
```

**参数处理规则：**
- 布尔值（`true`/`false`）转换为 `1`/`0`
- 数字转为字符串
- 所有参数拼接为 G-code 命令：`COMMAND PARAM1=value1 PARAM2=value2`

---

## 命令详细说明

### 工具管理命令

#### ACE_CHANGE_TOOL

换工具（加载/卸载耗材）。

**参数：**
- `TOOL`（integer，必填）：槽位索引（0-3）或 `-1`（卸载）

**示例：**
```bash
curl -X POST http://localhost:7125/server/ace/command \
  -H "Content-Type: application/json" \
  -d '{"command":"ACE_CHANGE_TOOL","params":{"TOOL":0}}'
```

**执行流程：**
1. 执行宏 `_ACE_PRE_TOOLCHANGE`
2. 回退上一槽位耗材（如有）
3. 等待槽位就绪
4. 将新耗材停泊到热端
5. 执行宏 `_ACE_POST_TOOLCHANGE`

---

#### ACE_PARK_TO_TOOLHEAD

将指定槽位耗材停泊到热端。

**参数：**
- `INDEX`（integer，必填）：槽位索引（0-3）

**示例：**
```bash
curl -X POST http://localhost:7125/server/ace/command \
  -H "Content-Type: application/json" \
  -d '{"command":"ACE_PARK_TO_TOOLHEAD","params":{"INDEX":0}}'
```

---

### 进给控制命令

#### ACE_FEED

进给指定长度的耗材。

**参数：**
- `INDEX`（integer，必填）：槽位索引（0-3）
- `LENGTH`（integer，必填）：进给长度（mm）
- `SPEED`（integer，可选）：进给速度（mm/s）

**示例：**
```bash
curl -X POST http://localhost:7125/server/ace/command \
  -H "Content-Type: application/json" \
  -d '{"command":"ACE_FEED","params":{"INDEX":0,"LENGTH":50,"SPEED":25}}'
```

---

#### ACE_RETRACT

回退指定长度的耗材。

**参数：**
- `INDEX`（integer，必填）
- `LENGTH`（integer，必填）
- `SPEED`（integer，可选）
- `MODE`（integer，可选）：0=普通，1=增强

**示例：**
```bash
curl -X POST http://localhost:7125/server/ace/command \
  -H "Content-Type: application/json" \
  -d '{"command":"ACE_RETRACT","params":{"INDEX":0,"LENGTH":50,"SPEED":25,"MODE":0}}'
```

---

#### ACE_UPDATE_FEEDING_SPEED

更新运行中的进给速度。

```bash
curl -X POST http://localhost:7125/server/ace/command \
  -H "Content-Type: application/json" \
  -d '{"command":"ACE_UPDATE_FEEDING_SPEED","params":{"INDEX":0,"SPEED":30}}'
```

---

#### ACE_UPDATE_RETRACT_SPEED

更新运行中的回退速度。

```bash
curl -X POST http://localhost:7125/server/ace/command \
  -H "Content-Type: application/json" \
  -d '{"command":"ACE_UPDATE_RETRACT_SPEED","params":{"INDEX":0,"SPEED":30}}'
```

---

#### ACE_STOP_FEED

停止进给。

```bash
curl -X POST http://localhost:7125/server/ace/command \
  -H "Content-Type: application/json" \
  -d '{"command":"ACE_STOP_FEED","params":{"INDEX":0}}'
```

---

#### ACE_STOP_RETRACT

停止回退。

```bash
curl -X POST http://localhost:7125/server/ace/command \
  -H "Content-Type: application/json" \
  -d '{"command":"ACE_STOP_RETRACT","params":{"INDEX":0}}'
```

---

### 烘干管理命令

#### ACE_START_DRYING

启动烘干。

**参数：**
- `TEMP`（integer，必填）：目标温度（20-55°C，受 `max_dryer_temperature` 限制）
- `DURATION`（integer，必填）：烘干时间（分钟）

```bash
curl -X POST http://localhost:7125/server/ace/command \
  -H "Content-Type: application/json" \
  -d '{"command":"ACE_START_DRYING","params":{"TEMP":50,"DURATION":240}}'
```

---

#### ACE_STOP_DRYING

停止烘干。

```bash
curl -X POST http://localhost:7125/server/ace/command \
  -H "Content-Type: application/json" \
  -d '{"command":"ACE_STOP_DRYING"}'
```

---

### Feed Assist 命令

#### ACE_ENABLE_FEED_ASSIST

为指定槽位启用 feed assist。

```bash
curl -X POST http://localhost:7125/server/ace/command \
  -H "Content-Type: application/json" \
  -d '{"command":"ACE_ENABLE_FEED_ASSIST","params":{"INDEX":0}}'
```

---

#### ACE_DISABLE_FEED_ASSIST

禁用 feed assist。

```bash
curl -X POST http://localhost:7125/server/ace/command \
  -H "Content-Type: application/json" \
  -d '{"command":"ACE_DISABLE_FEED_ASSIST","params":{"INDEX":0}}'
```

---

### 无限料盘命令

#### ACE_SET_INFINITY_SPOOL_ORDER

设置无限料盘槽位切换顺序。

```bash
curl -X POST http://localhost:7125/server/ace/command \
  -H "Content-Type: application/json" \
  -d '{"command":"ACE_SET_INFINITY_SPOOL_ORDER","params":{"ORDER":"0,1,none,3"}}'
```

---

#### ACE_INFINITY_SPOOL

耗材用尽时切换到下一个槽位。

```bash
curl -X POST http://localhost:7125/server/ace/command \
  -H "Content-Type: application/json" \
  -d '{"command":"ACE_INFINITY_SPOOL"}'
```

---

### 信息查询命令

#### ACE_FILAMENT_INFO

获取槽位耗材信息。

```bash
curl -X POST http://localhost:7125/server/ace/command \
  -H "Content-Type: application/json" \
  -d '{"command":"ACE_FILAMENT_INFO","params":{"INDEX":0}}'
```

---

#### ACE_DEBUG

调试命令，直接调用 ACE API 方法。

```bash
curl -X POST http://localhost:7125/server/ace/command \
  -H "Content-Type: application/json" \
  -d '{"command":"ACE_DEBUG","params":{"METHOD":"get_info","PARAMS":"{}"}}'
```

---

## WebSocket 订阅

### 连接 WebSocket

```javascript
const ws = new WebSocket('ws://localhost:7125/websocket');
```

### 订阅状态更新

```javascript
ws.send(JSON.stringify({
    jsonrpc: "2.0",
    method: "printer.objects.subscribe",
    params: {
        objects: {
            "ace": null
        }
    },
    id: 5434
}));
```

### 接收更新

```javascript
ws.onmessage = (event) => {
    const data = JSON.parse(event.data);

    // 方式一：通过 Klipper 对象状态更新
    if (data.method === "notify_status_update") {
        const aceData = data.params[0]?.ace;
        if (aceData) {
            updateAceUI(aceData);
        }
    }

    // 方式二：通过 ace_status 组件事件
    if (data.method === "notify_ace_status_update") {
        const aceData = data.params[0];
        updateAceUI(aceData);
    }
};
```

### 组件事件

组件在状态更新时发送 `ace:status_update` 事件：

```python
self.server.send_event("ace:status_update", ace_data)
```

---

## 使用示例

### JavaScript / TypeScript

#### 获取状态

```javascript
async function getAceStatus() {
    const response = await fetch('http://localhost:7125/server/ace/status');
    const data = await response.json();
    return data.result;
}

const status = await getAceStatus();
console.log('ACE Status:', status);
console.log('Slots:', status.slots);
```

#### 执行命令

```javascript
async function executeAceCommand(command, params = {}) {
    const response = await fetch('http://localhost:7125/server/ace/command', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ command, params })
    });
    return await response.json();
}

const result = await executeAceCommand('ACE_CHANGE_TOOL', { TOOL: 0 });
if (result.result.success) {
    console.log('Tool changed successfully');
} else {
    console.error('Error:', result.result.error);
}
```

#### 实时状态监控

```javascript
class AceStatusMonitor {
    constructor(url = 'ws://localhost:7125/websocket') {
        this.ws = new WebSocket(url);
        this.ws.onopen = () => {
            this.ws.send(JSON.stringify({
                jsonrpc: "2.0",
                method: "printer.objects.subscribe",
                params: { objects: { "ace": null } },
                id: 5434
            }));
        };
        this.ws.onmessage = (event) => {
            const data = JSON.parse(event.data);
            if (data.method === "notify_status_update") {
                const aceData = data.params[0]?.ace;
                if (aceData) this.onStatusUpdate(aceData);
            }
        };
    }
    onStatusUpdate(data) {
        console.log('Status updated:', data);
    }
}

const monitor = new AceStatusMonitor();
```

### Python

#### 获取状态

```python
import requests

def get_ace_status():
    response = requests.get('http://localhost:7125/server/ace/status')
    return response.json()['result']

status = get_ace_status()
print(f"ACE Status: {status['status']}")
print(f"Slots: {len(status['slots'])}")
```

#### 执行命令

```python
import requests

def execute_ace_command(command, params=None):
    url = 'http://localhost:7125/server/ace/command'
    data = {'command': command}
    if params:
        data['params'] = params
    response = requests.post(url, json=data)
    return response.json()['result']

result = execute_ace_command('ACE_PARK_TO_TOOLHEAD', {'INDEX': 0})
if result['success']:
    print('Command executed successfully')
else:
    print(f"Error: {result['error']}")
```

### cURL

```bash
# 获取状态
curl http://localhost:7125/server/ace/status

# 获取槽位
curl http://localhost:7125/server/ace/slots

# 换工具
curl -X POST http://localhost:7125/server/ace/command \
  -H "Content-Type: application/json" \
  -d '{"command":"ACE_CHANGE_TOOL","params":{"TOOL":0}}'

# 启动烘干
curl -X POST http://localhost:7125/server/ace/command \
  -H "Content-Type: application/json" \
  -d '{"command":"ACE_START_DRYING","params":{"TEMP":50,"DURATION":240}}'
```

---

## 故障排除

### 组件未加载

**症状：**
- Moonraker 日志中无 "ACE Status API extension loaded"
- 接口返回 404 或 405

**解决方法：**

1. 检查文件是否存在：
   ```bash
   ls -la ~/moonraker/moonraker/components/ace_status.py
   ```

2. 检查 `moonraker.conf` 配置节：
   ```bash
   grep -A 1 "\[ace_status\]" ~/printer_data/config/moonraker.conf
   ```

3. 检查 Moonraker 错误日志：
   ```bash
   tail -f ~/printer_data/logs/moonraker.log | grep -i error
   ```

4. 验证 Python 文件语法：
   ```bash
   python3 -m py_compile ~/moonraker/moonraker/components/ace_status.py
   ```

---

### 接口返回 404

**原因：** 组件未加载或路径有误。

**解决方法：**
1. 确认文件存在（或为有效符号链接）
2. 重启 Moonraker：`sudo systemctl restart moonraker`
3. 检查加载错误日志

---

### 接口返回 405（Method Not Allowed）

**原因：** HTTP 方法不正确。

**正确方法：**
- `/server/ace/status` —— 使用 `GET`
- `/server/ace/slots` —— 使用 `GET`
- `/server/ace/command` —— 使用 `POST`

---

### 命令执行失败

**症状：** 请求返回 `{"success": false, "error": "..."}`

**解决方法：**

1. 检查命令格式：
   ```bash
   # 正确
   curl -X POST http://localhost:7125/server/ace/command \
     -H "Content-Type: application/json" \
     -d '{"command":"ACE_CHANGE_TOOL","params":{"TOOL":0}}'
   ```

2. 确认所有必填参数均已提供
3. 检查 Klipper 日志：
   ```bash
   tail -f ~/printer_data/logs/klippy.log | grep -i ace
   ```

---

### 状态始终返回默认值

**原因：** `ace` 模块正常运行，但此次查询未能获取实时数据。

**说明：** 这是正常的回退行为。组件按以下策略返回数据：
1. 尝试通过 `query_objects()` 获取实时数据
2. 使用缓存的最近一次状态
3. 返回默认空结构

若长期返回默认值，请检查：
- ACE 设备是否已连接并响应
- Klipper 日志中是否有 ACE 相关错误

---

### WebSocket 不接收更新

**原因：** 订阅对象名称不正确，或 `ace` 模块未发布状态更新。

**解决方法：**
1. 确认订阅对象为 `"ace": null`
2. 检查 Moonraker 日志中的事件
3. 通过 `ACE_STATUS` G-code 命令验证模块是否运行正常

---

## 参见

- [安装指南](INSTALLATION.md)
- [命令参考](COMMANDS.md)
- [配置参考](CONFIGURATION.md)
- [通信协议](PROTOCOL.md)

---

*最后更新：2026*
