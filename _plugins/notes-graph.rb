#!/usr/bin/env ruby
#
# Links between notes, backlinks and the note graph.
#
# 1. Wikilinks, as Foam (VS Code) writes them, become ordinary links at build time:
#      [[ode]]  [[2026-07-06-ode]]  [[ode|custom text]]  [[ode#a-heading]]  [[_posts/2026-07-06-ode]]
#    A note is found by its slug (ode) or its file name (2026-07-06-ode, Foam's default). Links
#    to notes that do not exist (yet) become muted text and a build warning. Relative .md links,
#    which the VS Code and GitHub previews follow, are rewritten to the post's URL as well.
#    Code blocks and inline code are left alone, so `[[ -f x ]]` in a shell snippet stays as it is.
# 2. Every link from one note to another (wikilink, .md link or ordinary /posts/... link) is
#    recorded. Each post gets the notes that link to it, rendered from _includes/backlinks.html
#    before the post's footer.
# 3. assets/data/notes-graph.json holds the posts (nodes) and their links and shared tags
#    (edges), for the graph in the right panel and on the Graph tab (_includes/notes-graph.html,
#    _tabs/graph.md, assets/js/notes-graph.js). A tag edge lists the tags the two notes share.
#    Each node also carries its primary tags, the one to three tags that say what the note is
#    about: primary_tags in its front matter, or else its first two tags. The right panel
#    draws a tag edge only for a shared primary tag, and the Graph tab draws them all.
#
# The theme's layouts are not changed: the links are rewritten in the Markdown before it is
# rendered, and the backlinks and the graph are added to the rendered pages, next to markers
# from Chirpy's layouts. If a theme update moves a marker, the build warns and leaves the page
# as Chirpy renders it.

require 'json'

