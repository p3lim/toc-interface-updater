# TOC Interface Updater

This script will parse [World of Warcraft AddOn metadata files (TOC)](https://wowpedia.fandom.com/wiki/TOC_format) and update the Interface version(s) to the most recent version(s) of the game according to the [WoWInterface API](https://www.wowinterface.com/forums/showthread.php?s=11c51a8909d2cf65c6d0a0afba2a5d75&t=51835).

#### Multiple client flavours

This script supports updating the [multiple TOC files](https://wowpedia.fandom.com/wiki/TOC_format#Multiple_client_flavors) the game officially supports, such as:

- `MyAddon.toc` (default)
- `MyAddon_Mainline.toc` (Retail)
- `MyAddon_Vanilla.toc` (Classic Era)
- `MyAddon_TBC.toc` (Burning Crusade Classic)
- `MyAddon_Wrath.toc` (Wrath of the Lich King Classic)

It also supports legacy alternatives, although you should avoid using these:

- `MyAddon-Mainline.toc` (Retail)
- `MyAddon-Vanilla.toc` (Classic Era)
- `MyAddon_Classic.toc` (Classic Era)
- `MyAddon-Classic.toc` (Classic Era)
- `MyAddon-TBC.toc` (Burning Crusade Classic)
- `MyAddon_BCC.toc` (Burning Crusade Classic)
- `MyAddon-BCC.toc` (Burning Crusade Classic)
- `MyAddon-Wrath.toc` (Wrath of the Lich King Classic)
- `MyAddon_WOTLKC.toc` (Wrath of the Lich King Classic)
- `MyAddon-WOTLKC.toc` (Wrath of the Lich King Classic)

#### Multiple Interface versions

This script supports updating the [multiple Interface types used in BigWigs' packager](https://github.com/BigWigsMods/packager#single-toc-file), such as:

```
## Interface: NNNNN
## Interface-Retail: NNNNN
## Interface-Classic: NNNNN
## Interface-BCC: NNNNN
## Interface-Wrath: NNNNN
```

This is a deprecated feature, [multiple client flavours](#multiple-client-flavours) should be used instead.

#### Base version

The interface version used for the default `MyAddon.toc` (and `## Interface: ` in case of [multiple interface version](#multiple-interface-versions)).

- `mainline` (Retail)
- `vanilla` (Classic Era)
- `classic` (alias for `vanilla`)
- `tbc` (Burning Crusade Classic)
- `bcc` (alias for `tbc`)
- `wrath` (Wrath of the Lich King Classic)
- `wotlkc` (alias for `wrath`)

It is recommended to use `mainline` as the default base version, as CurseForge will not accept the zip file otherwise, and is why the script defaults to `mainline` as the base version unless specified.

## Usage

You'll also need `bash >= 4.0` `curl`, `jq`, `sed`, `find` and `md5sum` installed on your system.  
Only GNU versions are officially supported, Busybox alternatives (or others) have not been tested.

Then run the script:
```bash
export WOWI_API_TOKEN=...
bash update.sh         # use the default base version
bash update.sh classic # set Classic as the default Interface version
```

The only argument the script takes is the [base version](#base-version).

## GitHub Action

You can use this in a GitHub action workflow by referencing `p3lim/toc-interface-updater@v2`.

Options:
- `base` - sets the fallback game version for unsuffixed TOC files, see [base version](#base-version) for valid options

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
