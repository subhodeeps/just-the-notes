#!/usr/bin/env ruby
#
# Tag every draft with "draft".
#
# Drafts appear only in the local preview (`bash tools/run.sh -d`), and the
# tag tells them apart from published posts there. The deployed site builds
# without --drafts, so it never shows them.

Jekyll::Hooks.register :site, :post_read do |site|
  site.posts.docs.each do |post|
    next unless post.draft?

    post.data['tags'] = (Array(post.data['tags']) + ['draft']).uniq
  end
end
