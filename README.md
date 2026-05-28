# serv00-web-app-installer

一个面向 **Serv00 免费版合规用途**的轻量 Web 应用部署器。

目标是像 `serv00-play` 一样简单：安装后输入 `swi`，按数字选择即可。默认值尽量自动生成，小白也能少输入、少踩坑。

## 不做什么

本项目不包含，也不建议添加：

- AList / OpenList / abcd / 网盘聚合 / 文件中转
- 流量代理 / VPN / Tunneling / 翻墙 / 流量转发
- Nezha 探针、sing-box、Hysteria、VMess、SOCKS
- 高频保活、批量账号保号、隐藏进程名、随机二进制名
- 与网站、邮件、Git 仓库无关的长驻服务

## 支持功能

- 数字菜单操作，尽量少输入
- 一键创建默认静态站点
- 创建 HTML/CSS/JS 静态站点
- 创建 PHP 站点
- 创建 Node.js Web 应用
- 创建 Python Web 应用
- 自动使用 `项目名.$USER.serv00.net` 默认域名
- 使用 Serv00 `devil` 工具创建网站
- Node/Python 应用自动申请 Serv00 随机 TCP 端口，并用 Serv00 官方本地反代网站类型暴露为普通网站
- 可选申请 Let's Encrypt HTTPS
- Node/Python 自动生成启动、停止、低频健康检查脚本
- 查看网站、端口、cron、日志路径

## 快捷安装

在 Serv00 SSH 里执行：

```sh
bash <(curl -Ls https://raw.githubusercontent.com/tamd258/serv00-web-app-installer/main/start.sh) --install
```

重新登录后输入：

```sh
swi
```

## 菜单

```text
1. 一键创建默认静态站点（最适合小白）
2. 创建静态站点 HTML/CSS/JS
3. 创建 PHP 站点
4. 创建 Node.js Web 应用
5. 创建 Python Web 应用
6. 管理已有 Node/Python 应用
7. 查看状态 / 网站 / 端口 / cron
8. 安装或更新本工具到 ~/bin/swi
0. 退出
```

### 最简单用法

```sh
swi
```

然后选：

```text
1. 一键创建默认静态站点
```

项目名可以直接回车，脚本会自动生成类似 `site05281230` 的名字，默认域名是：

```text
项目名.你的用户名.serv00.net
```

## 命令行用法

如果你想跳过菜单：

```sh
sh start.sh --create static mysite
sh start.sh --create php blog
sh start.sh --create node api
sh start.sh --create python demo
```

自定义域名：

```sh
sh start.sh --create static mysite example.com
```

## 生成目录

```text
~/apps/<name>/                  # Node/Python 应用代码和日志
~/domains/<domain>/public_html/ # 静态/PHP 网站根目录
~/bin/<name>_health.sh          # Node/Python 健康检查脚本
```

## 环境变量

```sh
SWI_ROOT="$HOME/apps"           # 应用目录，默认 ~/apps
SWI_PUBLIC_ROOT="$HOME/domains" # 静态/PHP 网站目录，默认 ~/domains
SWI_HEALTH_INTERVAL=30          # 健康检查分钟数，默认 30，最低 15
SWI_AUTO_SSL=1                  # 创建网站后自动尝试申请 Let's Encrypt，默认 1
SWI_PORT=3000                   # 可选：手动指定 Node/Python 本地端口
```

## 适合的用途

- 个人主页、作品集、博客
- HTML/CSS/JS 静态页面
- PHP 小网站
- Node/Python 学习项目、小 API
- Webhook 接收页、小工具页面

## 许可

MIT
