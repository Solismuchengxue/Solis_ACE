"""
SolisACE 的 Moonraker API 扩展 —— 提供 ACE 状态查询与命令下发接口（单实例）。

安装：
  - 将本文件软链接到 Moonraker 的 components 目录，例如：
      ln -s /path/to/repo/moonraker/ace_status.py ~/moonraker/moonraker/components/ace_status.py
  - 在 moonraker.conf 中添加：
      [ace_status]
"""

from __future__ import annotations

import json
import logging
import re
from typing import TYPE_CHECKING, Any, Dict, List, Optional

# 仅用于类型检查的导入（运行时不加载，避免循环依赖）
if TYPE_CHECKING:
    from confighelper import ConfigHelper
    from websockets import WebRequest
    from . import klippy_apis

    APIComp = klippy_apis.KlippyAPI


# 仅允许 ACE_ 前缀的命令，防止本端点被用于执行任意 G-code（如 RESTART、M84、SAVE_CONFIG）
SAFE_COMMAND_RE = re.compile(r"^ACE_[A-Z0-9_]+$")
# 参数名白名单：只允许字母、数字、下划线
SAFE_KEY_RE = re.compile(r"^[A-Za-z0-9_]+$")


def _sanitize_key(key: Any) -> Optional[str]:
    """校验参数名：合法则返回该名称，非法返回 None。"""
    key_str = str(key).strip()
    if SAFE_KEY_RE.match(key_str):
        return key_str
    return None


def _sanitize_value(val: Any) -> str:
    """将参数值规范化为安全字符串（布尔转 1/0；去除换行，防止拼接多条命令）。"""
    if isinstance(val, bool):
        return "1" if val else "0"
    if isinstance(val, (int, float)):
        return str(val)
    text = str(val)
    # 去掉换行/回车，避免通过参数值注入额外的 G-code 行
    return text.replace("\n", " ").replace("\r", " ").strip()


