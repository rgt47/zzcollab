# Reproducibility Infrastructure and the Replication Crisis:
Positioning zzcollab in Light of the SCORE Project

*2026-05-28 08:10 PDT*

## Abstract

The SCORE project (Systematizing Confidence in Open Research and
Evidence), a seven-year DARPA-funded initiative involving 865
researchers, has produced the most comprehensive empirical account of
scientific reproducibility to date. Its nine papers, published in
*Nature* in early 2026, document failure rates across three distinct
dimensions of reproducibility -- computational, robustness, and
replication -- and assess the capacity of artificial intelligence to
predict which studies will hold up. This document synthesizes the
SCORE findings alongside four antecedent empirical studies that
provide mechanistic detail on the same failure modes: Stodden et al.
(2018) on journal policy effectiveness, Silberzahn et al. (2018) on
multi-analyst variability, Camerer et al. (2018) on replication of
high-profile social science experiments, and Hardwicke et al. (2018)
on mandatory open data policy at a single journal. Together these
sources map a precise causal account of reproducibility failure and
identify which architectural choices in zzcollab address which failure
modes.

---

## 1. Background: The Scale and Structure of the Problem

The replication crisis is not a new phenomenon, but its empirical
documentation has become substantially more precise over the past
decade. Nosek and colleagues (Open Science Collaboration, 2015)
replicated 100 psychology papers and matched the original results only
39 percent of the time. Camerer et al. (2016) replicated 18 laboratory
economics experiments and found a 61 percent success rate, with effect
sizes averaging 66 percent of the originals. These projects established
the scale of the problem. SCORE's contribution is diagnostic: rather
than asking only whether a study replicates, it decomposes the failure
space into three distinct empirical questions.

- **Computational reproducibility:** Given the same data and the same
  code, does a new analyst obtain the same numerical results?
- **Robustness:** Given the same data but different analytical
  methods, do multiple independent teams reach the same qualitative
  conclusion?
- **Replicability:** Given a new sample and the same research
  question, does the original effect hold?

These are separable failure modes with distinct causes and distinct
remedies. A study can be computationally reproducible but not robust
to analytical choice; it can replicate qualitatively while producing
substantially attenuated effect sizes. The four antecedent papers
reviewed here each address one or more of these dimensions with
controlled empirical designs, and together they provide the mechanistic
detail that justifies specific infrastructure choices.

---

## 2. The Empirical Evidence Base

### 2.1 Computational Reproducibility: Policy Is Necessary but
Insufficient

Stodden, Seiler, and Ma (2018) provide the most direct empirical test
of whether journal policies produce computational reproducibility. They
sampled 204 computational papers published in *Science* after that
journal implemented a mandatory data and code sharing policy in
February 2011. Contacting corresponding authors for the underlying
artifacts, they found that only 44 percent of emailed authors provided
any materials, yielding an overall artifact recovery rate of 44 percent
(95% CI [0.36, 0.50]). Of the 56 papers judged potentially
reproducible from those materials, they attempted replication on a
random sample of 22 and succeeded in all but 1. Their estimated
replication rate for the full sample is 26 percent (95% CI [0.20,
0.32]).

Several qualitative findings from this study are directly relevant to
zzcollab's design. First, only 13 percent of the papers mentioned
hardware or environmental settings -- the precise gap that a Dockerfile
addresses. Second, code received from authors had typically been
modified since it was used to generate the published results, producing
a silent divergence between the archived and the analytical code.
Third, Stodden et al. use the term 'research compendium' to refer to
the bundle of publication, data, and code -- the same structure that
zzcollab scaffolds as its default project layout. Fourth, and most
practically, their conclusion is that a policy requiring artifact
remission upon request is 'an improvement over no policy, but currently
insufficient for reproducibility'; they recommend instead that journals
verify deposit of artifacts as a condition of publication.

