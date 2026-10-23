#!/usr/bin/env ruby
#
# Put every draft in the category Draft, and every note in _drafts/private in
# the category Private, and mark their cards on the home page.
#
# Drafts appear only in the local preview (`bash tools/run.sh -d`), and the
# category tells them apart from published posts there. The deployed site
# builds without --drafts, so it never shows them. The cards get the class
# note-draft or note-private, which _sass/_note-cards.scss colours.

def note_kind(post)
  post.relative_path.start_with?('_drafts/private/') ? 'Private' : 'Draft'
end

Jekyll::Hooks.register :site, :post_read do |site|
  site.posts.docs.each do |post|
    next unless post.draft?

    kind = note_kind(post)
    post.data['categories'] = [kind] + (Array(post.data['categories']) - [kind])
  end
end

# The class goes on Chirpy's .post-preview link, which draws the card; the
# <article> around it stays as it is, since _plugins/home-hero.rb looks for it
Jekyll::Hooks.register :pages, :post_render do |page|
  site = page.site
  next unless site.show_drafts && page.output&.include?('class="post-preview')

  kinds = site.posts.docs.select(&:draft?).to_h do |post|
    ["#{site.baseurl}#{post.url}", "note-#{note_kind(post).downcase}"]
  end
  page.output = page.output.gsub(/<a href="([^"]+)" class="post-preview/) do |link|
    kind = kinds[Regexp.last_match(1)]
    kind ? link.sub('class="post-preview', %(class="post-preview #{kind})) : link
  end
end
