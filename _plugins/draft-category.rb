#!/usr/bin/env ruby
#
# Put every draft in the category Draft, every stub in _drafts/to-write in the
# category To Write, and every note in _drafts/private in the category Private.
# A stub is a stage before a draft: a note with its front matter and links, and
# the text still to be written.
#
# Drafts appear only in the local preview (`bash tools/run.sh -d`), and the
# category tells them apart from published posts there. The deployed site
# builds without --drafts, so it never shows them.
#
# The stage comes first among the categories, but it does not set the colour of
# the note: the graph and the home page colour a note by its subject, its first
# category after the stage, as they colour a published post, and they mark the
# stage with a dashed outline (_plugins/notes-graph.rb, _plugins/home-tiles.rb).

module NoteStage
  STAGES = ['Draft', 'To Write', 'Private'].freeze

  module_function

  # The first category that is not a stage, which sets the colour of the note
  def subject(doc)
    (Array(doc.data['categories']) - STAGES).first.to_s
  end

  # Draft, To Write or Private for a note that is not published, nil for a post
  def stage(doc)
    (Array(doc.data['categories']) & STAGES).first
  end
end

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
