# 维护与发布准备

## 架构

根 PPTMaker.ps1 只分发操作。Workspace.ps1 共用 ID、路径和配置读取；New-Deck 创建独立目录；config/vite.ts 相对自身定位资源，避免每个新 deck 重复配置。旧私人 deck 继续使用原配置。

Export-Deck 是唯一导出实现：预检、独占锁、输入快照、暂存三种文件、结构检查、归档旧版、发布。准备失败时旧成品不动，日志留在本次运行目录。快照记录源稿、资源、锁文件、本地主题及共享配置；不自动提供历史恢复命令。

export.config.json 最小配置是 `theme: default` 与 `pptxPerSlide: true`。本地主题使用 themeId 和 themeVersion。editablePostprocessor 指向 deck 内的 Python 修复脚本，接收 PPTX 路径和 --report 参数。额外输入通过 snapshotIncludes 列出 deck 内路径；Python 依赖与运行条件由该 deck 记录，不默认打包第三方库。

Check 分别记录结构检查、PDF 渲染、PPTX 原生渲染和可选浏览器检查，跳过不等于通过。普通导出不要求 PowerPoint，但某些私人 hook 可能依赖它，须由该 deck 说明。人工视觉审核独立记录。

## 回归

```powershell
Push-Location research-ppt
npm.cmd test
Pop-Location
python research-ppt/scripts/check-public-repo.py
```

Test-Workflow 在 _local/tests 的隔离副本验证创建保护、路径、缺失依赖、锁、版本冲突及失败重导保护，不改私人作品。完整验收需按根 README 实际预览、逐页截图和三格式导出。

修改公共代码后，在仅含 Git 跟踪文件的干净副本运行 npm.cmd ci 和完整流程，不复制 node_modules、Skills 或私人模板。新增依赖需审查锁文件，不执行破坏性升级。

## Git 与发布

根目录只维护一个 Git 仓库。用户新 deck 默认忽略，需单独备份。公开新示例前确认素材权限、清理个人信息，并同步修改 .gitignore 与 check-public-repo.py 白名单。

检查器读取 Git 索引，提交前重新暂存改动再检查，人工审阅 git diff --cached。不要对私人目录使用 git add -f。当前暂不添加本项目许可证，不创建远程仓库或推送；正式开源发布前需明确授权。

## 清理恢复

_local/cleanup-backups/<时间> 保存原文件清单与 SHA256、files 备份、清理动作和恢复说明。按原相对路径选择恢复，核对哈希，不覆盖后续新工作。私人 deck、模板、参考原件和历史交付物保持原路径。
