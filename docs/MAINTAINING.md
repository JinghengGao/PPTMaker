# 维护说明

## 实现边界

PPTMaker.ps1 分发 Doctor/New/Preview/Export/Check。Workspace.ps1 提供 ID、路径和安全清理；New-Deck 创建独立目录；config/vite.ts 为 deck 提供共享资源配置。

所有命令直接运行 decks/<id>/slides.md，不保留引擎根 slides.md 或根 Vite 转发。依赖版本固定在 package.json 与锁文件中，不盲目升级。

## 每版两份成品

Export-Deck 只生成 PDF 与可编辑 PPTX，放在 exports/v<版本>/。同版本可直接重导，其他版本不动。

导出时先获得 deck 锁，在 .export-work 准备并检查新成品。替换过程中原输出暂存于 previous；发布校验失败则恢复，成功后删除临时内容。不保存运行日志、输入快照、截图和重导历史。异常中断留下的 previous 必须先检查恢复，不能直接删除。

export.config.json 默认只声明 theme 与 themeVersion。本地主题使用 themeId。editablePostprocessor 可指向 deck 内的 Python 脚本，接收目标 PPTX 与 --report 参数；修复报告及副本只存在于临时工作目录。该脚本所需的原始输入与依赖应保存在当前 deck，不放到历史目录。

Check 在系统临时目录完成结构检查、PDF 渲染及可选 PPTX/浏览器检查，最后自动删除临时文件。缺少 PowerPoint 或未请求浏览器检查时明确说明，不冒称通过。人工审阅直接打开成品。

## 检查与发布

```powershell
Push-Location research-ppt
npm.cmd test
Pop-Location
python research-ppt/scripts/check-public-repo.py
```

文件保护测试使用临时副本，结束后清理。共享代码变更后应验证示例的实际预览和两格式导出；排版变更还要逐页查看临时截图，验收后删除。

公开检查器读取 Git 索引。私人内容默认忽略，禁止强制暂存；公开新示例时同步调整忽略规则与检查器白名单。当前不添加项目许可证、不建立远程仓库或推送。

## 清理旧工作区

根入口 Clean 默认只列出生成物清单，Apply 才删除。删除前检查范围、链接和活动导出进程；逐个删除文件，仅删除已空的目录。保留所有版本的 PDF/可编辑 PPTX、源稿、素材、当前 hook 及其同目录依赖、第三方运行库和私人笔记。
