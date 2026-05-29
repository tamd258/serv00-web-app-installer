#!/bin/sh
set -eu

APP_NAME="serv00-web-app-installer"
INSTALL_DIR="${SWI_INSTALL_DIR:-$HOME/serv00-web-app-installer}"
APP_ROOT="${SWI_ROOT:-$HOME/apps}"
PUBLIC_ROOT="${SWI_PUBLIC_ROOT:-$HOME/domains}"
RAW_BASE="${SWI_RAW_BASE:-https://raw.githubusercontent.com/tamd258/serv00-web-app-installer/main}"
AUTO_SSL="${SWI_AUTO_SSL:-1}"
HEALTH_INTERVAL="${SWI_HEALTH_INTERVAL:-30}"

red(){ printf '\033[0;91m%s\033[0m\n' "$1"; }
green(){ printf '\033[0;92m%s\033[0m\n' "$1"; }
yellow(){ printf '\033[0;33m%s\033[0m\n' "$1"; }
blue(){ printf '\033[0;94m%s\033[0m\n' "$1"; }
line(){ printf '%s\n' '----------------------------------------'; }
need(){ command -v "$1" >/dev/null 2>&1 || { red "缺少命令: $1"; exit 1; }; }

pause(){
  printf "按回车继续..."
  read _ || true
}

ask(){
  prompt="$1"
  default="$2"
  printf "%s" "$prompt" >&2
  if [ -n "$default" ]; then printf " [%s]" "$default" >&2; fi
  printf ": " >&2
  read answer || answer=""
  if [ -z "$answer" ]; then answer="$default"; fi
  printf '%s' "$answer"
}

