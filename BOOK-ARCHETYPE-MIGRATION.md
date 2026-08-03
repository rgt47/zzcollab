# Converting the Textbook Series to the zzc ‘book’ Archetype

*2026-07-29 09:49 PDT (plan) - updated 2026-08-02 18:13 PDT (completed)*

> **Status: complete.** All eleven root-level volumes have been
> converted to the zzcollab ‘book’ archetype and are live over HTTPS,
> joining the blockchain volume that served as the reference. This
> document began as a forward plan; it now records the outcome, and each
> section notes where the plan held and where reality diverged.

## 0. Outcome summary

Eleven volumes were converted, each relocated to `analysis/book/`, given
the zzcollab framework, switched from `publish.yml` to a single
`render-book.yml`, and deployed unchanged to their existing Netlify
subdomains:

- `01-r-bootcamp`, `03-scai`, `04-scai-advanced`, `06-applied-methods`
  (display-only R), `13-git-bootcamp`, `14-git-intermediate` (markdown),
  `15-rmd-to-quarto` (knitr), `16-python-for-r` (Jupyter),
  `12-reproducibility`, `05-applied-genai`, `02-practicum` (committed
  `_freeze/`).

A final sweep confirmed all twelve subdomains return HTTP 200. No volume
required a Dockerfile, a renv.lock, or the container backend.

## 1. Objective (as planned)

The stated goal was reproducibility parity: bring every volume onto the
blockchain volume’s footing (Quarto book under `analysis/book/`, one
uniform CI path). That was achieved. The *means* turned out lighter than
anticipated, see section 3.

## 2. Scope, and how the tiering proved wrong

In scope were the eleven root-level Quarto-book volumes. Out of scope,
and left untouched, were `07-phb228-stat-computing`,
`09-genai-public-health`, `10-journal-club` (course-material
directories, not books) and `08-phb243b-biostat` (root `_quarto.yml` not
of `type: book`).

The plan tiered the volumes A/B/C by *topic* (markdown, moderate R,
heavy computation) and predicted the `scai` pair would be hardest. This
was the plan’s central misjudgment. The real determinant was each book’s
**execution profile**, not its subject:

