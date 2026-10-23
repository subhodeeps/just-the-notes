#!/usr/bin/env ruby
#
# In the local preview, tell the browser to keep no copy of any file.
#
# Jekyll's server sends Cache-Control: no-store with every page, but with live reload on
# it returns other files, such as styles, scripts and the graph data, before it adds its
# headers. A browser may then reuse an old stylesheet or script after a change. This adds
# the header to every response of `jekyll serve`. The deployed site is a static build, and
# this plugin does nothing there.

module PreviewNoCache
  def do_GET(request, response)
    result = super
    # The same key as Jekyll's own header, so that pages carry it once
    response.header.merge!('Cache-Control' => 'private, max-age=0, no-store, no-cache, must-revalidate')
    result
  end
end

Jekyll::Hooks.register :site, :after_init do |site|
  next unless site.config['serving']

  require 'jekyll/commands/serve/servlet'
  servlet = Jekyll::Commands::Serve::Servlet
  servlet.prepend(PreviewNoCache) unless servlet.ancestors.include?(PreviewNoCache)
end
