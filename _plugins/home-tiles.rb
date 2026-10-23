#!/usr/bin/env ruby
#
# The post list of the home page: pinned posts as full-width bands, the latest posts as a grid
# of tiles of several sizes, and every card in the colour of its note in the graph.
#
# Chirpy's home layout lists every post as a band of the same height. Instead of copying that
# layout, and drifting from theme updates, this hook edits the rendered pages of the list, after
# _plugins/home-hero.rb has split it into pinned and latest posts.
#
# - Each card takes the colour of its subject, its first category, which is the colour of its
#   node in the note graph (--graph-node-<category> in _sass/amore/), as a stripe on the left
#   and a faint tint (_sass/_note-cards.scss). A draft, a stub or a private note has its stage
#   as the first category (_plugins/draft-category.rb), so its colour comes from the category
#   after the stage, and its card gets a dashed border in that colour. A new category takes its
#   graph colour with no further change.
# - The latest posts form a grid (_sass/_home-tiles.scss). The size of a tile follows the
#   length of the post, without its code: a short note is a small square, a longer one a wide
#   or a tall tile, and the longest a large square. A hash of the post's name decides between
#   wide and tall, so the pattern looks varied but stays the same from one build to the next.
#   The grid packs the tiles densely, so a new post finds its place without any configuration,
#   and assets/js/home-tiles.js closes the gaps that remain at its end, at every width.
# - A tall or a large tile has room for more than the description, so it also shows the
#   opening of the post, which fades out towards the date. The excerpt is the run of
#   paragraphs at the start of the post, up to the first display equation, code block, folded
#   box, quotation, figure or table, so that it never starts in the middle of an argument.
#   Inline math stays, and the home page loads MathJax for it (math: true in index.html).
#   A wide tile carries the opening as well, hidden until assets/js/home-tiles.js lengthens
#   the tile to two rows to close a gap, when it has the room of a large tile.

require 'zlib'

module HomeTiles
  CARD = %r{<article class="card-wrapper card">.*?</article>}m
  TILE = %r{<article class="card-wrapper card tile .*?</article>}m
  SMALL = 300 # words: a shorter post is a small square
  LARGE = 1500 # words: a longer post is a large square
  EXCERPT = { 'tile-tall' => 90, 'tile-wide' => 150, 'tile-large' => 150 }.freeze # words of the opening
  BLOCK = /\A\s*<(?:pre|details|blockquote|figure|table|div|ul|ol|h[1-6])\b/ # ends the opening run

  module_function

  # As slugify in assets/js/notes-graph.js, so that the names of the colours match
  def slug(category)
    category.to_s.downcase.strip.gsub(/[^a-z0-9]+/, '-')
  end

  def words(post)
    post.content.to_s.gsub(%r{<pre.*?</pre>}m, ' ').gsub(/```.*?```/m, ' ').gsub(/<[^>]+>/, ' ').split.size
  end

  # The paragraphs at the start of the post, up to about `limit` words. The run ends at the
  # first element that is not a paragraph, or at a paragraph with a display equation
  def excerpt(post, limit)
    html = post.content.to_s.sub(/\A\s*<!--.*?-->/m, '')
    out = []
    count = 0
    until html.strip.empty? || count >= limit
      html = html.lstrip.sub(/\A<!--.*?-->/m, '').lstrip
      break if html.match?(BLOCK)

      paragraph = html.match(%r{\A<p\b[^>]*>(.*?)</p>}m)
      break unless paragraph
      break if paragraph[1].match?(/\$\$|\\\[|\\begin\{/)

      text = paragraph[1].gsub(/<[^>]+>/, '').gsub(/\s+/, ' ').strip
      out << "<p>#{text}</p>" unless text.empty?
      count += text.split.size
      html = html[paragraph.end(0)..]
    end
    out.join
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

    category = HomeTiles.slug(NoteStage.subject(post))
    colour = %(style="--note: var(--graph-node-#{category}, var(--graph-node))")
    unpublished = NoteStage.stage(post) ? ' note-unpublished' : ''
    card = card.sub('class="post-preview', %(#{colour} class="post-preview note-card#{unpublished}))
    next card if post.data['pin']

    size = HomeTiles.size(post)
    if size == 'tile-small' && post.draft?
      # A small square hides the categories, but a draft still names its stage there
      stage = NoteStage.stage(post)
      card = card.sub(%r{<span class="categories">.*?</span>}m, %(<span class="categories">#{stage}</span>))
      size += ' tile-stage'
    end
    card = card.sub('<article class="card-wrapper card">', %(<article class="card-wrapper card tile #{size}">))
    excerpt = HomeTiles::EXCERPT[size] && HomeTiles.excerpt(post, HomeTiles::EXCERPT[size])
    excerpt.to_s.empty? ? card : card.sub('<div class="post-meta', %(<div class="tile-excerpt">#{excerpt}</div><div class="post-meta))
  end

  # The latest posts follow the pinned ones, so their tiles form one run
  tiles = page.output.to_enum(:scan, HomeTiles::TILE).map { Regexp.last_match }
  next if tiles.empty?

  start = tiles.first.begin(0)
  stop = tiles.last.end(0)
  script = %(<script defer src="#{site.baseurl}/assets/js/home-tiles.js"></script>) # closes the gaps
  page.output = "#{page.output[0...start]}<div class=\"home-tiles\">#{page.output[start...stop]}</div>#{script}#{page.output[stop..]}"
end
