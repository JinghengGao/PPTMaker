# PPTMaker

基于 [Slidev](https://sli.dev) 的 AI 辅助科研演示工作区。每套演示有独立源稿，每个版本只保留 **PDF 和可编辑 PPTX**。

项目提供工作流程与命令工具，不内置模型 API。优先支持 Windows，本项目许可证尚未选择，第三方依赖遵循 [各自许可](THIRD_PARTY_NOTICES.md)。

## 开始使用

需要 Windows PowerShell 5.1、Node.js ≥22.12（建议 24 LTS）、Python 3.10+ 和 Git。在项目根目录运行：

```powershell
Push-Location research-ppt
npm.cmd ci
npx.cmd --no-install playwright install chromium
Pop-Location

powershell.exe -NoProfile -File .\PPTMaker.ps1 -Action Doctor
powershell.exe -NoProfile -File .\PPTMaker.ps1 -Action Preview -DeckId demo
```

打开 <http://localhost:3030>，方向键翻页，`Ctrl+C` 停止。所有命令直接使用对应 deck 的源稿。

## 新建、编辑与导出

```powershell
powershell.exe -NoProfile -File .\PPTMaker.ps1 -Action New -DeckId my-talk
powershell.exe -NoProfile -File .\PPTMaker.ps1 -Action Preview -DeckId my-talk
powershell.exe -NoProfile -File .\PPTMaker.ps1 -Action Export -DeckId my-talk -Version 1.0.0
powershell.exe -NoProfile -File .\PPTMaker.ps1 -Action Check -DeckId my-talk -Version 1.0.0
```

编辑该 deck 的 brief.md、slides.md 与 QA.md；新建内容是待替换的示例，不是真实研究结果。New 默认使用官方 default 主题，也可传 `-Theme <本地主题ID>`。同名 deck 不会覆盖。

Deck ID 使用小写字母、数字和连字符，版本使用 X.Y.Z。**每个版本保留一对成品**；重复导出同一版本会在检查成功后替换这一版，失败时保留原成品，其他版本不受影响。无需额外的重导开关。

Check 会实际渲染 PDF，有 PowerPoint 时还会渲染可编辑 PPTX；加 `-RequirePowerPoint` 可要求必须完成 PPTX 原生检查。临时截图和检查文件结束后自动删除，人工打开最终成品复核布局即可。可编辑版的 SVG、公式等仍可能是图片，不保证所有对象都能原生编辑。

## 目录

```text
PPTMaker/
├─ PPTMaker.ps1                     # 唯一日常入口
├─ docs/                            # 创作、维护和验证说明
├─ references/                      # 本地参考原件与风格依据
├─ _local/notes/                    # 本地私人笔记
└─ research-ppt/
   ├─ config/                      # 共用资源配置
   ├─ scripts/                     # 创建、导出和检查工具
   ├─ templates/                   # 本地主题及创建规范
   ├─ public/decks/<id>/            # 对应演示仍需使用的素材
   └─ decks/<id>/
      ├─ brief.md / slides.md / QA.md
      ├─ export.config.json / vite.config.ts
      └─ exports/
         ├─ v1.0.0/                # PDF + 可编辑 PPTX
         └─ v1.1.0/                # PDF + 可编辑 PPTX
```

源稿始终是各 deck 内的 slides.md；工程根目录不再放重复入口。主题、来源材料及必要的导出修复代码保留；不自动生成普通 PPTX、HTML、ZIP、截图历史、日志历史、输入快照或重导归档。

## 清理已有历史产物

先停止预览与导出，再预览清理范围；加 Apply 才实际删除。每版 PDF、可编辑 PPTX、当前源稿、主题和原始资料保留。

```powershell
powershell.exe -NoProfile -File .\PPTMaker.ps1 -Action Clean
powershell.exe -NoProfile -File .\PPTMaker.ps1 -Action Clean -Apply
```

清理旧截图、快照、归档、测试副本、普通 PPTX，以及不属于当前导出依赖的旧一次性工具。私人笔记和必要的第三方运行库不会删除。

## AI 创作与 Git

[创作流程](docs/WORKFLOW.md) · [提示词](docs/PROMPTS.md) · [维护说明](docs/MAINTAINING.md) · [验证记录](docs/VALIDATION.md)

公开 Git 只跟踪工具、文档、规范与 demo。私人参考、其他 deck、主题、素材和输出默认不进入 Git，需自行备份重要研究材料。提交前检查暂存内容：

```powershell
git add .
python research-ppt/scripts/check-public-repo.py
git diff --cached --stat
```

## 常见问题

- **脚本被策略阻止**：确认可信后，为单次 powershell.exe 调用加 `-ExecutionPolicy Bypass`。
- **修改 SVG 后仍显示旧图**：停止并重新启动 Preview，清除 Slidev 的内联素材缓存。
- **异常退出留下锁或 .export-work**：确认没有导出进程后检查该目录；若包含 previous，先恢复原成品，再清理。正常成功或失败不会保留这些文件。
- **缺少 PowerPoint**：仍可导出，但 Check 明确跳过 PPTX 原生渲染。
- **已知工具链报错**：当前锁定版本的 FloatingVue 兼容报错默认使浏览器 QA 失败；需要接受已知条目时显式添加 `-AllowKnownToolchainIssues`，详见验证记录。
