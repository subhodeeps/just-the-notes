#!/usr/bin/env ruby
#
# Put every draft in the category Draft, every stub in _drafts/to-write in the
# category To Write, and every note in _drafts/private in the category Private.
# A stub is a stage before a draft: a note with its front matter and links, and
# the text still to be written.
#
# Drafts appear only in the local preview (`bash tools/run.sh -d`), and the
# category tells them apart from published posts there. The deployed site
# builds without --drafts, so it never shows them. As the first category, the
# stage also gives the note its colour in the graph and on its card on the home
# page (_plugins/home-tiles.rb).

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
