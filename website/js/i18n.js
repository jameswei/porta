const translations = {
  en: {
    pageTitle:      "Porta — Manage listening ports on macOS",
    metaDesc:       "A lightweight macOS menu-bar app for inspecting and stopping TCP listening ports, with scope and process-age indicators.",
    navAbout:       "About",
    navScreenshots: "Screenshots",
    navCapabilities:"Features",
    navStack:       "Stack",
    navCli:         "Install",
    heroBadge:      "macOS 13+ · Zero Dependencies · Free",
    heroTagline:    "See and manage listening ports<br class=\"br-desktop\" /> right from your menu bar.",
    heroSub:        "Porta shows the process behind each TCP listener, how it is exposed, and how long it has been running. Inspect it in Activity Monitor or stop it safely in one click.",
    heroCtaPrimary: "View on GitHub",
    heroCtaSecondary:"Learn more ↓",
    aboutTitle:     "Why Porta?",
    aboutP1:        "Web servers, databases, background jobs, and desktop apps can all open TCP ports. When a listener is forgotten or causes a conflict, finding its owning process should not require a trip through the terminal.",
    aboutP2:        "Porta sits quietly in your macOS menu bar, continuously running <code>lsof -iTCP -sTCP:LISTEN</code> on a configurable timer. Separate IPv4 and IPv6 entries for the same process are coalesced into a single row — no duplicates, no noise. Just a clean list of what's running and a single click to stop it.",
    aboutP3:        "Lightweight by design: no Dock icon, near-zero CPU and memory usage, and zero third-party dependencies. Built with Swift and SwiftUI, it works entirely through standard macOS APIs.",
    aboutCta:       "Explore the source on GitHub →",
    stat1:          "Third-party dependencies",
    stat2:          "Preset tool categories",
    stat3:          "Refresh intervals",
    stat4:          "Unit tests",
    screenshotsTitle: "See it in action",
    screenshotsSub:   "A minimal, focused UI — everything you need, nothing you don't.",
    screenshot1Title: "Port List · Light",
    screenshot1Desc:  "Scope, process age, process name, and PID — all at a glance.",
    screenshotDarkTitle:"Port List · Dark",
    screenshotDarkDesc: "Automatically follows the macOS Light, Dark, or Auto appearance.",
    screenshot2Title: "Settings",
    screenshot2Desc:  "Toggle presets, add custom ports or ranges, set refresh rate, enable launch at login.",
    capTitle:       "Features",
    capSub:         "Everything you need to understand and manage listening ports.",
    cap1Title:      "Detect Listening Ports",
    cap1Desc:       "Powered by <code>lsof</code>, surfaces matching TCP LISTEN-state ports and their owning processes. Updated at your chosen refresh interval.",
    cap2Title:      "Kill with One Click",
    cap2Desc:       "Re-verifies the PID still owns the port before acting. Sends SIGTERM, waits 2 seconds, then escalates to SIGKILL if the process persists.",
    cap3Title:      "Scope Badge",
    cap3Desc:       "Each port shows <strong>local</strong> (localhost-only) or <strong>public</strong> (all interfaces) so you know your exposure at a glance.",
    cap4Title:      "Color-Coded Process Age",
    cap4Desc:       "Age pills move from green to amber to red as a process runs longer, making potentially stale listeners easy to spot.",
    cap5Title:      "Configurable Presets",
    cap5Desc:       "11 tool categories to toggle: Node.js/npm, Vite/Webpack, Python, Ruby/Rails, Go, Java/Spring, PostgreSQL, MySQL, Redis, MongoDB, and more.",
    cap6Title:      "Custom Ports & Ranges",
    cap6Desc:       "Add individual port numbers or ranges (e.g. <code>9000–9010</code>) with per-entry validation. Flexible enough for any workflow.",
    cap7Title:      "Monitor All Ports",
    cap7Desc:       "One-tap toggle in the footer bypasses all preset and custom filters, showing every TCP LISTEN port instantly. macOS system daemons are always hidden.",
    cap8Title:      "Bilingual UI",
    cap8Desc:       "Switch between English and Simplified Chinese with a single tap. Language preference is remembered across sessions, independent of your OS locale.",
    cap9Title:      "Native macOS Experience",
    cap9Desc:       "A dedicated app icon, automatic Light/Dark appearance, launch at login, and a menu-bar-only design that stays out of your way.",
    stackTitle:     "Tech Stack",
    stackSub:       "Built on macOS-native APIs. No framework overhead.",
    stackLang:      "Language",
    stackPlatform:  "Platform",
    stackUi:        "UI Framework",
    stackDetection: "Port Detection",
    stackPersistence:"Persistence",
    stackDeps:      "Dependencies",
    stackLogin:     "Login Item",
    cliTitle:       "Build from Source",
    cliSub:         "Requires Xcode 15+ and any Apple ID (free) for local signing. CI runs 28 unit tests on every push.",
    cliDocsLink:    "Full build instructions on GitHub →",
    ctaTitle:       "Interested in the source?",
    ctaDesc:        "Porta is open-source under the MIT license. Star it, fork it, or open an issue.",
    ctaBtn:         "View on GitHub",
    footerBuilt:    'Built by <a href="https://www.linkedin.com/in/jamesweipek/" target="_blank" rel="noopener">James Wei</a>',
    footerGithub:   "GitHub Profile",
    footerRepo:     "Repository",
    footerLicense:  "MIT License",
  },

  zh: {
    pageTitle:      "Porta — 在 macOS 上管理监听端口",
    metaDesc:       "一款轻量级 macOS 菜单栏应用，用于检查和停止 TCP 监听端口，并显示暴露范围与进程运行时长。",
    navAbout:       "关于",
    navScreenshots: "截图",
    navCapabilities:"功能",
    navStack:       "技术栈",
    navCli:         "安装",
    heroBadge:      "macOS 13+ · 零第三方依赖 · 免费",
    heroTagline:    "直接在菜单栏查看和管理监听端口。",
    heroSub:        "Porta 显示每个 TCP 监听端口的所属进程、暴露范围和运行时长。你可以在活动监视器中检查它，或一键安全停止对应进程。",
    heroCtaPrimary: "在 GitHub 上查看",
    heroCtaSecondary:"了解更多 ↓",
    aboutTitle:     "为什么需要 Porta？",
    aboutP1:        "Web 服务器、数据库、后台任务和桌面应用都可能打开 TCP 端口。当监听进程被遗忘或引发端口冲突时，你不该必须打开终端才能找到它的所属进程。",
    aboutP2:        "Porta 安静地待在 macOS 菜单栏，按可配置的间隔持续运行 <code>lsof -iTCP -sTCP:LISTEN</code>。同一进程的 IPv4 和 IPv6 条目会自动合并为一行——无重复，无噪音。只需一个清晰的列表，一键停止目标进程。",
    aboutP3:        "设计上追求轻量：无 Dock 图标，CPU 和内存占用接近零，零第三方依赖。基于 Swift 和 SwiftUI 构建，完全通过标准 macOS API 运行。",
    aboutCta:       "在 GitHub 上查看源码 →",
    stat1:          "零第三方依赖",
    stat2:          "预设工具类别",
    stat3:          "可配置刷新间隔",
    stat4:          "单元测试",
    screenshotsTitle: "实际效果",
    screenshotsSub:   "极简专注的界面——你需要的一切，仅此而已。",
    screenshot1Title: "端口列表 · 浅色",
    screenshot1Desc:  "暴露范围、进程时长、进程名称和 PID——一目了然。",
    screenshotDarkTitle:"端口列表 · 深色",
    screenshotDarkDesc: "自动跟随 macOS 的浅色、深色或自动外观。",
    screenshot2Title: "设置",
    screenshot2Desc:  "开关预设、添加自定义端口或范围、设置刷新频率、启用开机自启。",
    capTitle:       "功能特性",
    capSub:         "理解和管理监听端口所需的一切。",
    cap1Title:      "检测监听端口",
    cap1Desc:       "由 <code>lsof</code> 驱动，展示匹配的 TCP LISTEN 状态端口及其所属进程，并按设定的刷新间隔自动更新。",
    cap2Title:      "一键终止",
    cap2Desc:       "终止前重新验证 PID 仍然持有该端口。发送 SIGTERM，等待 2 秒，若进程仍存在则升级为 SIGKILL。",
    cap3Title:      "暴露范围标识",
    cap3Desc:       "每个端口显示 <strong>local</strong>（仅本机）或 <strong>public</strong>（所有接口），一眼看清暴露范围。",
    cap4Title:      "彩色进程时长标识",
    cap4Desc:       "随着进程运行时间增长，时长标签由绿色变为琥珀色再到红色，帮助快速发现可能已闲置的监听进程。",
    cap5Title:      "可配置预设",
    cap5Desc:       "11 个工具类别可按需开关：Node.js/npm、Vite/Webpack、Python、Ruby/Rails、Go、Java/Spring、PostgreSQL、MySQL、Redis、MongoDB 等。",
    cap6Title:      "自定义端口和范围",
    cap6Desc:       "支持添加单个端口号或端口范围（如 <code>9000–9010</code>），每条记录独立校验，灵活适配任意工作流。",
    cap7Title:      "监控所有端口",
    cap7Desc:       "底栏一键切换，跳过所有预设和自定义过滤器，立即显示全部 TCP 监听端口。macOS 系统进程始终被隐藏。",
    cap8Title:      "双语界面",
    cap8Desc:       "一键切换英文和简体中文，语言偏好跨会话保留，与系统语言设置完全独立。",
    cap9Title:      "原生 macOS 体验",
    cap9Desc:       "专属应用图标、自动浅色/深色外观、开机自启，以及不打扰工作的纯菜单栏设计。",
    stackTitle:     "技术栈",
    stackSub:       "基于 macOS 原生 API 构建，无框架负担。",
    stackLang:      "语言",
    stackPlatform:  "平台",
    stackUi:        "UI 框架",
    stackDetection: "端口检测",
    stackPersistence:"持久化",
    stackDeps:      "依赖",
    stackLogin:     "开机启动",
    cliTitle:       "从源码构建",
    cliSub:         "需要 Xcode 15+ 和任意 Apple ID（免费）用于本地签名。CI 在每次推送时运行 28 个单元测试。",
    cliDocsLink:    "在 GitHub 上查看完整构建说明 →",
    ctaTitle:       "对源码感兴趣？",
    ctaDesc:        "Porta 基于 MIT 许可证开源。欢迎 Star、Fork 或提 Issue。",
    ctaBtn:         "在 GitHub 上查看",
    footerBuilt:    '由 <a href="https://www.linkedin.com/in/jamesweipek/" target="_blank" rel="noopener">James Wei</a> 构建',
    footerGithub:   "GitHub 主页",
    footerRepo:     "代码仓库",
    footerLicense:  "MIT 许可证",
  },
};

let currentLang = localStorage.getItem("porta-lang") || "en";

function setLanguage(lang) {
  currentLang = lang;
  localStorage.setItem("porta-lang", lang);
  document.documentElement.lang = lang;

  const t = translations[lang];

  document.title = t.pageTitle;

  const metaDesc = document.querySelector('meta[name="description"]');
  if (metaDesc) metaDesc.setAttribute("content", t.metaDesc);

  document.querySelectorAll("[data-i18n]").forEach(el => {
    const key = el.getAttribute("data-i18n");
    if (t[key] !== undefined) el.textContent = t[key];
  });

  document.querySelectorAll("[data-i18n-html]").forEach(el => {
    const key = el.getAttribute("data-i18n-html");
    if (t[key] !== undefined) el.innerHTML = t[key];
  });

  const toggle = document.getElementById("lang-toggle");
  if (toggle) toggle.textContent = lang === "en" ? "中文" : "English";
}

function toggleLanguage() {
  setLanguage(currentLang === "en" ? "zh" : "en");
}

setLanguage(currentLang);
