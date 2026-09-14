Create and manage multiple darktable test builds on Linux.

All builds get their own config directory and desktop integration.

Install location can be configured in the script. Default is `$HOME/.local/bin`.

---

Usage: `dt-test-build.sh [-d <path> [-m | -b <branch> | -p <#>] [-r <remote|URL>] [-s]] [-l] [-u <name>]`

`-d <path>`
   Directory with darktable Git checkout

`-m`
   Build master

`-b <branch name>`
   Build branch

`-p <#>`
   Build pull request

`-r <remote|repo URL>`
   Remote or repository URL to fetch branch from

`-s`
   Update submodules

`-l`
   List installed builds

`-u <directory name>`
   Uninstall build

`-h`
   Show this help
