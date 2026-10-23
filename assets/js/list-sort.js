/*
 * Sort the posts of a category or a tag page (Chirpy's _layouts/category.html and tag.html) and
 * the tiles under "Explore" on the home page (_plugins/home-tiles.rb).
 *
 * Chirpy lists the posts newest first. This script adds four buttons above the list or the grid,
 * for the newest or the oldest post first and for titles from A to Z or from Z to A, and
 * reorders the items in place. The order by date is Chirpy's own order, kept when the page
 * loads, or its reverse: Chirpy's date script removes the timestamps (data-ts) from the page once
 * it has formatted the dates, so the dates themselves cannot be read back. The title of a post is
 * the text of its link, or of its card title on the home page. The pinned posts on the home page
 * stay where they are, and since the home page shows ten posts to a page, the buttons sort the
 * tiles of the page in view. After a reorder, the script asks assets/js/home-tiles.js to pack the
 * grid again (the event tiles:reorder).
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

  function sorter({ container, items, title, key, after }) {
    if (items.length < 2) return;

    const rank = new Map(items.map((item, i) => [item, i])); // Chirpy's order, newest first
    const byTitle = (a, b) => title(a).localeCompare(title(b), undefined, { sensitivity: 'base', numeric: true });
    const ORDERS = {
      newest: { label: 'Newest', compare: (a, b) => rank.get(a) - rank.get(b) },
      oldest: { label: 'Oldest', compare: (a, b) => rank.get(b) - rank.get(a) },
      az: { label: 'A–Z', compare: byTitle },
      za: { label: 'Z–A', compare: (a, b) => byTitle(b, a) }
    };

    const bar = document.createElement('div');
    bar.className = 'list-sort';
    bar.setAttribute('role', 'group');
    bar.setAttribute('aria-label', 'Sort the posts');
    const buttons = Object.entries(ORDERS).map(([order, { label }]) => {
      const button = document.createElement('button');
      button.type = 'button';
      button.dataset.order = order;
      button.textContent = label;
      button.addEventListener('click', () => {
        sort(order);
        write(key, order);
        if (after) after();
      });
      bar.append(button);
      return button;
    });

    function sort(order) {
      container.append(...[...items].sort(ORDERS[order].compare));
      buttons.forEach((button) => button.setAttribute('aria-pressed', String(button.dataset.order === order)));
    }

    container.before(bar);
    const saved = read(key);
    // home-tiles.js packs the grid when it loads, after this script, so the first sort needs no call
    sort(ORDERS[saved] ? saved : 'newest');
  }

  const list = document.querySelector('#page-category ul.content, #page-tag ul.content');
  if (list) {
    sorter({
      container: list,
      items: [...list.children].filter((li) => li.querySelector('a')),
      title: (li) => li.querySelector('a').textContent.trim(),
      key: 'list-sort'
    });
  }

  const grid = document.querySelector('#post-list .home-tiles');
  if (grid) {
    sorter({
      container: grid,
      items: [...grid.querySelectorAll(':scope > .tile')],
      title: (tile) => (tile.querySelector('.card-title')?.textContent || '').trim(),
      key: 'home-sort',
      after: () => grid.dispatchEvent(new CustomEvent('tiles:reorder'))
    });
  }
})();
