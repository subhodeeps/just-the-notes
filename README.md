# Quasinormal Notes

The source of [Quasinormal Notes](https://quasinormal-notes.vercel.app), notes on theoretical physics, numerical methods, programming and tools. The site runs on [Jekyll](https://jekyllrb.com) with the [Chirpy][chirpy] theme. Its own plugins and styles add linked notes with a note graph, a tiled home page, figures and tables in the APS style, and references in the JHEP style.

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
| `bash tools/run.sh -d` | Serves the stubs, drafts and private notes alongside the posts. |
| `bash tools/stop.sh` | Stops the server, for example one left running in another terminal. |
| `bash tools/new-note.sh name [title]` | Creates a private note, `_drafts/private/YYYY-MM-DD-name.md`, named as Foam names notes, with the front matter of the Foam template. |
| `bash tools/test.sh` | Builds the site in a temporary folder and checks it with html-proofer. The preview in `_site/` stays as it is. |

The GitHub workflow (`.github/workflows/pages-deploy.yml`) runs the html-proofer check on every push. Vercel deploys the site from `main`.

The preview tells the browser to keep no copy of any page or file (`_plugins/preview-no-cache.rb`), so a reload always shows the latest build. Jekyll's server sends this header only with pages, not with styles and scripts. The preview also has no offline cache (`_config_dev.yml`). A browser that once opened a production build at the same address keeps Chirpy's service worker, which answers from its cache, so the pages stop updating. The preview serves a `sw.min.js` that replaces that worker, deletes its caches, unregisters itself and reloads the page.

### Stubs, drafts and private notes

`_drafts/` holds notes that the site does not publish: stubs, which have front matter and links but no text yet, drafts, and private notes. Git ignores its contents, and the deployed site never builds them. The folder mirrors the root of the site:

```
_drafts/
├── to-write/slug.md               # stub, to be written
├── slug.md                        # draft
├── private/note.md                # private note, never published
├── _includes/code/script.py       # {% include code/script.py %}
└── assets/images/slug/name.png    # /assets/images/slug/name.png
```

Two plugins act on these files, only with `-d`:

| Plugin | Function |
| --- | --- |
| `_plugins/draft-category.rb` | Puts each stub in `_drafts/to-write/` in the category To Write, each draft in the category Draft, and each note in `_drafts/private/` in the category Private, ahead of its own categories. The graph and the home page colour the note by its subject, the category after the stage, and mark the stage with a dashed outline. |
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

### Front matter

Besides Chirpy's fields (`title`, `description`, `date`, `categories`, `tags`, `math`, `pin`), a post can set two fields for the note graph:

| Field | Purpose |
| --- | --- |
| `short_title` | The label of the note in the graph. Without it, the graph uses `title`. |
| `primary_tags` | One to three tags that say what the note is about. On a post, the side panel draws a dotted line from the post to each note that shares one of them. Without the field, the first two tags count as primary. |

The first category sets the colour of the note in the graph.

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

## The Home Page

The home page lists the posts in Chirpy's order, ten to a page, below a hero that `index.html` configures in its front matter (`hero`). `_plugins/home-hero.rb` and `_plugins/home-tiles.rb` rearrange Chirpy's rendered list and leave its layout unchanged.

- **Pinned:** the posts with `pin: true` stay full-width bands, under the heading set by `pinned_heading`.
- **Explore:** the other posts form a grid of tiles, under the heading set by `list_heading`. A tile's size follows the length of the post, without its code: under 300 words a small square, over 1,500 words a large square, and in between a wide or a tall tile, chosen by a hash of the post's name. The grid packs the tiles densely, and `assets/js/home-tiles.js` closes the gaps at its end, so every page ends in a straight edge at every width. On a phone, the tiles stand in one column. A tall or a large tile also shows the opening of the post, which fades out towards the date, and so does a wide tile that the script lengthens to two rows to close a gap. The opening is the paragraphs at the start of the post, up to its first heading, display equation, code block or folded box. The home page loads MathJax for the inline math in these excerpts (`math: true` in `index.html`).
- **Colours:** every card, band or tile, takes the colour of its note in the graph, as a stripe on the left and a faint tint. The colour follows the subject, the first category. Drafts, stubs and private notes take the colour of their subject too, with a dashed border in that colour.

- **Sorting:** buttons under the Explore heading sort the latest posts of all pages, newest or oldest first, or by title from A to Z or from Z to A (`assets/js/list-sort.js`). `_plugins/home-tiles.rb` writes the tiles of every page to `assets/data/home-tiles.json`, and each page shows its slice of the sorted order, with as many tiles as Chirpy puts there. The pinned posts keep their place, and the grid packs itself again after each sort.

If a theme update changes the markup of the cards, the build warns and the page keeps Chirpy's list.

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

**Note graph, in the right panel.** A quiet map of where a note sits, beside its text.

- Nodes are posts, coloured by their first category, and labelled with `short_title` from the front matter, or the title if there is none. In the local preview, a draft, a stub or a private note takes the colour of its subject, the category after its stage, and has a dashed ring.
- Solid lines are links, and nodes are solid discs that hide the lines behind them.
- On a post, under the heading "Connections", the post and the notes it links to or from appear at full strength. The notes one link further away, and the notes that share a primary tag with the post, appear faintly. Dotted lines join the post to the notes that share a primary tag with it, where no link joins them already.
- On other pages, under "Note Graph", the panel shows every note with its links, and no dotted lines.
- The layout is flat and static, and the panel has no legend. Hovering over a node shows its title, and a click opens the note.
- The colours are the `--graph-*` variables in `_sass/amore/`, set for each theme. A new top-level category needs a `--graph-node-<category>` colour.
- Chirpy hides the right panel below a width of 1200px.

**Note Graph tab** (`_tabs/graph.md`), inspired by Obsidian's [Graph view](https://obsidian.md/help/plugins/graph).

- The tab shows every note, every link and every shared tag in three dimensions, and the graph turns slowly. Notes farther back fade a little. The graph opens as large as the canvas allows through a full turn, with its longest extent across the screen and an even spread of notes.
- With a mouse, a drag on empty space moves the graph, and a drag on a node pulls the note. Its links stretch and take its colour, its neighbours follow, and the graph springs back after the pull. Shift-drag or right-drag turns the graph all the way round.
- On a touch screen, one finger moves the graph or pulls a note, and two fingers zoom and turn it. The first tap on a node shows its title, and the second opens the note.
- The scroll wheel, a pinch, the + and − keys and the corner buttons zoom. The arrow keys move the graph.
- The legend of the colours sits below the graph, with the credit to Obsidian. In the local preview, it also explains the dashed ring of drafts, stubs and private notes.
- Phones and narrow windows have no right panel and see the graph here. The right panel leaves out its graph on this page (`panel_graph: false`).

The header of `assets/js/notes-graph.js` explains the design of both views: the forces, the starting view, the depth cues and the rules of the side panel.

### Foam in VS Code

The repository is configured for [Foam](https://foambubble.github.io/foam/). The recommended extension adds `[[` completion, backlinks and a note graph to VS Code. `.vscode/settings.json` excludes the build output and the toolchain from Foam, and stops Foam from appending link reference definitions to the notes.

**Foam: Create New Note** creates a draft in `_drafts/` from `.foam/templates/new-note.md`, with the front matter above, `short_title` and `primary_tags` included. To publish it, move it to `_posts/` as `YYYY-MM-DD-slug.md`. Foam resolves a note by its file name, so the posts link to each other as `[[2026-07-06-ode]]`, and a link to a draft needs the date prefix once the draft is published.

## Customising the Theme

All changes to Chirpy live in separate files, so new releases of the theme merge without conflicts. Two files replace files of the theme, and Chirpy provides both for this purpose:

- `assets/css/jekyll-theme-chirpy.scss` keeps the theme's lines at the top. Below the line "append your custom style below", it has one `@use` for each partial in `_sass/`.
- `_includes/metadata-hook.html` is the theme's empty placeholder for the `<head>`. It loads JetBrains Mono, the script that opens folded boxes, and on the home, category and tag pages the sort buttons.

New files:

| Location | Contents |
| --- | --- |
| `_sass/amore/` | Colours of the light and dark themes |
| `_sass/_*.scss` | Home page hero, tiles and card colours, sort buttons of category and tag pages, enlarged figures, ringdown, code font, note graph, folded boxes, APS captions and tables, references, display equations, heading sizes, footer |
| `_plugins/` | Home page hero and tiles, footer, note links and graph, stubs, drafts and private notes, references in the JHEP style, inline code without line breaks, page titles, no browser cache in the local preview (`posts-lastmod-hook.rb` comes from Chirpy) |
| `_data/locales/en.yml` | Chirpy's strings that differ: "Related Notes" in place of "Further Reading" for the posts that share tags with a post. Jekyll merges the file with the theme's. |
| `_bibliography/` | The master BibTeX file and the style of the citations |
| `tools/bib/` | JHEP.bst, the script that compares `_plugins/jhep.rb` with it, and test entries |
| `tools/` | The toolchain setup (`setup.sh`), the scripts behind some figures, and Chirpy's `run.sh` and `test.sh` with changes |
| `_includes/` | Home page hero, footer (copyright line and quotation), backlinks, note graph, scripts that posts include (`code/`) |
| `assets/js/notes-graph.js` | Drawing and interaction of the note graph |
| `assets/js/home-tiles.js` | Packing of the tiles on the home page |
| `assets/js/lightbox-theme.js` | Enlarged figures open in the theme the page shows, each with its caption (the `.aps-caption` paragraph after it). Chirpy's popup can otherwise open the dark figures after a switch from dark to light. `_sass/_lightbox.scss` gives each enlarged figure the background of the page, since the figures are transparent and the popup's backdrop is black. |
| `assets/js/list-sort.js` | Buttons on category and tag pages, and above the Explore tiles of the home page, that sort the posts by date or by title, newest or oldest first, A–Z or Z–A |
| `assets/img/favicons/` | The site icon, a light bulb, in place of Chirpy's. The 512 px icon is also the preview image that link previews show (`social_preview_image`). |

After a Chirpy update, compare the top of `assets/css/jekyll-theme-chirpy.scss` with the theme's copy at `$(bundle info --path jekyll-theme-chirpy)/assets/css/`, and copy over any change. The styles depend on Chirpy's class names and colour variables, such as `.content` and `--main-border-color`. If a release renames one of them, only the style that uses it stops working. The hooks in `_plugins/` that edit Chirpy's pages, for the home page hero, the tiles and the footer, print a build warning when the markup they expect is missing, and the page then keeps Chirpy's version.

For Chirpy's own options, see the [theme's documentation](https://github.com/cotes2020/jekyll-theme-chirpy/wiki).

## Credits

- [Chirpy][chirpy] and its [starter template](https://github.com/cotes2020/chirpy-starter), by Cotes Chung
- [Foam](https://foambubble.github.io/foam/)
- [foam-jekyll-template](https://github.com/hikerpig/foam-jekyll-template), by hikerpig
- [Graph view](https://obsidian.md/help/plugins/graph), by Obsidian
- [jekyll-scholar](https://github.com/inukshuk/jekyll-scholar), [citeproc-ruby](https://github.com/inukshuk/citeproc-ruby), [bibtex-ruby](https://github.com/inukshuk/bibtex-ruby) and [latex-decode](https://github.com/inukshuk/latex-decode), by Sylvester Keil
- [JHEP.bst](https://jhep.sissa.it/jhep/help/JHEP/TeXclass/DOCS/JHEP.bst), by SISSA Medialab, under the LaTeX Project Public License
- [INSPIRE](https://inspirehep.net), the source of the BibTeX entries
- [amore.mplstyle](https://github.com/subhodeeps/amore.mplstyle)
- [JetBrains Mono](https://www.jetbrains.com/lp/mono/)

## License

The code is under the [MIT License](LICENSE), which it inherits from Chirpy.

[chirpy]: https://github.com/cotes2020/jekyll-theme-chirpy/
