#!/usr/bin/env ruby
#
# Serve the files that drafts use from inside _drafts.
#
# _drafts mirrors the root of the site: a draft includes its scripts from
# _drafts/_includes and shows its images from _drafts/assets, with the same
# {% include %} tags and /assets/ URLs that a published post uses. To publish
# a draft, move each file to the same path at the root and the post needs no
# changes. Jekyll reads these folders only with --drafts
# (`bash tools/run.sh -d`), so the deployed site never sees them.

Jekyll::Hooks.register :site, :post_read do |site|
  next unless site.show_drafts

  drafts = site.in_source_dir('_drafts')

  # Look in _drafts/_includes after _includes, and before the theme
  includes = File.join(drafts, '_includes')
  if File.directory?(includes) && !site.includes_load_paths.include?(includes)
    site.includes_load_paths.insert(1, includes)
  end

  # _config.yml excludes _drafts/assets, so that Jekyll does not read the
  # images as drafts; add them here as static files under /assets/
  Dir.glob('assets/**/*', base: drafts).sort.each do |path|
    next if File.directory?(File.join(drafts, path)) || File.basename(path).start_with?('.')

    site.static_files << Jekyll::StaticFile.new(site, drafts, File.dirname(path), File.basename(path))
  end
end
