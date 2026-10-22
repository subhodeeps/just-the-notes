#!/usr/bin/env ruby
#
# Insert _includes/home-hero.html above the post list on the home page, and split
# the list into pinned and latest posts with a heading for each.
#
# Chirpy's `home` layout ignores the page's own content and lists pinned posts
# together with the rest, so instead of copying that layout (and drifting from
# theme updates), this hook edits the rendered page. Configure it with the
# `hero` front matter in index.html.

MARKER = '<div id="post-list"'
CARD = '<article class="card-wrapper card">'

Jekyll::Hooks.register :pages, :post_render do |page|
  next unless page.url == '/' && page.data['hero']

  unless page.output.include?(MARKER)
    Jekyll.logger.warn 'Home hero:', "'#{MARKER}' not found on the home page; the theme's markup may have changed"
    next
  end

  site = page.site
  hero = page.data['hero']
  template = site.liquid_renderer.file('home-hero').parse('{% include home-hero.html %}')
  html = template.render!(
    site.site_payload.merge('page' => page.to_liquid),
    registers: { site: site, page: page.to_liquid }
  )
  page.output = page.output.sub(MARKER) { html + MARKER }

  # Chirpy shows the pinned posts first; put the "latest" heading after them
  pinned = [site.posts.docs.count { |post| post.data['pin'] }, site.config['paginate'] || 10].min
  next unless pinned.positive? && hero['pinned_heading'] && hero['list_heading']

  cards = page.output.split(CARD, -1) # cards[0] is everything before the first card
  if cards.size - 1 <= pinned
    Jekyll.logger.warn 'Home hero:', "found #{cards.size - 1} '#{CARD}' for #{pinned} pinned posts" if cards.size == 1
    next
  end

  heading = %(<h2 class="home-list-heading">#{hero['list_heading']}</h2>\n)
  cards[pinned] += heading
  page.output = cards.join(CARD)
end
