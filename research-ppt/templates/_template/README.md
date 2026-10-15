# 新主题规范（不是已完成的主题）

每次由真实参考 PPT 派生新模板时，新建 `templates/<id>/`，至少应包含：

- `package.json`：本地 Slidev Theme 元数据，名称为 `slidev-theme-<id>`；
- `manifest.json`：模板 ID、来源、版本、状态、适用场景及验证结果；
- `STYLE-GUIDE.md`：源参考页码对应的具体设计证据与可复用规则；
- `styles/index.css`：该主题的专属设计 Token 和样式；
- `layouts/`：按原稿实际布局抽象出的 Vue 文件；
- `examples/`：代表性页面与实际渲染截图。

只有参考原稿经过观察后才填写样式，不应先编造第一套模板的颜色或字体。模板专属的 `cover.vue` 等不得放在工程根 `layouts/` 中覆盖其他主题。
