## Submission summary

This is a new submission. zzcollab scaffolds Docker-based reproducible research compendia and wraps the git and GitHub steps around them.

The package wraps external command line tools (git, gh, docker,
make). Functions that would invoke them are not run in examples or
tests against the user's working directory; the git helpers are
exercised against a throwaway repository under tempdir().

## Test environments

* Local: macOS 26.6.2 (aarch64-apple-darwin25.4.0), R 4.6.1

Before submission this should also be checked on:

* win-builder (devel and release)
* macbuilder
* R-hub (a Linux and a Windows target)

## R CMD check results

0 errors | 0 warnings | 1 note

The note is:

```
* checking CRAN incoming feasibility ... NOTE
  Maintainer: 'Ronald G. Thomas <rgthomas@ucsd.edu>'
  New submission
```

This note is expected for a first-time submission.

## Reverse dependencies

None. This is a new package with no reverse dependencies.

