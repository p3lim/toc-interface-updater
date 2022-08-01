# TOC Interface Updater

This script will parse [World of Warcraft AddOn metadata files (TOC)](https://wowpedia.fandom.com/wiki/TOC_format) and update the Interface version(s) to the most recent version(s) of the game according to the [WoWInterface API](https://www.wowinterface.com/forums/showthread.php?s=11c51a8909d2cf65c6d0a0afba2a5d75&t=51835).

#### "Distinct" TOC files

This script supports updating the multiple TOC files the game supports, such as:

- `MyAddon.toc` (default)
- `MyAddon-Mainline.toc` (Retail)
- `MyAddon_Mainline.toc` (Retail)
- `MyAddon-Classic.toc` (Classic Era)
- `MyAddon_Classic.toc` (Classic Era)
- `MyAddon-Vanilla.toc` (Classic Era)
- `MyAddon_Vanilla.toc` (Classic Era)
- `MyAddon-BCC.toc` (Burning Crusade Classic)
- `MyAddon_BCC.toc` (Burning Crusade Classic)
- `MyAddon-TBC.toc` (Burning Crusade Classic)
- `MyAddon_TBC.toc` (Burning Crusade Classic)
- `MyAddon-Wrath.toc` (Wrath of the Lich King Classic)
- `MyAddon_Wrath.toc` (Wrath of the Lich King Classic)
- `MyAddon-WOTLKC.toc` (Wrath of the Lich King Classic)
- `MyAddon_WOTLKC.toc` (Wrath of the Lich King Classic)

For more details see [this](https://github.com/Stanzilla/WoWUIBugs/issues/68#issuecomment-830351390) and [this](https://github.com/Stanzilla/WoWUIBugs/issues/68#issuecomment-889431675).

#### Multiple Interface types

This script supports updating the [multiple Interface types used in `release.sh`](https://github.com/BigWigsMods/packager#building-for-multiple-game-versions), such as:

```
## Interface: NNNNN
## Interface-Retail: NNNNN
## Interface-Classic: NNNNN
## Interface-BCC: NNNNN
## Interface-Wrath: NNNNN
```

Which game version the default `## Interface:` line uses can be specified by passing one of the following strings as the only argument to the script:
- `mainline` (Retail)
- `classic` (Classic Era)
- `vanilla` (alias for `classic`)
- `bcc` (Burning Crusade Classic)
- `tbc` (alias for `bcc`)
- `wrath` (Wrath of the Lich King Classic)
- `wotlkc` (Alias for `wrath`)

## Usage

You'll also need `bash >= 4.0` `curl`, `jq`, `sed`, `find` and `md5sum` installed on your system.  
Only GNU versions are officially supported, Busybox alternatives (or others) have not been tested.

Then run the script:
```bash
export WOWI_API_TOKEN=...
bash update.sh
bash update.sh classic # set Classic as the default Interface version
```

## GitHub Action

You can use this in a GitHub action workflow by referencing `p3lim/toc-interface-updater@v2`.

Options:
- `base` - sets the fallback game version for unsuffixed TOC files, one of:
  - `mainline` (this is the default)
  - `classic`
  - `vanilla` (alias for `classic`)
  - `bcc`
  - `tbc` (alias for `tbc`)
  - `wrath`
  - `wotlkc` (alias for `wrath`)

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
```
