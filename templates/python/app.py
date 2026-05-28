from __future__ import annotations

import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from typing import Any

try:
    import yaml  # type: ignore
except Exception:
    yaml = None

APP_NAME = os.environ.get("APP_NAME", "Serv00 Python App")
PORT = int(os.environ.get("PORT", "8000"))
CONFIG_PATH = Path(os.environ.get("API_KEYS_CONFIG", Path(__file__).with_name("api_keys.json")))


def _normalize_api_keys(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, list):
        return [str(item).strip() for item in value if str(item).strip()]
    if isinstance(value, str):
        value = value.strip()
        return [value] if value else []
    return []


def load_config(config_path: Path = CONFIG_PATH) -> dict[str, Any]:
    if not config_path.exists():
        return {"api_keys": [], "model_name": "", "source": "missing"}

    suffix = config_path.suffix.lower()
    raw = config_path.read_text(encoding="utf-8")

    if suffix == ".json":
        data = json.loads(raw) or {}
    elif suffix in {".yml", ".yaml"}:
        if yaml is None:
            return {"api_keys": [], "model_name": "", "source": "yaml-unavailable"}
        data = yaml.safe_load(raw) or {}
    else:
        data = {"api_keys": [line.strip() for line in raw.splitlines() if line.strip()], "model_name": "", "source": "text"}

    if not isinstance(data, dict):
        data = {}

    return {
        "api_keys": _normalize_api_keys(data.get("api_keys")),
        "model_name": str(data.get("model_name", "") or "").strip(),
        "source": suffix.lstrip(".") or "text",
    }


class Handler(BaseHTTPRequestHandler):
    def _send(self, status: int, body: bytes, content_type: str) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        cfg = load_config()
        if self.path == "/healthz":
            self._send(200, b"ok", "text/plain; charset=utf-8")
            return
        if self.path == "/api/config":
            body = json.dumps(
                {
                    "ok": True,
                    "app_name": APP_NAME,
                    "config_path": str(CONFIG_PATH),
                    "api_keys_count": len(cfg["api_keys"]),
                    "model_name": cfg["model_name"],
                    "source": cfg["source"],
                },
                ensure_ascii=False,
            ).encode("utf-8")
            self._send(200, body, "application/json; charset=utf-8")
            return

        model_row = f"<p><strong>Model:</strong> {cfg['model_name']}</p>" if cfg["model_name"] else ""
        body = f"""<!doctype html>
<html lang=\"zh-CN\">
<head>
  <meta charset=\"utf-8\">
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
  <title>{APP_NAME}</title>
  <style>
    body {{ font-family: system-ui, sans-serif; max-width: 760px; margin: 64px auto; padding: 0 20px; line-height: 1.7; }}
    .card {{ padding: 20px; border: 1px solid #ddd; border-radius: 12px; }}
    code {{ background: #f6f6f6; padding: 2px 6px; border-radius: 6px; }}
  </style>
</head>
<body>
  <div class=\"card\">
    <h1>{APP_NAME}</h1>
    <p>Serv00 上运行正常。</p>
    <p><strong>Config:</strong> <code>{CONFIG_PATH}</code></p>
    <p><strong>API keys:</strong> {len(cfg['api_keys'])}</p>
    {model_row}
    <p><a href=\"/api/config\">/api/config</a> · <a href=\"/healthz\">/healthz</a></p>
  </div>
</body>
</html>""".encode("utf-8")
        self._send(200, body, "text/html; charset=utf-8")


HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