yes_default(){
  prompt="$1"
  default="${2:-Y}"
  if [ "$default" = "Y" ]; then suffix="Y/n"; else suffix="y/N"; fi
  printf "%s [%s]: " "$prompt" "$suffix" >&2
  read answer || answer=""
  [ -z "$answer" ] && answer="$default"
  case "$answer" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

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
  mkdir -p "$INSTALL_DIR" "$INSTALL_DIR/scripts" "$INSTALL_DIR/templates/python" "$INSTALL_DIR/templates/keepalive" "$HOME/bin"
  curl -fsSL "$RAW_BASE/start.sh" -o "$INSTALL_DIR/start.sh"
  curl -fsSL "$RAW_BASE/scripts/healthcheck.sh" -o "$INSTALL_DIR/scripts/healthcheck.sh" || true
  curl -fsSL "$RAW_BASE/templates/python/app.py" -o "$INSTALL_DIR/templates/python/app.py" || true
  curl -fsSL "$RAW_BASE/templates/keepalive/keepalive.py" -o "$INSTALL_DIR/templates/keepalive/keepalive.py" || true
  curl -fsSL "$RAW_BASE/templates/keepalive/api_keys.json" -o "$INSTALL_DIR/templates/keepalive/api_keys.json" || true
  chmod +x "$INSTALL_DIR/start.sh"
  cat > "$HOME/bin/swi" <<EOF2
#!/bin/sh
exec "$INSTALL_DIR/start.sh" "\$@"
EOF2
  chmod +x "$HOME/bin/swi"
  # Ensure ~/bin is in PATH
  for rc in "$HOME/.bashrc" "$HOME/.profile"; do
    if [ -f "$rc" ] && ! grep -q '$HOME/bin' "$rc" 2>/dev/null; then
      printf 'export PATH="$HOME/bin:$PATH"\n' >> "$rc"
    fi
  done
  export PATH="$HOME/bin:$PATH"
  green "已安装/更新。重新登录后输入 swi 使用。"
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

allocate_port(){
  fallback="$1"
  if [ -n "${SWI_PORT:-}" ]; then
    printf '%s' "$SWI_PORT"
    return
  fi
  if ensure_devil; then
    port="$(devil port add tcp random 2>/dev/null | grep -oE '[0-9]{4,6}' | head -1)" || port=""
    if [ -n "$port" ]; then
      printf '%s' "$port"
      return
    fi
  fi
  printf '%s' "$fallback"
}

create_website(){
  domain="$1"
  mode="$2"
  target="$3"
  if ensure_devil; then
    if [ "$mode" = "php" ]; then
      devil www add "$domain" php "$target" >/dev/null 2>&1 || yellow "网站可能已存在或创建失败，请在面板检查：$domain"
    else
      devil www add "$domain" proxy "$target" >/dev/null 2>&1 || yellow "本地反代网站可能已存在或创建失败，请在面板检查：$domain"
    fi
    try_ssl "$domain"
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
  <style>body{font-family:system-ui,sans-serif;max-width:760px;margin:64px auto;padding:0 20px;line-height:1.7}.card{padding:20px;border:1px solid #ddd;border-radius:12px}</style>
</head>
<body>
  <div class="card">
    <h1>$name</h1>
    <p>PHP 站点已创建。</p>
    <p>当前时间：<?php echo date('Y-m-d H:i:s'); ?></p>
  </div>
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
  <style>body{font-family:system-ui,sans-serif;max-width:760px;margin:64px auto;padding:0 20px;line-height:1.7}.card{padding:20px;border:1px solid #ddd;border-radius:12px}</style>
</head>
<body>
  <div class="card">
    <h1>$name</h1>
    <p>静态站点已创建。</p>
  </div>
</body>
</html>
EOF2
  fi

  create_website "$domain" php "$target"
  print_result "$name" "$domain" "$target" ""
}

create_node_app(){
  name="$1"
  domain="${2:-$(user_domain "$name")}"
  app_dir="$APP_ROOT/$name"
  port="$(allocate_port 3000)"

  need node
  mkdir -p "$app_dir"
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
if pgrep -f "node server.js" >/dev/null 2>&1; then exit 0; fi
PORT="$port" nohup node server.js >> app.log 2>&1 &
EOF2
  cat > "$app_dir/stop.sh" <<EOF2
#!/bin/sh
pkill -f "node server.js" >/dev/null 2>&1 || true
EOF2
  chmod +x "$app_dir/start.sh" "$app_dir/stop.sh"
  "$app_dir/start.sh"
  create_website "$domain" proxy "127.0.0.1:$port"
  install_healthcheck "$name" "$app_dir/start.sh" "http://127.0.0.1:$port/"
  print_result "$name" "$domain" "$app_dir" "$port"
}

create_python_app(){
  name="$1"
  domain="${2:-$(user_domain "$name")}"
  app_dir="$APP_ROOT/$name"
  port="$(allocate_port 8000)"

  need python3
  mkdir -p "$app_dir"
  cp "$INSTALL_DIR/templates/python/app.py" "$app_dir/app.py"
  cat > "$app_dir/start.sh" <<EOF2
#!/bin/sh
cd "$app_dir"
if pgrep -f "python3 app.py" >/dev/null 2>&1; then exit 0; fi
PORT="$port" APP_NAME="$name" API_KEYS_CONFIG="$app_dir/api_keys.json" nohup python3 app.py >> app.log 2>&1 &
EOF2
  cat > "$app_dir/stop.sh" <<EOF2
#!/bin/sh
pkill -f "python3 app.py" >/dev/null 2>&1 || true
EOF2
  chmod +x "$app_dir/start.sh" "$app_dir/stop.sh"
  if [ ! -f "$app_dir/api_keys.json" ]; then
    cat > "$app_dir/api_keys.json" <<EOF2
{
  "api_keys": [],
  "model_name": ""
}
EOF2
  fi
  "$app_dir/start.sh"
  create_website "$domain" proxy "127.0.0.1:$port"
  install_healthcheck "$name" "$app_dir/start.sh" "http://127.0.0.1:$port/healthz"
  print_result "$name" "$domain" "$app_dir" "$port"
}

create_keepalive_app(){
  name="$1"
  domain="${2:-$(user_domain "$name")}"
  app_dir="$APP_ROOT/$name"
  port="$(allocate_port 8000)"

  need python3
  mkdir -p "$app_dir"
  cp "$INSTALL_DIR/templates/keepalive/keepalive.py" "$app_dir/keepalive.py"

  # Simple: just enter Zo Computer keys
  blue "Zo Computer API 保活"
  read -p "几个 key 需要保活？ [0]: " kc
  kc=${kc:-0}

  if [ "$kc" -gt 0 ] 2>/dev/null; then
    envfile="$app_dir/.env_keepalive"
    :> "$envfile"
    apis_json='"apis": ['
    i=1
    while [ "$i" -le "$kc" ]; do
      read -p "  密钥 $i: " keyval
      varname="ZO_KEY_$i"
      printf 'export %s="%s"\n' "$varname" "$keyval" >> "$envfile"
      [ "$i" -gt 1 ] && apis_json="$apis_json,"
      apis_json="$apis_json
    {\"name\":\"Zo-$i\",\"url\":\"https://api.zo.computer/zo/ask\",\"headers\":{\"authorization\":\"\$'$varname'\",\"content-type\":\"application/json\"},\"payload\":{\"input\":\"ping\"},\"method\":\"POST\",\"timeout\":30}"
      i=$((i + 1))
    done
    apis_json="$apis_json]"
    printf '{\n%s\n}\n' "$apis_json" > "$app_dir/api_keys.json"
    green "已配置 $kc 个 key，密钥存在 $envfile"
  else
    echo '{"apis":[]}' > "$app_dir/api_keys.json"
    yellow "跳过，可稍后编辑。"
  fi


  # Flask status page
  cat > "$app_dir/app.py" <<EOF3
from flask import Flask, jsonify
import subprocess, sys, os
app = Flask(__name__)

@app.route('/')
def index():
    return '<h1>API 保活</h1><p><a href="/run">手动执行</a> | <a href="/log">查看日志</a></p>'

@app.route('/healthz')
def healthz():
    return jsonify({"status":"ok"})

@app.route('/run')
def run():
    try:
        r = subprocess.run([sys.executable, 'keepalive.py'], capture_output=True, text=True,
                          cwd='$app_dir', timeout=120,
                          env={**os.environ, 'API_KEYS_CONFIG': '$app_dir/api_keys.json'})
        return '<pre>' + r.stdout + '</pre>', 200
    except Exception as e:
        return f'<pre>Error: {e}</pre>', 500

@app.route('/log')
def log():
    try:
        with open('$app_dir/keepalive.log', 'r') as f:
            lines = f.readlines()[-80:]
        return '<pre>' + ''.join(lines) + '</pre>'
    except:
        return '<pre>暂无日志</pre>'

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=$port)
EOF3

  # start.sh: runs both Flask status page and cron-driven keepalive
  cat > "$app_dir/start.sh" <<EOF3
#!/bin/sh
cd "$app_dir"
if ! pgrep -f "python3 app.py" >/dev/null 2>&1; then
  PORT="$port" nohup python3 app.py >> app.log 2>&1 &
fi
EOF3
  cat > "$app_dir/stop.sh" <<EOF3
#!/bin/sh
pkill -f "python3 app.py" >/dev/null 2>&1 || true
EOF3
  chmod +x "$app_dir/start.sh" "$app_dir/stop.sh"

  # Install pip deps if needed
  python3 -m pip install --user flask requests >/dev/null 2>&1 || true

  "$app_dir/start.sh"
  create_website "$domain" proxy "127.0.0.1:$port"

  # Set up cron for periodic keepalive
  normalize_interval
  if command -v crontab >/dev/null 2>&1; then
    tmp="$(mktemp)"
    crontab -l 2>/dev/null | grep -v "keepalive.py" > "$tmp" || true
    printf '*/%s * * * * cd %s && python3 keepalive.py >> keepalive.log 2>&1\n' "$HEALTH_INTERVAL" "$app_dir" >> "$tmp"
    crontab "$tmp"
    rm -f "$tmp"
    yellow "已添加保活 cron：每 $HEALTH_INTERVAL 分钟。"
  fi

  install_healthcheck "$name" "$app_dir/start.sh" "http://127.0.0.1:$port/healthz"
  print_result "$name" "$domain" "$app_dir" "$port"
}

install_healthcheck(){
  name="$1"
  start_cmd="$2"
  url="$3"
  normalize_interval
  mkdir -p "$HOME/bin" "$APP_ROOT/$name"
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
    keepalive) create_keepalive_app "$name" "$domain" ;;
    *) red "类型只支持 static/php/node/python/keepalive"; exit 1 ;;
  esac
}

print_result(){
  name="$1"
  domain="$2"
  path="$3"
  port="$4"
  line
  green "完成：$name"
  green "访问：https://$domain"
  green "目录：$path"
  if [ -n "$port" ]; then green "本地端口：$port"; fi
  line
}

pick_name(){
  prefix="$1"
  default="${prefix}$(date +%m%d%H%M)"
  name="$(ask "项目名，直接回车自动生成" "$default")"
  safe_name "$name" || { red "项目名不合法。"; exit 1; }
  printf '%s' "$name"
}

quick_create(){
  type="$1"
  case "$type" in
    static) title="静态站点"; prefix="site" ;;
    php) title="PHP 站点"; prefix="php" ;;
    node) title="Node.js 应用"; prefix="node" ;;
    python) title="Python 应用"; prefix="py" ;;
    keepalive) title="API 保活应用"; prefix="kp" ;;
    *) red "未知类型"; return ;;
  esac
  blue "创建 $title"
  name="$(pick_name "$prefix")"
  default_domain="$(user_domain "$name")"
  domain="$(ask "域名，直接回车使用默认域名" "$default_domain")"
  if [ "$AUTO_SSL" = "1" ]; then
    if yes_default "自动尝试申请 HTTPS 证书" "Y"; then AUTO_SSL=1; else AUTO_SSL=0; fi
  fi
  create_app "$type" "$name" "$domain"
}

