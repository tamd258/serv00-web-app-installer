#!/bin/sh
set -eu

APP_NAME="serv00-web-app-installer"
INSTALL_DIR="${SWI_INSTALL_DIR:-$HOME/serv00-web-app-installer}"
APP_ROOT="${SWI_ROOT:-$HOME/apps}"
PUBLIC_ROOT="${SWI_PUBLIC_ROOT:-$HOME/domains}"
RAW_BASE="${SWI_RAW_BASE:-https://raw.githubusercontent.com/YOUR_NAME/serv00-web-app-installer/main}"
AUTO_SSL="${SWI_AUTO_SSL:-1}"
HEALTH_INTERVAL="${SWI_HEALTH_INTERVAL:-30}"

red(){ printf '\033[0;91m%s\033[0m\n' "$1"; }
green(){ printf '\033[0;92m%s\033[0m\n' "$1"; }
yellow(){ printf '\033[0;33m%s\033[0m\n' "$1"; }
need(){ command -v "$1" >/dev/null 2>&1 || { red "缺少命令: $1"; exit 1; }; }

safe_name(){
  printf '%s' "$1" | grep -Eq '^[a-zA-Z0-9][a-zA-Z0-9_-]{1,40}$'
}

normalize_interval(){
  case "$HEALTH_INTERVAL" in
    ''|*[!0-9]*) HEALTH_INTERVAL=30 ;;
  esac
  if [ "$HEALTH_INTERVAL" -lt 15 ]; then HEALTH_INTERVAL=15; fi
}

user_domain(){
  name="$1"
  printf '%s.%s.serv00.net' "$name" "$USER"
}

install_self(){
  need curl
  mkdir -p "$INSTALL_DIR" "$INSTALL_DIR/scripts" "$HOME/bin"
  curl -fsSL "$RAW_BASE/start.sh" -o "$INSTALL_DIR/start.sh"
  curl -fsSL "$RAW_BASE/scripts/healthcheck.sh" -o "$INSTALL_DIR/scripts/healthcheck.sh" || true
  chmod +x "$INSTALL_DIR/start.sh"
  cat > "$HOME/bin/swi" <<EOF2
#!/bin/sh
exec "$INSTALL_DIR/start.sh" "\$@"
EOF2
  chmod +x "$HOME/bin/swi"
  green "已安装。重新登录后输入 swi 使用。"
}

ensure_devil(){
  if ! command -v devil >/dev/null 2>&1; then
    yellow "未检测到 devil 命令；将只创建本地文件，不会自动创建 Serv00 网站。"
    return 1
  fi
  return 0
}

try_ssl(){
  domain="$1"
  [ "$AUTO_SSL" = "1" ] || return 0
  if ensure_devil; then
    yellow "尝试为 $domain 申请 Let's Encrypt 证书..."
    devil ssl www add "$domain" le le >/dev/null 2>&1 || yellow "SSL 申请未完成，可稍后在 Serv00 面板手动申请。"
  fi
}

create_static_or_php_site(){
  type="$1"
  name="$2"
  domain="${3:-$(user_domain "$name")}"
  target="$PUBLIC_ROOT/$domain/public_html"

  mkdir -p "$target"
  if [ "$type" = "php" ]; then
    cat > "$target/index.php" <<EOF2
<?php
header('Content-Type: text/html; charset=utf-8');
?>
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$name</title>
  <style>body{font-family:system-ui,sans-serif;max-width:760px;margin:64px auto;padding:0 20px;line-height:1.7}</style>
</head>
<body>
  <h1>$name</h1>
  <p>PHP 站点已创建。</p>
  <p>当前时间：<?php echo date('Y-m-d H:i:s'); ?></p>
</body>
</html>
EOF2
  else
    cat > "$target/index.html" <<EOF2
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$name</title>
  <style>body{font-family:system-ui,sans-serif;max-width:760px;margin:64px auto;padding:0 20px;line-height:1.7}</style>
</head>
<body>
  <h1>$name</h1>
  <p>静态站点已创建。</p>
</body>
</html>
EOF2
  fi

  if ensure_devil; then
    devil www add "$domain" php "$target" >/dev/null 2>&1 || yellow "网站可能已存在或创建失败，请在面板检查：$domain"
    try_ssl "$domain"
  fi

  green "站点已创建: https://$domain"
  green "目录: $target"
}

create_node_app(){
  name="$1"
  domain="${2:-$(user_domain "$name")}"
  port="${SWI_PORT:-}"
  app_dir="$APP_ROOT/$name"

  need node
  mkdir -p "$app_dir"
  if [ -z "$port" ]; then
    if ensure_devil; then
      port="$(devil port add tcp random 2>/dev/null | awk '/[0-9]+/ {print $NF; exit}')"
    fi
    [ -n "$port" ] || port="3000"
  fi

  cat > "$app_dir/server.js" <<EOF2
const http = require('http');
const port = Number(process.env.PORT || '$port');
const server = http.createServer((req, res) => {
  res.writeHead(200, {'content-type': 'text/html; charset=utf-8'});
  res.end('<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>$name</title></head><body style="font-family:system-ui,sans-serif;max-width:760px;margin:64px auto;padding:0 20px;line-height:1.7"><h1>$name</h1><p>Node.js 应用正在运行。</p></body></html>');
});
server.listen(port, '127.0.0.1', () => console.log('listening on 127.0.0.1:' + port));
EOF2
  cat > "$app_dir/start.sh" <<EOF2
#!/bin/sh
cd "$app_dir"
PORT="$port" nohup node server.js >> app.log 2>&1 &
EOF2
  chmod +x "$app_dir/start.sh"
  "$app_dir/start.sh"

  if ensure_devil; then
    devil www add "$domain" proxy "127.0.0.1:$port" >/dev/null 2>&1 || yellow "proxy 网站可能已存在或创建失败，请在面板检查：$domain"
    try_ssl "$domain"
  fi
  install_healthcheck "$name" "$app_dir/start.sh" "http://127.0.0.1:$port/"
  green "Node.js 应用已创建: https://$domain"
  green "目录: $app_dir"
}

