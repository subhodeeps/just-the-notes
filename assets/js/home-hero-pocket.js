/*
 * The home page figure: a photon trapped in the pocket of the Hartle-Thorne spacetime
 * (marginal pocket, b = 4.304332 M), from the stored orbit of ht_chaos_reproduction: the photon of
 * Fig. 2 of K. Kostaros and G. Pappas, Class. Quantum Grav. 39, 134001 (2022), arXiv:2111.09367.
 * The simulation and this animation are our own reproduction.
 *
 * The zero-velocity separatrix stays still; the photon moves along its orbit with a short
 * bright tail, and the path so far builds up in faint ink, as in animation/pocket_photons.mp4.
 * The run loops: motion, a pause on the full picture, a fade, and again.
 *
 * Colours come from the CSS variables --pocket-separatrix and --pocket-photon (amore blue
 * and red, set per theme in _sass/amore), and are read again when the theme changes.
 * With prefers-reduced-motion, the finished picture is drawn once, without motion.
 */
(() => {
  const canvas = document.querySelector('.home-hero-canvas');
  if (!canvas) return;

  const MOTION = 14000; // ms for the whole orbit
  const HOLD = 3000; // ms on the finished picture
  const FADE = 1000; // ms to fade the path before starting again
  const TAIL = 0.02; // the bright tail: this fraction of the orbit
  const CHUNK = 10; // the faint path is stroked in pieces of this many points
  const PATH_ALPHA = 0.18; // opacity of each piece (pieces overlap, so dense regions darken)

  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');

  fetch(canvas.dataset.src)
    .then((res) => res.json())
    .then(start)
    .catch(() => {}); // no figure is better than a broken one

  function start(data) {
    const { width: W, height: H, scale } = data.view;
    const orbit = Float32Array.from(data.orbit, (v) => v / scale);
    const separatrix = data.separatrix.map((line) => Float32Array.from(line, (v) => v / scale));
    const n = orbit.length / 2;
    const tail = Math.max(2, Math.round(n * TAIL));

    const ctx = canvas.getContext('2d');
    const layer = document.createElement('canvas'); // the faint path, kept between frames
    const lctx = layer.getContext('2d');
    let k = 1; // canvas pixels per data unit
    let colours = {};
    let drawn = 0; // points of the faint path already on the layer
    let index = 0; // the photon's current point
    let t0 = null; // start of the current run
    let pausedAt = null;
    let frame = null;
    let moving = !reduceMotion.matches; // false: the finished picture, without the photon

    function readColours() {
      const css = getComputedStyle(canvas);
      colours = {
        separatrix: css.getPropertyValue('--pocket-separatrix').trim() || '#5c9dc7',
        photon: css.getPropertyValue('--pocket-photon').trim() || '#6b1d2a'
      };
    }

    function resize() {
      const dpr = window.devicePixelRatio || 1;
      const w = canvas.clientWidth;
      const h = canvas.clientHeight;
      if (!w || !h) return;
      canvas.width = layer.width = Math.round(w * dpr);
      canvas.height = layer.height = Math.round(h * dpr);
      k = (w * dpr) / W;
      redrawLayer();
      paint();
    }

    // Stroke the faint path from point `from` to `to` on the layer, in whole chunks
    function strokePath(from, to) {
      lctx.save();
      lctx.setTransform(k, 0, 0, (canvas.height / H), 0, 0);
      lctx.strokeStyle = colours.photon;
      lctx.globalAlpha = PATH_ALPHA;
      lctx.lineWidth = 0.8 / k * (window.devicePixelRatio || 1);
      lctx.lineJoin = 'round';
      for (let c = from; c < to; c += CHUNK) {
        const end = Math.min(c + CHUNK, n - 1);
        lctx.beginPath();
        lctx.moveTo(orbit[2 * c], orbit[2 * c + 1]);
        for (let i = c + 1; i <= end; i++) lctx.lineTo(orbit[2 * i], orbit[2 * i + 1]);
        lctx.stroke();
      }
      lctx.restore();
    }

    function redrawLayer() {
      lctx.clearRect(0, 0, layer.width, layer.height);
      strokePath(0, drawn);
    }

    function advanceTo(i) {
      const target = Math.floor(i / CHUNK) * CHUNK;
      if (target > drawn) {
        strokePath(drawn, target);
        drawn = target;
      }
      index = i;
    }

    function polyline(c, pts, from, to) {
      c.beginPath();
      c.moveTo(pts[2 * from], pts[2 * from + 1]);
      for (let i = from + 1; i <= to; i++) c.lineTo(pts[2 * i], pts[2 * i + 1]);
      c.stroke();
    }

    function paint(fade = 1) {
      const dpr = window.devicePixelRatio || 1;
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.clearRect(0, 0, canvas.width, canvas.height);

      ctx.globalAlpha = fade;
      ctx.drawImage(layer, 0, 0);

      ctx.setTransform(k, 0, 0, canvas.height / H, 0, 0);
      ctx.lineJoin = ctx.lineCap = 'round';

      ctx.globalAlpha = 1;
      ctx.strokeStyle = colours.separatrix;
      ctx.lineWidth = (1.5 * dpr) / k;
      separatrix.forEach((line) => polyline(ctx, line, 0, line.length / 2 - 1));

      if (!moving) return;
      ctx.globalAlpha = fade;
      ctx.strokeStyle = ctx.fillStyle = colours.photon;
      ctx.lineWidth = (1.6 * dpr) / k;
      polyline(ctx, orbit, Math.max(0, index - tail), index);

      // the head: a round dot, whatever the x and y scales
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.beginPath();
      ctx.arc(orbit[2 * index] * k, orbit[2 * index + 1] * (canvas.height / H), 3 * dpr, 0, 2 * Math.PI);
      ctx.fill();
    }

    function tick(now) {
      if (t0 === null) t0 = now;
      const elapsed = now - t0;
      if (elapsed < MOTION) {
        advanceTo(Math.min(n - 1, Math.floor((elapsed / MOTION) * n)));
        paint();
      } else if (elapsed < MOTION + HOLD) {
        advanceTo(n - 1);
        paint();
      } else if (elapsed < MOTION + HOLD + FADE) {
        paint(1 - (elapsed - MOTION - HOLD) / FADE);
      } else {
        drawn = index = 0;
        t0 = now;
        redrawLayer();
        paint();
      }
      frame = requestAnimationFrame(tick);
    }

    function play() {
      if (frame !== null) return;
      if (pausedAt !== null && t0 !== null) t0 += performance.now() - pausedAt;
      pausedAt = null;
      frame = requestAnimationFrame(tick);
    }

    function pause() {
      if (frame === null) return;
      cancelAnimationFrame(frame);
      frame = null;
      pausedAt = performance.now();
    }

    function still() {
      // the finished picture, without the photon
      pause();
      moving = false;
      drawn = n - 1;
      index = n - 1;
      redrawLayer();
      paint();
    }

    readColours();
    new ResizeObserver(resize).observe(canvas);
    resize();

    // Theme changes: Chirpy's toggle sets data-bs-theme on <html>; the system setting can change too
    const recolour = () => {
      readColours();
      redrawLayer();
      paint();
    };
    new MutationObserver(recolour).observe(document.documentElement, { attributeFilter: ['data-bs-theme'] });
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', recolour);

    if (reduceMotion.matches) {
      still();
      return;
    }

    // Animate only while the figure is on screen
    new IntersectionObserver(([entry]) => (entry.isIntersecting ? play() : pause())).observe(canvas);
    reduceMotion.addEventListener('change', () => {
      if (reduceMotion.matches) return still();
      moving = true;
      play();
    });
  }
})();