one_click(){
  blue "一键模式会创建一个静态站点，除项目名外都用默认值。"
  name="$(pick_name site)"
  create_app static "$name" ""
}

list_local_apps(){
  echo "应用目录: $APP_ROOT"
  if [ -d "$APP_ROOT" ]; then
    ls -1 "$APP_ROOT" 2>/dev/null || true
  fi
}

manage_app(){
  list_local_apps
  name="$(ask "输入要管理的应用名" "")"
  [ -n "$name" ] || return
  app_dir="$APP_ROOT/$name"
  if [ ! -d "$app_dir" ]; then red "未找到：$app_dir"; return; fi
  while true; do
    line
    echo "管理应用：$name"
    echo "1. 启动"
    echo "2. 停止"
    echo "3. 重启"
    echo "4. 查看日志"
    echo "5. 查看健康检查日志"
    echo "6. 查看目录"
    echo "7. 删除此应用"
    echo "0. 返回"
    printf "请选择: "; read n || return
    case "$n" in
      1) [ -x "$app_dir/start.sh" ] && "$app_dir/start.sh" || yellow "这个应用没有启动脚本。" ;;
      2) [ -x "$app_dir/stop.sh" ] && "$app_dir/stop.sh" || yellow "这个应用没有停止脚本。" ;;
      3) [ -x "$app_dir/stop.sh" ] && "$app_dir/stop.sh" || true; [ -x "$app_dir/start.sh" ] && "$app_dir/start.sh" || yellow "这个应用没有启动脚本。" ;;
      4) [ -f "$app_dir/app.log" ] && tail -80 "$app_dir/app.log" || yellow "暂无 app.log" ;;
      5) [ -f "$app_dir/health.log" ] && tail -80 "$app_dir/health.log" || yellow "暂无 health.log" ;;
      6) echo "$app_dir" ;;
      7) if yes_default "确认删除 $name" "N"; then
           pkill -f "$app_dir" 2>/dev/null || true
           rm -rf "$app_dir" "$HOME/bin/${name}_health.sh" 2>/dev/null
           crontab -l 2>/dev/null | grep -v "${name}_health\|keepalive.py.*$name" | crontab - 2>/dev/null || true
           green "已删除 $name"
           return
         fi
         ;;
      0) return ;;
      *) red "无效选项" ;;
    esac
  done
}


