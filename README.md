# serv00-web-app-installer

一个面向 Serv00 免费空间的轻量 Web 应用部署器。

目标是像 `serv00-play` 一样简单：安装后输入 `swi`，按数字选择即可。默认值尽量自动生成，小白也能少输入、少踩坑。

## 支持功能

- 数字菜单操作，尽量少输入
- 一键创建默认静态站点
- 创建 HTML/CSS/JS 静态站点
- 创建 PHP 站点
- 创建 Node.js Web 应用
- 创建 Python Web 应用
- **创建 API 保活应用**（定时 ping API 端点防休眠）
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

```
1. 一键创建默认静态站点（最适合小白）
2. 创建静态站点 HTML/CSS/JS
3. 创建 PHP 站点
4. 创建 Node.js Web 应用
5. 创建 Python Web 应用
6. 创建 API 保活应用
7. 管理已有 Node/Python 应用
8. 查看状态 / 网站 / 端口 / cron
9. 安装或更新本工具到 ~/bin/swi
0. 退出
```

## API 保活应用

创建后自动定时 ping 你配置的 API 端点，防止 Serv00 免费空间因闲置被休眠。

支持 GET / POST 请求，可配置多个 API。密钥从环境变量读取，不硬编码。

### 配置方式

在应用目录下创建 `api_keys.json`：

```json
{
  "apis": [
    {
      "name": "My API",
      "url": "https://api.example.com/health",
      "headers": {"authorization": "$MY_API_KEY"},
      "method": "GET"
    }
  ]
}
```

或通过环境变量 `API_KEYS_CONFIG` 指向自定义路径。

## 命令行用法

```sh
sh start.sh --create static mysite
sh start.sh --create php blog
sh start.sh --create node api
sh start.sh --create python demo
sh start.sh --create keepalive ping
```

## 生成目录

```
~/apps/<name>/                  # Node/Python 应用代码和日志
~/domains/<domain>/public_html/ # 静态/PHP 网站根目录
~/bin/<name>_health.sh          # 健康检查脚本
```

## 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| SWI_ROOT | 应用目录 | ~/apps |
| SWI_PUBLIC_ROOT | 静态/PHP 网站目录 | ~/domains |
| SWI_HEALTH_INTERVAL | 健康检查分钟数 | 30（最低 15） |
| SWI_AUTO_SSL | 创建后自动申请 HTTPS | 1 |
| SWI_PORT | 手动指定端口 | 自动分配 |

## 许可

MIT
