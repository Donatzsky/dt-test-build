Create and manage multiple darktable test builds on Linux.

All builds get their own config directory and desktop integration.

Install location can be configured in the script. Default is `$HOME/.local/bin`.

---

Usage: `dt-test-build.sh [-s <path> [-m | -p <#> | [-b <branch> -r <remote|URL>]] [-S] [-a <args>] [-l <label>] [-c <name>] [-d <config>] [-x]] [-i | -u <name>]`

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

`-l <label>`
   Label for the build

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
