---
title: "Example album"
date: 2026-09-03
draft: false
description: "How albums work: photographs can live in this folder, or be listed as R2 links."
---

This album uses **local images sitting in this folder** (`01.jpg`, `02.jpg`,
`03.jpg`). The theme finds them automatically and sorts by filename; the
`index.md` next to them holds only the words.

## Switching to photographs on R2

Once your photos are uploaded, delete the files in this folder and list the links
in the front matter instead:

```yaml
---
title: "Summer in Qingdao"
date: 2026-08-20
description: "August sea breeze"
cover: "https://img.example.com/2026/08/qingdao-01.webp"
photos:
  - "https://img.example.com/2026/08/qingdao-01.webp"
  - "https://img.example.com/2026/08/qingdao-02.webp"
  - "https://img.example.com/2026/08/qingdao-03.webp"
---
```

`cover` is the thumbnail in the album list; `photos` are the pictures inside,
shown in the order you write them. Both are ordinary URL strings — the theme
never fetches or reprocesses them.

Images load lazily, so only what you scroll to gets downloaded.
