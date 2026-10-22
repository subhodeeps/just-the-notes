#!/usr/bin/env ruby
#
# Insert _includes/home-hero.html above the post list on the home page.
#
# Chirpy's `home` layout ignores the page's own content, so instead of copying
# that layout (and drifting from theme updates), this hook adds the hero to the
# rendered page. Configure it with the `hero` front matter in index.html.

MARKER = '<div id="post-list"'

Jekyll::Hooks.register :pages, :post_render do |page|
  next unless page.url == '/' && page.data['hero']

  unless page.output.include?(MARKER)
    Jekyll.logger.warn 'Home hero:', "'#{MARKER}' not found on the home page; the theme's markup may have changed"
    next
  end

  site = page.site
  template = site.liquid_renderer.file('home-hero').parse('{% include home-hero.html %}')
  hero = template.render!(
    site.site_payload.merge('page' => page.to_liquid),
    registers: { site: site, page: page.to_liquid }
  )

  page.output = page.output.sub(MARKER) { hero + MARKER }
end