- **Display-only** (no executable cells; all R shown as
  `\`\`\`r`):`01`,`03`,`04`,`06\`, and the two git books. These render
  as plain markdown.
- **Committed `_freeze/`** (executable cells, but frozen results are
  committed so nothing re-executes in CI): `12`, `05`, `02`.
- **knitr / Jupyter with `eval: false`**: `15`, `16`.

Under this lens `03-scai`, the predicted worst case, was display-only
and as easy as a prose book. Difficulty tracked freeze status, full
stop.

## 3. Actual end state (differs from the planned target)

The plan’s target (copied from blockchain) included a `Dockerfile`,
`renv.lock`, `tooling.lock`, and three workflows (`publish.yml`,
`render-report.yml`, `r-package.yml`). The delivered end state is
simpler, because no volume re-executes code in CI:

- **R-package skeleton present but empty**: `DESCRIPTION`, `NAMESPACE`,
  `R/`, `man/`, `tests/`, `inst/`, `vignettes/`, `zzcollab.yaml`
  (`archetype: book`), `.zzcollab-state`, `.Rprofile`, `Makefile`.
- **No `Dockerfile`, no `renv.lock`, no `tooling.lock`** were needed.
- **The Quarto book under `analysis/book/`**, including any committed
  `_freeze/` and `partials/`.
- **One workflow, `render-book.yml`** (see section 4), replacing
  `publish.yml`. `render-report.yml` and `r-package.yml` are *not*
  installed for the book archetype.
- The US-spelling pre-render gate, repointed to
  `../../tools/us-spelling`.

## 4. The mechanism we built: render-book.yml

The pilot (`13-git-bootcamp`) revealed that the stock
`render-report.yml` is the wrong gate for a book: it is shaped for
`report.Rmd`/manuscript projects and, on a bare runner, tries to install
package dependencies and dies on missing system libraries (libcurl). So
a dedicated workflow was written and **upstreamed into the zzcollab book
archetype** (`templates/workflows/render-book.yml`, plus the
`create_github_workflows` branch in `modules/github.sh`). It:

- renders `analysis/book --to html` and deploys to Netlify only on a
  push to `main` (one render serves both the gate and the deploy);
- self-adapts the backend: container when a `Dockerfile` is present,
  else the host;
- on the host, detects the engine and provisions only what the book
  uses, R+knitr for
  `\`\`\`{r}`books or those with a`renv.lock`, Python+Jupyter for`\`\`\`{python}\`
  books, nothing for pure prose.

Because it ships with the archetype, every future
`zzc init --archetype book` inherits it, and no per-repo workflow
authoring is needed.

## 5. The actual per-volume recipe

1.  Generate a valid-named scaffold in a scratch dir
    (`zzc init --archetype book`; the directory basename must start with
    a letter, so `NN-name` dirs are scaffolded as `name`).
2.  `git mv` the book (chapters, `_quarto.yml`, `_variables.yml`,
    `.scss`, `references.bib`, `images/`, and any committed `_freeze/`
    and `partials/`) into `analysis/book/`. Move an untracked
    `nav-toggle.html` with a plain `mv`.
3.  Graft the framework files from the scaffold; replace `publish.yml`
    with the scaffold’s `render-book.yml`.
4.  Repoint the pre-render gate to `../../tools/us-spelling`; merge the
    `.gitignore` (adding `!nav-toggle.html` where the book gitignores
    `*.html`, and keeping `_freeze/` tracked).
5.  Render locally to confirm; for a display-only or committed-freeze
    book this needs no dependency capture.
6.  Commit on a `restructure/book-archetype` branch, push it as backup,
    `git merge --squash` to `main` for one clean commit, push, and
    verify render-book green plus the live subdomain.

## 6. Risks: which materialized

- **Dropbox corruption of `.git` (materialized, severe).** Transient
  `bad object HEAD` and, once, a genuinely *missing tree object* on
  `15-rmd-to-quarto` that healed only after Dropbox finished syncing.
  The fix was decisive: `xattr -w com.dropbox.ignored 1` on every repo’s
  `.git` (applied to seventeen repos). Every conversion after that was
  clean. Note for other machines: apply the same ignore there, or they
  will see their Dropbox `.git` copies removed and should rely on their
  local `.git` plus GitHub.
- **Path breakage on relocation (managed).** Handled by the pre-render
  repoint and a mandatory local render before each push. The only
  surprises were untracked `nav-toggle.html` (gitignored by `*.html` in
  several books) and root-anchored `.gitignore` rules that needed
  de-anchoring.
- **Deploy continuity (held).** Changing only the render command and
  publish directory, never the Netlify site binding, kept every
  subdomain and certificate intact.
- **Container cost and incomplete lockfiles (did not arise).** No volume
  used the container backend or a lockfile, so these planned risks were
  moot.

## 7. Open decisions, as resolved

1.  **Deploy path.** Host render for both gate and deploy; the container
    path exists in `render-book.yml` but was never needed.
2.  **Package skeleton.** Kept, empty, for parity; `r-package.yml` is
    simply not installed for books (a prose book has nothing to check).
3.  **The Python volume.** No special image was needed.
    `render-book.yml` detects
    `\`\`\`{python}`and installs Jupyter on the host; with`eval: false\`
    the render is trivial.

## 8. Outstanding items

- **The container backend of `render-book.yml` is unexercised.** No book
  in the series re-executes heavy computation without a committed
  freeze, so that path has not run in real CI. The first future book
  that does will be its test.
- **`02-practicum` diverges deliberately**: it keeps its custom
  `.Rprofile` (reticulate/Python config) and `Makefile` (`deps-py`)
  rather than the zzc defaults, since they serve its Python tooling.
- **Apply the `.git` Dropbox exclusion on other machines** to avoid the
  corruption recurring there.

------------------------------------------------------------------------

*Rendered on 2026-08-02 at 18:13 PDT.*  
*Source: ~/prj/sfw/07-zzcollab/zzcollab/BOOK-ARCHETYPE-MIGRATION.md*  
*Records the migration of the rgtlab textbook series (~/prj/tch) to the
zzc ‘book’ archetype.*