api_manage(){
  list_local_apps
  name="$(ask "输入保活应用名" "")"
  [ -n "$name" ] || return
  app_dir="$APP_ROOT/$name"
  config="$app_dir/api_keys.json"
  envfile="$app_dir/.env_keepalive"
  if [ ! -f "$config" ]; then red "未找到 $config"; return; fi

  while true; do
    line
    echo "API 管理: $name"
    line
    python3 -c "
import json
d=json.load(open('$config'))
for i,a in enumerate(d.get('apis',[])):
    print(f'{i+1}. {a[\"name\"]} | {a[\"method\"]} | {a[\"url\"]}')
" 2>/dev/null || yellow "暂无 API"
    line
    echo "1. 添加 API"
    echo "2. 修改密钥"
    echo "3. 删除 API"
    echo "0. 返回"
    printf "请选择: "; read n || return
    case "$n" in
      1)
        read -p "  名称: " nm
        read -p "  URL: " url
        read -p "  方法 [POST]: " mtd; mtd=${mtd:-POST}
        read -p "  密钥: " key
        python3 << PYADD
import json
d=json.load(open('$config'))
idx=len(d.get('apis',[]))+1
vname=f'ZO_KEY_{idx}'
d.setdefault('apis',[]).append({
  'name':'$nm','url':'$url',
  'headers':{'authorization':f'\${vname}','content-type':'application/json'},
  'payload':{'input':'ping'},'method':'$mtd','timeout':30
})
json.dump(d,open('$config','w'),indent=2)
with open('$envfile','a') as f:
    f.write(f'export {vname}={chr(34)}$key{chr(34)}\n')
