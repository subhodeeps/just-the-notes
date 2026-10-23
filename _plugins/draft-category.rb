#!/usr/bin/env ruby
#
# Put every draft in the category Draft, every stub in _drafts/to-write in the
# category To Write, and every note in _drafts/private in the category Private,
# and mark their cards on the home page. A stub is a stage before a draft: a note
# with its front matter and links, and the text still to be written.
#
# Drafts appear only in the local preview (`bash tools/run.sh -d`), and the
# category tells them apart from published posts there. The deployed site
# builds without --drafts, so it never shows them. The cards get the class
# note-draft, note-to-write or note-private, which _sass/_note-cards.scss colours.

def note_kind(post)
  return 'Private' if post.relative_path.start_with?('_drafts/private/')
  return 'To Write' if post.relative_path.start_with?('_drafts/to-write/')

  'Draft'
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
    ["#{site.baseurl}#{post.url}", "note-#{note_kind(post).downcase.tr(' ', '-')}"]
  end
  page.output = page.output.gsub(/<a href="([^"]+)" class="post-preview/) do |link|
    kind = kinds[Regexp.last_match(1)]
    kind ? link.sub('class="post-preview', %(class="post-preview #{kind})) : link
  end
end
