# Chirpy Starter

[![Gem Version](https://img.shields.io/gem/v/jekyll-theme-chirpy)][gem]&nbsp;
[![GitHub license](https://img.shields.io/github/license/cotes2020/chirpy-starter.svg?color=blue)][mit]

A minimal, ready-to-use template for creating a blog with the [**Chirpy**][chirpy] Jekyll theme. Get up and running in minutes with all critical files pre-configured.

## Why This Starter Exists

When installing Chirpy through [RubyGems.org][gem], Jekyll can only read a subset of theme files (`_data`, `_layouts`, `_includes`, `_sass`, `assets`) and limited `_config.yml` options from the gem. As a result, users cannot enjoy the full out-of-the-box experience that Chirpy offers.

To unlock all features, the following files must be present in your Jekyll site:

```shell
.
├── _config.yml
├── _plugins
├── _tabs
└── index.html
```

This starter bundles those files from the latest **Chirpy** release along with a [CD][CD] workflow, so you can start writing immediately.

## Local Development

`tools/setup.sh` builds a self-contained toolchain in `.venv/` (git-ignored), similar to a Python virtualenv. Nothing is installed globally and the system Ruby is left untouched.

| Component                         | Location        | Notes                                                        |
| --------------------------------- | --------------- | ------------------------------------------------------------ |
| Ruby 3.4.x                        | `.venv/ruby`    | Compiled from source with ruby-build; matches the CI version |
| libyaml                           | `.venv/deps`    | Needed by Ruby's YAML extension (psych), which Jekyll uses   |
| Node LTS + npm                    | `.venv/node`    | Official tarball, checksum-verified                          |
| Bundler, Jekyll, Chirpy, html-proofer | `.venv/bundle`  | Installed from the `Gemfile`                                 |
| Python + numpy, scipy, matplotlib, amore | `.venv/python` | Optional, for the figures of posts; needs [uv](https://docs.astral.sh/uv/) |

### First-time setup

Requires Xcode Command Line Tools on macOS (`xcode-select --install`), plus `git`, `curl`, `tar` and `make`. Compiling Ruby takes a few minutes.

```shell
bash tools/setup.sh
```

The script is safe to re-run: components that are already installed are skipped and gems are brought up to date. To pin different versions, set `RUBY_SERIES` or `NODE_SERIES`, e.g. `RUBY_SERIES=3.3 bash tools/setup.sh`.

### Serving the site

```shell
source .venv/bin/activate   # put the local toolchain on PATH
bash tools/run.sh           # serve at http://127.0.0.1:4000 with live reload
deactivate                  # restore your shell when done
```

Other useful commands while activated:

- `bash tools/run.sh -p` builds in production mode.
- `bash tools/test.sh` builds the site and checks it with html-proofer, as CI does.
- `python _includes/code/pendulum_phase_portrait.py assets/images/nonlinearpendulum` redraws the figures of the ODE post (light and dark), with the packages of `tools/requirements-figures.txt`. The figures use LaTeX for text.

### Starting over

Delete the environment and run setup again:

```shell
rm -rf .venv && bash tools/setup.sh
```

## Linking Notes

Posts can link to each other Zettelkasten-style, with backlinks and a graph of the notes. Everything happens at build time in `_plugins/notes-graph.rb`; Chirpy's layouts are not changed.

### Writing links

| You write | You get |
| --- | --- |
| `[[ode]]` | A link to the post, with its title as the text |
| `[[2026-07-06-ode]]` | The same, by file name (what Foam inserts) |
| `[[ode\|the ODE note]]` | A link with your own text |
| `[[ode#a-heading]]` | A link to a section of the post |
| `[the ODE note](2026-07-06-ode.md)` | A relative `.md` link, which also works in the VS Code and GitHub previews |
| `[the ODE note](/posts/ode/)` | An ordinary link, which counts as a link between notes too |

A link to a note that does not exist yet is shown as muted text, and the build prints a warning. Code blocks and inline code are left alone, so `[[ -f file ]]` in a shell snippet is safe.

### What the site shows

- **Linked from:** at the end of each post, the notes that link to it (its backlinks).
- **The note graph:** in the right panel, posts as dots coloured by their first category, solid lines for links and faint dotted lines for shared tags. On a post it shows that post's neighbourhood; on other pages, every note. Hovering a dot shows its title, and clicking opens it. The colours follow the light and dark themes (`--graph-*` in `_sass/amore/`); a new top-level category needs a `--graph-node-<category>` colour there. Chirpy hides the right panel on screens narrower than 1200px.

### Foam in VS Code

The repository is set up for [Foam](https://foambubble.github.io/foam/): install the recommended extension, and VS Code offers `[[` completion, backlinks and a graph of the notes. `.vscode/settings.json` keeps Foam out of the build output and the toolchain, and stops it from appending link reference definitions to the notes, which the site does not need. **Foam: Create New Note** starts a draft in `_drafts/` from `.foam/templates/new-note.md`; to publish it, move it to `_posts/` as `YYYY-MM-DD-slug.md`. Links written as `[[slug]]` keep working after the move.

The idea of publishing a Foam workspace with Jekyll comes from hikerpig's [foam-jekyll-template](https://github.com/hikerpig/foam-jekyll-template), which rewrites Foam's links in the browser. This site does the same at build time, and adds backlinks and the graph.

## Usage

Check out the [theme's docs](https://github.com/cotes2020/jekyll-theme-chirpy/wiki).

## Contributing

This repository is automatically updated with new releases from the theme repository. If you encounter any issues or want to contribute to its improvement, please visit the [theme repository][chirpy] to provide feedback.

## License

This work is published under [MIT][mit] License.

[gem]: https://rubygems.org/gems/jekyll-theme-chirpy
[chirpy]: https://github.com/cotes2020/jekyll-theme-chirpy/
[CD]: https://en.wikipedia.org/wiki/Continuous_deployment
[mit]: https://github.com/cotes2020/chirpy-starter/blob/master/LICENSE
