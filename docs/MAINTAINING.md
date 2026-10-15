# 维护说明

## 代码分工

根 PPTMaker.ps1 只分发日常命令；不保留兼容入口或一次性迁移清理命令。

scripts/ 只保留四个运行所需文件，日常通过根入口调用，不需要逐个执行：

| 文件 | 职责 |
| --- | --- |
| Workspace.ps1 | 环境检查、新建、导出、成品检查，以及共用路径和配置规则 |
| browser.mjs | Chromium 环境检查与预览逐页检查：溢出、图片、公式、控制台和翻页 |
| Render.ps1 | 独立子进程中的 PDF / PowerPoint 原生渲染，供 Check 使用 |
| inspect-exports.py | 导出暂存阶段修正 Slidev 内部跳转；导出与 Check 共用的完整性、页数及原生文本检查 |

成品检查属于制作演示的通用能力；截图和报告在临时目录中生成，用完删除。开发者的回归测试脚本、固定本仓库文件及哈希的提交审查脚本不随工作区分发。

共用 config/vite.ts 指向 public/，禁止构建时复制整个私人素材目录。文件服务仅允许 research-ppt 引擎范围，供主题示例读取 node_modules 内公式字体。两套主题及 New 创建的 deck 通过一行配置转接复用它；官方 demo 不需要额外配置。保留 research-ppt 引擎边界，避免改变本地既有作品的相对路径。

Get-DeckDirectory 统一解析三套内置示例与用户 deck：demo 指向 decks/demo；template-mc、template-nku 指向各主题 examples/。成品检查从主题 manifest 识别示例 ID。不要为直接预览再复制一份示例源稿。

TemplateMC 与 TemplateNKU 通过各自的 layouts/ 转接 templates/_shared/Frame.vue 与基础样式；主题颜色和 NKU 校园素材只在对应主题内声明。共享骨架修改时回归两套主题，原版 demo 的源码和成品哈希应保持不变。每套主题包含来源提交、参考 PDF 指纹、逐页布局依据和八页示例；示例成品只保留 v1.0.0 的 PDF/PPTX。

Render.ps1 是独立进程入口，不要在交互会话中直接执行或点导入。PDF 分支在全部页面和检查记录写入成功后退出，避免 WinRT 清理阶段阻塞；失败仍返回错误。日常使用根入口 Check。

## 导出事务

Export 先取得 deck 根 .export.lock，在 .export-work 准备并检查新成品，再替换 exports/v<版本>/。旧输出只在事务内暂存为 previous，发布检查失败则恢复；成功后删除临时文件。异常中断时先检查恢复 previous，不能直接删除最后一份旧成品。

Check 使用同一个锁，避免检查期间导出替换成品。暂存检查通过前，将 Slidev 的临时 localhost/print 页码链接转换为 PPTX 内部跳转；真实外部网址保持不变。没有原生文本对象的 PPTX 不通过可编辑文本检查。

export.config.json 可记录 theme、themeVersion；本地主题使用 themeId。可选 editablePostprocessor 指向 deck 内 Python 脚本，接收目标 PPTX 与 --report 参数。私人修复逻辑和依赖保持在对应 deck，不进入通用引擎。

## 检查与提交

修改脚本后，在临时工作副本验证 Doctor、New、Preview、Export、Check，覆盖非法路径、同名目录、缺失依赖、锁冲突与重导失败保护。测试副本与临时产物不进入仓库。

提交前使用 Git 审阅完整清单和暂存差异：

```powershell
git status --short
git add <已审阅的文件>
git diff --cached --name-status
git diff --cached --check
git diff --cached
```

核查私人资料、身份信息、凭据、本机绝对路径及文档链接。官方 demo、内置主题源码及已审阅素材和示例成品纳入 Git；重新导出示例时逐页审阅，并同步 .gitignore 与 README 链接。原始参考 PDF 保持本地。

正式发布前运行 `npm.cmd --prefix research-ppt audit --audit-level=high`，审阅完整依赖报告并解决影响发布的漏洞。不要自动执行 audit fix --force 或更换锁定版本；依赖调整后重新验证导出。项目许可证及模板、照片和校园素材的分发授权必须明确后，才能宣称完成开源授权。

依赖版本固定，不顺带升级。用户 deck、主题、资料和其他成品默认忽略；Git 忽略不是备份，重要材料需自行保存。

共享代码修改后验证 New、Preview、Export、Check；演示内容变动须逐页观察。测试与渲染使用临时目录，不提交截图、报告、依赖和机器配置。官方 demo 的来源在根第三方声明中，其 slides.md 应与安装包 @slidev/cli/template.md 内容一致，Counter.vue 来自同一版本的官方脚手架。

## 限制

- Windows 优先，未验证 macOS/Linux。缺少 PowerPoint 时明确跳过 PPTX 原生渲染。
- 可编辑 PPTX 中的公式、SVG 或复杂效果可能仍为图片；对象结构检查不替代视觉审阅。
- 官方 demo 使用在线图片、推文、字体及 PlantUML 服务，网络受限时可能缺失；不为离线运行改写官方稿。
- 锁定 Slidev 53 工具链曾出现 FloatingVue / Twoslash 的 Popper 控制台错误。浏览器 QA 默认失败；显式加 AllowKnownToolchainIssues 仅接受已知条目。
- 本项目授权尚未确定；保留第三方许可，不创建远程仓库或推送。