Hardwicke et al. (2018) conducted a complementary natural experiment,
examining the introduction of a mandatory open data policy at the
journal *Cognition* on 1 March 2015. The policy substantially
increased data availability: data available statements rose from 25
percent pre-policy (104/417) to 78 percent post-policy (136/174). But
availability is not the same as usability. Of the data that were
nominally available, only 62 percent were in-principle reusable
(accessible, complete, and understandable). And when the team actually
attempted to reproduce key outcomes from 35 articles with in-principle
reusable data, they achieved an initial reproduction rate of only 31
percent without author assistance. With author assistance, 63 percent
were eventually reproducible; 37 percent remained not fully
reproducible even with author help.

Two specific findings from Hardwicke et al. deserve emphasis. First,
they note that 'authors may not always be aware of the hidden defaults
employed by statistical software. For example, R defaults to a Welch
*t*-test and SPSS reports both the Student *t*-test and the Welch
*t*-test' (p. 14). This is not a marginal concern: 53 percent of the
discrete reproducibility issues they identified were attributable to
incomplete or ambiguous specification of the analysis procedure --
hidden default choices that the original analyst never thought to
document. Second, the paper was itself written using R Markdown with
a Code Ocean container to capture the software environment, directly
demonstrating that the technology to solve this problem already exists.
Their description of the experience of reproducing an underdocumented
analysis -- 'assembling flat pack furniture without an instruction
booklet' -- captures the practical cost of absent infrastructure.

SCORE's computational reproducibility arm adds to this picture at
larger scale: re-running original code against original data for 143
papers, approximately 9 percent produced completely different results
and another 14 percent only approximately the same. When the team had
to reconstruct code independently, exact reproduction fell below 50
percent. The SCORE figures are consistent with Hardwicke et al.'s 31
percent unaided rate: absent a specified environment and analysis
script, the baseline computational failure rate across fields is
roughly 50 to 70 percent.

### 2.2 Robustness: The Analytical Degrees of Freedom Problem

Silberzahn et al. (2018) provide the clearest experimental evidence
for what SCORE's robustness arm measures at scale. Twenty-nine teams
involving 61 analysts independently addressed the same research
question -- whether soccer referees are more likely to give red cards
to dark-skinned players -- using the same dataset of 146,028
player-referee dyads. Analytic approaches varied widely: the 29 teams
used 21 unique combinations of covariates and model specifications
ranging from ordinary least squares regression to zero-inflated
Poisson regression to hierarchical Bayesian models. Effect sizes
ranged from 0.89 to 2.93 in odds-ratio units (Mdn = 1.31). Twenty
teams (69%) found a statistically significant positive effect; 9 teams
(31%) did not. No team reported a significant negative relationship.

The key finding is not the variability in results but the failure of
any observable factor to explain it. Analysts' prior beliefs about the
hypothesis did not predict their results. Expertise level -- as
measured by academic rank, graduate teaching, and methodological
publications -- did not predict effect size or significance. Peer
ratings of analysis quality showed no association with reported effect
sizes. As the authors conclude: 'uncertainty in interpreting research
results is therefore not just a function of statistical power or the
use of questionable research practices; it is also a function of the
many reasonable decisions that researchers must make in order to
conduct the research' (p. 354).

Silberzahn et al. are explicit that this problem is distinct from
*p*-hacking: 'analysts had no incentive to try different
specifications and choose one that supported the hypothesis...even so,
the variability in analytic choices led to variability in observed
results' (p. 352). The source of divergence is the set of defensible
but undeclared choices made during preprocessing and model
specification -- covariate selection, handling of non-independence
across observations, distributional assumptions, exclusion criteria.
These choices are made silently, governed partly by software defaults
and partly by field conventions that are not encoded in any published
artifact.

SCORE's robustness arm scales this finding to 100 papers across
multiple social science disciplines: only 57 percent of papers yielded
roughly the same result across at least five independent analyst teams;
only one-third yielded precisely the same result.

### 2.3 Replicability and Effect Size Attenuation

Camerer et al. (2018) -- the Social Sciences Replication Project
(SSRP) -- replicated 21 experimental studies published in *Nature* and
*Science* between 2010 and 2015. All replications were pre-registered
at the Open Science Framework and reviewed by the original authors
before data collection. Sample sizes were on average five times larger
than in the original studies. Thirteen of the 21 studies (62%) showed
a statistically significant effect in the same direction as the
original, using the primary criterion of statistical significance.

