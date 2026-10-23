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
- `bash tools/run.sh -d` serves the notes in `_drafts/` alongside the posts. `_plugins/draft-category.rb` puts each draft in the category Draft, and each note in `_drafts/private/` in the category Private, ahead of its own categories, and gives their cards on the home page a teal or red stripe. The deployed site never builds them.

  Git ignores everything in `_drafts/`, and the folder mirrors the root of the site, so that a draft keeps its files beside it and uses them the way a published post does:

  ```
  _drafts/
  ├── slug.md                        # the draft
  ├── private/note.md                # a private note, never to be published
  ├── _includes/code/script.py       # {% include code/script.py %}
  └── assets/images/slug/name.png    # /assets/images/slug/name.png
  ```

  `_plugins/draft-files.rb` serves these files only with `-d`. To publish a draft, move each file to the same path at the root, and the draft to `_posts/` as `YYYY-MM-DD-slug.md`; the post itself needs no changes. Jekyll does not watch `_drafts/assets/`, so after you redraw a figure, save the draft or restart the preview to see it.
- `bash tools/test.sh` builds the site and checks it with html-proofer. The GitHub workflow (`.github/workflows/pages-deploy.yml`) runs the same check on every push; Vercel deploys the site from `main`.

### Syncing the drafts

The drafts live in a second, private repository, cloned into `_drafts/` itself. This repository ignores everything in `_drafts/` except `.gitkeep`, so it never sees the inner repository, its `.git` folder included. Jekyll skips folders whose names start with a dot, so it does not read `.git` as drafts either.

To set it up on the first device:

```shell
cd _drafts
printf '.gitkeep\n.DS_Store\n' > .gitignore
git init -b main
git add -A
git commit -m "Add the drafts"
gh repo create quasinormal-notes-private-notes --private --source=. --push
```

On another device, after you clone this repository:

```shell
cd _drafts
git init -b main
git remote add origin git@github.com:subhodeeps/quasinormal-notes-private-notes.git
git pull origin main
```

From then on, `git pull` and `git push` inside `_drafts/` sync the drafts. The inner `.gitignore` keeps the `.gitkeep` of this repository out of the drafts repository; without it, the pull on a second device stops on that file. When you publish a draft, its files move out of `_drafts/` into this repository, so the drafts repository holds only work in progress.

### Starting over

Delete the environment and run setup again:

```shell
rm -rf .venv && bash tools/setup.sh
```

## Writing Posts

Posts follow the style of the APS journals. The classes below come from the partials in `_sass/`.

### Figures

Each figure has a light and a dark version, and Chirpy shows the one that matches the theme. The caption goes below the figure:

```markdown
![Alt text](/assets/images/post/name-light.png){: .light width="1603" height="523" }
![Alt text](/assets/images/post/name-dark.png){: .dark width="1603" height="523" }

<span class="aps-label">Fig. 1.</span> Caption.
{: .aps-caption .aps-figure}
```

In the text, write Fig. 1, or Figure 1 at the start of a sentence.

### Tables

The caption goes above the table, and the table gets double rules and no shading:

```markdown
<span class="aps-label">Table I.</span> Caption.
{: .aps-caption}

| Set | $x(0)$ |
|:---:|:---:|
| (a) | $5\pi$ |
{: .aps-table}
```

### Equations

MathJax numbers the equations of an `align` environment. Label one with `\label{eq:name}` and refer to it as `Eq. $\eqref{eq:name}$`. A display equation wider than the page scrolls sideways, and the page itself keeps its width.

### Folded boxes

A `<details>` box hides long code or an aside until the reader opens it. With `markdown="1"`, kramdown renders the Markdown inside:

```markdown
<details class="code-fold" markdown="1">
<summary>Show the script</summary>

A code block, a list, or any other Markdown.

</details>
```

`code-fold` gives a plain box, and `prompt-fold` one that looks like Chirpy's info box. A link to anything inside a closed box opens the box first.

### Citations

The references go at the end of a post, under `## References`, in a folded box. Each one gets a number and an anchor, and every citation in the text links to its anchor:

```markdown
## References

<details class="code-fold" markdown="1">
<summary>Show the references</summary>

[1] S. H. Strogatz, *Nonlinear Dynamics and Chaos*, 2nd ed. (Westview Press, Boulder, CO, 2015).
{: #ref-1 }

</details>
```

| To cite | You write |
| --- | --- |
| One reference | `the well-known equation [\[1\]](#ref-1)` |
| Several references | `ODEPACK [\[2\]](#ref-2), [\[4\]](#ref-4)` |

The backslashes stop the note links from reading `[[1]]` as a link to a note. A citation opens the folded box, and the reference lights up briefly, as Chirpy's footnotes do.

The references follow the style of the APS journals: initials before the surname, *et al.* after the first author when there are many, article titles in sentence case, the abbreviated journal name, the volume in bold, and the year in parentheses. The link goes on the journal reference, to the DOI.

| Source | You write |
| --- | --- |
| Article | `[3] P. Virtanen et al., SciPy 1.0: Fundamental algorithms for scientific computing in Python, [Nat. Methods **17**, 261 (2020)](https://doi.org/10.1038/s41592-019-0686-2).` |
| Preprint | `[5] A. Author and B. Author, Title of the preprint, [arXiv:2401.01234](https://arxiv.org/abs/2401.01234).` |
| Book | `[1] S. H. Strogatz, *Nonlinear Dynamics and Chaos*, 2nd ed. (Westview Press, Boulder, CO, 2015), Secs. 6.7 and 7.5.` |
| Chapter in a book | `[2] A. C. Hindmarsh, ODEPACK, a systematized collection of ODE solvers, in *Scientific Computing*, edited by R. S. Stepleman et al. (North-Holland, Amsterdam, 1983), pp. 55–64.` |

