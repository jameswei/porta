# Porta

**项目主页：** https://jameswei.github.io/porta/ · [English](./README.md)

> 一款轻量级 macOS 菜单栏应用，用于检测并关闭编码工具遗留的孤儿监听端口。

当 AI 编码工具（或任何开发工具）在会话结束后遗留进程时，这些进程仍会持续占用 TCP 端口。Porta 驻留在菜单栏，展示所有匹配的 LISTEN 状态端口，让你一键关闭对应进程。

## 截图

<table>
  <tr>
    <td><img src="assets/screenshot_main.png" width="340" alt="端口列表 — 暴露范围标识、进程名称、PID、相对运行时间"/></td>
    <td><img src="assets/screenshot_settings.png" width="260" alt="设置 — 端口预设、自定义端口、刷新间隔、开机自启"/></td>
  </tr>
  <tr>
    <td align="center"><em>端口列表</em></td>
    <td align="center"><em>设置</em></td>
  </tr>
</table>

## 功能特性

- **检测监听端口** — 由 `lsof` 驱动，展示已配置开发工具中的 TCP LISTEN 状态端口
- **一键终止** — SIGTERM → 等待 2 秒 → SIGKILL，终止前弹出确认对话框并重新验证进程归属
- **暴露范围标识** — 每个端口显示 `local`（仅本机）或 `public`（所有接口），一眼看清暴露范围
- **相对运行时间** — 显示进程已运行时长（"5h ago"、"2 min ago"）
- **监控所有端口** — 底栏过滤图标一键切换，跳过所有预设和自定义过滤器，立即显示全部 TCP 监听端口；macOS 系统守护进程（ControlCenter、mDNSResponder 等）始终被隐藏
- **可配置预设** — 按工具类别开关：Node.js/npm、Vite/Webpack、Python、Ruby/Rails、Go、Java/Spring、PostgreSQL、MySQL、Redis、MongoDB、Common Dev
- **自定义端口** — 添加单个端口号或端口范围（如 `9000–9010`），每条记录独立校验
- **可调刷新间隔** — 1 秒、3 秒、5 秒、10 秒、30 秒或 60 秒
- **开机自启** — 通过 `SMAppService` 在后台保持就绪
- **英文 / 简体中文** — 在应用内切换语言（标题栏翻译按钮），独立于系统语言设置；语言偏好跨会话保留
- **轻量** — 仅驻留菜单栏，无 Dock 图标，CPU/内存占用接近零，无第三方依赖

## 环境要求

| 要求 | 说明 |
|------|------|
| macOS 13.0（Ventura）或更高版本 | `SMAppService` 开机自启 API 的最低要求 |
| Xcode 15+ | 从源码构建所需 |
| 任意 Apple ID（免费） | 用于 Xcode 本地代码签名 |

## 从源码构建

```bash
git clone https://github.com/jameswei/porta.git
cd porta
open Porta.xcodeproj
```

在 Xcode 中：
1. 工具栏选择 **Porta** scheme
2. 运行目标选择 **My Mac**
3. 按 **⌘R** 构建并运行

> **首次运行提示：** 如果 Xcode 询问签名问题，请前往 **Xcode → Settings → Accounts**，添加 Apple ID，点击 **Manage Certificates**，创建一个 *Apple Development* 证书。

## 运行已下载的 Release

如果从 GitHub Releases 下载 `.app` 后 macOS 显示 Gatekeeper 警告（因为构建未使用付费 Developer ID 签名）：

```bash
# 方式 A — 移除隔离标记
xattr -cr /path/to/Porta.app
open /path/to/Porta.app

# 方式 B — 右键点击 .app → 打开 → "仍要打开"
```

## 使用方法

1. 点击菜单栏中的插头图标，打开端口列表
2. 每张卡片显示：端口号 + 范围标识、进程名称、PID 和相对启动时间
3. 点击放大镜图标打开活动监视器（进程名称已复制到剪贴板 — 按 **⌘F** 粘贴查找）
4. 点击 **✕** 终止对应进程（需确认）
5. 点击底栏中央的过滤图标，切换**监控所有端口**模式 — 跳过预设/自定义过滤器，显示所有 TCP 监听端口
6. 点击 **⚙**（左下角）打开设置：开关预设、添加自定义端口、设置刷新频率、启用开机自启；应用版本显示在设置底部
7. 点击**翻译**图标（右上角）在英文和简体中文之间切换
8. 点击 **⏻** 或按 **⌘Q** 退出

## 架构

组件结构、关键设计决策、编码规范和测试指南详见 [`docs/architecture.md`](./docs/architecture.md)。

## 更新日志

| 版本 | 日期 | 主要内容 |
|------|------|---------|
| [v1.1.0](./CHANGELOG.md#110---2026-06-27) | 2026-06-27 | 内置简体中文、监控所有端口切换、系统进程自动屏蔽 |
| [v1.0.0](./CHANGELOG.md#100---2026-06-26) | 2026-06-26 | 首次发布 — 范围标识、相对运行时间、预设、自定义端口、28 个单元测试 |

完整更新历史见 [CHANGELOG.md](./CHANGELOG.md)。

## 许可证

MIT — 详见 [LICENSE](./LICENSE)。