The effect size findings are the most consequential for zzcollab's
strategic positioning. The mean standardized effect size of the
replications was 0.249, compared to 0.460 in the original studies --
a mean relative effect size of 46.2 percent. For the 13 studies that
replicated, the replication effect sizes were on average 75 percent of
the originals. For the 8 that did not replicate, the mean relative
effect size was approximately zero. The Bayesian mixture model
estimated the true-positive rate at 67 percent, and the relative
effect size of true positives at 71 percent. Even the true-positive
findings are systematically overestimated in the original literature.

Two additional findings from Camerer et al. are relevant here. First,
prediction markets populated by domain experts closely tracked actual
replication outcomes (mean market prediction 63.4 percent vs. actual
replication rate 61.9 percent; Spearman correlation 0.842, *p* <
0.001). Expert judgment can identify which studies will replicate with
substantial accuracy. Second, the paper concludes that 'systematic
biases can be reduced by implementing pre-registration of analysis
plans to reduce the likelihood of false positives and registration and
reporting of all study results to reduce the effects of publication
bias inflating effect sizes' (p. 642) -- the most direct statement
from this literature of what structural intervention is warranted.

SCORE confirms this pattern at larger scale: roughly half of the 164
replicated studies achieved statistical significance on the original
outcome, and effect sizes diminished by median reductions exceeding 50
percent in effect magnitude and 80 percent in explained variance.

### 2.4 The Limits of Artificial Intelligence Prediction

DARPA's original motivation for SCORE was to develop an automated
'credit score' for scientific claims: a system that could predict from
features of a published paper whether its results would hold up. The
SCORE machine learning models detect some signal -- they are not
entirely uninformative -- but they are far from deployable as
standalone assessments. Camerer et al. (2018) found that expert peer
judgment achieves ~75 percent accuracy in predicting replication
outcomes. The AI prediction problem is not primarily algorithmic.
Current models lack access to the structured, machine-readable
provenance information -- environment specifications, analysis
histories, data lineage records -- that would be needed to make
reliable predictions. Generating that provenance data is a
prerequisite, not a byproduct, of solving the prediction problem.

---

## 3. Mapping Failure Modes to zzcollab Architecture

zzcollab's Five Pillars -- Dockerfile, renv.lock, .Rprofile, source
code, and research data -- address the reproducibility stack from the
computational environment upward. The empirical findings reviewed above
allow a precise mapping from failure mode to architectural response.

### 3.1 Pillar 1 (Dockerfile) and Pillar 2 (renv.lock): Eliminating
Environmental Drift

Stodden et al. (2018) found that only 13 percent of the papers they
assessed mentioned hardware or environmental settings. Hardwicke et al.
(2018) found that 18 percent of their discrete reproducibility issues
were attributable to missing or incorrect information in the data file,
and a further 9 percent to typographical errors introduced during
transfer of information from analysis output to manuscript -- errors
that a reproducible pipeline (code generating the manuscript directly)
would prevent. These findings identify the environmental specification
gap as both common and consequential.

The Dockerfile addresses this gap directly. By specifying R version,
system library versions, locale, timezone, and thread count, it makes
the computational substrate explicit and portable. A container built
from a versioned Dockerfile seven years after the original analysis
will behave identically to the original environment -- not
approximately, but exactly. renv.lock extends this guarantee to the R
package layer, pinning every dependency to a specific version and
source.

An important point from Hardwicke et al. is that the analysis pipeline
itself, not only the data and code, must be specified. They note that
'authors can greatly improve the traceability of reported outcomes, and
reduce the likelihood of typographical errors, by taking advantage of
technologies like R Markdown which interleave analysis code with
regular prose to generate reproducible documents' (p. 14). zzcollab's
scaffold supports exactly this: the `reports/` directory is structured
for R Markdown or Quarto documents that render directly from data,
eliminating the copy-paste step that Hardwicke et al. identify as a
primary error source.

