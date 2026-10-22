#!/usr/bin/env ruby
#
# Keep inline code from wrapping inside a word, such as after the hyphen of a flag
# (`-rfbport=5900` would otherwise break as "-" / "rfbport=5900").
#
# Browsers may break a line after any hyphen, and CSS cannot turn that off for hyphens
# alone, while `white-space: nowrap` on the whole snippet pushes long commands past the
# edge of the page. So each space-free token of inline code is wrapped in a span that does
# not break (.code-token in _sass/_code-font.scss): long commands still wrap between words,
# never inside one. Tokens longer than MAX_TOKEN stay breakable, so they cannot overflow
# a phone screen. Code blocks are left alone, and the copied text is unchanged.

MAX_TOKEN = 40
INLINE_CODE = %r{(<code class="[^"]*\bhighlighter-rouge\b[^"]*">)(.*?)(</code>)}m

Jekyll::Hooks.register [:documents, :pages], :post_render do |doc|
  next unless doc.output_ext == '.html' && doc.output.include?('highlighter-rouge')

  doc.output = doc.output.gsub(INLINE_CODE) do
    open, body, close = Regexp.last_match.captures
    next Regexp.last_match[0] if body.include?('<') # not plain text: leave it as it is

    tokens = body.gsub(/[^\s]+/) do |token|
      token.include?('-') && token.length <= MAX_TOKEN ? %(<span class="code-token">#{token}</span>) : token
    end
    open + tokens + close
  end
end
