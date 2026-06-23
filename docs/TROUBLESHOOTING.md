# SolisACE 故障排除

常见问题诊断与解决指南。

## 目录

1. [设备无法连接](#设备无法连接)
2. [停泊问题](#停泊问题)
3. [换工具问题](#换工具问题)
4. [进给/回退问题](#进给回退问题)
5. [烘干问题](#烘干问题)
6. [性能问题](#性能问题)
7. [连接诊断步骤](#连接诊断步骤)

---

## 设备无法连接

### 症状

- 状态显示 `disconnected`
- 命令无响应
- 日志中出现连接错误

### 解决方法

#### 1. 检查 USB 连接

```bash
# 检查系统是否能识别设备
lsusb | grep -i anycubic

# 应显示 VID:PID 为 28e9:018a 的设备
```

若未显示：
- 检查 USB 线
- 尝试其他 USB 口
- 确认 ACE 设备已通电

#### 2. 检查串口

```bash
# 查看所有 USB 串口设备
ls -la /dev/serial/by-id/

# 应存在类似以下路径：
# usb-ANYCUBIC_ACE_1-if00 -> ../../ttyACM0
```

若路径不存在，设备未被系统识别，临时修复权限：
```bash
sudo chmod 666 /dev/ttyACM0
```

#### 3. 检查配置

确认 `ace.cfg` 中串口路径正确：

```ini
[ace]
serial: /dev/serial/by-id/usb-ANYCUBIC_ACE_1-if00
```

或使用自动检测（不填 `serial`）：
```ini
[ace]
baud: 115200
```

#### 4. 检查用户权限

```bash
# 将用户加入 dialout 组
sudo usermod -a -G dialout $USER
# 重新登录后生效
```

#### 5. 检查端口占用

```bash
# 查看端口是否被其他进程占用
lsof /dev/ttyACM0
```

若端口已被占用，终止相关进程或重启 Klipper。

---

## 停泊问题

### 症状：停泊不完成

**可能原因：**

1. **耗材未到达喷嘴**
   - 确认耗材可以顺畅通过整段路径
   - 检查 ACE 内耗材张力
   - 确认热端已加热到工作温度

2. **`park_hit_count` 值过大**
   ```ini
   # 在 ace.cfg 中减小此值
   park_hit_count: 3  # 原来是 5
   ```

3. **端点开关问题**
   - 检查喷嘴内的端点开关工作是否正常
   - 确认接线无误

**诊断：**
```gcode
ACE_STATUS
# 关注 feed_assist_count 值
# 停泊过程中该值应持续增大
```

### 症状：停泊过早完成

**解决方法：**
```ini
# 增大 park_hit_count
park_hit_count: 7  # 原来是 5
```

### 症状：报错 "Feed assist not working"

**原因：**
- 耗材卡在路径中
- ACE 机构问题
- 槽位无耗材

**解决方法：**
1. 检查槽位是否有耗材
2. 查看槽位状态：`ACE_STATUS`
3. 尝试手动进给：`ACE_FEED INDEX=0 LENGTH=50 SPEED=20`
4. 若问题持续，检查 ACE 机械部分

---

## 换工具问题

### 症状：换工具卡住

**诊断：**
```bash
tail -f ~/printer_data/logs/klippy.log | grep -i "toolchange\|park"
```

**可能原因：**

1. **回退后槽位未就绪**
   - 增大等待时间
   - 确认回退已完全完成

2. **停泊未完成**
   - 参见 [停泊问题](#停泊问题)

3. **宏出错**
   - 检查 `_ACE_PRE_TOOLCHANGE` 和 `_ACE_POST_TOOLCHANGE` 宏
   - 确认宏不会阻塞执行

**手动逐步排查：**
```gcode
ACE_DISABLE_FEED_ASSIST INDEX=0   # 禁用当前 assist
ACE_RETRACT INDEX=0 LENGTH=100 SPEED=25  # 手动回退
# 等待完成后...
ACE_PARK_TO_TOOLHEAD INDEX=1      # 手动停泊新槽位
```

### 症状：报错 "Slot is not ready"

**原因：**
- 槽位为空
- 耗材卡住
- ACE 机构问题

**解决方法：**
1. 检查槽位物理状态
2. 确认耗材已正确装入
3. 尝试其他槽位
4. 查看状态：`ACE_STATUS`

---

## 进给/回退问题

### 症状：耗材不进给

**诊断：**
```gcode
ACE_FEED INDEX=0 LENGTH=50 SPEED=25
ACE_STATUS
```

**可能原因：**

1. **槽位为空** —— 检查耗材是否存在，查看槽位状态

2. **耗材卡住** —— 检查路径，手动清除卡料

3. **速度配置有误**
   ```ini
   feed_speed: 25
   ```

### 症状：进给/回退速度慢

**解决方法：**
```ini
# 提高速度（ACE Pro 建议不超过 25）
feed_speed: 25
retract_speed: 25
```

或在命令中直接指定：
```gcode
ACE_FEED INDEX=0 LENGTH=50 SPEED=25
```

### 症状：命令无响应

**诊断：**
```gcode
ACE_STATUS
# 若显示 disconnected，参见设备无法连接章节
```

---

## 烘干问题

### 症状：烘干无法启动

**检查：**
```gcode
ACE_STATUS
ACE_START_DRYING TEMP=50 DURATION=120
```

**可能原因：**

1. **温度超过上限**
   ```ini
   # 检查配置
   max_dryer_temperature: 55
   ```

2. **参数不合法**
   - 温度范围：20-55°C
   - 时间范围：1-240 分钟

### 症状：温度达不到目标值

**可能原因：**
- ACE 加热器故障
- 电源功率不足
- 通风问题

**解决方法：**
- 检查设备物理状态
- 确认风扇运转正常
- 尝试降低目标温度

---

## 性能问题

### 症状：命令响应慢

**解决方法：**

1. **减小超时值：**
   ```ini
   response_timeout: 1.5  # 原来是 2.0
   read_timeout: 0.05     # 原来是 0.1
   write_timeout: 0.3     # 原来是 0.5
   ```

2. **减小队列大小：**
   ```ini
   max_queue_size: 10  # 原来是 20
   ```

### 症状：CPU 占用过高

**解决方法：**
- 关闭 DEBUG 日志
- 检查系统中是否有其他高负载进程

---

## 连接诊断步骤

### 步骤 1：检查 USB 设备

```bash
lsusb | grep -i anycubic
# 预期输出：
# Bus 001 Device 003: ID 28e9:018a Anycubic ACE
```

### 步骤 2：检查串口

```bash
ls -la /dev/serial/by-id/ | grep -i ace
# 预期输出：
# usb-ANYCUBIC_ACE_1-if00 -> ../../ttyACM0
```

### 步骤 3：检查访问权限

```bash
ls -l /dev/ttyACM0
# 预期输出类似：
# crw-rw---- 1 root dialout 166, 0 Jan 1 12:00 /dev/ttyACM0
```

### 步骤 4：测试串口连接

```bash
python3 -c "import serial; s=serial.Serial('/dev/ttyACM0', 115200); print('OK'); s.close()"
```

若报错，检查权限或端口是否被占用。

### 步骤 5：通过 Klipper 验证

```gcode
ACE_STATUS
ACE_DEBUG METHOD=get_info
```

---

## 常见错误代码

| 错误 | 原因 | 解决方法 |
|------|------|---------|
| `Connection lost` | 与设备失去连接 | 检查 USB 线；重启 Klipper；查看详细日志 |
| `Queue overflow` | 同时发送命令过多 | 增大 `max_queue_size`；降低命令发送频率 |
| `CRC mismatch` | 数据传输错误 | 检查 USB 线（可能损坏）；尝试其他 USB 口 |
| `Slot is not ready` | 槽位为空或耗材未就绪 | 检查耗材装载状态；尝试其他槽位 |

---

## 收集调试信息

若问题无法解决，请收集以下信息：

### 1. Klipper 日志

```bash
tail -100 ~/printer_data/logs/klippy.log > klipper_log.txt
```

### 2. 设备状态

```gcode
ACE_STATUS
ACE_DEBUG METHOD=get_info
```

### 3. 系统信息

```bash
# Klipper 版本
cd ~/klipper && git log -1

# Python 版本
python3 --version

# USB 设备列表
lsusb > usb_devices.txt

# 串口列表
ls -la /dev/serial/by-id/ > serial_ports.txt
```

### 4. 配置文件

```bash
cp ~/printer_data/config/ace.cfg ace_config_backup.txt
```

---

## 获取帮助

若问题仍未解决：

1. **查阅文档：**
   - [用户指南](USER_GUIDE.md)
   - [命令参考](COMMANDS.md)
   - [配置参考](CONFIGURATION.md)

2. **社区讨论：**
   - [Telegram - perdoling3d](https://t.me/perdoling3d/45834)
   - [Telegram - ERCFcrealityACEpro](https://t.me/ERCFcrealityACEpro/21334)

3. **提交 GitHub Issue：**
   - 附上收集到的调试信息
   - 描述重现步骤
   - 注明 Klipper 版本和打印机型号
   - 仓库地址：https://github.com/Solismuchengxue/Solis_ACE

---

*最后更新：2026*
