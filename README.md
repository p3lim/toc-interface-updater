# TOC Interface Updater

This script will parse `*.toc` files (World of Warcraft AddOn metadata file) and update the `## Interface: ` line to the most recent version of the game according to the [WoWInterface API](https://www.wowinterface.com/forums/showthread.php?s=11c51a8909d2cf65c6d0a0afba2a5d75&t=51835).

#### "Distinct" TOC files

This script supports updating the multiple TOC files the game supports, such as:

- `MyAddon.toc` (default)
- `MyAddon-Mainline.toc` (Retail, supported since build 38627)
- `MyAddon-Classic.toc` (Classic, supported since build 38548)
- `MyAddon-BCC.toc` (TBC Classic, supported since build 38631)

For more details see [this issue](https://github.com/Stanzilla/WoWUIBugs/issues/68#issuecomment-830351390).

#### Multiple Interface types

This script supports updating the [multiple Interface types used in `release.sh`](https://github.com/BigWigsMods/packager#building-for-multiple-game-versions), such as:

```
## Interface: NNNNN
## Interface-Retail: NNNNN
## Interface-Classic: NNNNN
## Interface-BCC: NNNNN
```

Which game version the default `## Interface:` line uses can be specified by passing one of the following strings as the only argument to the script:
- `mainline` (Retail)
- `classic` (Classic)
- `bcc` (TBC Classic)

## Usage

You'll need to set these environment variables containing API tokens:
- `WOWI_API_TOKEN` - a [WoWInterface API token](https://www.wowinterface.com/downloads/filecpl.php?action=apitokens)

You'll also need `bash >= 4.0` `curl`, `jq`, `sed` and `find` installed on your system.

Then run the script:
```bash
export WOWI_API_TOKEN=...
bash update.sh
bash update.sh classic # set Classic as the default Interface version
```

## GitHub Action

You can use this in a GitHub action workflow by referencing `p3lim/toc-interface-updater@v1`.

Options:
- `base` - dictates which version `## Interface:` will be set to, one of "mainline", "classic" or "bcc"
  - _optional, defaults to "mainline"_

#### Example

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
        uses: p3lim/toc-interface-updater@v2
        with:
          base: mainline # this is default

      - name: Create pull request
        uses: peter-evans/create-pull-request@v3
        with:
          title: Update Interface version
          commit-message: Update Interface version
          branch: interface-version
          delete-branch: true
    env:
      WOWI_API_TOKEN: ${{ secrets.WOWI_API_TOKEN }}
```
