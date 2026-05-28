#!/usr/bin/env python3
"""API 保活脚本 - 定时 ping 配置的 API 端点，防止 Serv00 空闲休眠。
   通过 cron 每 N 分钟调用一次。"""

import requests
import os
import sys
import json
import time
from datetime import datetime

# ---- Serv00 兼容：优先使用本地虚拟环境的 requests ----
# 如果没装依赖，尝试自动安装
try:
    import requests
except ImportError:
    import subprocess
    subprocess.run([sys.executable, '-m', 'pip', 'install', '--user', 'requests'], check=False)
    import requests


class APIKeepAlive:
    def __init__(self, name, url, headers, payload=None, method="POST", timeout=30):
        self.name = name
        self.url = url
        self.headers = headers
        self.payload = payload or {}
        self.method = method.upper()
        self.timeout = timeout

    def ping(self):
        try:
            if self.method == "POST":
                resp = requests.post(
                    self.url, headers=self.headers, json=self.payload, timeout=self.timeout
                )
            else:
                resp = requests.get(self.url, headers=self.headers, timeout=self.timeout)

            if resp.status_code == 200:
                result = resp.json() if resp.text else {}
                output = str(result.get("output", ""))[:100] if "output" in result else "OK"
                return True, f"[{resp.status_code}] {output}"
            else:
                return False, f"[{resp.status_code}]"
        except Exception as e:
            return False, str(e)[:100]


def load_config(config_path):
    """从 JSON 配置文件加载 API 列表，支持 $ENV_VAR 语法替换环境变量。"""
    with open(config_path, 'r') as f:
        config = json.load(f)

    apis = []
    for entry in config.get('apis', []):
        headers = {}
        for k, v in entry.get('headers', {}).items():
            # 支持 $VAR 和 ${VAR} 语法
            val = v
            if isinstance(val, str):
                import re
                def replacer(m):
                    return os.environ.get(m.group(1), m.group(0))
                val = re.sub(r'\$\{?(\w+)\}?', replacer, val)
            headers[k] = val

        apis.append(APIKeepAlive(
            name=entry['name'],
            url=entry['url'],
            headers=headers,
            payload=entry.get('payload'),
            method=entry.get('method', 'POST'),
            timeout=entry.get('timeout', 30)
        ))
    return apis


def keep_all_alive(apis):
    all_ok = True
    now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    lines = [f"\n{'='*50}", f"保活检查 - {now}", f"{'='*50}"]

    for api in apis:
        success, message = api.ping()
        status = "✅ OK" if success else "❌ FAILED"
        line = f"{status} | {api.name}: {message}"
        lines.append(line)
        if not success:
            all_ok = False

    output = "\n".join(lines)
    print(output)
    return all_ok


if __name__ == "__main__":
    config_path = os.environ.get('API_KEYS_CONFIG', os.path.join(os.path.dirname(__file__), 'api_keys.json'))
    apis = load_config(config_path)
    if not apis:
        print("⚠️  未配置任何 API，请在 api_keys.json 中添加。")
        sys.exit(0)
    all_ok = keep_all_alive(apis)
    sys.exit(0 if all_ok else 1)
