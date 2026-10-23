#!/usr/bin/env ruby
#
# Strip HTML tags from the <title> of every page, and give a tab its own title when Chirpy
# has none for it.
#
# A post title may contain markup, e.g. "Solving ODEs using <code>odeint</code>", which
# Chirpy shows as a code chip in the heading. The <title> element cannot hold markup, so
# the browser tab and bookmarks would show the tags as text. The heading is left as it is.
#
# Chirpy takes the <title> of a tab from its locale file (_data/locales/en.yml in the
# theme), which names only its own tabs, so a tab of this site, such as Note Graph, would
# get an empty title before " | Quasinormal Notes".

Jekyll::Hooks.register [:pages, :documents], :post_render do |doc|
  next unless doc.output_ext == '.html' && doc.output&.include?('<title>')

  doc.output = doc.output.sub(%r{<title>(.*?)</title>}m) do
    title = Regexp.last_match(1).gsub(/<[^>]+>/, '').strip
    title = "#{doc.data['title']} #{title}" if title.start_with?('|') && doc.respond_to?(:collection) && doc.collection&.label == 'tabs'
    "<title>#{title}</title>"
  end
end