### 3.2 Pillar 3 (.Rprofile): Addressing the Silent Defaults Problem

Silberzahn et al.'s 29-team experiment reveals that effect size
estimates for the same hypothesis on identical data range across a
factor of three (0.89 to 2.93 OR) depending on legitimate but
undeclared analytical choices. The choices that drive this divergence
are not exotic methodological decisions: they are the routine selection
of covariates, distributional assumptions, and handling of
non-independence that every analyst makes, often without realizing that
a different defensible choice would produce a meaningfully different
result.

Hardwicke et al. make the software default component of this problem
explicit: 'R defaults to a Welch *t*-test and SPSS reports both the
Student *t*-test and the Welch *t*-test. Authors may not always be
aware of the hidden defaults employed by statistical software' (p. 14).
This is a precise statement of what zzcollab's `.Rprofile` pillar
addresses. The most consequential defaults in R analysis pipelines are:

- `options(stringsAsFactors = FALSE)` -- prior to R 4.0, the default
  was `TRUE`, silently converting character vectors to factors and
  changing model behavior downstream.
- `options(contrasts = c('contr.treatment', 'contr.poly'))` --
  contrast coding determines how categorical predictors enter
  regression models; the default is not universal across statistical
  traditions.
- `options(na.action = 'na.omit')` -- missing data handling propagates
  through every model call; a different default changes sample sizes,
  degrees of freedom, and standard errors.
- `options(digits = 7)` and `options(OutDec = '.')` -- precision and
  decimal formatting affect how results are printed to reports and
  compared numerically.

Making these options explicit in a version-controlled `.Rprofile` does
not eliminate analytical choice -- analysts should deviate when their
research question demands it -- but it records the defaults against
which deviations are measured. This converts hidden choices into
auditable decisions. It is the minimum infrastructure required to
conduct the kind of multi-analyst robustness study that Silberzahn
et al. and SCORE pioneered: without a declared baseline environment,
it is impossible to attribute divergent results to deliberate
analytical choices versus silent environmental differences.

SCORE's finding that only 57 percent of papers yield roughly the same
result across five independent analyst teams is a measure of the
aggregate effect of undeclared choices of this kind. The `.Rprofile`
pillar does not reduce that heterogeneity to zero -- different analysts
will still make different covariate selection decisions -- but it
eliminates the subset attributable to platform differences and
undocumented default states.

### 3.3 Pillars 4 and 5 (Source Code and Research Data): Making
Sharing the Default

Stodden et al.'s most direct finding is that a policy requiring
artifact remission *upon request* is insufficient: it produced a 44
percent artifact recovery rate and an estimated 26 percent replication
rate. Their recommendation is that journals verify deposit of artifacts
at the time of publication. Hardwicke et al. show that even mandatory
deposit policies leave a substantial gap: 22 percent of post-policy
articles at *Cognition* still did not have data available statements,
and 38 percent of nominally available datasets were not in-principle
reusable.

Both studies converge on the same architectural implication: sharing
must be the default state of the project, not a step added at
submission. zzcollab structures sharing as the initial project state
rather than a subsequent obligation. The `data/raw/` directory is
read-only by convention; all derived data is generated by
version-controlled scripts; the Docker environment ensures the scripts
are not silently environment-dependent. A collaborator who clones the
repository and runs `make r` obtains what Stodden et al. call a
'research compendium' -- the bundle of publication, data, and code
that they identify as the target state -- not a collection of files
that requires undocumented local setup.

Stodden et al. also note that code frequently arrives after
publication having been modified, making reproduction uncertain even
when code is shared. Git version control -- a first-class feature of
zzcollab projects -- addresses this directly: the analysis code that
generated a specific result is tagged to the commit that produced it,
and divergence between tagged and current code is explicit and
auditable.

---

## 4. Gaps and Proposed Extensions

The Five Pillars address computational reproducibility comprehensively.
The robustness and replicability findings from Silberzahn et al.,
Camerer et al., and SCORE motivate extensions that zzcollab does not
currently implement.

