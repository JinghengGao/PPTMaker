# PPTMaker

基于 [Slidev](https://sli.dev) 的 AI 辅助演示工作区。用 Markdown 编写内容，按 deck 管理源稿，每个版本只保存 **PDF 和可编辑 PPTX**。

Windows 优先；不内置模型 API。本项目许可证尚未确定，第三方来源与许可见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

## 快速开始

需要 Windows PowerShell 5.1、Node.js ≥22.12（建议 24 LTS）、Python 3.10+ 和 Git。在仓库根目录运行：

```powershell
cd research-ppt
npm.cmd ci
npx.cmd --no-install playwright install chromium
cd ..

.\PPTMaker.ps1 -Action Doctor
.\PPTMaker.ps1 -Action Preview -DeckId demo
```

打开 <http://localhost:3030>，使用方向键翻页，`Ctrl+C` 停止。

**demo 是 Slidev 53.0.0 的官方 Starter 原稿及 Counter 组件**，使用官方 Seriph 主题。在线图片、推文、字体及 PlantUML 示例需要网络，离线时可能无法完整显示。

仓库附带 v1.0.0 的 [PDF](research-ppt/decks/demo/exports/v1.0.0/demo-v1.0.0.pdf) 和 [可编辑 PPTX](research-ppt/decks/demo/exports/v1.0.0/demo-v1.0.0-editable.pptx)，克隆后可直接打开。该版 PDF 的第 2 页渐变标题在 Windows 渲染中异常，第 6 页在线推文未显示；官方随机封面也会使两格式背景不同。源码保持原样。

## 制作自己的演示

```powershell
.\PPTMaker.ps1 -Action New -DeckId my-talk
.\PPTMaker.ps1 -Action Preview -DeckId my-talk
.\PPTMaker.ps1 -Action Export -DeckId my-talk -Version 1.0.0
.\PPTMaker.ps1 -Action Check -DeckId my-talk -Version 1.0.0
```

New 从官方示例创建独立副本，默认使用 default 主题；支持 `-Theme <本地主题ID>`，同名目录不会覆盖。编辑该 deck 的 slides.md，任务与检查结论填写在 brief.md、QA.md；自己的素材放入 public/decks/my-talk/，使用 `/decks/my-talk/文件名` 引用。

Deck ID 使用小写字母、数字及连字符；版本使用 X.Y.Z。成品位于 `research-ppt/decks/my-talk/exports/v1.0.0/`。同版本重导成功后替换，失败保留旧成品，其他版本不动。临时截图和报告结束后删除。

Check 检查成品结构并渲染 PDF；安装 PowerPoint 时还会原生渲染 PPTX。可加 `-RequirePowerPoint` 要求原生检查，或 `-PreviewUrl http://localhost:3030` 检查正在预览的全部页面。人工仍需打开最终文件逐页复核；公式、SVG 和复杂效果可能是图片，不保证所有对象可编辑。

## 仓库结构

```text
PPTMaker.ps1                    日常入口：Doctor / New / Preview / Export / Check
README.md / AGENTS.md           使用说明与 AI 工作约定
docs/                          创作流程与维护说明
research-ppt/
  package.json / package-lock.json
  config/vite.ts               共用静态资源配置
  scripts/                     新建、导出、检查及回归测试
  decks/demo/                  官方源稿、Counter 及 v1.0.0 的 PDF/PPTX
```

demo 源码及上述两份成品纳入 Git；自己的 deck、本地主题（templates/）、素材（public/）、参考材料（根 references/）和其他成品默认忽略，按需创建。每套演示直接使用自己的 slides.md，工程根目录没有重复源稿。依赖通过 npm 安装，本机 Skills 不随仓库分发。

[创作流程与 AI 提示词](docs/WORKFLOW.md) · [维护与验证](docs/MAINTAINING.md)

## 常见问题

- **脚本执行策略阻止运行**：确认代码可信后，使用 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\PPTMaker.ps1` 加相应参数。
- **修改 SVG 后未更新**：停止并重新启动 Preview。
- **异常中断留下 .export.lock 或 .export-work**：确认导出已停止；若工作目录中有 previous，先恢复旧成品，再清理。
- **浏览器 QA 报 FloatingVue / Popper 错误**：锁定工具链的已知兼容问题，默认检查失败。确认接受该问题时显式加 `-AllowKnownToolchainIssues`，不会放行其他错误。