create_python_app(){
  name="$1"
  domain="${2:-$(user_domain "$name")}"
  port="${SWI_PORT:-}"
  app_dir="$APP_ROOT/$name"

  need python3
  mkdir -p "$app_dir"
  if [ -z "$port" ]; then
    if ensure_devil; then
      port="$(devil port add tcp random 2>/dev/null | awk '/[0-9]+/ {print $NF; exit}')"
    fi
    [ -n "$port" ] || port="8000"
  fi

  cat > "$app_dir/app.py" <<EOF2
from http.server import BaseHTTPRequestHandler, HTTPServer
import os

PORT = int(os.environ.get('PORT', '$port'))

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = '''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>$name</title></head><body style="font-family:system-ui,sans-serif;max-width:760px;margin:64px auto;padding:0 20px;line-height:1.7"><h1>$name</h1><p>Python 应用正在运行。</p></body></html>'''.encode()
        self.send_response(200)
        self.send_header('content-type', 'text/html; charset=utf-8')
        self.send_header('content-length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

HTTPServer(('127.0.0.1', PORT), Handler).serve_forever()
EOF2
  cat > "$app_dir/start.sh" <<EOF2
#!/bin/sh
cd "$app_dir"
PORT="$port" nohup python3 app.py >> app.log 2>&1 &
EOF2
  chmod +x "$app_dir/start.sh"
  "$app_dir/start.sh"

  if ensure_devil; then
    devil www add "$domain" proxy "127.0.0.1:$port" >/dev/null 2>&1 || yellow "proxy 网站可能已存在或创建失败，请在面板检查：$domain"
    try_ssl "$domain"
  fi
  install_healthcheck "$name" "$app_dir/start.sh" "http://127.0.0.1:$port/"
  green "Python 应用已创建: https://$domain"
  green "目录: $app_dir"
}

install_healthcheck(){
  name="$1"
  start_cmd="$2"
  url="$3"
  normalize_interval
  mkdir -p "$HOME/bin"
  script="$HOME/bin/${name}_health.sh"
  cat > "$script" <<EOF2
#!/bin/sh
code="\$(curl -L -s -o /dev/null -w '%{http_code}' '$url' || true)"
if [ "\$code" != "200" ]; then
  echo "\$(date '+%F %T') unhealthy: \$code, restarting" >> "$APP_ROOT/$name/health.log"
  sh '$start_cmd'
else
  echo "\$(date '+%F %T') healthy: \$code" >> "$APP_ROOT/$name/health.log"
fi
EOF2
  chmod +x "$script"
  if command -v crontab >/dev/null 2>&1; then
    tmp="$(mktemp)"
    crontab -l 2>/dev/null | grep -v "$script" > "$tmp" || true
    printf '*/%s * * * * /bin/sh %s\n' "$HEALTH_INTERVAL" "$script" >> "$tmp"
    crontab "$tmp"
    rm -f "$tmp"
    yellow "已添加低频健康检查 cron：每 $HEALTH_INTERVAL 分钟。"
  fi
}

create_app(){
  type="$1"
  name="$2"
  domain="${3:-}"
  safe_name "$name" || { red "项目名只能包含字母、数字、下划线、短横线，长度 2-41。"; exit 1; }
  mkdir -p "$APP_ROOT" "$PUBLIC_ROOT"
  case "$type" in
    static) create_static_or_php_site static "$name" "$domain" ;;
    php) create_static_or_php_site php "$name" "$domain" ;;
    node) create_node_app "$name" "$domain" ;;
    python) create_python_app "$name" "$domain" ;;
    *) red "类型只支持 static/php/node/python"; exit 1 ;;
  esac
}

show_status(){
  echo "安装目录: $INSTALL_DIR"
  echo "应用目录: $APP_ROOT"
  echo "网站目录: $PUBLIC_ROOT"
  command -v devil >/dev/null 2>&1 && devil www list || true
}

menu(){
  while true; do
    echo ""
    echo "== serv00-web-app-installer =="
    echo "1. 创建静态站点"
    echo "2. 创建 PHP 站点"
    echo "3. 创建 Node.js 应用"
    echo "4. 创建 Python 应用"
    echo "5. 查看状态"
    echo "0. 退出"
    printf "请选择: "; read n || exit 0
    case "$n" in
      1) ask_create static ;;
      2) ask_create php ;;
      3) ask_create node ;;
      4) ask_create python ;;
      5) show_status ;;
      0) exit 0 ;;
      *) red "无效选项" ;;
    esac
  done
}

ask_create(){
  type="$1"
  printf "项目名: "; read name || exit 0
  printf "域名（留空使用 项目名.$USER.serv00.net）: "; read domain || true
  create_app "$type" "$name" "${domain:-}"
}

case "${1:-}" in
  --install) install_self ;;
  --create) shift; create_app "${1:-}" "${2:-}" "${3:-}" ;;
  --status) show_status ;;
  *) menu ;;
esac
