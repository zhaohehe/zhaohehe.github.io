/* 大图查看器。文章正文和相册页共用。

   约定：任何 <img data-photo ...> 都可以点开。

     data-full     大图地址（必填）
     data-thumb    缩略图地址 —— 大图加载失败时退回它
     data-caption  图注
     data-exif     拍摄参数

   箭头可以在当前页面所有带 data-photo 的图片之间切换。
   一张图时不显示计数和箭头。 */
(function () {
  'use strict';

  var box = null;
  var nodes = [];
  var current = 0;

  function el(cls, html) {
    var node = document.createElement('div');
    node.className = cls;
    if (html) node.innerHTML = html;
    return node;
  }

  function build() {
    box = el('pv');
    box.setAttribute('role', 'dialog');
    box.setAttribute('aria-modal', 'true');
    box.setAttribute('aria-label', '照片大图');

    box.innerHTML =
      '<button class="pv__btn pv__close" type="button" aria-label="关闭">&times;</button>' +
      '<button class="pv__btn pv__nav pv__prev" type="button" aria-label="上一张">&#8249;</button>' +
      '<button class="pv__btn pv__nav pv__next" type="button" aria-label="下一张">&#8250;</button>' +
      '<div class="pv__stage">' +
        '<div class="pv__loading">正在加载原图…</div>' +
        '<img class="pv__img" alt="">' +
      '</div>' +
      '<div class="pv__info">' +
        '<div class="pv__count"></div>' +
        '<div class="pv__caption"></div>' +
        '<div class="pv__exif"></div>' +
      '</div>';

    var img = box.querySelector('.pv__img');

    img.addEventListener('load', function () {
      img.classList.add('is-ready');
      box.querySelector('.pv__loading').style.display = 'none';
    });

    // 大图挂了就退回缩略图，只退一次
    img.addEventListener('error', function () {
      var thumb = img.getAttribute('data-thumb');
      if (thumb && img.getAttribute('src') !== thumb) {
        img.setAttribute('src', thumb);
      } else {
        box.querySelector('.pv__loading').textContent = '这张图加载失败了';
      }
    });

    box.querySelector('.pv__close').addEventListener('click', close);
    box.querySelector('.pv__prev').addEventListener('click', function () { step(-1); });
    box.querySelector('.pv__next').addEventListener('click', function () { step(1); });

    // 点空白处关闭（点图片本身不关，方便仔细看）
    box.addEventListener('click', function (event) {
      if (event.target === box) close();
    });

    document.body.appendChild(box);
  }

  function show(i) {
    if (!box) build();
    if (!nodes.length) return;

    current = ((i % nodes.length) + nodes.length) % nodes.length;
    var node = nodes[current];

    var img = box.querySelector('.pv__img');
    var full = node.getAttribute('data-full') || node.getAttribute('src');
    var thumb = node.getAttribute('data-thumb') || node.getAttribute('src');

    box.querySelector('.pv__loading').style.display = '';
    box.querySelector('.pv__loading').textContent = '正在加载原图…';
    img.classList.remove('is-ready');
    img.setAttribute('data-thumb', thumb);
    img.alt = node.getAttribute('alt') || '';
    img.setAttribute('src', full);

    box.querySelector('.pv__count').textContent =
      nodes.length > 1 ? (current + 1) + ' / ' + nodes.length : '';
    box.querySelector('.pv__caption').textContent = node.getAttribute('data-caption') || '';
    box.querySelector('.pv__exif').textContent = node.getAttribute('data-exif') || '';

    box.classList.toggle('is-single', nodes.length === 1);
    box.classList.add('is-open');
    document.body.style.overflow = 'hidden';
  }

  function step(delta) {
    show(current + delta);
  }

  function close() {
    if (!box) return;
    box.classList.remove('is-open');
    document.body.style.overflow = '';
  }

  // 点击委托：既认图片本身，也认包着它的链接
  document.addEventListener('click', function (event) {
    if (!event.target.closest) return;

    var target = event.target.closest('img[data-photo]');
    if (!target) {
      var link = event.target.closest('a');
      target = link && link.querySelector('img[data-photo]');
    }
    if (!target) return;

    event.preventDefault();
    nodes = Array.prototype.slice.call(document.querySelectorAll('img[data-photo]'));
    show(nodes.indexOf(target));
  });

  document.addEventListener('keydown', function (event) {
    if (!box || !box.classList.contains('is-open')) return;
    if (event.key === 'Escape') close();
    else if (event.key === 'ArrowLeft') step(-1);
    else if (event.key === 'ArrowRight') step(1);
  });
})();
