# PPTMaker

基于 [Slidev](https://sli.dev) 的 AI 辅助科研演示工作区。使用 Markdown、Vue 和本地主题制作演示，按版本导出 PDF、普通 PPTX 与部分可编辑 PPTX，保留源稿快照与检查记录。

这是可复用的工作区和命令工具，需要你与 AI 代理共同准备内容、审核页面，不内置模型 API。目前优先支持 Windows。**本项目尚未选择许可证，暂不构成完整的开源授权**；第三方依赖遵循各自许可，见 [第三方声明](THIRD_PARTY_NOTICES.md)。

## 快速开始

需要 Windows PowerShell 5.1、Node.js ≥22.12（建议 24 LTS）、npm、Python 3.10+ 和 Git。Chromium 由 Playwright 安装；PowerPoint 仅用于可选的 PPTX 原生打开与渲染检查。

在克隆后的项目根目录打开 PowerShell：

```powershell
Push-Location .\research-ppt
npm.cmd ci
npx.cmd --no-install playwright install chromium
Pop-Location

powershell.exe -NoProfile -File .\PPTMaker.ps1 -Action Doctor
powershell.exe -NoProfile -File .\PPTMaker.ps1 -Action Preview -DeckId demo
```

打开 <http://localhost:3030>，用方向键翻页，`Ctrl+C` 停止预览。示例共 5 页，包含中文、本地图片、表格和公式，数值均为演示数据。在另一个终端导出并检查：

```powershell
powershell.exe -NoProfile -File .\PPTMaker.ps1 -Action Export -DeckId demo -Version 1.0.0
powershell.exe -NoProfile -File .\PPTMaker.ps1 -Action Check -DeckId demo -Version 1.0.0 -PreviewUrl http://localhost:3030 -AllowKnownToolchainIssues
```

检查会渲染 PDF；安装 PowerPoint 时还会打开并渲染两种 PPTX。缺少 PowerPoint 时明确记录跳过，不代表 PPTX 视觉检查通过。要求必须完成原生检查时添加 `-RequirePowerPoint`。自动检查后仍须逐页查看截图。

## 制作自己的演示

```powershell
powershell.exe -NoProfile -File .\PPTMaker.ps1 -Action New -DeckId my-talk
powershell.exe -NoProfile -File .\PPTMaker.ps1 -Action Preview -DeckId my-talk -Port 3031
```

编辑 `research-ppt/decks/my-talk/brief.md`、`slides.md` 与 `QA.md`，素材放入 `research-ppt/public/decks/my-talk/`。新建命令复制可运行示例，请替换示例文字和数值。已有同名项目或素材目录时停止，不覆盖。

默认使用官方 `default` 主题。若已安装完整本地主题，创建时传入 `-Theme <主题ID>`。私人主题不随公开工程分发，新用户无需这些主题即可使用示例。参考学习与提示词见 [创作流程](docs/WORKFLOW.md) 和 [常用提示词](docs/PROMPTS.md)。

## 常用命令

| 操作 | 参数 |
| --- | --- |
| 检查环境 | `-Action Doctor` |
| 新建 | `-Action New -DeckId my-talk [-Theme local-theme-id]` |
| 预览 | `-Action Preview -DeckId my-talk [-Port 3030]` |
| 导出新版本 | `-Action Export -DeckId my-talk -Version 1.0.0` |
| 重导已有版本 | 上述导出命令追加 `-Rebuild` |
| 检查成品 | `-Action Check -DeckId my-talk -Version 1.0.0` |

参数传给根目录 `PPTMaker.ps1`。Deck ID 使用小写字母、数字和连字符，版本使用 `X.Y.Z`。版本号只标记当前源稿的输出，不会加载历史源稿。旧 `Export-PPT.ps1` 仍可使用，但必须显式传入 Deck ID 和版本。

## 目录与交付

```text
PPTMaker/
├─ PPTMaker.ps1                 # 日常统一入口
├─ docs/                        # 创作、维护和验证说明
├─ references/inbox/            # 用户参考 PPT，本地保留
├─ _local/                      # 本地笔记、整理备份与测试记录
└─ research-ppt/
   ├─ config/                   # 新 deck 共用 Vite 配置
   ├─ scripts/                  # 生成、导出、渲染与检查
   ├─ templates/                # _template 规范和用户本地主题
   ├─ public/decks/<id>/        # 按 deck 隔离的素材
   └─ decks/<id>/
      ├─ brief.md / slides.md / QA.md
      ├─ exports/v<版本>/        # 三份成品
      ├─ screenshots/v<版本>/    # 检查截图与导出日志
      ├─ versions/v<版本>/       # 每次导出的输入快照
      └─ archive/               # 重导前保留的旧成品
```

| 格式 | 能力与限制 |
| --- | --- |
| PDF | 阅读、提交和投影 |
| 普通 PPTX | 整页图片，优先保持外观，文字不能逐字编辑 |
| `-editable.pptx` | 部分文字、色块等是原生对象；SVG、公式和复杂效果可能仍是图片，换行需要复核 |

三种格式按源幻灯片导出，不展开点击动画。失败时保留原成品；`-Rebuild` 在新成品准备并检查成功后归档旧版。长期源稿始终是各 deck 的 `slides.md`，PowerPoint 中的修改不会回写 Markdown。不默认生成 HTML 或 ZIP。

## Git 与本地材料

公开 Git 默认只跟踪工具、文档、目录规范和 `demo`。参考文件、新建 deck、私人模板、素材、成品、截图、历史版本、本机 Skills 及 `_local` 默认忽略，依然保留在磁盘上。**忽略的文件不会由 Git 备份，请另行备份研究材料。** 不要把整个工作目录打 ZIP 公开。

准备提交时检查暂存区：

```powershell
git add .
python .\research-ppt\scripts\check-public-repo.py
git diff --cached --stat
```

检查器审查 Git 索引中的路径、敏感模式和本地文档链接，不能代替人工核对材料权限。公开其他示例时需同时调整忽略规则与检查器白名单。回归与维护见 [维护说明](docs/MAINTAINING.md)，实测范围见 [验证记录](docs/VALIDATION.md)。

## 常见问题

- **脚本被策略阻止**：确认可信后，在单次 `powershell.exe` 调用中添加 `-ExecutionPolicy Bypass`，无需修改系统策略。
- **Chromium 下载失败**：检查网络后在 `research-ppt` 运行 `npx.cmd --no-install playwright install chromium`，再跑 Doctor。
- **版本已存在**：换新版本号，或加 `-Rebuild` 归档旧成品后重导。
- **导出失败**：查看该 deck 的 `screenshots/v<版本>/export-runs/<时间>/export.log` 和 `failure.json`。
- **遗留导出锁**：确认没有相关导出进程后，才手动移除该 deck 的 `.export.lock`。
- **字体或可编辑版换行不同**：工程不分发字体，接收方需安装对应字体，并单独检查可编辑 PPTX。

当前锁定的 Slidev 53 工具链存在已复现的 FloatingVue / Twoslash 控制台兼容报错。默认浏览器 QA 严格失败；上述快速检查命令显式使用 `-AllowKnownToolchainIssues`，仅接受报告中匹配该已知错误的条目，仍保留完整错误并标记为带已知问题通过。其他错误仍失败，详细影响见验证记录。示例关闭 wakeLock，避免无头浏览器锁屏权限错误。