print(f'added {vname}')
PYADD
        green "已添加"
        ;;
      2)
        python3 -c "
import json
d=json.load(open('$config'))
for i,a in enumerate(d.get('apis',[])):
    k=a.get('headers',{}).get('authorization','?')
    print(f'{i+1}. {a[\"name\"]} ({k})')
" 2>/dev/null
        read -p "  修改第几个？ " idx
        read -p "  新密钥: " key
        python3 << PYMOD
import json
d=json.load(open('$config'))
i=int('$idx')-1
old_k=d['apis'][i]['headers']['authorization'].replace('\$','')
d['apis'][i]['headers']['authorization']='\$'+old_k
json.dump(d,open('$config','w'),indent=2)
# update env file
lines=open('$envfile','r').readlines()
with open('$envfile','w') as f:
    for l in lines:
        if old_k in l:
            f.write(f'export {old_k}={chr(34)}$key{chr(34)}\n')
        else:
            f.write(l)
PYMOD
        green "已更新"
        ;;
      3)
        python3 -c "
import json
d=json.load(open('$config'))
for i,a in enumerate(d.get('apis',[])):
    print(f'{i+1}. {a[\"name\"]}')
" 2>/dev/null
        read -p "  删除第几个？ " idx
        python3 << PYDEL
import json
d=json.load(open('$config'))
i=int('$idx')-1
old_k=d['apis'][i]['headers']['authorization'].replace('\$','')
del d['apis'][i]
json.dump(d,open('$config','w'),indent=2)
lines=open('$envfile','r').readlines()
with open('$envfile','w') as f:
    for l in lines:
        if old_k not in l:
            f.write(l)
PYDEL
        green "已删除"
        ;;
      0) return ;;
      *) red "无效" ;;
    esac
  done
}

