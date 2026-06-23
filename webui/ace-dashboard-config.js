// ACE Dashboard Configuration

const ACE_DASHBOARD_CONFIG = {
    // Moonraker API 地址：与 nginx 同主机，直连 Moonraker 端口 7125。
    // install.sh 已在 moonraker.conf 中配置 CORS，允许来自 nginx 端口的请求。
    // 如需修改，例如：apiBase: 'http://192.168.1.100:7125',
    apiBase: `http://${window.location.hostname}:7125`,

    // WebSocket 地址（null = 自动从 apiBase 推导）
    wsBase: null,

    // 自动刷新间隔（毫秒）
    autoRefreshInterval: 10000,

    // WebSocket 重连超时（毫秒）
    wsReconnectTimeout: 3000,

    // 开启调试控制台日志
    debug: false,

    // 命令默认值
    defaults: {
        feedLength: 50,
        feedSpeed: 25,
        retractLength: 50,
        retractSpeed: 25,
        dryingTemp: 50,
        dryingDuration: 240,
        presetFeedLength: 50,
        presetRetractLength: 50
    }
};

// 构建 WebSocket URL（ws:// 或 wss://）
function getWebSocketUrl() {
    if (ACE_DASHBOARD_CONFIG.wsBase) {
        return ACE_DASHBOARD_CONFIG.wsBase;
    }
    const apiBase = ACE_DASHBOARD_CONFIG.apiBase;
    if (apiBase.startsWith('https://')) {
        return apiBase.replace('https://', 'wss://') + '/websocket';
    }
    return apiBase.replace('http://', 'ws://') + '/websocket';
}

if (typeof module !== 'undefined' && module.exports) {
    module.exports = { ACE_DASHBOARD_CONFIG, getWebSocketUrl };
}