### 4.1 Multi-Analyst Workflow Scaffolding

Silberzahn et al.'s crowdsourcing protocol is the most fully specified
empirical example of multi-analyst robustness assessment in the
literature. The protocol proceeds in seven stages: (1) building a
shared, documented dataset; (2) recruiting analyst teams; (3) first
independent round of analysis; (4) round-robin peer evaluation of
analytic approaches without access to others' results; (5) second
round of analysis incorporating peer feedback; (6) open discussion and
synthesis; (7) granular assessment of specific statistical concerns by
technique-specific experts. All materials and results were deposited
at OSF at each stage.

zzcollab's Docker and renv infrastructure provides the necessary
technical foundation for this protocol. Every team receives an
identical computational environment; renv.lock ensures that no team
can produce divergent results due to package version differences; the
shared read-only `data/raw/` directory provides the canonical dataset.
The missing piece is a project scaffold convention and a set of `make`
targets that operationalize the multi-analyst workflow. A concrete
proposal:

```
multiverse/
  analyst-01/   # one directory per analyst team
  analyst-02/
  analyst-03/
  summary/      # collation scripts and comparison outputs
```

A `make multiverse-init` target would scaffold this structure; a
`make multiverse-compare` target would collect primary outcomes across
analyst directories and produce a structured comparison, including the
forest-plot format used in Silberzahn et al.'s Figure 2. This is
primarily a convention and a pair of shell targets. Silberzahn et al.'s
conclusion provides the scientific rationale directly: 'transparency
in data, methods, and process gives the rest of the community
opportunity to see the decisions, question them, offer alternatives,
and test these alternatives in further research' (p. 354).

### 4.2 Pre-Registration and Analysis Plan Locking

Camerer et al. (2018) pre-registered all 21 of their replications at
the Open Science Framework prior to data collection, had replication
plans reviewed by original authors, and documented all protocol
deviations in the final replication reports. This is the gold standard
for confirmatory replication design. Silberzahn et al. note that
'preregistration solves the problems of forking paths and *p*-hacking
by removing the flexibility of data-contingent analyses and reducing
the opportunity to present post hoc tests as *a priori*' (p. 352),
while also observing that it cannot fully eliminate the kind of
analytical variability they document -- defensible choices made during
analysis still produce heterogeneous results even when all teams work
from pre-registered plans.

Camerer et al.'s final conclusion is explicit: 'systematic biases can
be reduced by implementing pre-registration of analysis plans to reduce
the likelihood of false positives and registration and reporting of all
study results to reduce the effects of publication bias inflating
effect sizes' (p. 642).

zzcollab could support a lightweight implementation of this practice
without requiring any external registry. The core mechanism: a
`preregistration/` directory in the project scaffold and a `make
lock-plan` target that generates a cryptographic hash of the analysis
plan directory and records it with a timestamp in a
`preregistration/MANIFEST` file. The hash is committed to version
control. Any post-hoc modification to the plan produces a detectable
divergence.

```bash
make lock-plan   # hashes preregistration/, writes MANIFEST, commits
make audit-plan  # diffs current preregistration/ against MANIFEST
```

The git history provides the audit trail. This does not require OSF
integration or any external service, though the MANIFEST file can
trivially be deposited at OSF if an external timestamp is required. The
`audit-plan` target produces a structured diff that a reviewer,
collaborator, or journal editor can inspect to verify that the analysis
was conducted as pre-registered, and to evaluate whether any
deviations are methodologically consequential.

### 4.3 Reproducibility Metadata as Machine-Readable Provenance

