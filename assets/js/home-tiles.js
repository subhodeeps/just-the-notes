/*
 * Close the gaps in the grid of tiles on the home page (_plugins/home-tiles.rb).
 *
 * The grid packs its tiles densely, so gaps remain only near its end, and where they fall
 * depends on the number of columns, which changes with the width of the window. After each
 * layout, this script reads where every tile landed and fixes the tiles in place, so that a
 * change to one tile cannot move the others. It then fills each empty cell, from the bottom
 * row up: it widens the tile to the left of the cell, or else lengthens the tile above it, or
 * else widens the tile to its right towards it. The grid then ends in a straight edge at
 * every width. On a phone the tiles stand in one column, and there is nothing to fill.
 *
 * A wide tile that is lengthened to two rows gets the class tile-grown, which shows the
 * opening of the post that the plugin puts in it (_sass/_home-tiles.scss), so that the
 * taller tile does not stand half empty.
 *
 * The sort buttons above the grid (assets/js/list-sort.js) reorder the tiles, or put in the
 * tiles of other pages, and then send the event tiles:reorder, which packs the grid again.
 */
(() => {
  const grid = document.querySelector('#post-list .home-tiles');
  if (!grid) return;

  function pack() {
    // the sort buttons may have put other tiles in the grid, so take the ones it holds now
    const tiles = [...grid.querySelectorAll(':scope > .tile')];
    tiles.forEach((tile) => {
      tile.style.gridColumn = '';
      tile.style.gridRow = '';
      tile.classList.remove('tile-grown');
    });
    const style = getComputedStyle(grid);
    const cols = style.gridTemplateColumns.split(' ').length;
    if (cols < 2) return;

    // Where each tile landed, in cells
    const box = grid.getBoundingClientRect();
    const [colGap, rowGap] = [parseFloat(style.columnGap), parseFloat(style.rowGap)];
    const colStep = (box.width - colGap * (cols - 1)) / cols + colGap;
    const rowStep = parseFloat(style.gridAutoRows) + rowGap;
    const place = tiles.map((tile) => {
      const r = tile.getBoundingClientRect();
      return {
        tile,
        col: Math.round((r.left - box.left) / colStep),
        row: Math.round((r.top - box.top) / rowStep),
        cols: Math.round((r.width + colGap) / colStep),
        rows: Math.round((r.height + rowGap) / rowStep)
      };
    });
    const rows = Math.max(...place.map((p) => p.row + p.rows));
    const cell = Array.from({ length: rows }, () => Array(cols).fill(null));
    const mark = (p) => {
      for (let r = p.row; r < p.row + p.rows; r++) for (let c = p.col; c < p.col + p.cols; c++) cell[r][c] = p;
    };
    place.forEach(mark);

    const empty = (r0, r1, c0, c1) => {
      for (let r = r0; r < r1; r++) for (let c = c0; c < c1; c++) if (cell[r][c]) return false;
      return true;
    };
    for (let r = rows - 1; r >= 0; r--) {
      for (let c = 0; c < cols; c++) {
        if (cell[r][c]) continue;
        const left = c > 0 ? cell[r][c - 1] : null;
        const above = r > 0 ? cell[r - 1][c] : null;
        const right = c < cols - 1 ? cell[r][c + 1] : null;
        if (left && left.col + left.cols === c && empty(left.row, left.row + left.rows, c, c + 1)) {
          left.cols += 1;
          mark(left);
        } else if (above && above.row + above.rows === r && empty(r, r + 1, above.col, above.col + above.cols)) {
          above.rows += 1;
          mark(above);
        } else if (right && right.col === c + 1 && empty(right.row, right.row + right.rows, c, c + 1)) {
          right.col -= 1;
          right.cols += 1;
          mark(right);
        }
      }
    }

    place.forEach((p) => {
      p.tile.style.gridColumn = `${p.col + 1} / span ${p.cols}`;
      p.tile.style.gridRow = `${p.row + 1} / span ${p.rows}`;
      p.tile.classList.toggle('tile-grown', p.rows > 1 && p.tile.classList.contains('tile-wide'));
    });
  }

  let columns = 0;
  const repack = () => {
    const now = getComputedStyle(grid).gridTemplateColumns.split(' ').length;
    if (now === columns) return;
    columns = now;
    pack();
  };
  repack();
  window.addEventListener('resize', () => requestAnimationFrame(repack));
  grid.addEventListener('tiles:reorder', () => pack());
})();
