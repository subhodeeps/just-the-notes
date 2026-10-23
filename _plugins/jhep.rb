#!/usr/bin/env ruby
#
# References in the style of JHEP.bst, version 2.18, by SISSA Medialab
# (https://jhep.sissa.it/jhep/help/JHEP/TeXclass/DOCS/JHEP.bst, kept in tools/bib/).
#
# jekyll-scholar reads _bibliography/references.bib, numbers the citations in the order
# in which a post first cites them, and renders {% bibliography %} through the template in
# _config.yml, which calls the Liquid filter jhep on each entry. A CSL style cannot put a
# link around a span of text, as JHEP.bst does with the journal reference, so this file
# ports the functions of JHEP.bst to Ruby and writes HTML in place of LaTeX: \emph becomes
# <em>, \bfseries <strong>, \ttfamily and \scshape a span of class bib-tt or bib-sc, \href
# a link, and ~ a non-breaking space. Names, initials and sentence case follow the rules of
# BibTeX itself. Math in $...$ passes through to MathJax. Cross-references (crossref) are
# not supported.
#
# tools/bib/check.rb compares the output with that of BibTeX and JHEP.bst, entry by entry.

require 'bibtex'
require 'cgi'
require 'latex/decode'

module JHEP
  NBSP = " "

  # The month macros of JHEP.bst
  MONTHS = {
    'jan' => 'Jan.', 'feb' => 'Feb.', 'mar' => 'Mar.', 'apr' => 'Apr.', 'may' => 'May', 'jun' => 'June',
    'jul' => 'July', 'aug' => 'Aug.', 'sep' => 'Sept.', 'oct' => 'Oct.', 'nov' => 'Nov.', 'dec' => 'Dec.'
  }.freeze

  # LaTeX font commands with an argument, and the HTML that replaces them
  FONTS = {
    'emph' => ['<em>', '</em>'], 'textit' => ['<em>', '</em>'], 'textbf' => ['<strong>', '</strong>'],
    'textsc' => ['<span class="bib-sc">', '</span>'], 'texttt' => ['<span class="bib-tt">', '</span>'],
    'textrm' => ['', '']
  }.freeze

  module_function

  # ---- Entries ----------------------------------------------------------------------------

  # The entries of a .bib file, with names and months left as written, cached until the
  # file changes
  def entries(path)
    @entries ||= {}
    mtime = File.mtime(path)
    cached = @entries[path]
    return cached[1] if cached && cached[0] == mtime

    bib = BibTeX.open(path, parse_names: false, parse_months: false)
    bib.replace_strings
    bib.join_strings
    table = bib.data.select { |item| item.is_a?(BibTeX::Entry) }.to_h do |entry|
      fields = entry.fields.to_h { |name, value| [name.to_s.downcase, value.to_s] }
      [entry.key.to_s, fields.merge('@type' => entry.type.to_s.downcase)] # 'type' is a field of BibTeX
    end
    @entries[path] = [mtime, table]
    table
  end

  # ---- Braces -------------------------------------------------------------------------------

  def matching_brace(s, open)
    depth = 0
    (open...s.length).each do |i|
      depth += 1 if s[i] == '{'
      depth -= 1 if s[i] == '}'
      return i if depth.zero?
    end
    s.length - 1
  end

  # Split s at every match of separator that lies outside braces
  def split_top(s, separator)
    parts = []
    depth = 0
    start = 0
    i = 0
    while i < s.length
      c = s[i]
      if c == '{'
        depth += 1
      elsif c == '}'
        depth -= 1
      elsif depth.zero? && (m = s[i..].match(separator))
        parts << s[start...i]
        i += m[0].length
        start = i
        next
      end
      i += 1
    end
    parts << s[start..]
  end

  # ---- Names, after format.name$ of BibTeX --------------------------------------------------

  def split_names(field)
    split_top(field.strip, /\A\s+and\s+/i).map(&:strip).reject(&:empty?)
  end

  # The words of a name part, each with the separator that follows it: '-', '~' or ' '
  def words(part)
    tokens = []
    current = +''
    depth = 0
    part.strip.each_char do |c|
      depth += 1 if c == '{'
      depth -= 1 if c == '}'
      if depth.zero? && c.match?(/[\s~-]/)
        if current.empty?
          tokens.last[1] = c == '-' ? '-' : tokens.last[1] if tokens.any?
        else
          tokens << [current, c.match?(/\s/) ? ' ' : c]
          current = +''
        end
      else
        current << c
      end
    end
    tokens << [current, ''] unless current.empty?
    tokens
  end

  # Whether a word starts in lower case, as BibTeX decides it: the first letter outside
  # braces counts, a special character such as {\'e} counts by its letter, and other brace
  # groups have no case
  def lower?(word)
    i = 0
    while i < word.length
      c = word[i]
      if c == '{'
        close = matching_brace(word, i)
        if word[i + 1] == '\\'
          group = word[i..close]
          command = group[/\A\{\\([A-Za-z]+)/, 1]
          return command == command.downcase if command && %w[OE AE AA O L oe ae aa o l i j ss].include?(command)

          letter = group.sub(/\A\{\\(?:[A-Za-z]+|.)/, '')[/[A-Za-z]/]
          return letter ? letter == letter.downcase : false
        end
        i = close + 1
        next
      end
      return c == c.downcase if c.match?(/[A-Za-z]/)

      i += 1
    end
    false
  end

  def join_words(tokens)
    tokens.each_with_index.map { |(word, sep), i| i == tokens.length - 1 ? word : word + (sep == '-' ? '-' : sep) }.join
  end

  def parse_name(name)
    parts = split_top(name, /\A,/).map(&:strip)
    case parts.length
    when 1
      tokens = words(parts[0])
      return { first: [], von: [], last: tokens, jr: '' } if tokens.length < 2

      start = (0...tokens.length - 1).find { |i| lower?(tokens[i][0]) }
      if start.nil?
        { first: tokens[0...-1], von: [], last: [tokens[-1]], jr: '' }
      else
        stop = (start...tokens.length - 1).select { |i| lower?(tokens[i][0]) }.max
        { first: tokens[0...start], von: tokens[start..stop], last: tokens[(stop + 1)..], jr: '' }
      end
    else
      tokens = words(parts[0])
      stop = (0...tokens.length - 1).select { |i| lower?(tokens[i][0]) }.max
      von = stop ? tokens[0..stop] : []
      last = stop ? tokens[(stop + 1)..] : tokens
      first = words(parts.length == 2 ? parts[1] : parts[2])
      { first: first, von: von, last: last, jr: parts.length > 2 ? parts[1] : '' }
    end
  end

  # {f.}: the first letter of each word of the first names, with a full stop, the words of a
  # hyphenated name joined by a hyphen; remove.spaces of JHEP.bst then drops spaces and ties
  def initials(tokens)
    tokens.each_with_index.map do |(word, sep), i|
      letter = word.start_with?('{') ? word[0..matching_brace(word, 0)] : word[0]
      "#{letter}.#{sep == '-' && i < tokens.length - 1 ? '-' : ''}"
    end.join
  end

  # {f.}~{vv~}{ll}{, jj}
  def format_name(name)
    return 'others' if name.strip == 'others'

    n = parse_name(name)
    first = initials(n[:first])
    out = +''
    out << first << '~' unless first.empty?
    out << join_words(n[:von]) << '~' unless n[:von].empty?
    out << join_words(n[:last])
    out << ', ' << n[:jr] unless n[:jr].empty?
    out
  end

  # format.names: "A, B and C", and from the seventh name on, "et al."
  def format_names(field)
    names = split_names(field)
    out = +''
    names.each_with_index do |name, index|
      ptr = index + 1
      left = names.length - index
      t = format_name(name)
      if ptr > 6
        left = 0
        t = 'others'
      end
      if ptr > 1
        if left > 1
          out << ', ' << t
        else
          out << (t == 'others' ? ' et~al.' : " and #{t}")
        end
      else
        out << t
      end
      break if left.zero?
    end
    html(out)
  end

  # ---- Case and LaTeX -----------------------------------------------------------------------

  # change.case$ with "t": lower case outside braces, except the first character and the
  # first character after a colon and a space; special characters such as {\'E} change too
  def sentence_case(s)
    out = +''
    depth = 0
    colon = false
    i = 0
    while i < s.length
      c = s[i]
      if depth.zero? && c == '{' && s[i + 1] == '\\'
        close = matching_brace(s, i)
        group = s[i..close]
        keep = i.zero? || (colon && s[i - 1].match?(/\s/))
        out << (keep ? group : group.gsub(/\\([A-Za-z]+)|([A-Za-z])/) do
          if Regexp.last_match(1)
            command = Regexp.last_match(1)
            %w[OE AE AA O L].include?(command) ? "\\#{command.downcase}" : "\\#{command}"
          else
            Regexp.last_match(2).downcase
          end
        end)
        colon = false
        i = close + 1
        next
      end
      if c == '{'
        depth += 1
        out << c
      elsif c == '}'
        depth -= 1 if depth.positive?
        out << c
      elsif depth.positive?
        out << c
      else
        keep = i.zero? || (colon && s[i - 1].match?(/\s/))
        out << (keep ? c : c.downcase)
        if c == ':'
          colon = true
        elsif !c.match?(/\s/)
          colon = false
        end
      end
      i += 1
    end
    out
  end

  # LaTeX to HTML: font commands become tags, accents and dashes become characters, ties
  # become non-breaking spaces, braces go, and $...$ stays as it is for MathJax
  def html(s)
    s = s.to_s
    out = +''
    text = +''
    flush = lambda do
      plain = text.gsub(/(?<!\\)~/, NBSP)
      out << CGI.escapeHTML(LaTeX.decode(plain).delete('{}'))
      text = +''
    end
    i = 0
    while i < s.length
      if s[i] == '$' && (close = s.index('$', i + 1))
        flush.call
        out << CGI.escapeHTML(s[i..close])
        i = close + 1
      elsif (m = s[i..].match(/\A\\([a-z]+)\s*\{/)) && FONTS.key?(m[1])
        flush.call
        open = i + m[0].length - 1
        close = matching_brace(s, open)
        out << FONTS[m[1]][0] << html(s[(open + 1)...close]) << FONTS[m[1]][1]
        i = close + 1
      else
        text << s[i]
        i += 1
      end
    end
    flush.call
    out
  end

  def visible(fragment)
    CGI.unescapeHTML(fragment.gsub(/<[^>]*>/, ''))
  end

  # add.period$: a full stop, unless the text already ends with . ? or !
  def add_period(fragment)
    visible(fragment).match?(/[.?!]\z/) ? fragment : "#{fragment}."
  end

  # ---- The output state machine of JHEP.bst -------------------------------------------------

  class Writer
    attr_accessor :state

    def initialize
      @out = +''
      @pending = +''
      @state = :before_all
    end

    def output(s)
      output_nonnull(s) unless s.nil? || s.empty?
    end

    def output_nonnull(s)
      @out << case @state
              when :mid then "#{@pending}, "
              when :after_quote, :after_quoted_block then "#{@pending} "
              when :before_all then @pending
              else "#{JHEP.add_period(@pending)} " # after a sentence or a block
              end
      @state = :mid
      @pending = s
    end

    def blank_sep
      @state = :after_quote
    end

    def new_block
      return if @state == :before_all

      @state = @state == :after_quote ? :after_quoted_block : :after_block
    end

    def new_sentence
      @state = :after_sentence unless %i[after_block before_all].include?(@state)
    end

    def fin_entry
      @out << (@state == :after_quoted_block ? @pending : JHEP.add_period(@pending))
    end

    def to_s
      @out
    end
  end

  # ---- The formatting functions of JHEP.bst --------------------------------------------------

  class Entry
    def initialize(fields)
      @f = fields
      @w = Writer.new
    end

    def field(name)
      value = @f[name].to_s
      value.strip.empty? ? nil : value
    end

    def missing?(name)
      !@f.key?(name)
    end

    def h(name)
      JHEP.html(field(name))
    end

    def link(url, text)
      %(<a href="#{CGI.escapeHTML(url)}">#{text}</a>)
    end

    def format_authors
      field('author') ? JHEP.format_names(field('author')) : ''
    end

    def format_editors
      return '' unless field('editor')

      count = JHEP.split_names(field('editor')).length
      JHEP.format_names(field('editor')) + (count > 1 ? ', eds.' : ', ed.')
    end

    def format_collaboration
      field('collaboration') ? %(<span class="bib-sc">#{h('collaboration')}</span> collaboration) : ''
    end

    def format_author_or_collaboration
      field('collaboration') ? format_collaboration : format_authors
    end

    def format_title
      field('title') ? "<em>#{JHEP.html(JHEP.sentence_case(field('title')))}</em>, " : ''
    end

    def format_title_p
      field('title') ? "“#{JHEP.html(JHEP.sentence_case(field('title')))}.”" : ''
    end

    def format_btitle
      field('title') ? "<em>#{h('title')}</em>" : ''
    end

    def doi_url
      "https://doi.org/#{field('doi')}"
    end

    def format_doi_text
      field('doi') ? link(doi_url, CGI.escapeHTML(field('doi'))) : ''
    end

    def formatfull_doi
      field('doi') ? link(doi_url, 'DOI') : ''
    end

    def format_url
      field('url') ? link(field('url'), CGI.escapeHTML(field('url'))) : ''
    end

    def format_eprint
      return '' unless field('eprint')

      id = field('archive') ? "#{field('archive')}/#{field('eprint')}" : field('eprint')
      link("https://arxiv.org/abs/#{id}", %(<span class="bib-tt">#{CGI.escapeHTML(id)}</span>))
    end

    def format_eprint_paren
      field('eprint') ? "[#{format_eprint}]" : ''
    end

    def month
      m = field('month')
      m && (MONTHS[m.strip.downcase[0, 3]] || m)
    end

    def format_date
      year = h('year')
      return (month || '') unless field('year')

      month ? "#{month}, #{year}" : year
    end

    def format_date_paren
      return (month || '') unless field('year')

      month ? "(#{month}, #{h('year')})" : "(#{h('year')})"
    end

    def format_date_paren_nomonth
      field('year') ? "(#{h('year')})" : ''
    end

    def format_bvolume
      return '' unless field('volume')

      "vol.#{NBSP}#{h('volume')}" + (field('series') ? " of <em>#{h('series')}</em>" : '')
    end

    def format_number_series
      return '' if field('volume')
      return field('series') ? h('series') : '' unless field('number')

      "#{@w.state == :mid ? 'no.' : 'No.'}#{NBSP}#{h('number')}" + (field('series') ? " in #{h('series')}" : '')
    end

    def format_edition
      field('edition') ? "#{JHEP.html(field('edition').downcase)}#{NBSP}ed." : ''
    end

    def multi_page?
      field('pages').match?(/[-,+]/)
    end

    def format_pages
      return '' unless field('pages')

      multi_page? ? "pp.#{NBSP}#{JHEP.html(field('pages').gsub(/(?<!-)-(?!-)/, '--'))}" : "p.#{NBSP}#{h('pages')}"
    end

    def format_pages_nopp
      return '' unless field('pages')

      multi_page? ? JHEP.html(field('pages')[/\A[^-]*/]) : h('pages')
    end

    def format_volume
      field('volume') ? "<strong>#{h('volume')}</strong>" : ''
    end

    def format_in_ed_booktitle
      return '' unless field('booktitle')

      "in <em>#{h('booktitle')}</em>" + (field('editor') ? ", #{format_editors}" : '')
    end

    def format_thesis_type(default)
      return default unless field('type')

      type = field('type')
      JHEP.html(@w.state == :after_block ? JHEP.sentence_case(type) : type.downcase)
    end

    def format_paddress
      field('address') ? "(#{h('address')})" : ''
    end

    def format_tr_number
      @w.output(field('type') ? h('type') : 'Tech. Rep.')
      @w.blank_sep
      field('url') ? link(field('url'), h('number')) : h('number')
    end

    # ---- Entry types ----

    def article
      @w.output format_author_or_collaboration
      @w.output format_editors if field('author').nil? && field('editor')
      @w.output format_title
      @w.blank_sep
      if field('journal').nil?
        @w.output format_eprint
      else
        open = field('doi') ? %(<a href="#{CGI.escapeHTML(doi_url)}">) : ''
        close = field('doi') ? '</a>' : ''
        @w.state = :before_all
        @w.output "#{open}<em>#{h('journal')}</em>"
        @w.blank_sep
        @w.output format_volume
        @w.blank_sep
        @w.output format_date_paren_nomonth
        @w.blank_sep
        @w.output format_pages_nopp + close
        @w.blank_sep
      end
      if missing?('report')
        @w.output format_eprint_paren if field('journal')
      else
        @w.blank_sep
        @w.output h('report')
        @w.output format_eprint_paren
      end
      @w.new_sentence
      @w.fin_entry
    end

    def book
      @w.output format_collaboration
      @w.output(field('author') ? format_authors : format_editors)
      @w.output format_btitle
      @w.output format_bvolume
      @w.output format_number_series
      @w.output h('publisher')
      @w.output h('address')
      @w.output format_edition
      @w.blank_sep
      @w.output format_date_paren
      @w.output format_doi_text
      @w.output format_eprint_paren
      @w.fin_entry
    end

    def booklet
      @w.output format_author_or_collaboration
      if field('title').nil?
        @w.new_sentence if field('howpublished')
      else
        quoted = field('howpublished') || (field('address').nil? && field('month').nil? && field('year').nil?)
        @w.output(quoted ? format_title_p : format_title)
        @w.blank_sep
      end
      @w.output h('howpublished')
      @w.output h('address')
      @w.output format_date
      @w.new_block
      @w.output h('doi')
      @w.fin_entry
    end

    def incollection(date = :paren)
      @w.output format_author_or_collaboration
      @w.output format_title
      @w.blank_sep
      @w.output format_in_ed_booktitle
      @w.output format_bvolume
      @w.output format_number_series
      @w.output format_paddress
      @w.output format_pages
      @w.output h('organization')
      @w.output h('publisher')
      if date == :paren
        @w.blank_sep
        @w.output format_date_paren_nomonth
      else
        @w.output format_date
      end
      @w.output(field('doi') ? formatfull_doi : format_url)
      @w.blank_sep
      @w.output format_eprint_paren
      @w.fin_entry
    end

    def inproceedings
      incollection(:plain)
    end

    def manual
      @w.output format_collaboration
      if field('author').nil?
        if field('organization')
          @w.output h('organization')
          @w.output h('address')
        end
      else
        @w.output format_authors
      end
      @w.output format_btitle
      if field('author').nil?
        if field('organization').nil?
          @w.new_block if field('address')
          @w.output h('address')
        end
      else
        @w.new_block if field('organization') || field('address')
        @w.output h('organization')
        @w.output h('address')
      end
      @w.output format_edition
      @w.output format_date
      @w.new_block
      @w.output h('doi')
      @w.fin_entry
    end

    def mastersthesis
      @w.output format_authors
      @w.output format_title
      @w.blank_sep
      @w.output format_thesis_type('Master’s thesis') # LaTeX sets ' as ’
      @w.output h('school')
      @w.output h('address')
      @w.output format_date
      @w.output format_doi_text
      @w.output format_eprint_paren
      @w.fin_entry
    end

    def misc
      @w.output format_collaboration
      @w.output format_authors
      if field('title').nil?
        @w.new_sentence if field('howpublished')
      else
        quoted = field('howpublished') || (field('month').nil? && field('year').nil?)
        @w.output(quoted ? format_title_p : format_title)
        @w.blank_sep
      end
      @w.output h('howpublished')
      @w.output format_date
      @w.new_block
      @w.output h('doi')
      @w.fin_entry
    end

    def phdthesis
      @w.output format_authors
      @w.output format_btitle
      @w.output format_thesis_type('Ph.D. thesis')
      @w.output h('school')
      @w.output h('address')
      @w.output format_date
      @w.new_block
      @w.output format_eprint
      @w.new_block
      @w.output h('doi')
      @w.fin_entry
    end

    def proceedings
      @w.output(field('editor') ? format_editors : h('organization'))
      @w.output format_btitle
      @w.output format_bvolume
      @w.output format_number_series
      @w.output format_paddress
      @w.output h('organization') if field('editor')
      @w.output h('publisher')
      @w.output format_date
      @w.new_block
      @w.output h('doi')
      @w.fin_entry
    end

    def techreport
      @w.output format_author_or_collaboration
      @w.output format_title
      @w.blank_sep
      @w.output format_tr_number
      @w.output h('institution')
      @w.output h('address')
      @w.blank_sep
      @w.output format_date_paren
      @w.output formatfull_doi
      @w.fin_entry
    end

    def unpublished
      @w.output format_author_or_collaboration
      @w.output format_title_p
      @w.blank_sep
      @w.output format_date
      @w.fin_entry
    end

    TYPES = {
      'article' => :article, 'book' => :book, 'booklet' => :booklet, 'incollection' => :incollection,
      'inbook' => :incollection, 'inproceedings' => :inproceedings, 'conference' => :inproceedings,
      'manual' => :manual, 'electronic' => :manual, 'mastersthesis' => :mastersthesis, 'misc' => :misc,
      'phdthesis' => :phdthesis, 'proceedings' => :proceedings, 'techreport' => :techreport,
      'unpublished' => :unpublished
    }.freeze

    def to_html
      send(TYPES.fetch(@f['@type'], :misc))
      @w.to_s
    end
  end

  def format(fields)
    Entry.new(fields).to_html
  end

  # Runs of three or more consecutive numbers in a citation become a range, as the cite
  # package of LaTeX writes them in a JHEP paper: "1, 2, 3, 4, 7" becomes "1–4, 7". The
  # citation style asks for this, but citeproc-ruby does not apply it. A citation with
  # anything other than numbers, such as a locator, stays as it is.
  def collapse(numbers)
    items = numbers.split(/,\s*/)
    return numbers unless items.all? { |item| item.match?(/\A\d+\z/) }

    runs = items.map(&:to_i).slice_when { |a, b| b != a + 1 }
    runs.map { |run| run.length >= 3 ? "#{run.first}–#{run.last}" : run.join(', ') }.join(', ')
  end
end

# {{ entry | jhep }} in the bibliography template of jekyll-scholar (_config.yml)
if defined?(Liquid)
  module Jekyll
    module JHEPFilter
      def jhep(entry)
        site = @context.registers[:site]
        scholar = site.config['scholar'] || {}
        path = File.join(site.source, scholar['source'] || '_bibliography', scholar['bibliography'] || 'references.bib')
        fields = JHEP.entries(path)[entry['key']]
        fields ? JHEP.format(fields) : CGI.escapeHTML(entry['key'].to_s)
      end
    end
  end

  Liquid::Template.register_filter(Jekyll::JHEPFilter)
end

# The citations of jekyll-scholar on each rendered page, [1, 2, 3] -> [1–3]
if defined?(Jekyll::Hooks)
  Jekyll::Hooks.register [:pages, :documents], :post_render do |doc|
    next unless doc.output&.include?('class="citation"')

    doc.output = doc.output.gsub(%r{(<a class="citation" href="[^"]*">)\[([^\]<]*)\](</a>)}) do
      "#{Regexp.last_match(1)}[#{JHEP.collapse(Regexp.last_match(2))}]#{Regexp.last_match(3)}"
    end
  end
end
