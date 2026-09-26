# zhaohehe

杂志编排风格的照片博客。**仓库里只放文字，照片全部放在 Cloudflare R2 上**，
用 Hugo + [Blank Magazine](https://github.com/codesign2020/blank-magazine) 主题生成，
托管在 GitHub Pages。

## 为什么这么设计

| | 放在哪 | 为什么 |
|---|---|---|
| 文章 | 仓库里的 Markdown | 纯文本，几十万字也没多大 |
| 照片 | Cloudflare R2 | 免费 10 GB 存储，**出站流量永久免费** |
| 站点产物 | GitHub Pages | 只有文字和代码，通常几百 KB |

GitHub Pages 单站点上限 1 GB，照片迟早会撞穿；而图片站真正的账单是流量费，
R2 的流量不要钱，这两点正好对上。

这个主题对正文图片**不做任何加工**——原样输出。所以图片始终从 R2 加载，
永远不会被复制进 GitHub 仓库，也不会拖慢构建。

## 两种放照片的方式

| 用在哪 | 写作方式 | 有灯箱吗 |
|---|---|---|
| **文章正文**（图文混排） | 普通 Markdown 图片语法 | 没有，就是普通图片 |
| **相册**（照片是主角） | front matter 里列 `photos` | 有，可左右切换、Esc 关闭 |

一篇文字配 10 张照片用文章；一组照片配少量文字用相册。

## 两种语言

网站有中文和英文两套，右上角有个按钮可以切换。中文在根目录（`/`），英文在 `/en/` 下。

同一篇文章的两种语言写成**同一个文件夹**里的两个文件：

```
content/posts/jeju-20260916/
├── index.zh.md      ← 中文版
├── index.en.md      ← 英文版
├── jeju-01.webp     ← 图片两份共用，不用存两遍
└── ...
```

文件名里的 `.zh` / `.en` 就是语言标记，Hugo 会自动把它们认成同一篇文章的两种版本。
点切换按钮时会跳到对应的那一篇，而不是回到首页。

界面上的文字（导航、按钮、日期格式等）在 `i18n/zh.toml` 和 `i18n/en.toml` 里，
两个文件要有相同的键名。站点名称、简介、联系方式在 `hugo.toml` 的
`[languages.zh.params]` 和 `[languages.en.params]` 里分别设置。

> **只写一种语言也可以。** 只有 `.zh.md` 没有 `.en.md` 时，英文站就看不到这篇；
> 切换按钮在那一页会退回英文首页。相册同理。

> 有个技术细节：同一篇的图片只会被发布在**一个**语言的目录下（Hugo 的行为），
> 所以 `hugo.toml` 里有一个 `imageOwnerLang = "zh"` 指明是哪个语言，
> 英文页面会正确地引用中文目录下的图片。哪天把 `defaultContentLanguage`
> 改成 `en`，这里也要跟着改。

## 写文章

在 `content/posts/` 下建一个 `.md` 文件：

```yaml
---
title: "国庆回老家"
date: 2026-10-05
draft: false                  # 改成 true 就先不发布
description: "列表页上显示的一句话简介"
tags: ["旅行", "摄影"]
categories: ["散文"]
featured: true                # 加上这行，这篇会成为首页大图精选
cover: "https://img.example.com/2026/10/cover.webp"
---
```

> **封面一定要写完整网址**（`https://` 开头）。因为 `cover` 会同时出现在首页、
> 列表页和文章页，相对路径在这三个地方解析结果不一样，会变成裂图。

正文里放照片就是最普通的 Markdown：

```markdown
![傍晚的街道](https://img.example.com/2026/09/street.webp)
```

## 建一本相册

在 `content/gallery/` 下建文件夹，里面放 `index.md`，照片写成外链：

```yaml
---
title: "青岛的夏天"
date: 2026-08-20
draft: false
description: "八月的海风"
cover: "https://img.example.com/2026/08/qingdao-01.webp"
photos:
  - "https://img.example.com/2026/08/qingdao-01.webp"
  - "https://img.example.com/2026/08/qingdao-02.webp"
  - "https://img.example.com/2026/08/qingdao-03.webp"
---

照片之间写下当时的光线和心情。
```

`cover` 是相册列表里的封面，`photos` 是按顺序展示的照片。

主题也支持把照片直接丢进文件夹、自动扫描（不需要图床），但那样图片就进了仓库——
对我们这个「图片多」的场景不合适，所以这里统一走外链。

## 让图文错落有致

图片默认和正文栏同宽。想打破「一张接一张等宽图」的单调感，在**图注最前面**加一个方括号指令：

```markdown
![傍晚的海](图片地址)                    与正文同宽（默认）
![傍晚的海](图片地址 "[wide] 傍晚的海")   出血，比正文宽（适合风景）
![傍晚的海](图片地址 "[full] 傍晚的海")   占满整个屏幕宽（一篇文章别超过两张）
![码头](图片地址   "[half] 码头")        缩到 46% 居中（细节、特写）
![招牌](图片地址   "[small] 招牌")        缩到 62% 居中
```

方括号里的指令**不会显示出来**，图注就是后面的文字。手机上所有尺寸会自动还原成满宽，不会挤出屏幕。

济州岛那篇就是这么排的：开头一张 `[full]` 铺开，接着 `[half]` 收一下，再来 `[wide]` 展开，最后一张落在默认宽度——一放一收，读起来有节奏。

## 拍摄参数是自动的

照片下面那行小字（`f/5.0 · 1/1000s · ISO 100 · 105mm`）**不用手打**：

1. 上传脚本把原图里的 EXIF 读出来，存进 `data/photo-exif.json`（几 KB 的文本文件）
2. 模板按文件名查表，自动显示在图注下面
3. 点开大图时，参数也会出现在灯箱底部

为什么要绕这一道：照片上传到 R2 之后，Hugo 构建时读不到文件里的 EXIF（我们特意不让它去抓图，否则每次构建都要把图全下载一遍）。所以在上传这一步把参数取出来存成小表，构建依然又快又不依赖网络。

相机和镜头信息也一起存了，只是没显示。想带上，改 `layouts/_markup/render-image.html` 里 `$exifLine` 那几行就行。

> 导出照片时如果勾了「抹除元数据」，参数就没了。脚本会明确提示「没有 EXIF」。

## 上传照片（一次性准备）

1. **注册 Cloudflare**，进 R2 控制台建一个 bucket，比如 `blog-photos`。

2. **创建访问密钥**：R2 页面点 *Manage R2 API Tokens* → *Create API Token*，
   权限选 **Object Read & Write**。记下 Access Key ID、Secret Access Key，
   以及 S3 endpoint（形如 `https://<账户ID>.r2.cloudflarestorage.com`）。

3. **打开公开访问**：进 bucket 的 *Settings*，两种做法：

   - **有自己域名**：在 *Custom Domains* 绑一个 `img.你的域名.com`，地址好看、速度也好。
   - **没有域名**：用 *Public Development URL*，会给你一个 `https://pub-xxxx.r2.dev` 地址。
     注意它带速率限制，是给开发调试用的，长期用建议还是绑域名。

   > 你的真实地址、账户 ID、bucket 名都记在本机的 `LOCAL-NOTES.md` 里，
   > 那个文件已被忽略，不会进仓库。

4. **装工具并配置 rclone**：

   ```bash
   brew install webp rclone
   rclone config
   ```

   `rclone config` 里依次选：`n`（新建）→ 名字填 `r2` → 存储类型选 `s3`
   → provider 选 `Cloudflare` → 填第 2 步的密钥和 endpoint。验证一下：

   ```bash
   rclone lsd r2:
   ```

5. **写本地配置**：

   ```bash
   cp .photo-env.example .photo-env
   ```

   把 `R2_BUCKET` 填成 bucket 名，`R2_PUBLIC_BASE` 填成第 3 步的公开地址。
   这个文件已在 `.gitignore` 里，不会进仓库。

## 上传照片（每次都做）

把照片丢进 `photos-inbox/`，然后：

```bash
./scripts/publish-photos.sh
```

脚本会把长边压到 1600px、转成 WebP、上传到 R2 的 `年/月/` 目录，
然后打印两份可以直接粘的内容：一份是文章正文用的 Markdown 语法，
一份是相册用的 `photos:` 列表。iPhone 的 HEIC 会自动先转 JPEG。

想批量处理别处的照片：

```bash
./scripts/publish-photos.sh ~/Pictures/青岛/*.jpg
```

压缩参数在 `.photo-env` 里：`WIDTH` 是长边像素，`WEBP_QUALITY` 是画质（1–100）。

## 本地预览

```bash
./scripts/preview.sh
```

浏览器打开 **http://localhost:1313**，`Ctrl+C` 停止，改了内容会自动刷新。

Hugo 约 30 MB，只解压到项目里的 `.tools/` 目录，不装进系统、不需要 sudo，
只有第一次运行需要下载。想换端口就 `PORT=8080 ./scripts/preview.sh`。

`./scripts/preview.sh --setup-only` 只准备环境、不启动服务器。

## 首次部署

1. 在 GitHub 建仓库。想要 `https://你的用户名.github.io` 这种地址，
   仓库名就叫 `你的用户名.github.io`；想要 `https://你的用户名.github.io/blog` 这种，
   仓库名就叫 `blog` 或别的名字。

2. 推送代码：

   ```bash
   git init -b main
   git add .
   git commit -m "初始化博客"
   git remote add origin git@github.com:你的用户名/仓库名.git
   git push -u origin main
   ```

3. 仓库里进 **Settings → Pages**，把 *Source* 改成 **GitHub Actions**。

4. 回到 **Actions** 页面，等那次自动部署跑完（绿勾），网站就上线了。

网址不用写死在配置里——工作流会自动算，以后从项目站换成用户站也不用改。

## 目录结构

```
content/posts/      文章
content/gallery/    相册
data/               拍摄参数表（photo-exif.json，上传脚本自动更新）
i18n/               界面文字的翻译（zh.toml / en.toml）
layouts/            页面模板（已从主题接管，可自由改）
static/             灯箱等自己加的样式和脚本
scripts/            照片上传、EXIF 读取、本地预览、拉主题
.github/workflows/  自动部署
themes/             主题，只提供 CSS/JS，由 CI 拉取，不进仓库
photos-inbox/       待上传的原图，不进仓库
```

## 关于模板

`layouts/` 里的模板是从 Blank Magazine 主题**接管过来**的。这么做是因为两件事：

1. 要支持中英双语，主题本身没有多语言设计，界面文字全是写死的
2. 主题的「关于」页里写死了作者自己的简历（产品经理、MBA 之类）——那一页后来
   整个删掉了，但当时必须先把模板接管过来才改得动

接管之后这些文件归我们所有，可以随便改。`themes/` 里的主题现在只提供 CSS 和 JS。
代价是主题上游的更新不会自动生效。

想彻底换主题的话：删掉 `layouts/` 下的这些模板，改 `scripts/setup-theme.sh`、
`.github/workflows/deploy.yml` 里的 `THEME_REPO`，再改 `hugo.toml` 的 `theme`。

`layouts/about/list.html` 现在没有页面用到（关于页已删除），但留着备用：
哪天想再加一个关于页，建好 `content/about/_index.zh.md` 和 `.en.md`，
再把 `[languages.zh.menu.main]` / `[languages.en.menu.main]` 里补上菜单项就行。

## 已知的小问题

之前的两处问题（日期一律英文、`Share`/`Tags`/`Related posts` 写死英文）已经修好，
现在中英文各自显示正确的文案和日期格式。

（顺带一提：构建时那行 `deprecated: .Site.LanguageCode` 警告也没了。）

## 一些提醒

- GitHub Pages 单站点上限 1 GB、每月约 100 GB 流量。照片放 R2 就是为了绕开这条。
- **不要用 Git LFS 存图片**，GitHub Pages 不支持，图片会挂掉。
- 上传完记得清理 `photos-inbox/` 里的原图，那里不进仓库但会占本地硬盘。