module NotesGraph
  WIKILINK = /
    (?<code>
      ^(?<fence>`{3,}|~{3,})[^\n]*\n.*?^\k<fence>[ \t]*$     # fenced code block
      | (?<ticks>`+)(?:(?!\k<ticks>).)+?\k<ticks>             # inline code
    )
    | (?<!!)\[\[(?<target>[^\]|#\n]+)(?<anchor>\#[^\]|\n]*)?(?:\|(?<label>[^\]\n]+))?\]\]
    | (?<mdlink>\]\(\s*<?(?<href>[^)\s>]+?)>?(?<title>\s+"[^"]*")?\s*\))
  /mx

  TAIL_MARKER = '<div class="post-tail-wrapper'
  ACCESS_MARKER = '<div class="access">' # the panel's "Recently Updated" and "Trending Tags"
  TAG_HUB_LIMIT = 15 # a tag on more posts than this is too general to draw edges for

  module_function

  def plain(html)
    html.to_s.gsub(/<[^>]+>/, '').strip
  end

  # The notes a link can point to: slug and file name -> document
  def index(site)
    notes = {}
    site.collections.each_value do |collection|
      collection.docs.each do |doc|
        next unless doc.extname == '.md' || doc.extname == '.markdown'

        [doc.data['slug'], File.basename(doc.path, '.*')].compact.each do |key|
          notes[key.downcase] ||= doc
        end
      end
    end
    notes
  end

  def lookup(notes, target)
    key = target.strip.sub(%r{\A.*/}, '').sub(/\.(md|markdown)\z/i, '').downcase
    notes[key]
  end

  # /posts/<slug>/, with or without the site's address, to the note's key
  def post_slug(href, site)
    base = "#{site.config['url']}#{site.config['baseurl']}".sub(%r{/\z}, '')
    path = href.sub(/\A#{Regexp.escape(base)}/, '').sub(/\A\{\{\s*site\.baseurl\s*\}\}/, '')
    path[%r{\A/posts/([^/#?]+)/?(?:[#?].*)?\z}, 1]
  end

  # Rewrite the wikilinks and .md links of one document; return the documents it links to
  def link(doc, notes, site)
    targets = []
    doc.content = doc.content.gsub(WIKILINK) do
      m = Regexp.last_match
      if m[:code]
        m[0]
      elsif m[:target]
        target = lookup(notes, m[:target])
        label = m[:label]&.strip
        if target
          targets << target
          "[#{label || target.data['title']}](#{target.url}#{m[:anchor]})"
        else
          Jekyll.logger.warn 'Notes:', "#{doc.relative_path}: no note called '#{m[:target].strip}'"
          %(<span class="wikilink-missing" title="No note called #{m[:target].strip} yet">#{label || m[:target].strip}</span>)
        end
      else
        href = m[:href]
        if href =~ /\.(md|markdown)(#.*)?\z/i && href !~ %r{\A[a-z]+://}i && (target = lookup(notes, href.sub(/#.*\z/, '')))
          targets << target
          "](#{target.url}#{href[/#.*\z/]}#{m[:title]})"
        else
          slug = post_slug(href, site)
          target = slug && notes[slug.downcase]
          targets << target if target
          m[0]
        end
      end
    end
    targets.uniq - [doc]
  end

  # The subject of the note, which sets its colour, even for a draft (_plugins/draft-category.rb)
  def category_of(doc)
    NoteStage.subject(doc)
  end

  # primary_tags from the front matter, at most three, or else the first two tags
  def primary_tags(doc)
    explicit = Array(doc.data['primary_tags'])
    (explicit.empty? ? Array(doc.data['tags']).first(2) : explicit).first(3)
  end

  def graph(posts, links)
    nodes = posts.map do |doc|
      { id: doc.data['slug'], title: plain(doc.data['short_title'] || doc.data['title']), url: doc.url,
        category: category_of(doc), stage: NoteStage.stage(doc), tags: Array(doc.data['tags']),
        primary: primary_tags(doc) }.compact
    end
    ids = posts.to_h { |doc| [doc, doc.data['slug']] }

    edges = []
    posts.each do |doc|
      (links[doc] || []).each do |target|
        edges << { source: ids[doc], target: ids[target], kind: 'link' } if ids[target]
      end
    end

    by_tag = Hash.new { |h, k| h[k] = [] }
    posts.each { |doc| Array(doc.data['tags']).each { |tag| by_tag[tag] << doc } }
    shared = Hash.new { |h, k| h[k] = [] }
    by_tag.each do |tag, docs|
      next if docs.size > TAG_HUB_LIMIT

      docs.combination(2) { |a, b| shared[[ids[a], ids[b]].sort] << tag }
    end
    shared.each { |(a, b), tags| edges << { source: a, target: b, kind: 'tag', weight: tags.size, tags: tags } }

    { nodes: nodes, edges: edges }
  end

  def render_include(site, name, page)
    template = site.liquid_renderer.file(name).parse("{% include #{name} %}")
    template.render!(site.site_payload.merge('page' => page.to_liquid),
                     registers: { site: site, page: page.to_liquid })
  end

  # Insert html as the first child of the element whose opening tag is `marker`
  def prepend_to(output, marker, html, where)
    unless output.include?(marker)
      Jekyll.logger.warn 'Notes:', "no #{marker} in #{where}; the theme's markup may have changed"
      return output
    end
    output.sub(marker) { marker + html }
  end

  def insert_before(output, markers, html, where)
    marker = markers.find { |m| output.include?(m) }
    unless marker
      Jekyll.logger.warn 'Notes:', "no #{markers.join(' or ')} in #{where}; the theme's markup may have changed"
      return output
    end
    output.sub(marker) { html + marker }
  end

  class Generator < Jekyll::Generator
    priority :low

    def generate(site)
      notes = NotesGraph.index(site)
      links = {}
      site.collections.each_value do |collection|
        collection.docs.each do |doc|
          next unless doc.extname == '.md' || doc.extname == '.markdown'

          links[doc] = NotesGraph.link(doc, notes, site)
        end
      end

      posts = site.posts.docs.reject { |doc| doc.data['hidden'] }
      posts.each do |doc|
        sources = links.select { |_, targets| targets.include?(doc) }.keys
        doc.data['backlinks'] = sources.map do |src|
          { 'url' => src.url, 'title' => src.data['title'], 'description' => src.data['description'] }
        end
      end

      json = Jekyll::PageWithoutAFile.new(site, site.source, 'assets/data', 'notes-graph.json')
      json.content = JSON.generate(NotesGraph.graph(posts, links))
      json.data['layout'] = nil
      json.data['sitemap'] = false
      site.pages << json
    end
  end
end

# The backlinks, before the post's footer
Jekyll::Hooks.register :posts, :post_render do |post|
  next if Array(post.data['backlinks']).empty?

  html = NotesGraph.render_include(post.site, 'backlinks.html', post)
  post.output = NotesGraph.insert_before(post.output, [NotesGraph::TAIL_MARKER], html, post.relative_path)
end

# The graph, as the first section of the right panel's "access" block, above "Recently Updated".
# Inside that block it takes Chirpy's panel styles, and the block stays the panel's only child
# on pages without a table of contents, which is what keeps it sticky (.access:only-child). On a
# post, _plugins/post-panel.rb leaves out "Recently Updated", so the graph comes first and
# Chirpy's "Contents" follows the block.
Jekyll::Hooks.register [:pages, :documents], :post_render do |doc|
  next unless doc.output_ext == '.html' && doc.output&.include?('id="panel-wrapper"')
  next if doc.data['panel_graph'] == false # the Graph tab, which shows the graph itself

  html = NotesGraph.render_include(doc.site, 'notes-graph.html', doc)
  doc.output = NotesGraph.prepend_to(doc.output, NotesGraph::ACCESS_MARKER, html, doc.relative_path)
end
