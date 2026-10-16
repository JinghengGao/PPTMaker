# PPTMaker

基于 [Slidev](https://sli.dev) 的 AI 辅助演示工作区。用 Markdown 编写内容，按 deck 管理源稿，每个版本只保存 **PDF 和可编辑 PPTX**。

Windows 优先；不内置模型 API。本项目许可证尚未确定，第三方来源与许可见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

## 快速开始

需要 Windows PowerShell 5.1、Node.js ≥22.12（建议 24 LTS）、Python 3.10+ 和 Git。PowerPoint 可选，仅用于 PPTX 原生检查；导出不要求安装 Office。在仓库根目录运行：

```powershell
cd workspace
npm.cmd ci
npx.cmd --no-install playwright install chromium
cd ..

.\PPTMaker.ps1 -Action Doctor
.\PPTMaker.ps1 -Action Preview -DeckId demo
```

打开 <http://localhost:3030>，使用方向键翻页，`Ctrl+C` 停止。

**demo 是 Slidev 53.0.0 的官方 Starter 原稿及 Counter 组件**，使用官方 Seriph 主题。在线图片、推文、字体及 PlantUML 示例需要网络，离线时可能无法完整显示。

三套内置示例均附带源稿及 v1.0.0 的 PDF、可编辑 PPTX。克隆后可直接打开成品；完成上述安装后即可预览，无需先运行 New。官方 demo 的 PDF 第 2 页渐变标题在 Windows 渲染中异常，第 6 页在线推文未显示；官方随机封面也会使两格式背景不同。源码保持原样。mc、nku 使用本地图片和字体配置，适合先体验中文演示流程。

官方 demo 的严格预览检查还会报告第 4 页装饰箭头越界、第 5 页代码块横向溢出。它用于展示官方功能，当前并未通过全部严格 QA；不会为通过检查而改写官方源稿。

## 制作自己的演示

```powershell
.\PPTMaker.ps1 -Action New -DeckId my-talk
.\PPTMaker.ps1 -Action Preview -DeckId my-talk
.\PPTMaker.ps1 -Action Export -DeckId my-talk -Version 1.0.0
.\PPTMaker.ps1 -Action Check -DeckId my-talk -Version 1.0.0
```

New 默认从官方示例创建独立副本，使用 default 主题；支持 `-Theme mc`、`-Theme nku` 或其他包含 theme/ 的示例 ID，同名目录不会覆盖。编辑 `workspace/decks/my-talk/slides.md`，任务与检查结论填写在同目录的 brief.md、QA.md；自己的素材放入 `workspace/public/decks/my-talk/`，使用 `/decks/my-talk/文件名` 引用。

Deck ID 使用小写字母、数字及连字符；版本使用 X.Y.Z。成品位于 `workspace/decks/my-talk/exports/v1.0.0/`。同版本重导成功后替换，失败保留旧成品，其他版本不动。临时截图和报告结束后删除。

demo、mc、nku 是内置示例的保留 ID；自己的作品使用其他 ID。

Check 检查成品结构并渲染 PDF；安装 PowerPoint 时还会原生渲染 PPTX。可加 `-RequirePowerPoint` 要求原生检查，或 `-PreviewUrl http://localhost:3030` 检查正在预览的全部页面。人工仍需打开最终文件逐页复核；公式、SVG 和复杂效果可能是图片，不保证所有对象可编辑。

## 三套内置示例

| 示例 ID | 特征 | 使用说明与现成文件 |
| --- | --- | --- |
| demo | Slidev 官方 Starter / Seriph，11 页 | [源稿](workspace/decks/demo/slides.md) · [PDF](workspace/decks/demo/exports/v1.0.0/demo-v1.0.0.pdf) · [PPTX](workspace/decks/demo/exports/v1.0.0/demo-v1.0.0-editable.pptx) |
| mc | TemplateMC 蓝色科研主题，8 页 | [主题说明](workspace/decks/mc/STYLE-GUIDE.md) · [PDF](workspace/decks/mc/exports/v1.0.0/mc-v1.0.0.pdf) · [PPTX](workspace/decks/mc/exports/v1.0.0/mc-v1.0.0-editable.pptx) |
| nku | TemplateNKU 南开紫及原版校徽、建筑，8 页 | [主题说明](workspace/decks/nku/STYLE-GUIDE.md) · [PDF](workspace/decks/nku/exports/v1.0.0/nku-v1.0.0.pdf) · [PPTX](workspace/decks/nku/exports/v1.0.0/nku-v1.0.0-editable.pptx) |

可直接选择任意示例运行；切换前用 Ctrl+C 停止当前预览：

```powershell
.\PPTMaker.ps1 -Action Preview -DeckId demo
.\PPTMaker.ps1 -Action Preview -DeckId mc
.\PPTMaker.ps1 -Action Preview -DeckId nku
```

三套示例同样支持 Export 和 Check，例如：

```powershell
.\PPTMaker.ps1 -Action Export -DeckId mc -Version 1.1.0
.\PPTMaker.ps1 -Action Check -DeckId mc -Version 1.1.0
```

demo、mc、nku 并列保存在 decks/，每套的源稿、素材和成品都在自己的目录。制作自己的演示时再运行 New：

```powershell
.\PPTMaker.ps1 -Action New -DeckId mc-talk -Theme mc
.\PPTMaker.ps1 -Action New -DeckId nku-talk -Theme nku
```

New 会复制对应主题的示例与所需图片，主题仍引用来源示例的 theme/。普通页面用 `heading` 设置顶部标题；目录用 `agenda` 数组和 `active` 设置当前条目。NKU 支持 `agendaStyle: tiles` 或 `list`。MC、NKU 的配色、布局和品牌素材保存在各自 theme/ 内，共同页面骨架在 shared/；迁移作品时保留这些依赖目录。上游来源与素材权利见第三方声明。

## 仓库结构

```text
PPTMaker.ps1                    日常入口：Doctor / New / Preview / Export / Check
README.md / AGENTS.md           使用说明与 AI 工作约定
docs/                          创作流程与维护说明
workspace/
  package.json / package-lock.json
  config/vite.ts               共用素材路径、文件访问范围和构建规则
  scripts/
    Workflow.ps1               环境、新建、导出及检查流程
    check-browser.mjs          Chromium 环境与逐页预览检查
    Render-Exports.ps1         PDF / PowerPoint 原生渲染
    inspect_exports.py         PDF / PPTX 结构与可编辑文本检查
  decks/
    demo/                      官方源稿、Counter 及 PDF/PPTX
    mc/                        slides.md、assets/、theme/、exports/
    nku/                       slides.md、assets/、theme/、exports/
  shared/                      MC、NKU 共用的页面骨架和基础样式
```

根目录提供使用入口和说明；workspace/ 集中管理 Slidev 依赖、演示与运行工具。在该目录执行 `npm.cmd ci`，即可安装锁定版本的 Slidev。config/vite.ts 供 mc、nku 和新建作品复用：统一 public/ 素材路径，允许读取工作区内的公式字体，并防止构建时复制整个私人素材目录。

官方 demo、两套内置主题及其已审阅素材和示例成品纳入 Git；自己的 deck、素材（public/）、参考材料（根 references/）和其他成品默认忽略，按需创建。每套演示直接使用自己的 slides.md，工程根目录没有重复源稿。依赖通过 npm 安装，本机 Skills 不随仓库分发。

[创作流程与 AI 提示词](docs/WORKFLOW.md) · [维护与验证](docs/MAINTAINING.md)

## 常见问题

- **脚本执行策略阻止运行**：确认代码可信后，使用 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\PPTMaker.ps1` 加相应参数。
- **修改 SVG 后未更新**：停止并重新启动 Preview。
- **异常中断留下 .export.lock 或 .export-work**：确认导出已停止；若工作目录中有 previous，先恢复旧成品，再清理。
- **浏览器 QA 报 FloatingVue / Popper 错误**：上游 Twoslash 与 FloatingVue 的兼容问题，影响拖动选择代码时的提示框增强。依赖捕获错误后继续运行，浏览器 QA 默认仍判失败。确认接受该问题时显式加 `-AllowKnownToolchainIssues`，只允许这条已知错误，不表示问题已修复。
