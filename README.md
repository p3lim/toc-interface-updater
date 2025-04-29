# TOC Interface Updater

This script will parse [World of Warcraft AddOn metadata files (TOC)](https://warcraft.wiki.gg/wiki/TOC_format) and update the Interface version(s) to the most recent version(s) of the game.

#### Multiple client flavors

This script supports updating the [multiple TOC files](https://warcraft.wiki.gg/wiki/TOC_format#Multiple_client_flavors) the game officially supports, such as:

- `MyAddon.toc` (default)
- `MyAddon_Mainline.toc` (Retail)
- `MyAddon_Vanilla.toc` (Classic Era)
- `MyAddon_Cata.toc` (Cataclysm Classic)

It also supports legacy alternatives, although you should avoid using those.

#### Flavor

The interface version used for the default `MyAddon.toc` is defined by passing the flavor to the script, which can be any of the following:

- `retail` (Retail)
  - `mainline` (alias for `retail`)
- `classic_era` (Classic Era)
  - `vanilla` (alias for `classic_era`)
- `classic` (Cataclysm Classic)
  - `cata` (alias for `classic`)

The script will default to `retail` unless specified.

#### Single-TOC multi-flavor

One of [BigWigs' packager](https://github.com/BigWigsMods/packager/?tab=readme-ov-file#single-toc-file) features is the ability for it to automatically create TOC files for flavors based on `## Interface` suffixes. This script will also check for those.

#### Beta/PTR

The script can optionally support Beta and PTR versions. If their versions are newer than the current game version they will be appended to the interface version. E.g. If retail is `110002` and there's a PTR for `110005` then the TOC file will be updated to: `## Interface: 110002, 110005`.

## Usage

You'll need `bash >= 4.0`, `nc`, `awk`, `sed`, `grep`, `find`, `getopt` and `md5sum` installed on your system.  
Only GNU versions are officially supported, Busybox alternatives (or others) have not been tested.

Then run the script:
```bash
bash update.sh                  # use the default flavor
bash update.sh -f classic       # set Classic as the default Interface version
bash update.sh -f classic -b -p # set Classic as the default Interface version,
                                # and add beta and PTR versions
```

Run the script with `--help` to see all available options.

## GitHub Action

You can use this in a GitHub workflow by referencing `p3lim/toc-interface-updater@v3`.

Options:
- `flavor` - sets the fallback game version for unsuffixed TOC files, see [flavor](#flavor) for valid options
- `beta` - set to `true` if beta versions should be appended
- `ptr` - set to `true` if PTR versions should be appended
- `depth` - change the recursion depth when looking for TOC files

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
        uses: actions/checkout@v4

      - name: Update TOC Interface version
        uses: p3lim/toc-interface-updater@v4
        with:
          flavor: retail # this is the default
          beta: true     # this is optional
          ptr: true      # this is optional

      - name: Create pull request
        uses: peter-evans/create-pull-request@v6
        with:
          title: Update Interface version
          commit-message: Update Interface version
          branch: interface-version
          delete-branch: true
```
