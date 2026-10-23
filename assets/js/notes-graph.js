/*
 * The note graph in the right panel and on the Graph tab (_includes/notes-graph.html), from
 * assets/data/notes-graph.json (_plugins/notes-graph.rb).
 *
 * Nodes are posts, coloured by their first category. Solid edges are links between notes
 * (wikilinks or ordinary links); faint edges join notes that share tags. On a post, the graph
 * shows the post, the notes within two links of it and the notes sharing a tag with it;
 * elsewhere it shows every note.
 *
 * The layout is a small force simulation (repulsion between nodes, springs along edges, a pull
 * to the centre), computed in full before drawing and seeded from the note names, so the same
 * notes always land in the same place. Hovering a node highlights it and its neighbours and
 * shows its title; clicking opens it. On a touch screen, which has no hover, the first tap on a
 * node shows its title and the second opens it.
 *
 * In the panel the layout is flat and holds still. On the Graph tab it is three-dimensional and
 * drawn in perspective: it turns slowly by itself, a drag turns it by hand, and the wheel, a
 * pinch or the buttons in its corner zoom in and out.
 *
 * Colours come from CSS variables set per theme in _sass/amore: --graph-node-<category>
 * (e.g. --graph-node-physics), --graph-node for other categories, --graph-edge,
 * --graph-edge-faint and --graph-current. They are read again when the theme changes.
 */