Further reading, which the text does not cite, goes before the references as an ordinary list, with the same format for each entry and a sentence or two on what it covers.

### Code from files

A script in `_includes/code/` can appear in a post, so the post always shows the script as it is:

~~~markdown
```python
{% include code/script.py %}
```
~~~

Code blocks fit the page without scrolling sideways at 72 characters or fewer. `uvx ruff format --line-length 72` formats a script to this width; it leaves long comments alone, so move them to a line of their own.

## Linking Notes

Posts can link to each other Zettelkasten-style, with backlinks and a graph of the notes. Everything happens at build time in `_plugins/notes-graph.rb`; Chirpy's layouts are not changed.

### Writing links

| You write | You get |
| --- | --- |
| `[[2026-07-06-ode]]` | A link to the post, with its title as the text |
| `[[ode]]` | The same, by slug, which the site understands but Foam does not |
| `[[2026-07-06-ode\|the ODE note]]` | A link with your own text |
| `[[2026-07-06-ode#a-heading]]` | A link to a section of the post |
| `[the ODE note](2026-07-06-ode.md)` | A relative `.md` link, which also works in the VS Code and GitHub previews |
| `[the ODE note](/posts/ode/)` | An ordinary link, which counts as a link between notes too |

A link to a note that does not exist yet is shown as muted text, and the build prints a warning. Code blocks and inline code are left alone, so `[[ -f file ]]` in a shell snippet is safe.

### What the site shows

- **Linked from:** at the end of each post, the notes that link to it (its backlinks).
- **The note graph:** in the right panel, posts as dots coloured by their first category, solid lines for links and faint dotted lines for shared tags. On a post it shows that post's neighbourhood; on other pages, every note. Hovering a dot shows its title, and clicking opens it. The graph labels a note with its `short_title` from the front matter, or with its title when it has none. The colours follow the light and dark themes (`--graph-*` in `_sass/amore/`); a new top-level category needs a `--graph-node-<category>` colour there. Chirpy hides the right panel on screens narrower than 1200px.
- **The Note Graph tab:** the sidebar has a Note Graph tab below Tags (`_tabs/graph.md`), which shows the whole graph on a page of its own, inspired by Obsidian's [Graph view](https://obsidian.md/help/plugins/graph) plugin. There the graph is three-dimensional and turns slowly. A drag on empty space moves it across the canvas, a drag on a dot pulls that note, so that its links stretch and light up and its neighbours follow, and a drag with Shift or the right mouse button turns it. On a touch screen, one finger moves the graph or pulls a note, and two fingers turn it. The scroll wheel, a pinch, the + and − keys or the buttons in its corner zoom in and out, and the arrow keys move the graph. Phones and narrow windows have no right panel, so this is where they can see the graph. Since a touch screen cannot hover, the first tap on a dot shows the title of the note and a second tap opens it. The right panel leaves out its own graph on this page (`panel_graph: false`).

### Foam in VS Code

The repository is set up for [Foam](https://foambubble.github.io/foam/): install the recommended extension, and VS Code offers `[[` completion, backlinks and a graph of the notes. `.vscode/settings.json` keeps Foam out of the build output and the toolchain, and stops it from appending link reference definitions to the notes, which the site does not need. **Foam: Create New Note** starts a draft in `_drafts/` from `.foam/templates/new-note.md`; to publish it, move it to `_posts/` as `YYYY-MM-DD-slug.md`. Foam finds a note by its file name, which is why the posts link to each other as `[[2026-07-06-ode]]`, and once a draft moves to `_posts/`, any link to it needs the date in front of its slug.

The idea of publishing a Foam workspace with Jekyll comes from hikerpig's [foam-jekyll-template](https://github.com/hikerpig/foam-jekyll-template), which rewrites Foam's links in the browser. This site does the same at build time, and adds backlinks and the graph.

## Customising the Theme

All the changes to Chirpy live in files of their own, so a new release of the theme merges without conflicts. Only two files replace files of the theme, and Chirpy provides both for this purpose:

- `assets/css/jekyll-theme-chirpy.scss` keeps the theme's own lines at the top. The styles of this site follow the line "append your custom style below", one `@use` for each partial in `_sass/`.
- `_includes/metadata-hook.html` is the theme's empty placeholder for the `<head>`. Here it loads JetBrains Mono and the script that opens folded boxes.

Everything else is new:

| Location | Contents |
| --- | --- |
| `_sass/amore/` | Colours of the light and dark themes |
| `_sass/_*.scss` | Home page hero, ringdown, code font, note graph, folded boxes, APS captions and tables, display equations, heading sizes, footer |
| `_plugins/` | Home page hero, footer, note links and graph, inline code without line breaks, plain page titles (`posts-lastmod-hook.rb` comes with the starter) |
| `_includes/` | Home page hero, footer (copyright line and quotation), backlinks, note graph, scripts that posts include (`code/`) |

After a Chirpy update, compare the top of `assets/css/jekyll-theme-chirpy.scss` with the theme's copy, at `$(bundle info --path jekyll-theme-chirpy)/assets/css/`, and copy over any change. The styles rely on Chirpy's class names and colour variables, such as `.content` and `--main-border-color`. If a release renames one of them, the style that uses it stops applying, and the rest of the site keeps working. The hooks in `_plugins/` that edit Chirpy's pages, for the home page hero and the footer, print a warning during the build when they cannot find the markup they look for, and the page then keeps Chirpy's own version.

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
