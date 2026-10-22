#!/usr/bin/env ruby
#
# Strip HTML tags from the <title> of every page.
#
# A post title may contain markup, e.g. "Solving ODEs using <code>odeint</code>", which
# Chirpy shows as a code chip in the heading. The <title> element cannot hold markup, so
# the browser tab and bookmarks would show the tags as text. The heading is left as it is.

Jekyll::Hooks.register [:pages, :documents], :post_render do |doc|
  next unless doc.output_ext == '.html' && doc.output&.include?('<title>')

  doc.output = doc.output.sub(%r{<title>(.*?)</title>}m) do
    "<title>#{Regexp.last_match(1).gsub(/<[^>]+>/, '')}</title>"
  end
end