port_menu(){
  while true; do
    line
    echo "端口管理"
    line
    if command -v devil >/dev/null 2>&1; then
      devil port list 2>/dev/null || true
    else
      yellow "未检测到 devil 命令。"
      return
    fi
    line
    echo "1. 添加端口"
    echo "2. 删除端口"
    echo "3. 清除所有端口"
    echo "0. 返回"
    printf "请选择: "; read n || return
    case "$n" in
      1)
        echo "端口类型: 1.tcp  2.udp"
        read -p "请选择 [1]: " pt
        case "$pt" in 2) ptype="udp" ;; *) ptype="tcp" ;; esac
        read -p "端口备注(可选): " note
        if yes_default "自动分配端口" "Y"; then
          result=$(devil port add "$ptype" random 2>/dev/null | grep -oE '[0-9]{4,6}' | head -1)
          [ -n "$result" ] && green "已分配: $result" || red "分配失败"
        else
          read -p "输入端口号: " mp
          devil port add "$ptype" "$mp" "$note" 2>/dev/null && green "已添加" || red "添加失败"
        fi
        pause
        ;;
      2)
        read -p "输入要删除的端口号: " dp
        if [ -n "$dp" ]; then
          # 从列表中找到端口类型
          ptype=$(devil port list 2>/dev/null | awk -v p="$dp" '$1==p{print $2; exit}')
          [ -n "$ptype" ] && devil port del "$ptype" "$dp" 2>/dev/null && green "已删除 $dp" || red "未找到端口 $dp"
        fi
        pause
        ;;
      3)
        if yes_default "确认删除所有端口" "N"; then
          devil port list 2>/dev/null | awk 'NR>1 && $1 ~ /^[0-9]+$/ {print $2, $1}' | while read -r typ port; do
            devil port del "$typ" "$port" 2>/dev/null && echo "  已删除 $port"
          done
          green "已清除"
        fi
        pause
        ;;
      0) return ;;
      *) red "无效选项" ;;
    esac
  done
}

show_status(){
  line
  echo "安装目录: $INSTALL_DIR"
  echo "应用目录: $APP_ROOT"
  echo "网站目录: $PUBLIC_ROOT"
  echo "健康检查间隔: $HEALTH_INTERVAL 分钟"
  line
  echo "本地应用:"
  list_local_apps
  if command -v devil >/dev/null 2>&1; then
    line
    echo "Serv00 网站列表:"
    devil www list || true
    line
    echo "Serv00 端口列表:"
    devil port list || true
  else
    yellow "未检测到 devil 命令。"
  fi
  if command -v crontab >/dev/null 2>&1; then
    line
    echo "本工具创建的 cron:"
    crontab -l 2>/dev/null | grep '_health.sh' || true
  fi
}

menu(){
  while true; do
    line
    echo "serv00-web-app-installer"
    line
    echo "1. 一键创建默认静态站点（最适合小白）"
    echo "2. 创建静态站点 HTML/CSS/JS"
    echo "3. 创建 PHP 站点"
    echo "4. 创建 Node.js Web 应用"
    echo "5. 创建 Python Web 应用"
    echo "6. 创建 API 保活应用"
    echo "7. 管理已有应用"
    echo "8. API 密钥管理（增/删/改）"
    echo "9. 端口管理（增/删/查看）"
    echo "10. 查看状态 / 网站 / 端口 / cron"
    echo "11. 安装或更新本工具到 ~/bin/swi"
    echo "0. 退出"
    printf "请选择: "; read n || exit 0
    case "$n" in
      1) one_click; pause ;;
      2) quick_create static; pause ;;
      3) quick_create php; pause ;;
      4) quick_create node; pause ;;
      5) quick_create python; pause ;;
      6) quick_create keepalive; pause ;;
      7) manage_app; pause ;;
      8) api_manage; pause ;;
      9) port_menu; pause ;;
      10) show_status; pause ;;
      11) install_self; pause ;;
      0) exit 0 ;;
      *) red "无效选项" ;;
    esac
  done
}

case "${1:-}" in
  --install) install_self ;;
  --create) shift; create_app "${1:-}" "${2:-}" "${3:-}" ;;
  --status) show_status ;;
  --manage) manage_app ;;
  *) menu ;;
esac
