#!/usr/bin/env ruby
#
# The right panel of a post shows "Connections" (the note graph, _plugins/notes-graph.rb) and
# Chirpy's "Contents", without Chirpy's "Recently Updated". The list of recent posts stays on the
# pages of the sidebar: the home page, the categories, the tags, the archives and the tabs.
#
# The hook removes the "Recently Updated" section from the panel's "access" block. The graph stays
# in that block, so Chirpy's "Contents" follows it and stays in view as the reader scrolls. If the
# theme's markup changes, the hook finds no section to remove and the panel stays as Chirpy
# renders it.

module PostPanel
  RECENT = '<section id="access-lastmod">'

  module_function

  # The section from its opening tag up to its </section>; it holds no other section
  def without_recent(output)
    start = output.index(RECENT)
    stop = start && output.index('</section>', start)
    return output unless stop

    output[0...start] + output[(stop + '</section>'.length)..]
  end
end

Jekyll::Hooks.register :posts, :post_render do |post|
  next unless post.output_ext == '.html'

  post.output = PostPanel.without_recent(post.output)
end
