/*
 * The note graph in the right panel (_includes/notes-graph.html), from
 * assets/data/notes-graph.json (_plugins/notes-graph.rb).
 *
 * Nodes are posts, coloured by their first category. Solid edges are links between notes
 * (wikilinks or ordinary links); faint edges join notes that share tags. On a post, the graph
 * shows the post, the notes within two links of it and the notes sharing a tag with it;
 * elsewhere it shows every note.
 *
 * The layout is a small force simulation (repulsion between nodes, springs along edges, a pull
 * to the centre), computed in full before drawing and seeded from the note names, so the same
 * notes always land in the same place and nothing moves on screen. Hovering a node highlights
 * it and its neighbours and shows its title; clicking opens it.
 *
 * Colours come from CSS variables set per theme in _sass/amore: --graph-node-<category>
 * (e.g. --graph-node-physics), --graph-node for other categories, --graph-edge,
 * --graph-edge-faint and --graph-current. They are read again when the theme changes.
 */
(() => {
  const section = document.getElementById('notes-graph');
  if (!section) return;
  const canvas = section.querySelector('canvas');
  const legend = section.querySelector('.notes-graph-legend');
  const list = section.querySelector('.notes-graph-list');
  const current = canvas.dataset.current || null;

  const LINK_LENGTH = 30; // rest length of the springs, in layout units
  const TAG_LENGTH = 60;
  const ITERATIONS = 400;
  const HIT = 9; // px: how close the pointer must be to a node

  fetch(canvas.dataset.src)
    .then((res) => res.json())
    .then(start)
    .catch(() => section.remove()); // no graph is better than a broken one

  const slugify = (s) => s.toLowerCase().trim().replace(/[^a-z0-9]+/g, '-');

  // A small deterministic random generator, seeded from a string
  function seeded(text) {
    let h = 2166136261;
    for (const ch of text) h = Math.imul(h ^ ch.charCodeAt(0), 16777619);
    return () => {
      h = Math.imul(h ^ (h >>> 15), 2246822507);
      h = Math.imul(h ^ (h >>> 13), 3266489909);
      return ((h ^= h >>> 16) >>> 0) / 4294967296;
    };
  }

  // The notes to show: all of them, or the neighbourhood of the current one
  function subgraph(data) {
    if (!current || !data.nodes.some((n) => n.id === current)) return data;
    const keep = new Set([current]);
    const linkNeighbours = (ids) =>
      data.edges
        .filter((e) => e.kind === 'link' && (ids.has(e.source) || ids.has(e.target)))
        .flatMap((e) => [e.source, e.target]);
    const first = new Set(linkNeighbours(keep));
    first.forEach((id) => keep.add(id));
    linkNeighbours(first).forEach((id) => keep.add(id));
    data.edges
      .filter((e) => e.kind === 'tag' && (e.source === current || e.target === current))
      .forEach((e) => keep.add(e.source === current ? e.target : e.source));
    return {
      nodes: data.nodes.filter((n) => keep.has(n.id)),
      edges: data.edges.filter((e) => keep.has(e.source) && keep.has(e.target))
    };
  }

  function layout(nodes, edges) {
    const random = seeded(nodes.map((n) => n.id).join('|'));
    const byId = new Map(nodes.map((n) => [n.id, n]));
    nodes.forEach((n, i) => {
      const angle = (2 * Math.PI * i) / nodes.length + random() * 0.5;
      const radius = 40 + random() * 40;
      Object.assign(n, { x: Math.cos(angle) * radius, y: Math.sin(angle) * radius, vx: 0, vy: 0 });
    });
    const springs = edges
      .map((e) => [byId.get(e.source), byId.get(e.target), e])
      .filter(([a, b]) => a && b);

    for (let step = 0; step < ITERATIONS; step++) {
      const alpha = 1 - step / ITERATIONS;
      for (let i = 0; i < nodes.length; i++) {
        for (let j = i + 1; j < nodes.length; j++) {
          const a = nodes[i];
          const b = nodes[j];
          let dx = b.x - a.x;
          let dy = b.y - a.y;
          const d2 = Math.max(dx * dx + dy * dy, 1);
          const f = (900 / d2) * alpha;
          const d = Math.sqrt(d2);
          dx /= d;
          dy /= d;
          a.vx -= dx * f;
          a.vy -= dy * f;
          b.vx += dx * f;
          b.vy += dy * f;
        }
      }
      for (const [a, b, e] of springs) {
        const link = e.kind === 'link';
        const rest = link ? LINK_LENGTH : TAG_LENGTH;
        const k = (link ? 0.08 : 0.015 * (e.weight || 1)) * alpha;
        const dx = b.x - a.x;
        const dy = b.y - a.y;
        const d = Math.max(Math.hypot(dx, dy), 0.01);
        const f = (d - rest) * k;
        a.vx += (dx / d) * f;
        a.vy += (dy / d) * f;
        b.vx -= (dx / d) * f;
        b.vy -= (dy / d) * f;
      }
      for (const n of nodes) {
        n.vx = (n.vx - n.x * 0.02 * alpha) * 0.6;
        n.vy = (n.vy - n.y * 0.02 * alpha) * 0.6;
        n.x += n.vx;
        n.y += n.vy;
      }
    }
    return springs;
  }

  function start(data) {
    const { nodes, edges } = subgraph(data);
    if (!nodes.length) return section.remove();
    const springs = layout(nodes, edges);

    const degree = new Map(nodes.map((n) => [n.id, 0]));
    const neighbours = new Map(nodes.map((n) => [n.id, new Set()]));
    for (const [a, b, e] of springs) {
      if (e.kind === 'link') {
        degree.set(a.id, degree.get(a.id) + 1);
        degree.set(b.id, degree.get(b.id) + 1);
      }
      neighbours.get(a.id).add(b.id);
      neighbours.get(b.id).add(a.id);
    }

    // Legend: the categories in view; hidden list: the notes, for screen readers
    const categories = [...new Set(nodes.map((n) => n.category).filter(Boolean))].sort();
    legend.innerHTML = categories
      .map((c) => `<li><span class="dot" data-category="${slugify(c)}"></span>${c}</li>`)
      .join('');
    list.innerHTML = nodes.map((n) => `<li><a href="${n.url}">${n.title}</a></li>`).join('');

    const ctx = canvas.getContext('2d');
    let colours = {};
    let hover = null;
    let view = { scale: 1, ox: 0, oy: 0 };
    const dpr = () => window.devicePixelRatio || 1;
    const radius = (n) => (n.id === current ? 5.5 : 3.2 + Math.sqrt(degree.get(n.id)) * 1.2);

    function readColours() {
      const css = getComputedStyle(section);
      const get = (name, fallback) => css.getPropertyValue(name).trim() || fallback;
      colours = {
        node: get('--graph-node', '#768594'),
        edge: get('--graph-edge', '#c2c9d1'),
        faint: get('--graph-edge-faint', 'rgba(194, 201, 209, 0.45)'),
        current: get('--graph-current', '#67428a'),
        text: get('--text-color', '#28313d'),
        bg: get('--main-bg', '#ffffff'),
        category: Object.fromEntries(
          categories.map((c) => [c, get(`--graph-node-${slugify(c)}`, get('--graph-node', '#768594'))])
        )
      };
      legend.querySelectorAll('.dot').forEach((dot, i) => {
        dot.style.background = colours.category[categories[i]];
      });
    }

    function fit() {
      const w = canvas.clientWidth;
      const h = canvas.clientHeight;
      canvas.width = Math.round(w * dpr());
      canvas.height = Math.round(h * dpr());
      const xs = nodes.map((n) => n.x);
      const ys = nodes.map((n) => n.y);
      const [x0, x1, y0, y1] = [Math.min(...xs), Math.max(...xs), Math.min(...ys), Math.max(...ys)];
      const pad = 14;
      const scale = Math.min((w - 2 * pad) / Math.max(x1 - x0, 1), (h - 2 * pad) / Math.max(y1 - y0, 1), 3);
      view = { scale, ox: w / 2 - ((x0 + x1) / 2) * scale, oy: h / 2 - ((y0 + y1) / 2) * scale };
    }

    const screen = (n) => [n.x * view.scale + view.ox, n.y * view.scale + view.oy];

    function draw() {
      const s = dpr();
      ctx.setTransform(s, 0, 0, s, 0, 0);
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      const lit = hover ? neighbours.get(hover.id) : null;
      const dim = (id) => hover && id !== hover.id && !lit.has(id);

      for (const [a, b, e] of springs) {
        const [ax, ay] = screen(a);
        const [bx, by] = screen(b);
        const link = e.kind === 'link';
        ctx.globalAlpha = hover && !(a === hover || b === hover) ? 0.25 : 1;
        ctx.strokeStyle = link ? colours.edge : colours.faint;
        ctx.lineWidth = link ? 1.2 : 0.8;
        ctx.setLineDash(link ? [] : [2, 3]);
        ctx.beginPath();
        ctx.moveTo(ax, ay);
        ctx.lineTo(bx, by);
        ctx.stroke();
      }
      ctx.setLineDash([]);

      for (const n of nodes) {
        const [x, y] = screen(n);
        ctx.globalAlpha = dim(n.id) ? 0.3 : 1;
        ctx.fillStyle = colours.category[n.category] || colours.node;
        ctx.beginPath();
        ctx.arc(x, y, radius(n), 0, 2 * Math.PI);
        ctx.fill();
        if (n.id === current) {
          ctx.strokeStyle = colours.current;
          ctx.lineWidth = 1.5;
          ctx.beginPath();
          ctx.arc(x, y, radius(n) + 3, 0, 2 * Math.PI);
          ctx.stroke();
        }
      }
      ctx.globalAlpha = 1;

      if (hover) label(hover);
    }

    // The title of a node, on the page's background, kept inside the canvas
    function label(n) {
      const [x, y] = screen(n);
      ctx.font = '12px "Source Sans Pro", sans-serif';
      const w = canvas.clientWidth;
      const text = n.title.length > 42 ? `${n.title.slice(0, 40)}…` : n.title;
      const tw = ctx.measureText(text).width;
      const lx = Math.min(Math.max(x - tw / 2, 2), w - tw - 2);
      const ly = y - radius(n) - 6 < 12 ? y + radius(n) + 14 : y - radius(n) - 6;
      ctx.fillStyle = colours.bg;
      ctx.globalAlpha = 0.85;
      ctx.fillRect(lx - 3, ly - 11, tw + 6, 15);
      ctx.globalAlpha = 1;
      ctx.fillStyle = colours.text;
      ctx.fillText(text, lx, ly);
    }

    function nodeAt(event) {
      const rect = canvas.getBoundingClientRect();
      const px = event.clientX - rect.left;
      const py = event.clientY - rect.top;
      let best = null;
      let bestD = HIT;
      for (const n of nodes) {
        const [x, y] = screen(n);
        const d = Math.hypot(x - px, y - py) - radius(n);
        if (d < bestD) [best, bestD] = [n, d];
      }
      return best;
    }

    canvas.addEventListener('pointermove', (event) => {
      const n = nodeAt(event);
      if (n === hover) return;
      hover = n;
      canvas.style.cursor = n ? 'pointer' : 'default';
      draw();
    });
    canvas.addEventListener('pointerleave', () => {
      hover = null;
      canvas.style.cursor = 'default';
      draw();
    });
    canvas.addEventListener('click', (event) => {
      const n = nodeAt(event);
      if (n && n.id !== current) window.location.href = n.url;
    });

    readColours();
    new ResizeObserver(() => {
      fit();
      draw();
    }).observe(canvas);

    const recolour = () => {
      readColours();
      draw();
    };
    new MutationObserver(recolour).observe(document.documentElement, { attributeFilter: ['data-bs-theme'] });
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', recolour);
  }
})();
