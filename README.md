# serv00-web-app-installer

一个面向 **Serv00 免费版合规用途**的轻量 Web 应用部署器。

它只做 Serv00 免费版明确适合的事情：普通网站、静态页面、PHP 页面、轻量 Node.js/Python Web 应用、HTTPS、低频健康检查和日志查看。

## 不做什么

本项目不包含，也不建议添加：

- AList / OpenList / abcd / 网盘聚合 / 文件中转
- Proxy / VPN / Tunneling / 翻墙 / 流量转发
- Nezha 探针、sing-box、Hysteria、VMess、SOCKS
- 高频保活、批量账号保号、隐藏进程名、随机二进制名
- 与网站、邮件、Git 仓库无关的长驻服务

## 支持功能

- 安装到 `~/serv00-web-app-installer`
- 创建静态站点模板
- 创建 PHP 站点模板
- 创建 Node.js HTTP 应用模板
- 创建 Python HTTP 应用模板
- 使用 Serv00 `devil` 工具创建网站
- 可选申请 Let's Encrypt 证书
- 查看站点状态、日志路径和项目目录
- 为 Node/Python 应用生成**低频**健康检查 cron（默认 30 分钟）

## 快捷安装

```sh
bash <(curl -Ls https://raw.githubusercontent.com/YOUR_NAME/serv00-web-app-installer/main/start.sh) --install
```

重新登录后输入：

```sh
swi
```

如果你是手动下载仓库，也可以直接运行：

```sh
sh start.sh
```

## 直接创建应用

```sh
sh start.sh --create static mysite
sh start.sh --create php blog
sh start.sh --create node api
sh start.sh --create python demo
```

默认会使用 `项目名.$USER.serv00.net`。如需自定义域名：

```sh
sh start.sh --create static mysite example.com
```

## 环境变量

```sh
SWI_ROOT="$HOME/apps"          # 应用存放目录，默认 ~/apps
SWI_PUBLIC_ROOT="$HOME/domains" # 静态/PHP 网站目录，默认 ~/domains
SWI_HEALTH_INTERVAL=30          # Node/Python 健康检查分钟数，默认 30，最低 15
SWI_AUTO_SSL=1                  # 创建网站后自动尝试申请 Let's Encrypt，默认 1
```

## 生成目录

```text
~/apps/<name>/                  # Node/Python 应用代码和日志
~/domains/<domain>/public_html/ # 静态/PHP 网站根目录
~/bin/<name>_health.sh          # 可选健康检查脚本
```

## 适合的用途

- 个人主页、作品集、博客
- PHP 小网站
- Node/Python 学习项目、小 API
- Webhook 接收页、小工具页面
- HTML/CSS/JS 静态页面

## 许可

MIT
