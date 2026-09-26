/* 正文图片的点击放大。复用主题全局的 .lightbox 样式类，
   外观和相册页的灯箱一致：黑底、左右切换、计数、Esc 关闭。 */
(function () {
  'use strict';

  var links = [];
  var index = 0;
  var box = null;

  function build() {
    var el = document.createElement('div');
    el.className = 'lightbox';
    el.innerHTML =
      '<button class="lightbox-close" aria-label="关闭">&times;</button>' +
      '<button class="lightbox-prev" aria-label="上一张">&lsaquo;</button>' +
      '<img src="" alt="">' +
      '<button class="lightbox-next" aria-label="下一张">&rsaquo;</button>' +
      '<div class="lightbox-counter"></div>';

    el.addEventListener('click', function (event) {
      if (event.target === el || event.target.classList.contains('lightbox-close')) {
        close();
      }
    });
    el.querySelector('.lightbox-prev').addEventListener('click', function (event) {
      event.stopPropagation();
      go(-1);
    });
    el.querySelector('.lightbox-next').addEventListener('click', function (event) {
      event.stopPropagation();
      go(1);
    });

    // 大图加载失败时（比如某张照片没有生成 -full 版本）退回正文图，
    // 只退一次，避免两个地址都失效时来回打转。
    var big = el.querySelector('img');
    big.addEventListener('load', function () {
      el.classList.remove('is-loading');
    });
    big.addEventListener('error', function () {
      el.classList.remove('is-loading');
      var fallback = big.getAttribute('data-fallback');
      if (fallback) {
        big.setAttribute('data-fallback', '');
        big.src = fallback;
      }
    });

    document.body.appendChild(el);
    return el;
  }

  function show(i) {
    if (!box) {
      box = build();
    }
    if (!links.length) {
      return;
    }
    index = ((i % links.length) + links.length) % links.length;

    var link = links[index];
    var img = link.querySelector('img');
    var caption = link.getAttribute('data-caption') || '';
    var exif = link.getAttribute('data-exif') || '';
    var counter = box.querySelector('.lightbox-counter');

    var big = box.querySelector('img');
    big.setAttribute('data-fallback', link.getAttribute('data-fallback') || link.getAttribute('href'));
    big.alt = img ? img.getAttribute('alt') || '' : '';
    // 大图有几 MB，先把提示显示出来
    box.classList.add('is-loading');
    big.src = link.getAttribute('href');

    var parts = [];
    if (links.length > 1) {
      parts.push(index + 1 + ' / ' + links.length);
    }
    if (caption) {
      parts.push(caption);
    }
    if (exif) {
      parts.push(exif);
    }
    counter.textContent = parts.join('   ·   ');

    box.classList.add('open');
    document.body.style.overflow = 'hidden';
  }

  function close() {
    if (!box) {
      return;
    }
    box.classList.remove('open');
    document.body.style.overflow = '';
  }

  function go(step) {
    show(index + step);
  }

  document.addEventListener('click', function (event) {
    var link = event.target.closest ? event.target.closest('a.post-img-link') : null;
    if (!link) {
      return;
    }
    event.preventDefault();
    links = Array.prototype.slice.call(document.querySelectorAll('a.post-img-link'));
    show(links.indexOf(link));
  });

  document.addEventListener('keydown', function (event) {
    if (!box || !box.classList.contains('open')) {
      return;
    }
    if (event.key === 'Escape') {
      close();
    } else if (event.key === 'ArrowLeft') {
      go(-1);
    } else if (event.key === 'ArrowRight') {
      go(1);
    }
  });
})();
