#!/usr/bin/env ruby
#
# Replace the content of Chirpy's footer with _includes/site-footer.html on every page.
#
# Chirpy's footer.html holds the copyright line and the "Using the Chirpy theme" line.
# Instead of copying that file (and drifting from theme updates), this hook edits the
# rendered pages. The footer element itself stays, so Chirpy's layout still finds it.

FOOTER = %r{<footer\s+aria-label="Site Info"[^>]*>.*?</footer>}m

Jekyll::Hooks.register :site, :pre_render do |site|
  template = site.liquid_renderer.file('site-footer').parse('{% include site-footer.html %}')
  site.config['site_footer_html'] = template.render!(site.site_payload, registers: { site: site })
end

Jekyll::Hooks.register [:pages, :documents], :post_render do |doc|
  next unless doc.output_ext == '.html' && doc.output.include?('<footer')

  html = doc.site.config['site_footer_html']
  footer = %(<footer aria-label="Site Info" class="site-footer">\n#{html}</footer>)
  output = doc.output.sub(FOOTER) { footer }
  if output.equal?(doc.output) || output == doc.output
    Jekyll.logger.warn 'Site footer:', "no Chirpy footer found in #{doc.relative_path}; the theme's markup may have changed"
  end
  doc.output = output
end
