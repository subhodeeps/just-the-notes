#!/usr/bin/env ruby
#
# The post list of the home page: pinned posts as full-width bands, the latest posts as a grid
# of tiles of several sizes, and every card in the colour of its note in the graph.
#
# Chirpy's home layout lists every post as a band of the same height. Instead of copying that
# layout, and drifting from theme updates, this hook edits the rendered pages of the list, after
# _plugins/home-hero.rb has split it into pinned and latest posts.
#
# - Each card takes the colour of its first category, which is the colour of its node in the
#   note graph (--graph-node-<category> in _sass/amore/), as a stripe on the left and a faint
#   tint (_sass/_note-cards.scss). Drafts, stubs and private notes have Draft, To Write or
#   Private as their first category (_plugins/draft-category.rb), so they take the colours of
#   those stages. A new category takes its graph colour with no further change.
# - The latest posts form a grid (_sass/_home-tiles.scss). The size of a tile follows the
#   length of the post, without its code: a short note is a small square, a longer one a wide
#   or a tall tile, and the longest a large square. A hash of the post's name decides between
#   wide and tall, so the pattern looks varied but stays the same from one build to the next.
#   The grid packs the tiles densely, so a new post finds its place without any configuration,
#   and assets/js/home-tiles.js closes the gaps that remain at its end, at every width.

require 'zlib'

module HomeTiles
  CARD = %r{<article class="card-wrapper card">.*?</article>}m
  TILE = %r{<article class="card-wrapper card tile .*?</article>}m
  SMALL = 300 # words: a shorter post is a small square
  LARGE = 1500 # words: a longer post is a large square

  module_function

  # As slugify in assets/js/notes-graph.js, so that the names of the colours match
  def slug(category)
    category.to_s.downcase.strip.gsub(/[^a-z0-9]+/, '-')
  end

  def words(post)
    post.content.to_s.gsub(%r{<pre.*?</pre>}m, ' ').gsub(/```.*?```/m, ' ').gsub(/<[^>]+>/, ' ').split.size
  end

  def size(post)
    count = words(post)
    return 'tile-small' if count < SMALL
    return 'tile-large' if count > LARGE

    Zlib.crc32(post.data['slug'].to_s).even? ? 'tile-wide' : 'tile-tall'
  end
end

Jekyll::Hooks.register :pages, :post_render do |page|
  next unless page.output&.include?('<div id="post-list"')

  # If a theme update changes the markup of the cards, the page keeps Chirpy's list as it is
  unless page.output.match?(HomeTiles::CARD) && page.output.include?('class="post-preview')
    Jekyll.logger.warn 'Home tiles:', "no Chirpy cards found in #{page.url}; the theme's markup may have changed"
    next
  end

  site = page.site
  posts = site.posts.docs.to_h { |post| ["#{site.baseurl}#{post.url}", post] }
  page.output = page.output.gsub(HomeTiles::CARD) do |card|
    post = posts[card[/<a href="([^"]+)" class="post-preview/, 1]]
    next card unless post

    category = HomeTiles.slug(Array(post.data['categories']).first)
    colour = %(style="--note: var(--graph-node-#{category}, var(--graph-node))")
    card = card.sub('class="post-preview', %(#{colour} class="post-preview note-card))
    next card if post.data['pin']

    card.sub('<article class="card-wrapper card">', %(<article class="card-wrapper card tile #{HomeTiles.size(post)}">))
  end

  # The latest posts follow the pinned ones, so their tiles form one run
  tiles = page.output.to_enum(:scan, HomeTiles::TILE).map { Regexp.last_match }
  next if tiles.empty?

  start = tiles.first.begin(0)
  stop = tiles.last.end(0)
  script = %(<script defer src="#{site.baseurl}/assets/js/home-tiles.js"></script>) # closes the gaps
  page.output = "#{page.output[0...start]}<div class=\"home-tiles\">#{page.output[start...stop]}</div>#{script}#{page.output[stop..]}"
end
