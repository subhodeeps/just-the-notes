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

`tools/setup.sh` installs a self-contained toolchain in `.venv/`, which Git ignores. The script installs nothing globally and leaves the system Ruby untouched.

| Component | Location | Notes |
| --- | --- | --- |
| Ruby 3.4.x | `.venv/ruby` | Compiled from source with ruby-build. Matches the CI version. |
| libyaml | `.venv/deps` | Required by Ruby's YAML extension (psych), which Jekyll uses. |
| Node LTS + npm | `.venv/node` | Official tarball, checksum-verified. |
| Bundler, Jekyll, Chirpy, jekyll-scholar, html-proofer | `.venv/bundle` | Installed from the `Gemfile`. |
| Python + numpy, scipy, matplotlib, amore | `.venv/python` | Optional, for the figures of posts. Requires [uv](https://docs.astral.sh/uv/). |

### First-time setup

Requirements: Xcode Command Line Tools on macOS (`xcode-select --install`), `git`, `curl`, `tar` and `make`. Compiling Ruby takes a few minutes.

```shell
bash tools/setup.sh
```

The script is idempotent. It skips installed components and updates the gems. `RUBY_SERIES` and `NODE_SERIES` select other versions, for example `RUBY_SERIES=3.3 bash tools/setup.sh`.

### Commands

```shell
source .venv/bin/activate   # put the local toolchain on PATH
bash tools/run.sh           # serve at http://127.0.0.1:4000 with live reload
deactivate                  # restore the shell
```

| Command | Effect |
| --- | --- |
| `bash tools/run.sh` | Serves the site at http://127.0.0.1:4000 with live reload. |
| `bash tools/run.sh -p` | Serves the site in production mode. |
| `bash tools/run.sh -d` | Serves the drafts and private notes alongside the posts. |
| `bash tools/test.sh` | Builds the site and checks it with html-proofer. |

The GitHub workflow (`.github/workflows/pages-deploy.yml`) runs the html-proofer check on every push. Vercel deploys the site from `main`.

### Drafts and private notes

`_drafts/` holds drafts and private notes. Git ignores its contents, and the deployed site never builds them. The folder mirrors the root of the site:

```
_drafts/
├── slug.md                        # draft
├── private/note.md                # private note, never published
├── _includes/code/script.py       # {% include code/script.py %}
└── assets/images/slug/name.png    # /assets/images/slug/name.png
```

Two plugins act on these files, only with `-d`:

| Plugin | Function |
| --- | --- |
| `_plugins/draft-category.rb` | Puts each draft in the category Draft and each note in `_drafts/private/` in the category Private, ahead of its own categories. Marks their cards on the home page with a teal or red stripe. |
| `_plugins/draft-files.rb` | Serves `_drafts/_includes/` and `_drafts/assets/` at the same paths as their counterparts at the root. |

To publish a draft, move each of its files to the same path at the root, and the draft to `_posts/` as `YYYY-MM-DD-slug.md`. The post needs no other changes.

Jekyll does not watch `_drafts/assets/`. A redrawn figure appears after the draft is saved again or the preview restarts.

### Syncing the drafts

A second, private repository holds the drafts and is cloned into `_drafts/`. This repository ignores the contents of `_drafts/` except `.gitkeep`, the inner `.git` folder included. Jekyll skips folders whose names start with a dot.

On the first device:

```shell
cd _drafts
printf '.gitkeep\n.DS_Store\n' > .gitignore
git init -b main
git add -A
git commit -m "Add the drafts"
gh repo create quasinormal-notes-private-notes --private --source=. --push
```

On another device, after cloning this repository:

```shell
cd _drafts
git init -b main
git remote add origin git@github.com:subhodeeps/quasinormal-notes-private-notes.git
git pull origin main
```

`git pull` and `git push` inside `_drafts/` then sync the drafts. The inner `.gitignore` excludes `.gitkeep`, which would otherwise block the first pull on a second device. Published drafts move out of `_drafts/`, so the drafts repository holds only work in progress.

### Starting over

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

In the text, a figure is Fig. 1, or Figure 1 at the start of a sentence.

### Tables

The caption goes above the table. Tables have double rules and no shading:

```markdown
<span class="aps-label">Table I.</span> Caption.
{: .aps-caption}

| Set | $x(0)$ |
|:---:|:---:|
| (a) | $5\pi$ |
{: .aps-table}
```

### Equations

MathJax numbers the equations of an `align` environment. `\label{eq:name}` labels an equation, and `Eq. $\eqref{eq:name}$` refers to it. A display equation wider than the page scrolls horizontally, and the page keeps its width.

### Folded boxes

A `<details>` box hides long code or an aside until the reader opens it. With `markdown="1"`, kramdown renders the Markdown inside:

```markdown
<details class="code-fold" markdown="1">
<summary>Show the script</summary>

A code block, a list, or any other Markdown.

</details>
```

| Class | Appearance |
| --- | --- |
| `code-fold` | Plain box |
| `prompt-fold` | Chirpy's info box |

A link to an element inside a closed box opens the box first.

### Citations

All references live in one master file, `_bibliography/references.bib`. [jekyll-scholar](https://github.com/inukshuk/jekyll-scholar) reads the file, numbers the citations of a post in the order of first citation, and lists the cited entries at the end of the post. `_plugins/jhep.rb` formats the entries in the style of [JHEP.bst](https://jhep.sissa.it/jhep/help/JHEP/TeXclass/DOCS/JHEP.bst), version 2.18, the bibliography style of the Journal of High Energy Physics.

**1. Add the entry.** [INSPIRE](https://inspirehep.net) exports BibTeX in the form that JHEP.bst expects. The *cite* button of a record gives the entry, and so does the INSPIRE API, by DOI or by arXiv number:

```shell
curl -s "https://inspirehep.net/api/literature?q=doi:10.1103/PhysRevD.100.024018&format=bibtex"
curl -s "https://inspirehep.net/api/literature?q=arxiv:1906.00873&format=bibtex"
```

Paste the entry into `_bibliography/references.bib` unchanged. For a book or a paper that INSPIRE does not list, write the entry by hand in the same form: a key of the form `Author:Year`, the journal abbreviated as INSPIRE abbreviates it, and the `doi` and `eprint` fields where they exist. JHEP.bst links the journal reference to the DOI and the `eprint` to arXiv, and it ignores `url` for books and articles.

**2. Cite it.** A post cites an entry by its key and lists the cited entries in the folded References box at its end:

```markdown
the well-known equation {% cite Strogatz:2015 %}

## References

<details class="code-fold" markdown="1">
<summary>Show the references</summary>

{% bibliography --cited_in_order %}

</details>
```

| Citation | Markdown | Output |
| --- | --- | --- |
| One reference | `{% cite Gralla:2019xty %}` | [1] |
| Two references | `{% cite Hindmarsh:1983 Petzold:1983 %}` | [3, 4] |
| Three or more consecutive references | `{% cite Strogatz:2015 Virtanen:2019joe Hindmarsh:1983 Petzold:1983 %}` | [1–4] |

Runs of three or more consecutive numbers become a range, as with the cite package of LaTeX. A citation of several references links to the first of them. A citation opens the folded box and briefly highlights the reference, as Chirpy's footnotes do. `_bibliography/citations.csl` formats the citations.

**3. The style.** `_plugins/jhep.rb` ports the rules of JHEP.bst from LaTeX to HTML. A CSL style cannot reproduce the link that JHEP.bst puts around the whole journal reference, so the site does not use one for the references. The rules include:

- Authors appear with initials, as in "S.E. Gralla, D.E. Holz and R.M. Wald". From the seventh author on, the list ends in "et al.". In an article, a `collaboration` field replaces the authors.
- Article titles are in italics and in sentence case, as BibTeX sets them. Braces protect capitals, as in `{SciPy}` or `{Kerr}`. INSPIRE braces the titles it exports, so its entries keep their capitals.
- The journal reference reads *Journal* **volume** (year) first page, and it links to the DOI.
- The arXiv number follows in brackets, in a monospaced font, and links to arXiv.

**4. Check the style.** `tools/bib/check.rb` runs BibTeX with `tools/bib/JHEP.bst` on a `.bib` file and compares each entry with the output of `_plugins/jhep.rb`, in text and in links. It requires a TeX installation:

```shell
bundle exec ruby tools/bib/check.rb                      # _bibliography/references.bib
bundle exec ruby tools/bib/check.rb tools/bib/test.bib   # test entries of every type
```

Further reading, which the text does not cite, goes before the references as an ordinary list, with one or two sentences on each entry. Its entries follow the APS style: initials before the surname, *et al.* after the first author for long author lists, article titles in sentence case, abbreviated journal names, the volume in bold, and the year in parentheses. The link goes on the journal reference and points to the DOI.

| Source | Markdown |
| --- | --- |
| Article | `P. Virtanen et al., SciPy 1.0: Fundamental algorithms for scientific computing in Python, [Nat. Methods **17**, 261 (2020)](https://doi.org/10.1038/s41592-019-0686-2).` |
| Preprint | `A. Author and B. Author, Title of the preprint, [arXiv:2401.01234](https://arxiv.org/abs/2401.01234).` |
| Book | `S. H. Strogatz, *Nonlinear Dynamics and Chaos*, 2nd ed. (Westview Press, Boulder, CO, 2015).` |
| Chapter in a book | `A. C. Hindmarsh, ODEPACK, a systematized collection of ODE solvers, in *Scientific Computing*, edited by R. S. Stepleman et al. (North-Holland, Amsterdam, 1983), pp. 55–64.` |

### Code from files

A post shows a script from `_includes/code/` with `{% include %}`, so the post always shows the current version of the script:

~~~markdown
```python
{% include code/script.py %}
```
~~~

Code blocks fit the page width at 72 characters or fewer. `uvx ruff format --line-length 72` formats a script to this width. Ruff leaves long comments unchanged, so these go on lines of their own.

## Linking Notes

Posts link to each other in the manner of a Zettelkasten, with backlinks and a graph of the notes. `_plugins/notes-graph.rb` builds both at build time and leaves Chirpy's layouts unchanged.

### Writing links

| Markdown | Result |
| --- | --- |
| `[[2026-07-06-ode]]` | Link to the post, with its title as the text |
| `[[ode]]` | The same link, by slug. The site resolves it, Foam does not. |
| `[[2026-07-06-ode\|the ODE note]]` | Link with custom text |
| `[[2026-07-06-ode#a-heading]]` | Link to a section of the post |
| `[the ODE note](2026-07-06-ode.md)` | Relative `.md` link, also valid in the VS Code and GitHub previews |
| `[the ODE note](/posts/ode/)` | Ordinary link, also counted as a link between notes |

A link to a note that does not exist renders as muted text, and the build prints a warning. The plugin skips code blocks and inline code, so `[[ -f file ]]` in a shell snippet stays as it is.

### Backlinks and the note graph

**Backlinks.** The end of each post lists the notes that link to it, under "Linked from".

**Note graph, in the right panel.**

- Nodes are posts, coloured by their first category. The label is `short_title` from the front matter, or the title if there is none.
- Solid lines are links, and dotted lines join notes that share a tag.
- On a post, the graph shows the post's neighbourhood under the heading "Connections". On other pages, it shows every note under "Note Graph".
- The layout is flat and static. Hovering over a node shows its title, and a click opens the note.
- The colours are the `--graph-*` variables in `_sass/amore/`, set for each theme. A new top-level category needs a `--graph-node-<category>` colour.
- Chirpy hides the right panel below a width of 1200px.

**Note Graph tab** (`_tabs/graph.md`), inspired by Obsidian's [Graph view](https://obsidian.md/help/plugins/graph).

- The tab shows every note in three dimensions, and the graph turns slowly.
- With a mouse, a drag on empty space moves the graph, and a drag on a node pulls the note. Its links stretch and take its colour, and its neighbours follow. Shift-drag or right-drag turns the graph.
- On a touch screen, one finger moves the graph or pulls a note, and two fingers zoom and turn it. The first tap on a node shows its title, and the second opens the note.
- The scroll wheel, a pinch, the + and − keys and the corner buttons zoom. The arrow keys move the graph.
- Phones and narrow windows have no right panel and see the graph here. The right panel leaves out its graph on this page (`panel_graph: false`).

### Foam in VS Code

The repository is configured for [Foam](https://foambubble.github.io/foam/). The recommended extension adds `[[` completion, backlinks and a note graph to VS Code. `.vscode/settings.json` excludes the build output and the toolchain from Foam, and stops Foam from appending link reference definitions to the notes.

**Foam: Create New Note** creates a draft in `_drafts/` from `.foam/templates/new-note.md`. To publish it, move it to `_posts/` as `YYYY-MM-DD-slug.md`. Foam resolves a note by its file name, so the posts link to each other as `[[2026-07-06-ode]]`, and a link to a draft needs the date prefix once the draft is published.

## Customising the Theme

All changes to Chirpy live in separate files, so new releases of the theme merge without conflicts. Two files replace files of the theme, and Chirpy provides both for this purpose:

- `assets/css/jekyll-theme-chirpy.scss` keeps the theme's lines at the top. Below the line "append your custom style below", it has one `@use` for each partial in `_sass/`.
- `_includes/metadata-hook.html` is the theme's empty placeholder for the `<head>`. It loads JetBrains Mono and the script that opens folded boxes.

New files:

| Location | Contents |
| --- | --- |
| `_sass/amore/` | Colours of the light and dark themes |
| `_sass/_*.scss` | Home page hero, ringdown, code font, note graph, cards of drafts and private notes, folded boxes, APS captions and tables, references, display equations, heading sizes, footer |
| `_plugins/` | Home page hero, footer, note links and graph, drafts and private notes, references in the JHEP style, inline code without line breaks, page titles (`posts-lastmod-hook.rb` comes with the starter) |
| `_bibliography/` | The master BibTeX file and the style of the citations |
| `tools/bib/` | JHEP.bst, the script that compares `_plugins/jhep.rb` with it, and test entries |
| `_includes/` | Home page hero, footer (copyright line and quotation), backlinks, note graph, scripts that posts include (`code/`) |
| `assets/js/notes-graph.js` | Drawing and interaction of the note graph |
| `assets/img/favicons/` | Icons made from the profile picture, in place of Chirpy's |

After a Chirpy update, compare the top of `assets/css/jekyll-theme-chirpy.scss` with the theme's copy at `$(bundle info --path jekyll-theme-chirpy)/assets/css/`, and copy over any change. The styles depend on Chirpy's class names and colour variables, such as `.content` and `--main-border-color`. If a release renames one of them, only the style that uses it stops working. The hooks in `_plugins/` that edit Chirpy's pages, for the home page hero and the footer, print a build warning when the markup they expect is missing, and the page then keeps Chirpy's version.

## Usage

Check out the [theme's docs](https://github.com/cotes2020/jekyll-theme-chirpy/wiki).

## Contributing

This repository is automatically updated with new releases from the theme repository. If you encounter any issues or want to contribute to its improvement, please visit the [theme repository][chirpy] to provide feedback.

## Credits

- [Chirpy][chirpy] and [chirpy-starter](https://github.com/cotes2020/chirpy-starter), by Cotes Chung
- [Foam](https://foambubble.github.io/foam/)
- [foam-jekyll-template](https://github.com/hikerpig/foam-jekyll-template), by hikerpig
- [Graph view](https://obsidian.md/help/plugins/graph), by Obsidian
- [jekyll-scholar](https://github.com/inukshuk/jekyll-scholar), [citeproc-ruby](https://github.com/inukshuk/citeproc-ruby), [bibtex-ruby](https://github.com/inukshuk/bibtex-ruby) and [latex-decode](https://github.com/inukshuk/latex-decode), by Sylvester Keil
- [JHEP.bst](https://jhep.sissa.it/jhep/help/JHEP/TeXclass/DOCS/JHEP.bst), by SISSA Medialab, under the LaTeX Project Public License
- [INSPIRE](https://inspirehep.net), the source of the BibTeX entries
- [amore.mplstyle](https://github.com/subhodeeps/amore.mplstyle)
- [JetBrains Mono](https://www.jetbrains.com/lp/mono/)

## License

This work is published under [MIT][mit] License.

[gem]: https://rubygems.org/gems/jekyll-theme-chirpy
[chirpy]: https://github.com/cotes2020/jekyll-theme-chirpy/
[CD]: https://en.wikipedia.org/wiki/Continuous_deployment
[mit]: https://github.com/cotes2020/chirpy-starter/blob/master/LICENSE
