#!/usr/bin/env ruby
#
# Compare _plugins/jhep.rb with BibTeX and JHEP.bst, entry by entry.
#
# BibTeX formats every entry of a .bib file with JHEP.bst; the text of each entry, after
# the LaTeX markup is removed, must match the text of the HTML that _plugins/jhep.rb
# writes, and the links must match in order. Requires bibtex (TeX Live or MacTeX).
#
# Usage:
#   bundle exec ruby tools/bib/check.rb                       # _bibliography/references.bib
#   bundle exec ruby tools/bib/check.rb tools/bib/test.bib    # the test entries

require 'tmpdir'
require 'fileutils'
require_relative '../../_plugins/jhep'

root = File.expand_path('../..', __dir__)
bib = File.expand_path(ARGV[0] || File.join(root, '_bibliography', 'references.bib'))
bst = File.join(__dir__, 'JHEP.bst')

# Text without markup, with spaces made plain and none before punctuation
def plain(text)
  text.gsub(/\u00a0/, ' ').gsub(/\s+/, ' ').gsub(/ ([.,])/, '\1').strip
end

bbl = Dir.mktmpdir do |dir|
  FileUtils.cp(bib, File.join(dir, 'refs.bib'))
  FileUtils.cp(bst, File.join(dir, 'JHEP.bst'))
  File.write(File.join(dir, 'test.aux'), "\\citation{*}\n\\bibstyle{JHEP}\n\\bibdata{refs}\n")
  log = `cd "#{dir}" && bibtex test 2>&1`
  abort "bibtex failed:\n#{log}" unless File.exist?(File.join(dir, 'test.bbl'))
  File.read(File.join(dir, 'test.bbl'))
end

expected = bbl.split(/\\bibitem\{/).drop(1).to_h do |item|
  key, body = item.split('}', 2)
  body = body.sub(/\\end\{thebibliography\}.*/m, '')
  links = body.scan(/\\href\{([^}]*)\}/).flatten
  latex = body.gsub(/\\href\{[^}]*\}/, '').gsub('\\newblock', ' ').gsub(/\\(bfseries|ttfamily|scshape)\b\s*/, '').gsub('\/', '')
              .gsub('``', '“').gsub("''", '”')
  [key, [plain(JHEP.visible(JHEP.html(latex))), links]]
end

entries = JHEP.entries(bib)
failures = 0
entries.each do |key, fields|
  out = JHEP.format(fields)
  text = plain(JHEP.visible(out))
  links = out.scan(/href="([^"]*)"/).flatten.map { |url| CGI.unescapeHTML(url) }
  want_text, want_links = expected[key]
  if want_text == text && want_links == links
    puts "ok    #{key}"
  else
    failures += 1
    puts "DIFF  #{key}"
    puts "  JHEP.bst: #{want_text}", "  jhep.rb:  #{text}"
    puts "  links JHEP.bst: #{want_links.inspect}", "  links jhep.rb:  #{links.inspect}" if want_links != links
  end
end
puts "#{entries.size - failures} of #{entries.size} entries match JHEP.bst"
exit(failures.zero? ? 0 : 1)
