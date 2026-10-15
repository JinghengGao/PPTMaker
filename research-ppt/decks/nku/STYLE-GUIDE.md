# TemplateNKU：设计依据与使用

本主题是依据用户提供 PDF 与 [上游仓库](https://github.com/GrokCV/TemplateNKU) 实现的 Slidev 适配，不是 LaTeX 源码的直接运行，也不声称两种排版引擎像素一致。参考原稿共 16 页，已全部渲染观察；文件 SHA256 与上游提交见 manifest.json。

## 视觉依据

| 参考页 | 观察与实现 |
| --- | --- |
| 1 | 封面标题带与作者区，见 cover 布局 |
| 2–4 | 目录及条目层级，见 agenda 布局 |
| 5–10 | 顶部小标题与细线、白底正文、三段页脚、三线表、单图和双栏、算法环境 |
| 11–12 | 浅色圆角公式框和虚线公式框，见 formula-box 类 |
| 13 | 常规、警告、核心要点色块，分别沿用主色、红色、橙色 |
| 14 | 参考文献页；普通内容页可放真实文献，示例不编造引用 |
| 15 | Q&A，见 center 布局 |
| 16 | 全屏主色致谢，见 end 布局 |

参考画布为 453.54 × 255.12 pt，约为 16:9；本主题使用 960 × 540。正文原稿约 10.91 pt，按宽度折算约 23 px；页脚约 5.98 pt，折算约 12.7 px。封面大标题约 31.9 pt。主题对应采用正文 23 px、标题栏 23 px、封面 64 px、页脚 12 px。内容区左右约 60 px，标题区约 43 px，页脚高 25 px，页脚三段比例为 30% / 60% / 10%。

PDF 中字体包括 Liberation Sans、Noto Sans CJK JP、TeX Gyre Termes Math。为方便 Windows 使用，采用 Arial / Microsoft YaHei / Noto Sans CJK SC 回退与 KaTeX 默认数学字体；没有分发任何字体文件，字形与换行可能略有不同。

## 创建与编辑

仓库自带完整示例，可直接运行 `.\PPTMaker.ps1 -Action Preview -DeckId nku`；初始 PDF/PPTX 位于本主题 exports/v1.0.0/。制作自己的作品时再使用下面的 New。

在仓库根目录运行：

~~~powershell
.\PPTMaker.ps1 -Action New -DeckId my-talk -Theme TemplateNKU
.\PPTMaker.ps1 -Action Preview -DeckId my-talk
.\PPTMaker.ps1 -Action Export -DeckId my-talk -Version 1.0.0
~~~

也接受小写主题 ID nku。New 使用本主题 slides.md，复制所需示例图片；不会复制原稿作者、主页或科研数据。八页示例数据明确标注为演示，不代表真实实验。

| 布局 | 内容写法 |
| --- | --- |
| cover | Markdown 一级标题；author、organization、date 配置作者信息 |
| agenda | agenda 数组、active 高亮项（从 1 开始） |
| default | heading 设置标题栏，正文正常使用 Markdown |
| two-cols | heading 设置标题栏；::right:: 分隔两列 |
| center | 居中 Q&A 或简短结论；heading 可选 |
| end | 全屏主色，正文使用一级标题 |

全局第一页可设置 footerLeft、footerTitle；各页可单独覆盖。showTotal: true 显示总页数。局部素材建议放在自己的 public/decks/<id>/；引用 /decks/<id>/文件名。

~~~yaml
---
layout: default
heading: 本页标题
---
~~~

公式使用 KaTeX，formula-box 和 formula-box dashed 提供两类公式框。theme-block、theme-block warning、theme-block takeaway 提供主色、红色、橙色信息块；algorithm 为文本伪代码区域。三线表使用普通 Markdown 表格。

## 复用边界

共享骨架与基础样式在 ../../shared，配色和封面差异位于 theme/。只在 .ppt-theme 内生效，不覆盖官方 demo 或其他主题；复用时保留共享目录。示例图片来自上游 image/demo.jpg；不得把图片当作研究证据。

保持图片比例、对齐和留白；内容溢出时重排或拆页。不要把页脚改成长段落，不要堆叠过多信息块。原 PDF 的黑色缺失图片、LaTeX 导航按钮和原作者科研内容不作为默认素材复用。未在原稿中出现的新设计应标注为延伸设计。

预览、PDF、可编辑 PPTX 的实际验证记录见 manifest.json。复杂公式、图片和校园标识在 PPTX 中可能是图片；不能声称所有元素原生可编辑。来源和素材权利见仓库根 THIRD_PARTY_NOTICES.md。

## 主题差异

封面与目录强调色 #86006a，内容主色 #70005f；来自 PDF 矢量填色和上游 config.tex。按用户要求保留上游原始南开校徽与两幅建筑插图，默认封面标题仍为通用占位。支持 logo、leftArt、rightArt 覆盖图片路径；设置到自己的 /decks/<id>/ 素材即可。

agendaStyle: tiles 对应原稿第 2–3 页；agendaStyle: list 对应第 4 页。active 从 1 开始，条目建议 3–5 项，长标题用 list 并实际检查换行。
