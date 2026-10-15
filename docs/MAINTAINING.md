# 维护说明

## 代码分工

根 PPTMaker.ps1 只分发日常命令；不保留兼容入口或一次性迁移清理命令。

| 文件 | 职责 |
| --- | --- |
| Workspace.ps1 | deck ID、路径边界、配置读取与临时目录清理 |
| New-Deck.ps1 | 从官方示例或主题自带 starter 创建 deck、任务书与 QA，不覆盖已有目录 |
| Doctor.ps1 / doctor.mjs | Node、npm、Python、Git、Slidev、Chromium 和可选 PowerPoint |
| Export-Deck.ps1 | PDF 与可编辑 PPTX、并发锁、暂存检查和失败回滚 |
| Test-Exports.ps1 | 成品结构、原生渲染及可选浏览器检查，结束后删除临时文件 |
| inspect-exports.py | PDF 头尾、PPTX 页数、原生对象、ZIP 完整性与哈希 |
| Render-Pdf.ps1 / Render-PowerPoint.ps1 | Windows 原生逐页渲染；也可用于本地参考分析 |
| qa-deck.mjs | 逐页检查溢出、图片、公式、控制台与翻页 |
| Test-Workflow.ps1 | 隔离临时副本中的文件保护和导出回滚测试 |
| check-public-repo.py | Git 索引中的公开路径、敏感内容与文档链接 |

共用 config/vite.ts 指向 public/，禁止构建时复制整个私人素材目录。New 为每个新 deck 写入配置转接文件；官方 demo 不需要额外配置。保留 research-ppt 引擎边界，避免改变本地既有作品的相对路径。

TemplateMC 与 TemplateNKU 通过各自的 layouts/ 转接 templates/_shared/Frame.vue 与基础样式；主题颜色和 NKU 校园素材只在对应主题内声明。共享骨架修改时回归两套主题，原版 demo 的源码和成品哈希应保持不变。每套主题包含来源提交、参考 PDF 指纹、逐页布局依据和八页示例；示例成品只保留 v1.0.0 的 PDF/PPTX。

Render-Pdf 的 ExitAfterRendering 仅供独立子进程使用：全部页面及检查记录写入成功后退出，避免本机 WinRT 清理阶段阻塞。不要在交互会话中直接调用该开关；日常使用根入口 Check。

## 导出事务

Export 先取得 deck 根 .export.lock，在 .export-work 准备并检查新成品，再替换 exports/v<版本>/。旧输出只在事务内暂存为 previous，发布检查失败则恢复；成功后删除临时文件。异常中断时先检查恢复 previous，不能直接删除最后一份旧成品。

export.config.json 可记录 theme、themeVersion；本地主题使用 themeId。可选 editablePostprocessor 指向 deck 内 Python 脚本，接收目标 PPTX 与 --report 参数。私人修复逻辑和依赖保持在对应 deck，不进入通用引擎。

## 检查与提交

```powershell
cd research-ppt
npm.cmd test
cd ..
git add .
python -B research-ppt/scripts/check-public-repo.py
git diff --cached --stat
```

公开检查读取 Git 索引；先审阅完整跟踪清单，再提交。官方 demo、内置主题源码及其公开素材和示例成品纳入 Git，检查器固定公开二进制文件的路径与已审阅 SHA256。重新导出或更换公开版本时，先逐页审阅，再同步更新 .gitignore、PUBLIC_BINARIES 和 README 链接；其余二进制文件仍会被检查器拒绝。原始参考 PDF 保持本地，不强制暂存。

依赖版本固定，不顺带升级。用户 deck、主题、资料和其他成品默认忽略；Git 忽略不是备份，重要材料需自行保存。

共享代码修改后验证 New、Preview、Export、Check；演示内容变动须逐页观察。测试与渲染使用临时目录，不提交截图、报告、依赖和机器配置。官方 demo 的来源在根第三方声明中，其 slides.md 应与安装包 @slidev/cli/template.md 内容一致，Counter.vue 来自同一版本的官方脚手架。

## 限制

- Windows 优先，未验证 macOS/Linux。缺少 PowerPoint 时明确跳过 PPTX 原生渲染。
- 可编辑 PPTX 中的公式、SVG 或复杂效果可能仍为图片；对象结构检查不替代视觉审阅。
- 官方 demo 使用在线图片、推文、字体及 PlantUML 服务，网络受限时可能缺失；不为离线运行改写官方稿。
- 锁定 Slidev 53 工具链曾出现 FloatingVue / Twoslash 的 Popper 控制台错误。浏览器 QA 默认失败；显式加 AllowKnownToolchainIssues 仅接受已知条目。
- 本项目授权尚未确定；保留第三方许可，不创建远程仓库或推送。
