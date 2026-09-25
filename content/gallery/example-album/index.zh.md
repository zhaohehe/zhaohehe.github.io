---
title: "示例相册"
date: 2026-09-03
draft: false
description: "演示相册怎么用：照片可以在本文件夹里，也可以写成 R2 的外链。"
---

这本相册用的是**放在本文件夹里的本地图片**（`01.jpg`、`02.jpg`、`03.jpg`），
主题会自动扫描并按文件名排序，`index.md` 里只写文字。

## 换成 R2 上的照片

把照片用上传脚本传上去之后，把本文件夹里的图片删掉，改成在开头列出外链：

```yaml
---
title: "青岛的夏天"
date: 2026-08-20
description: "八月的海风"
cover: "https://img.example.com/2026/08/qingdao-01.webp"
photos:
  - "https://img.example.com/2026/08/qingdao-01.webp"
  - "https://img.example.com/2026/08/qingdao-02.webp"
  - "https://img.example.com/2026/08/qingdao-03.webp"
---
```

`cover` 是相册列表里的封面，`photos` 是相册内的照片，按写的顺序展示。
这两个都只是普通的 URL 字符串，主题不会去抓取或重新处理它们。

照片的加载是懒加载的，滚到哪儿才下哪儿。
