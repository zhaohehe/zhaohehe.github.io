---
title: "带照片的文章"
date: 2026-09-24
draft: false
description: "演示图文混排：正文照片就用最普通的 Markdown 语法，主题不做任何加工。"
tags: ["摄影", "示例"]
categories: ["散文"]
# 封面会同时出现在首页、列表页和文章页，用相对路径在这三个地方会解析成不同地址。
# 下面这个是站点根目录下的占位图（演示用）。配好 R2 之后换成完整网址：
# cover: "https://img.example.com/2026/09/cover.webp"
cover: "/img/demo-cover.jpg"
---

这篇演示图文混排。下面的图是仓库里自带的一张占位图，你换成上传到 R2 之后的链接就行。

## 写法

```markdown
![傍晚的街道](https://img.example.com/2026/09/street.webp)
```

就是最普通的 Markdown 图片语法，没有任何自定义标记。主题对正文图片不做加工，
原样输出，所以图片始终从 R2 加载，永远不会被复制进 GitHub 仓库。

## 效果

![示例照片](sample.jpg "引号里写的就是图注，会显示在图片下方")

图片之间空一行，就是独立的两张：

![照片一](sample.jpg)

![照片二](sample.jpg)

## 成套的照片用相册

如果一组照片是主角、文字只是陪衬，用「相册」更合适——相册自带灯箱，
可以左右切换、Esc 关闭、显示序号。做法见 `content/gallery/` 里的示例。

顺手提醒一句：上传完记得把 `photos-inbox/` 里的原图清掉，不然硬盘会越来越满。

> 这篇和它旁边的 `sample.jpg` 是演示用的，看完可以一起删掉。
