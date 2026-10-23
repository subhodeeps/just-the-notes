/*
 * Open the enlarged figures (Chirpy's GLightbox popup) in the theme the page shows.
 *
 * Chirpy makes one gallery for the theme in which the page loads and, when the theme changes, a
 * second one for the other theme, but it keeps both galleries listening. A figure that has no
 * light and dark versions, such as a single plot, matches both, and after a change of theme the
 * gallery of the first theme can open on it. On a phone in dark mode with the site switched to
 * light, a tap then opens the dark figures.
 *
 * This script catches the click on a figure before Chirpy's galleries see it, and opens a gallery
 * of the figures of the current theme and the figures that have one version only: every figure
 * except those marked for the other theme (.light or .dark), as in Chirpy's own selectors, but
 * decided at the moment of the click. The theme is the one on <html> (data-bs-theme), or the
 * system's when the page has none. The gallery is discarded when it closes.
 *
 * Each enlarged figure carries its caption: the paragraph with the class .aps-caption that follows
 * the figure in the post, label and maths included. GLightbox's "See more" cut-off is turned off,
 * so a long caption shows in full.
 *
 * The figures are saved with transparent backgrounds, and the lightbox draws them on a black
 * backdrop; _sass/_lightbox.scss gives each enlarged figure the background of the page, and the
 * captions the colours of the theme.
 *
 * The script edits nothing of the theme. Without GLightbox, it lets Chirpy handle the click.
 */
(() => {
  if (!document.querySelector('a.popup')) return;

  // The caption of a figure: the .aps-caption paragraph right after the paragraph that holds it
  const caption = (link) => {
    const next = link.closest('p')?.nextElementSibling;
    return next?.classList.contains('aps-caption') ? next.innerHTML : '';
  };

  const theme = () =>
    document.documentElement.dataset.bsTheme ||
    (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');

  window.addEventListener(
    'click',
    (event) => {
      const link = event.target.closest?.('a.popup');
      if (!link || typeof window.GLightbox !== 'function') return;
      event.preventDefault();
      event.stopImmediatePropagation();

      const other = theme() === 'dark' ? 'light' : 'dark';
      const links = [...document.querySelectorAll('a.popup')].filter((a) => !a.classList.contains(other));
      const gallery = window.GLightbox({
        elements: links.map((a) => ({
          href: a.href,
          type: 'image',
          alt: a.querySelector('img')?.alt || '',
          description: caption(a)
        })),
        descPosition: 'bottom',
        moreLength: 0
      });
      // A caption copied before MathJax finished still holds TeX, so typeset each slide as it loads
      gallery.on('slide_after_load', ({ slideNode }) => {
        if (window.MathJax?.typesetPromise) window.MathJax.typesetPromise([slideNode]).catch(() => {});
      });
      gallery.on('close', () => setTimeout(() => gallery.destroy(), 0));
      gallery.openAt(Math.max(links.indexOf(link), 0));
    },
    true // in the capture phase, before Chirpy's galleries
  );
})();