(() => {
  const LINK_LENGTH = 30; // rest length of the springs, in layout units
  const TAG_LENGTH = 60;
  const ITERATIONS = 400;
  const HIT = 9; // px: how close the pointer must be to a node
  const HIT_TOUCH = 18; // px: the same, for a finger
  const PITCH = 0.35; // rad: the starting tilt of the 3D view
  const SPIN = 0.0025; // rad per frame: how fast the 3D view turns by itself
  const [ZOOM_MIN, ZOOM_MAX] = [0.5, 4];

  document.querySelectorAll('.notes-graph').forEach((section) => {
    fetch(section.querySelector('canvas').dataset.src)
      .then((res) => res.json())
      .then((data) => start(section, data))
      .catch(() => section.remove()); // no graph is better than a broken one
  });

  const slugify = (s) => s.toLowerCase().trim().replace(/[^a-z0-9]+/g, '-');
  const clamp = (v, lo, hi) => Math.min(Math.max(v, lo), hi);

  // 3 x 3 rotation matrices, stored by rows: about the vertical axis y and the horizontal axis x
  const rotY = (a) => [Math.cos(a), 0, Math.sin(a), 0, 1, 0, -Math.sin(a), 0, Math.cos(a)];
  const rotX = (a) => [1, 0, 0, 0, Math.cos(a), -Math.sin(a), 0, Math.sin(a), Math.cos(a)];
  const times = (a, b) =>
    Array.from({ length: 9 }, (_, k) => {
      const [i, j] = [Math.floor(k / 3), k % 3];
      return a[3 * i] * b[j] + a[3 * i + 1] * b[3 + j] + a[3 * i + 2] * b[6 + j];
    });

  // Rounding errors pile up over many small turns; Gram-Schmidt on the rows keeps the matrix a rotation
  function orthonormal(m) {
    const unit = (v) => v.map((c) => c / Math.hypot(...v));
    const dot = (u, v) => u[0] * v[0] + u[1] * v[1] + u[2] * v[2];
    const a = unit(m.slice(0, 3));
    const b0 = m.slice(3, 6);
    const b = unit(b0.map((c, i) => c - dot(a, b0) * a[i]));
    const c = [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
    return [...a, ...b, ...c];
  }

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
  function subgraph(data, current) {
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

  // With depth, the nodes start off the plane and the forces act in three dimensions; without
  // it, z stays zero and the layout is the flat one
  function layout(nodes, edges, depth) {
    const random = seeded(nodes.map((n) => n.id).join('|'));
    const byId = new Map(nodes.map((n) => [n.id, n]));
    nodes.forEach((n, i) => {
      const angle = (2 * Math.PI * i) / nodes.length + random() * 0.5;
      const radius = 40 + random() * 40;
      const z = depth ? (random() - 0.5) * 80 : 0;
      Object.assign(n, { x: Math.cos(angle) * radius, y: Math.sin(angle) * radius, z, vx: 0, vy: 0, vz: 0 });
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
          let dz = b.z - a.z;
          const d2 = Math.max(dx * dx + dy * dy + dz * dz, 1);
          const f = ((depth ? 2400 : 900) / d2) * alpha; // 3D has more room, so push harder
          const d = Math.sqrt(d2);
          dx /= d;
          dy /= d;
          dz /= d;
          a.vx -= dx * f;
          a.vy -= dy * f;
          a.vz -= dz * f;
          b.vx += dx * f;
          b.vy += dy * f;
          b.vz += dz * f;
        }
      }
      for (const [a, b, e] of springs) {
        const link = e.kind === 'link';
        const rest = link ? LINK_LENGTH : TAG_LENGTH;
        const k = (link ? 0.08 : 0.015 * (e.weight || 1)) * alpha;
        const dx = b.x - a.x;
        const dy = b.y - a.y;
        const dz = b.z - a.z;
        const d = Math.max(Math.hypot(dx, dy, dz), 0.01);
        const f = (d - rest) * k;
        a.vx += (dx / d) * f;
        a.vy += (dy / d) * f;
        a.vz += (dz / d) * f;
        b.vx -= (dx / d) * f;
        b.vy -= (dy / d) * f;
        b.vz -= (dz / d) * f;
      }
      for (const n of nodes) {
        n.vx = (n.vx - n.x * 0.02 * alpha) * 0.6;
        n.vy = (n.vy - n.y * 0.02 * alpha) * 0.6;
        n.vz = (n.vz - n.z * 0.02 * alpha) * 0.6;
        n.x += n.vx;
        n.y += n.vy;
        n.z += n.vz;
      }
    }
    return springs;
  }

  function start(section, data) {
    const canvas = section.querySelector('canvas');
    const legend = section.querySelector('.notes-graph-legend');
    const list = section.querySelector('.notes-graph-list');
    const current = canvas.dataset.current || null;
    const big = section.classList.contains('notes-graph-page'); // the Graph tab: larger and in 3D
    const { nodes, edges } = subgraph(data, current);
    if (!nodes.length) return section.remove();
    const springs = layout(nodes, edges, big);

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
    let touch = false; // whether the last pointer was a finger
    let view = { scale: 1, ox: 0, oy: 0, cx: 0, cy: 0, cz: 0, r: 0 }; // r > 0 once the 3D view fits
    let turn = { m: rotX(PITCH), zoom: 1 }; // m: how the 3D view is turned, a rotation matrix
    const proj = new Map(); // node -> where it is drawn: x, y, depth z and perspective factor f
    const dpr = () => window.devicePixelRatio || 1;
    const radius = (n) =>
      (n.id === current ? 5.5 : 3.2 + Math.sqrt(degree.get(n.id)) * 1.2) *
      (big ? 1.6 * proj.get(n).f * Math.sqrt(turn.zoom) : 1);
    const short = (title, max) => (title.length > max ? `${title.slice(0, max - 2)}…` : title);

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
        font: css.fontFamily || 'sans-serif',
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
      if (big) {
        // The 3D view turns about the centre of the notes, and the sphere that holds them all
        // fits the canvas whichever way it turns
        const mean = (key) => nodes.reduce((s, n) => s + n[key], 0) / nodes.length;
        const [cx, cy, cz] = [mean('x'), mean('y'), mean('z')];
        const r = Math.max(...nodes.map((n) => Math.hypot(n.x - cx, n.y - cy, n.z - cz)), 1);
        const pad = w < 500 ? 24 : 40;
        view = { scale: (Math.min(w, h) - 2 * pad) / (2 * r), ox: w / 2, oy: h / 2, cx, cy, cz, r };
        return;
      }
      const xs = nodes.map((n) => n.x);
      const ys = nodes.map((n) => n.y);
      const [x0, x1, y0, y1] = [Math.min(...xs), Math.max(...xs), Math.min(...ys), Math.max(...ys)];
      const pad = 14;
      const scale = Math.min((w - 2 * pad) / Math.max(x1 - x0, 1), (h - 2 * pad) / Math.max(y1 - y0, 1), 3);
      view = { ...view, scale, ox: w / 2 - ((x0 + x1) / 2) * scale, oy: h / 2 - ((y0 + y1) / 2) * scale };
    }

    // Turn the 3D layout by the matrix turn.m, and look at it from a distance of three radii;
    // z grows away from the viewer
    function project() {
      if (!big) {
        for (const n of nodes) proj.set(n, { x: n.x * view.scale + view.ox, y: n.y * view.scale + view.oy, z: 0, f: 1 });
        return;
      }
      const m = turn.m;
      const distance = 3 * view.r;
      for (const n of nodes) {
        const [x, y, z] = [n.x - view.cx, n.y - view.cy, n.z - view.cz];
        const x1 = m[0] * x + m[1] * y + m[2] * z;
        const y1 = m[3] * x + m[4] * y + m[5] * z;
        const z1 = m[6] * x + m[7] * y + m[8] * z;
        const f = distance / (distance + z1);
        const s = view.scale * turn.zoom * f;
        proj.set(n, { x: view.ox + x1 * s, y: view.oy + y1 * s, z: z1, f });
      }
    }

    const screen = (n) => [proj.get(n).x, proj.get(n).y];
    // Notes at the back of the 3D view fade a little, so the eye reads the depth
    const depth = (z) => (big ? 0.55 + 0.45 * clamp((view.r - z) / (2 * view.r), 0, 1) : 1);

    function draw() {
      if (big && !view.r) return;
      project();
      const s = dpr();
      ctx.setTransform(s, 0, 0, s, 0, 0);
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      const lit = hover ? neighbours.get(hover.id) : null;
      const dim = (id) => hover && id !== hover.id && !lit.has(id);

      for (const [a, b, e] of springs) {
        const [ax, ay] = screen(a);
        const [bx, by] = screen(b);
        const link = e.kind === 'link';
        const fade = depth((proj.get(a).z + proj.get(b).z) / 2);
        ctx.globalAlpha = (hover && !(a === hover || b === hover) ? 0.25 : 1) * fade;
        ctx.strokeStyle = link ? colours.edge : colours.faint;
        ctx.lineWidth = (link ? 1.2 : 0.8) * (big ? 1.25 : 1);
        ctx.setLineDash(link ? [] : [2, 3]);
        ctx.beginPath();
        ctx.moveTo(ax, ay);
        ctx.lineTo(bx, by);
        ctx.stroke();
      }
      ctx.setLineDash([]);

      // From the back to the front, so that nearer notes cover farther ones
      const order = big ? [...nodes].sort((a, b) => proj.get(b).z - proj.get(a).z) : nodes;
      for (const n of order) {
        const [x, y] = screen(n);
        ctx.globalAlpha = (dim(n.id) ? 0.3 : 1) * depth(proj.get(n).z);
        ctx.fillStyle = colours.category[n.category] || colours.node;
        ctx.beginPath();
        ctx.arc(x, y, radius(n), 0, 2 * Math.PI);
        ctx.fill();
        if (big) {
          // A ring in the background colour lifts the node off the lines that meet it
          ctx.strokeStyle = colours.bg;
          ctx.lineWidth = 2;
          ctx.stroke();
          if (n === hover) {
            ctx.strokeStyle = colours.category[n.category] || colours.node;
            ctx.lineWidth = 1.5;
            ctx.beginPath();
            ctx.arc(x, y, radius(n) + 4, 0, 2 * Math.PI);
            ctx.stroke();
          }
        }
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
      ctx.font = `${big ? '600 13px' : '12px'} ${colours.font}`;
      const w = canvas.clientWidth;
      const text = short(n.title, 42);
      const tw = ctx.measureText(text).width;
      const lx = clamp(x - tw / 2, 2, w - tw - 2);
      const ly = y - radius(n) - 6 < 12 ? y + radius(n) + 14 : y - radius(n) - 6;
      ctx.fillStyle = colours.bg;
      ctx.globalAlpha = 0.85;
      ctx.fillRect(lx - 3, ly - 11, tw + 6, 15);
      ctx.globalAlpha = 1;
      ctx.fillStyle = colours.text;
      ctx.fillText(text, lx, ly);
    }

    // The nearest node under the pointer; in 3D, the frontmost one wins a tie
    function nodeAt(event) {
      const rect = canvas.getBoundingClientRect();
      const px = event.clientX - rect.left;
      const py = event.clientY - rect.top;
      let best = null;
      let bestD = touch ? HIT_TOUCH : HIT;
      for (const n of nodes) {
        const [x, y] = screen(n);
        const d = Math.hypot(x - px, y - py) - radius(n);
        if (d < bestD || (d === bestD && best && proj.get(n).z < proj.get(best).z)) [best, bestD] = [n, d];
      }
      return best;
    }

    // The 3D view: turning by itself, by hand, and zooming
    let spinning = false;
    let frame = null;
    const spinButton = section.querySelector('[data-graph="spin"]');

    function setSpin(on) {
      spinning = on;
      if (spinButton) {
        spinButton.querySelector('i').className = on ? 'fas fa-pause' : 'fas fa-play';
        spinButton.setAttribute('aria-label', on ? 'Stop turning' : 'Start turning');
        spinButton.title = spinButton.getAttribute('aria-label');
      }
      if (on && !frame) frame = requestAnimationFrame(tick);
    }

    // The view holds still while the pointer rests on a note, so that its title can be read
    function tick() {
      frame = null;
      if (!spinning) return;
      if (!hover) {
        // About the layout's own vertical axis, like a globe, whichever way the view is tilted
        turn.m = orthonormal(times(turn.m, rotY(SPIN)));
        draw();
      }
      frame = requestAnimationFrame(tick);
    }

    function zoomBy(k) {
      turn.zoom = clamp(turn.zoom * k, ZOOM_MIN, ZOOM_MAX);
      draw();
    }

    const pointers = new Map(); // the pointers down on the 3D canvas: id -> last position
    let travel = 0; // px the pointers moved since they went down; a drag is not a click

    function turnOrPinch(event) {
      const [px, py] = pointers.get(event.pointerId);
      const [qx, qy] = [event.clientX, event.clientY];
      if (pointers.size === 1) {
        // About the axes of the screen, so that the view follows the pointer and turns all the
        // way round in every direction, upside down included
        const drag = times(rotX((qy - py) * 0.008), rotY((qx - px) * 0.008));
        turn.m = orthonormal(times(drag, turn.m));
        travel += Math.hypot(qx - px, qy - py);
      } else {
        const [ox, oy] = [...pointers].find(([id]) => id !== event.pointerId)[1];
        zoomBy(Math.hypot(qx - ox, qy - oy) / Math.max(Math.hypot(px - ox, py - oy), 1));
        travel += 10;
      }
      pointers.set(event.pointerId, [qx, qy]);
      if (travel > 4) canvas.style.cursor = 'grabbing';
      draw();
    }

    // A finger cannot hover, and it leaves the canvas at the end of every tap, so only taps
    // move the highlight on a touch screen
    canvas.addEventListener('pointerdown', (event) => {
      touch = event.pointerType === 'touch';
      if (!big) return;
      pointers.set(event.pointerId, [event.clientX, event.clientY]);
      canvas.setPointerCapture(event.pointerId);
      travel = 0;
      setSpin(false);
    });
    canvas.addEventListener('pointermove', (event) => {
      touch = event.pointerType === 'touch';
      if (big && pointers.has(event.pointerId)) return turnOrPinch(event);
      if (touch) return;
      const n = nodeAt(event);
      canvas.style.cursor = n ? 'pointer' : big ? 'grab' : 'default';
      if (n === hover) return;
      hover = n;
      draw();
    });
    const release = (event) => {
      pointers.delete(event.pointerId);
      if (big && !touch) canvas.style.cursor = 'grab';
    };
    canvas.addEventListener('pointerup', release);
    canvas.addEventListener('pointercancel', release);
    canvas.addEventListener('pointerleave', (event) => {
      if (event.pointerType === 'touch') return;
      hover = null;
      canvas.style.cursor = 'default';
      draw();
    });
    canvas.addEventListener('click', (event) => {
      if (big && travel > 4) return;
      const n = nodeAt(event);
      if (touch && n !== hover) {
        hover = n;
        draw();
        return;
      }
      if (n && n.id !== current) window.location.href = n.url;
    });

    if (big) {
      canvas.addEventListener(
        'wheel',
        (event) => {
          event.preventDefault();
          zoomBy(Math.exp(-event.deltaY * 0.0015));
        },
        { passive: false }
      );
      const actions = {
        'zoom-in': () => zoomBy(1.25),
        'zoom-out': () => zoomBy(0.8),
        reset: () => {
          turn = { m: rotX(PITCH), zoom: 1 };
          draw();
        },
        spin: () => setSpin(!spinning)
      };
      section.querySelectorAll('[data-graph]').forEach((button) => {
        button.addEventListener('click', () => actions[button.dataset.graph]());
      });
      canvas.style.cursor = 'grab';
      setSpin(!window.matchMedia('(prefers-reduced-motion: reduce)').matches);
    }

    readColours();
    new ResizeObserver(() => {
      fit();
      draw();
    }).observe(canvas);
    document.fonts.ready.then(draw); // the labels use the page's web font

    const recolour = () => {
      readColours();
      draw();
    };
    new MutationObserver(recolour).observe(document.documentElement, { attributeFilter: ['data-bs-theme'] });
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', recolour);
  }
})();
