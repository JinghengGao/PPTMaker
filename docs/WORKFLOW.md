# 科研演示创作流程

## 任务书与资料

用 New 创建 deck，填写 brief 中的受众、核心观点、主题及版本、来源和交付要求。长期源稿与 QA 保存在同一 deck，素材进入同 ID 的 public/decks 目录。新内容和本地主题默认不进入公开 Git。

## 从参考创建主题

1. 发现 references/inbox 中的真实文件名，建立唯一参考归档；复制原件并记录哈希，不改原件。
2. 检查实际页数、画布比例、主题和内容分布。用可用 PowerPoint 渲染每页；没有工具时说明未完成的视觉检查，不凭 XML 声称复刻成功。
3. 按参考的实际页面类型记录字体、字号、配色、网格、标题、页脚、图表和密度，附页码证据；未知值写“待确认”。
4. 按 [主题规范](../research-ppt/templates/_template/README.md) 建立独立本地主题。抽取设计语言，不能沿用参考作者、Logo 或论文图片作为默认素材。
5. 生成 5–8 页代表性样例，区分原稿版式与延伸设计，逐页并排比较截图。
6. 浏览器、PDF、两种 PPTX 和受影响主题回归通过后再标记 validated；记录版本和限制。

工具见 [脚本索引](../research-ppt/scripts/README.md)。inspect_pptx.py 分析 OOXML；Render-PowerPoint.ps1 渲染全部页面；New-ContactSheet.ps1 生成总览；New-ComparisonSheets.ps1 按 comparison-map.json 对照。字体仅记录名称，不打包文件。

## 创作与检查

每页一个主要结论，事实、用户贡献、论文图片和示例数据分开标记。资料不足时明确占位，不编造。溢出时先精简、重排或拆页。技术图优先 SVG/Vue，复杂图形与公式在可编辑 PPTX 中可能仍为图片。

启动 Preview，检查全部页面。自动浏览器 QA 可在 research-ppt 中运行：

```powershell
node scripts/qa-deck.mjs http://localhost:3030 decks/demo/screenshots/browser 5
```

最后的数字是源幻灯片页数。检查全页截图、溢出、图片、公式、控制台与翻页；主题可用 data-qa-content 标记内容边界。警告单独记录，页面错误、失败请求及排版问题导致失败。

Export 生成三个文件，Check 实际渲染。安装 PowerPoint 时可添加 RequirePowerPoint，保证原生验证不跳过。人工查看每页 PNG，在 QA 中记录页码、修复、字体回退与不可编辑元素。日志、截图及输出留在本地。

锁定工具链的 FloatingVue 错误默认导致失败；确认与验证记录一致时，可在 QA 命令末尾加 `--allow-known-toolchain-issues`。原始错误仍完整保留，不会接受任意页面错误。