class AceStatus:
    def __init__(self, config: ConfigHelper):
        # 获取 Moonraker server 与 Klipper API 组件
        self.server = config.get_server()
        self.logger = logging.getLogger(__name__)
        self.klippy_apis: APIComp = self.server.lookup_component("klippy_apis")

        # 注册三个 REST 端点：状态查询、料槽查询、命令下发
        self.server.register_endpoint(
            "/server/ace/status", ["GET"], self.handle_status_request
        )
        self.server.register_endpoint(
            "/server/ace/slots", ["GET"], self.handle_slots_request
        )
        self.server.register_endpoint(
            "/server/ace/command", ["POST"], self.handle_command_request
        )

        # 订阅 Klipper 状态更新事件，用于缓存最新的 ace 对象状态
        self.server.register_event_handler(
            "server:status_update", self._handle_status_update
        )

        # 最近一次成功获取的状态，作为查询失败时的回退缓存
        self._last_status: Optional[Dict[str, Any]] = None
        self.logger.info("ACE Status API extension loaded (single-instance mode)")

    async def _query_ace_status(self) -> Dict[str, Any]:
        """查询 Klipper 中唯一的 'ace' 对象状态。"""
        try:
            # 通过 klippy_apis 查询 ace 对象；查不到或类型不符时返回空字典
            result = await self.klippy_apis.query_objects({"ace": None})
            ace = result.get("ace")
            return ace if isinstance(ace, dict) else {}
        except Exception as exc:
            self.logger.debug("query_objects(ace) failed: %s", exc)
            return {}

    def _default_status(self) -> Dict[str, Any]:
        """拿不到任何 ACE 数据时返回的默认状态结构（含 4 个空料槽占位）。"""
        return {
            "status": "unknown",
            "model": "Anycubic Color Engine Pro",
            "firmware": "Unknown",
            "dryer": {
                "status": "stop",
                "target_temp": 0,
                "duration": 0,
                "remain_time": 0,
            },
            "temp": 0,
            "fan_speed": 0,
            "enable_rfid": 0,
            "slots": [
                {
                    "index": i,
                    "status": "unknown",
                    "type": "",
                    "color": [0, 0, 0],
                    "sku": "",
                    "rfid": 0,
                }
                for i in range(4)
            ],
        }

    async def handle_status_request(self, webrequest: WebRequest) -> Dict[str, Any]:
        """返回当前 ACE 设备状态。"""
        try:
            # 优先返回实时查询结果；查不到则用缓存；再没有则返回默认结构
            ace_data = await self._query_ace_status()
            if ace_data:
                self._last_status = ace_data
                return ace_data
            if self._last_status:
                self.logger.debug("Returning cached ACE status")
                return self._last_status
            self.logger.warning("No ACE data available, returning default structure")
            return self._default_status()
        except Exception as exc:
            self.logger.error("Error getting ACE status: %s", exc, exc_info=True)
            return {"error": str(exc)}

    async def handle_slots_request(self, webrequest: WebRequest) -> Dict[str, Any]:
        """仅返回料槽列表。"""
        # 复用完整状态查询，再从中取出 slots 字段
        status = await self.handle_status_request(webrequest)
        if "error" in status:
            return status
        return {"slots": status.get("slots", [])}

    async def handle_command_request(self, webrequest: WebRequest) -> Dict[str, Any]:
        """通过 Moonraker 执行一条 ACE G-code 命令。"""
        try:
            # 1) 尝试解析 JSON 请求体（POST body）
            json_body: Optional[Dict[str, Any]] = None
            try:
                payload = await webrequest.get_json()
                if isinstance(payload, dict):
                    json_body = payload
            except Exception:
                json_body = None

            # 2) 取命令名：优先 query 参数，其次 JSON body
            command = webrequest.get_str("command", None)
            if not command and json_body:
                command = json_body.get("command")

            if not command:
                return {"error": "Command parameter is required"}

            # 3) 统一转大写并校验：只放行 ACE_ 前缀命令
            command = str(command).strip().upper()
            if not SAFE_COMMAND_RE.match(command):
                return {"error": "Only ACE_ commands are allowed on this endpoint"}

            # 4) 收集命令参数（合并 JSON body 的 params 与 query 参数）
            params: Dict[str, Any] = {}

            if json_body and isinstance(json_body.get("params"), dict):
                params.update(json_body["params"])

            try:
                args = webrequest.get_args()
            except Exception:
                args = {}

            if args:
                # query 中的 params 可能是 JSON 字符串，也可能是字典
                qp_params = args.get("params")
                if qp_params:
                    if isinstance(qp_params, str):
                        try:
                            parsed = json.loads(qp_params)
                            if isinstance(parsed, dict):
                                params.update(parsed)
                        except Exception:
                            pass
                    elif isinstance(qp_params, dict):
                        params.update(qp_params)

                # 其余 query 参数（command/params 之外）也并入命令参数
                for key, value in args.items():
                    if key in ("command", "params"):
                        continue
                    params[key] = value

            # 5) 逐个校验参数名并规范化值，拼成 KEY=value 形式
            formatted_params: List[str] = []
            for key, value in params.items():
                safe_key = _sanitize_key(key)
                if not safe_key:
                    self.logger.debug("Skipping unsafe param key: %s", key)
                    continue
                formatted_params.append(f"{safe_key}={_sanitize_value(value)}")

            # 6) 组装最终 G-code 命令并下发给 Klipper
            gcode_cmd = f"{command} {' '.join(formatted_params)}".strip()

            try:
                await self.klippy_apis.run_gcode(gcode_cmd)
                return {
                    "success": True,
                    "message": f"Command {command} executed successfully",
                    "command": gcode_cmd,
                }
            except Exception as exc:
                self.logger.error("Error executing ACE command %s: %s", gcode_cmd, exc)
                return {"success": False, "error": str(exc), "command": gcode_cmd}

        except Exception as exc:
            self.logger.error("Error handling ACE command request: %s", exc)
            return {"error": str(exc)}

    async def _handle_status_update(self, status: Dict[str, Any]) -> None:
        """缓存 Klipper 状态变化事件（server:status_update）推送的 ACE 对象数据，并向前端广播。"""
        try:
            # 只关心 ace 对象的更新：缓存它并向前端广播 ace:status_update 事件
            ace_data = status.get("ace")
            if isinstance(ace_data, dict):
                self._last_status = ace_data
                self.server.send_event("ace:status_update", ace_data)
        except Exception as exc:
            self.logger.debug("Error handling status update: %s", exc)


# Moonraker 组件入口：加载本组件时由 Moonraker 调用
def load_component(config: ConfigHelper) -> AceStatus:
    return AceStatus(config)
