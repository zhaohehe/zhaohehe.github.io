---
title: "A post with photographs"
date: 2026-09-24
draft: false
description: "How text and photographs sit together: body images are plain Markdown, untouched by the theme."
tags: ["Photography", "Example"]
categories: ["Essays"]
# The cover must be a full URL, because it appears on the home page, in lists
# and on the post page, and a relative path resolves differently in each.
# Once R2 is set up, write it like this:
# cover: "https://img.example.com/2026/09/cover.webp"
---

This post demonstrates text and photographs together. The images below are a
placeholder file that ships with the repository — swap in the links the upload
script gives you once your photos are on R2.

## The syntax

```markdown
![Dusk on the street](https://img.example.com/2026/09/street.webp)
```

Plain Markdown, no custom markup at all. The theme leaves body images alone, so
they are always loaded from R2 and never copied into the GitHub repository.

## How it looks

![Sample photograph](sample.jpg "Text in the quotes becomes the caption")

Leave a blank line between two images and they become two separate pictures:

![First](sample.jpg)

![Second](sample.jpg)

## Sets of photographs belong in a gallery

When a group of images is the point and the text is secondary, use a gallery.
Galleries come with a lightbox: arrow keys to move, Escape to close, a counter at
the bottom. See the example under `content/gallery/`.

One reminder: after uploading, clear the originals out of `photos-inbox/` — that
folder is not committed, but it does fill up your disk.

> This post and the `sample.jpg` beside it are just examples. Delete them whenever.
