# TOC Interface Updater

This script will parse `*.toc` files (World of Warcraft AddOn metadata file) and update lines containing the following:

```
## Interface: NNNNN
## Interface-Retail: NNNNN
## Interface-Classic: NNNNN
```

These will be updated by parsing CurseForge and WoWInterface APIs.

For the `Interface-*` fields, see https://github.com/Stanzilla/WoWUIBugs/issues/68.

### Usage

You'll need to set these environment variables containing API tokens:
- `CF_API_KEY` - a [CurseForge API token](https://wow.curseforge.com/account/api-tokens)
- `WOWI_API_TOKEN` - a [WoWInterface API token](https://www.wowinterface.com/downloads/filecpl.php?action=apitokens)

You'll also need `curl`, `jq`, `sed` and `find` installed on your system.

Then run the script:
```bash
export CF_API_KEY=...
export WOWI_API_TOKEN=...
bash update.sh
```

### GitHub Action

This is an example workflow that will do the following:
- check out the project
- use this script as an action
- create a pull request (if there were changes)

This will occur every day at 12:00.

```yaml
name: Update TOC Interface version(s)

on:
  schedule:
    - cron: 0 12 * * *

jobs:
  run:
    runs-on: ubuntu-latest
    steps:
      - name: Clone project
        uses: actions/checkout@v2

      - name: Update TOC Interface version
        uses: p3lim/toc-interface-updater@v1

      - name: Create pull request
        uses: peter-evans/create-pull-request@v3
        with:
          title: Update Interface version
          commit-message: Update Interface version
          branch: interface-version
          delete-branch: true
    env:
      CF_API_KEY: ${{ secrets.CF_API_KEY }}
      WOWI_API_TOKEN: ${{ secrets.WOWI_API_TOKEN }}
```
