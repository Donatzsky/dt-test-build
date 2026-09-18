Create and manage multiple darktable test builds on Linux.

All builds get their own config directory and desktop integration.

Install location can be configured in the script. Default is `$HOME/.local/bin`.

# Usage

`dt-test-build.sh [-s <path> [-m | -p <#> | [-b <branch> -r <remote|URL>]] [-S] [-a <args>] [-t] [-l <label>] [-c <name>] [-d <config>] [-x]] [-i | -u <name>]`

`-s <path>`
   Directory with darktable source Git checkout

`-m`
   Build master

`-p <1234>`
   Build pull request

`-b <branch name>`
   Build branch

`-r <remote|repo URL>`
   Remote or repository URL to fetch branch from

`-S`
   Update submodules

`-a <build arguments>`
   Pass arguments directly to build.sh

`-t`
   Label with date and time

`-l <label>`
   Custom label

`-c <directory name>`
   Override config directory name

`-d <config directory name>`
   Duplicate (copy) existing config

`-x`
   Dry-run. Don't build or install

`-i`
   List installed builds

`-u <directory name>`
   Uninstall build

`-h`
   Show this help

# Examples

The following assumes the darktable checkout is in `$HOME/darktable`.

Build master:
`dt-build-test.sh -s "$HOME/darktable" -m`

Give it a label:
`dt-build-test.sh -s "$HOME/darktable" -m -l "My label"`

Build a pull request:
`dt-build-test.sh -s "$HOME/darktable" -p 12345`

Build the Contrast & Texture dev branch:
`dt-test-build.sh -s "$HOME/darktable" -b "contrastntexture_detaillevels" -r "https://github.com/jandren/darktable"`

Uninstall it:
`dt-test-build.sh -u "darktable-test-5.7.0+362_g6e15409c95-dirty_contrastntexture_detaillevels"`

Find the name:
`dt-test-build.sh -i`
