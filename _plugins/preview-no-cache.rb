#!/usr/bin/env ruby
#
# In the local preview, tell the browser to keep no copy of any file, and retire any service
# worker that a production build installed.
#
# Jekyll's server sends Cache-Control: no-store with every page, but with live reload on
# it returns other files, such as styles, scripts and the graph data, before it adds its
# headers. A browser may then reuse an old stylesheet or script after a change. This adds
# the header to every response of `jekyll serve`. The deployed site is a static build, and
# this plugin does nothing there.

module PreviewNoCache
  def do_GET(request, response)
    result = super
    # The same key as Jekyll's own header, so that pages carry it once
    response.header.merge!('Cache-Control' => 'private, max-age=0, no-store, no-cache, must-revalidate')
    result
  end
end

Jekyll::Hooks.register :site, :after_init do |site|
  next unless site.config['serving']

  require 'jekyll/commands/serve/servlet'
  servlet = Jekyll::Commands::Serve::Servlet
  servlet.prepend(PreviewNoCache) unless servlet.ancestors.include?(PreviewNoCache)
end

# A browser that once opened a production build of the site on this address keeps Chirpy's
# service worker, which answers from its offline cache first, so the page stops updating. The
# browser checks the script of its worker on every visit and installs it again when it has
# changed. The preview therefore serves, in place of Chirpy's worker, one that deletes the
# caches, unregisters itself and reloads the open pages.
RETIRE_WORKER = <<~JS
  // The local preview has no offline cache (_plugins/preview-no-cache.rb). This worker
  // replaces one that a production build installed: it deletes the caches, unregisters
  // itself and reloads the open pages.
  self.addEventListener('install', () => self.skipWaiting());
  self.addEventListener('activate', (event) => {
    event.waitUntil((async () => {
      for (const key of await caches.keys()) await caches.delete(key);
      await self.registration.unregister();
      for (const client of await self.clients.matchAll({ type: 'window' })) client.navigate(client.url);
    })());
  });
JS

Jekyll::Hooks.register :site, :post_write do |site|
  next unless site.config['serving']

  worker = File.join(site.dest, 'sw.min.js')
  File.write(worker, RETIRE_WORKER) if File.exist?(worker)
end