Hardwicke et al. (2018) made their paper itself a working example of
reproducible practice: they wrote it using R Markdown with knitr and
papaja, and made it available in a Code Ocean container
(https://doi.org/10.24433/CO.abd8b483-c5c3-4382-a493-1fc5aecb0f1d.v2)
that recreates the software environment in which the original analyses
were performed. This is the model for the reproducibility manifest
proposed here.

SCORE's AI prediction work failed, in part, because the features most
predictive of replication success -- environment specification, data
availability, code sharing, pre-registration status -- are not
systematically encoded in published papers. They exist as narrative
text, if at all. zzcollab projects already generate most of the raw
provenance data needed for a structured reproducibility record: the
Dockerfile captures the environment, renv.lock captures the package
state, git history captures the analysis timeline, and `.Rprofile`
captures the analytical defaults. The gap is a machine-readable
metadata layer that aggregates these into a structured reproducibility
manifest.

A `make reproducibility-report` target could emit a structured YAML
or JSON file:

```yaml
reproducibility_manifest:
  r_version: "4.4.0"
  docker_image_hash: "sha256:..."
  renv_lockfile_hash: "sha256:..."
  preregistration:
    status: "locked"
    hash: "sha256:..."
    date: "2026-01-15"
  data_sharing: "full"
  code_sharing: "full"
  analysis_options:
    stringsAsFactors: false
    contrasts: "contr.treatment"
    na_action: "na.omit"
```

This manifest could be submitted alongside a manuscript, deposited on
OSF, or ingested by future AI systems trained to predict replication
credibility. It is the structured provenance layer that SCORE's
prediction work required but did not have available.

---

## 5. Strategic Positioning

The empirical literature reviewed here establishes a clear hierarchy
of interventions, from those with the most direct evidence to those
that are plausible but less well tested. In descending order of
demonstrated effect:

1. **Code and data sharing mandates** -- Stodden et al. and Hardwicke
   et al. document both the substantial gap created by absence of
   sharing and the meaningful improvement from mandatory policies.
2. **Analysis pipeline specification** -- Hardwicke et al. find that
   53 percent of reproducibility issues arise from incomplete analysis
   specification; R Markdown with containerization directly addresses
   this.
3. **Environmental specification** -- Stodden et al. find that only 13
   percent of papers report hardware and environment details; the
   Dockerfile addresses this comprehensively.
4. **Standardized analytical defaults** -- Hardwicke et al. identify
   hidden software defaults as a primary source of non-reproducibility;
   the `.Rprofile` addresses this.
5. **Pre-registration** -- Camerer et al. use pre-registration as a
   quality control mechanism for their replications and recommend it as
   a structural intervention; SCORE concurs.
6. **Multi-analyst robustness checks** -- Silberzahn et al. and SCORE
   demonstrate the magnitude of analytical variability; crowdsourcing
   data analysis makes that variability visible and quantifiable.

zzcollab currently implements items 1 through 4 as default project
structure. Items 5 and 6 are the highest-value extensions the evidence
motivates, and both are tractable additions to the existing framework.

The AI prediction angle is not yet productive as a development
direction. SCORE's conclusion is that structured provenance data must
precede credible ML application. zzcollab is better positioned as
infrastructure that generates that provenance -- through the manifest
format proposed in Section 4.3 -- than as a consumer of AI predictions.
The community will need several years of structured data accumulation
before the prediction problem becomes tractable.

The NIH's stated plans -- data sharing tools, a dedicated replication
journal, targeted replication grants -- suggest that the institutional
incentive structure is shifting toward rewarding computational
reproducibility. Hardwicke et al.'s finding that the *Cognition* open
data policy substantially increased availability while leaving
reusability gaps suggests that the next policy frontier is
standardizing how artifacts are structured, not merely that they are
deposited. zzcollab's scaffold positions projects for that standard
from the outset rather than as a retrofit.

---

## 6. Summary

SCORE and the four antecedent studies reviewed here provide
quantitative grounding for specific design choices in zzcollab. The
failure rate of computational reproduction -- roughly 50 to 70 percent
absent a specified environment and analysis script -- is addressed by
the Dockerfile, renv.lock, and the R Markdown pipeline. The hidden
defaults problem, which Hardwicke et al. identify as contributing to
53 percent of discrete reproducibility issues, is addressed by the
`.Rprofile`. The research compendium structure that Stodden et al.
identify as the target state for shareable research artifacts is the
default layout zzcollab scaffolds.

The two extensions with the clearest empirical motivation --
multi-analyst scaffolding (Silberzahn et al.) and pre-registration
support (Camerer et al.) -- are architecturally straightforward given
the existing infrastructure. The reproducibility manifest is a
lower-priority but strategically important addition that would position
zzcollab projects to contribute to the provenance data layer that any
future AI-based replication prediction system will require.

---

## References

### SCORE Project (primary sources)

The nine SCORE papers were published as a collection in *Nature*
in early 2026. The full citation list with DOIs is available at the
project landing page and the associated Nature collection. All data
and code are publicly archived on OSF.

- Center for Open Science. (2026). SCORE: Systematizing Confidence
  in Open Research and Evidence. Project landing page.
  `https://www.cos.io/score`
- SCORE Project data and code archive. Open Science Framework.
  `https://osf.io/dtzx4/`
- SCORE nine-paper collection. *Nature* (2026).
  `https://www.nature.com/collections/hgijhcfadg`

The collection covers the following domains (paper-level DOIs should
be retrieved directly from the Nature collection page):

1. Project overview and design
2. Computational reproducibility (same data, same code)
3. Robustness to analytical choice (same data, different methods)
4. Replicability (new data, same research question)
5. AI and machine learning prediction of replication outcomes
6. Expert judgment as a predictor of replication success
7. Data and code availability as moderators of reproducibility
8. Effect size attenuation across replication attempts
9. Synthesis and implications for scientific practice

### Core empirical studies (reviewed in full)

- Stodden, V., Seiler, J., & Ma, Z. (2018). An empirical analysis of
  journal policy effectiveness for computational reproducibility.
  *Proceedings of the National Academy of Sciences*, 115(11),
  2584-2589. `https://doi.org/10.1073/pnas.1708290115`

  Key findings: 44% artifact recovery rate and 26% replication rate
  from 204 *Science* papers despite a mandatory sharing policy. Only
  13% of papers reported hardware or environmental settings. Code
  received from authors had typically been modified since publication.
  Policy is insufficient; artifact deposit at time of publication is
  recommended. Introduces the term 'research compendium' for the
  bundle of publication, data, and code.

- Silberzahn, R., Uhlmann, E. L., Martin, D. P., Anselmi, P., Aust,
  F., Awtrey, E., ... & Nosek, B. A. (2018). Many analysts, one data
  set: Making transparent how variations in analytic choices affect
  results. *Advances in Methods and Practices in Psychological
  Science*, 1(3), 337-356.
  `https://doi.org/10.1177/2515245917747646`

  Key findings: 29 teams on identical data produced effect size
  estimates from 0.89 to 2.93 OR (Mdn = 1.31); 20/29 teams found
  significant effects. 21 unique covariate combinations used. Neither
  expertise, prior beliefs, nor peer quality ratings explained the
  variability. The problem is distinct from p-hacking. Crowdsourcing
  analysis makes subjective but defensible choices transparent.

- Camerer, C. F., Dreber, A., Holzmeister, F., Ho, T. H., Huber, J.,
  Johannesson, M., ... & Nosek, B. A. (2018). Evaluating the
  replicability of social science experiments in *Nature* and
  *Science* between 2010 and 2015. *Nature Human Behaviour*, 2,
  637-644. `https://doi.org/10.1038/s41562-018-0399-z`

  Key findings: 13/21 (62%) of high-profile social science experiments
  replicated with statistical significance; mean relative effect size
  46.2% of originals; for successful replications, effect sizes still
  only 75% of originals. Expert prediction markets tracked actual
  replication rate (r = 0.84). All replications pre-registered at OSF.
  Pre-registration recommended as a structural remedy.

- Hardwicke, T. E., Mathur, M. B., MacDonald, K., Nilsonne, G.,
  Banks, G. C., Kidwell, M. C., ... & Frank, M. C. (2018). Data
  availability, reusability, and analytic reproducibility: Evaluating
  the impact of a mandatory open data policy at the journal
  *Cognition*. *Royal Society Open Science*, 5(8), 180448.
  `https://doi.org/10.1098/rsos.180448`

  Key findings: Mandatory policy at *Cognition* raised data available
  statements from 25% to 78%. But 38% of nominally available datasets
  were not in-principle reusable. Initial unaided reproduction rate
  31%; 63% with author assistance; 37% not reproducible despite help.
  53% of issues attributable to incomplete analysis specification;
  18% to data file problems. Hidden R defaults (e.g., Welch vs.
  Student *t*-test) identified as a source. R Markdown with Code
  Ocean container used for the paper itself as a working example.

### Journalism

- Zimmer, C. (2026, April 1). Can science predict when a study won't
  hold up? *The New York Times*, Section A, p. 22.
  `https://www.nytimes.com/2026/04/01/science/ai-experiments-replication.html`

### Antecedent reproducibility studies

- Open Science Collaboration. (2015). Estimating the reproducibility
  of psychological science. *Science*, 349(6251), aac4716.
  `https://doi.org/10.1126/science.aac4716`
- Camerer, C. F., et al. (2016). Evaluating replicability of
  laboratory experiments in economics. *Science*, 351, 1433-1436.
  `https://doi.org/10.1126/science.aaf0918`
- Errington, T. M., et al. (2021). Investigating the replicability of
  preclinical cancer biology. *eLife*, 10, e71601.
  `https://doi.org/10.7554/eLife.71601`
- Simmons, J. P., Nelson, L. D., & Simonsohn, U. (2011). False-
  positive psychology: Undisclosed flexibility in data collection and
  analysis allows presenting anything as significant. *Psychological
  Science*, 22(11), 1359-1366.
  `https://doi.org/10.1177/0956797611417632`
- Gelman, A., & Loken, E. (2014). The statistical crisis in science.
  *American Scientist*, 102(6), 460-465.
  `https://doi.org/10.1511/2014.111.460`

### Pre-registration and open science practice

- Nosek, B. A., et al. (2018). The preregistration revolution.
  *Proceedings of the National Academy of Sciences*, 115(11),
  2600-2606. `https://doi.org/10.1073/pnas.1708274114`
- Wagenmakers, E. J., et al. (2012). An agenda for purely
  confirmatory research. *Perspectives on Psychological Science*,
  7(6), 632-638. `https://doi.org/10.1177/1745691612463078`
- Wicherts, J. M., et al. (2016). Degrees of freedom in planning,
  running, analyzing, and reporting psychological studies: A checklist
  to avoid *p*-hacking. *Frontiers in Psychology*, 7, 1832.
  `https://doi.org/10.3389/fpsyg.2016.01832`

### Multiverse and robustness analysis

- Steegen, S., Tuerlinckx, F., Gelman, A., & Vanpaemel, W. (2016).
  Increasing transparency through a multiverse analysis.
  *Perspectives on Psychological Science*, 11(5), 702-712.
  `https://doi.org/10.1177/1745691616658637`
- Simonsohn, U., Simmons, J. P., & Nelson, L. D. (2020). Specification
  curve analysis. *Nature Human Behaviour*, 4, 1208-1214.
  `https://doi.org/10.1038/s41562-020-0912-z`

### Computational reproducibility infrastructure

- Boettiger, C. (2015). An introduction to Docker for reproducible
  research. *ACM SIGOPS Operating Systems Review*, 49(1), 71-79.
  `https://doi.org/10.1145/2723872.2723882`
- Piccolo, S. R., & Frampton, M. B. (2016). Tools and techniques for
  computational reproducibility. *GigaScience*, 5(1), 30.
  `https://doi.org/10.1186/s13742-016-0135-4`
- Sandve, G. K., et al. (2013). Ten simple rules for reproducible
  computational research. *PLOS Computational Biology*, 9(10),
  e1003285. `https://doi.org/10.1371/journal.pcbi.1003285`
- Marwick, B., Boettiger, C., & Mullen, L. (2017). Packaging data
  analytical work reproducibly using R (and friends). *The American
  Statistician*, 72(1), 80-88.
  `https://doi.org/10.1080/00031305.2017.1375986`
