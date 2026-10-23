/*
 * Sort the posts of a category or a tag page (Chirpy's _layouts/category.html and tag.html) and
 * the tiles under "Explore" on the home page (_plugins/home-tiles.rb).
 *
 * Chirpy lists the posts newest first. This script adds four buttons above the list or the grid,
 * for the newest or the oldest post first and for titles from A to Z or from Z to A. The order by
 * date is Chirpy's own order or its reverse: Chirpy's date script removes the timestamps (data-ts)
 * from the page once it has formatted the dates, so the dates themselves cannot be read back.
 *
 * On a category or a tag page, the buttons reorder the items of the list in place.
 *
 * The home page shows ten posts to a page, so its buttons sort the latest posts of all pages:
 * they load the tiles of every page from assets/data/home-tiles.json (the grid's data-all, which
 * the plugin writes), sort them, and show on each page the slice of the order that falls on it,
 * with as many tiles as Chirpy puts there. "Newest" brings back the page as Chirpy built it. If
 * the file cannot be loaded, the buttons sort the tiles of the page in view. The pinned posts
 * stay where they are. After a sort, the script asks assets/js/home-tiles.js to pack the grid
 * again (the event tiles:reorder) and MathJax to typeset the excerpts of the new tiles.
 *
 * The browser keeps the choice (localStorage), one for the category and tag pages and one for the
 * home page, so the next page opens in the same order.
 *
 * The script edits no layout of the theme. If a Chirpy release changes the markup of a list, it
 * finds nothing to sort and leaves the page as Chirpy renders it.
 */
(() => {
  const read = (key) => {
    try {
      return localStorage.getItem(key);
    } catch {
      return null;
    }
  };
  const write = (key, order) => {
    try {
      localStorage.setItem(key, order);
    } catch {
      // private windows may refuse storage; the order then lasts for this page only
    }
  };

  const byTitle = (a, b) => a.title.localeCompare(b.title, undefined, { sensitivity: 'base', numeric: true });
  const ORDERS = {
    newest: { label: 'Newest', compare: (a, b) => a.rank - b.rank },
    oldest: { label: 'Oldest', compare: (a, b) => b.rank - a.rank },
    az: { label: 'A–Z', compare: byTitle },
    za: { label: 'Z–A', compare: (a, b) => byTitle(b, a) }
  };

  // The buttons above `container`; `apply(order)` shows the posts in that order
  function buttons(container, key, apply) {
    const bar = document.createElement('div');
    bar.className = 'list-sort';
    bar.setAttribute('role', 'group');
    bar.setAttribute('aria-label', 'Sort the posts');
    const all = Object.entries(ORDERS).map(([order, { label }]) => {
      const button = document.createElement('button');
      button.type = 'button';
      button.dataset.order = order;
      button.textContent = label;
      button.addEventListener('click', () => {
        choose(order);
        write(key, order);
      });
      bar.append(button);
      return button;
    });
    function choose(order) {
      all.forEach((button) => button.setAttribute('aria-pressed', String(button.dataset.order === order)));
      apply(order);
    }
    container.before(bar);
    const saved = read(key);
    choose(ORDERS[saved] ? saved : 'newest');
  }

  // A category or a tag page: the items of its list, in place
  const list = document.querySelector('#page-category ul.content, #page-tag ul.content');
  if (list) {
    const items = [...list.children]
      .filter((li) => li.querySelector('a'))
      .map((node, rank) => ({ node, rank, title: node.querySelector('a').textContent.trim() }));
    if (items.length > 1) {
      buttons(list, 'list-sort', (order) => {
        list.append(...[...items].sort(ORDERS[order].compare).map((item) => item.node));
      });
    }
  }

  // The home page: the tiles of all its pages
  const grid = document.querySelector('#post-list .home-tiles');
  if (grid) {
    const own = [...grid.querySelectorAll(':scope > .tile')];
    const local = own.map((node, rank) => ({
      node,
      rank,
      title: (node.querySelector('.card-title')?.textContent || '').trim()
    }));
    const number = Number(location.pathname.match(/\/page(\d+)\/?$/)?.[1] || 1);
    let pages = null; // the tiles of every page, once loaded
    const load = () =>
      (pages ??= fetch(grid.dataset.all)
        .then((response) => (response.ok ? response.json() : Promise.reject(response.status)))
        .then((data) => data.pages)
        .catch(() => null));

    const show = (nodes) => {
      grid.replaceChildren(...nodes);
      grid.dispatchEvent(new CustomEvent('tiles:reorder'));
      if (window.MathJax?.typesetPromise) MathJax.typesetPromise([grid]).catch(() => {});
    };

    let latest = 0; // a later click wins over a slow load
    const apply = async (order) => {
      const call = ++latest;
      if (order === 'newest') return show(own);
      const all = await load();
      if (call !== latest) return;
      if (!all) return show([...local].sort(ORDERS[order].compare).map((item) => item.node));

      // Every tile, in Chirpy's order, then the slice of the sorted order that falls on this page
      const tiles = all.flatMap((page) => page.tiles).map((tile, rank) => ({ ...tile, rank }));
      const before = all.filter((page) => page.page < number).reduce((sum, page) => sum + page.tiles.length, 0);
      const here = all.find((page) => page.page === number)?.tiles.length ?? own.length;
      const slice = tiles.sort(ORDERS[order].compare).slice(before, before + here);
      const holder = document.createElement('div');
      holder.innerHTML = slice.map((tile) => tile.html).join('');
      show([...holder.children]);
    };

    if (own.length > 1) buttons(grid, 'home-sort', apply);
  }
})();
