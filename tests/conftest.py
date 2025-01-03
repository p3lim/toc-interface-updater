import pytest

@pytest.fixture
def toc_files(tmp_path):
    toc_content = {
        "default.toc": "## Interface: 110007\n\nfile.lua\n",
        "specific-Classic.toc": "## Interface: 40401\n\nfile.lua\n",
        "multi.toc": "## Interface: 110007\n## Interface-Vanilla: 11505\n## Interface-Classic: 40401\n## Interface-Cata: 40400\n\nfile.lua\n",
        "multi-oneline.toc": "## Interface: 11505, 40401, 110007\n\nfile.lua\n",
        "specific-Mainline.toc": "## Interface: 110007\n\nfile.lua\n",
        "specific_Cata.toc": "## Interface: 40401\n\nfile.lua\n"
    }

    for filename, content in toc_content.items():
        file_path = tmp_path / filename
        file_path.write_text(content)

    return tmp_path

@pytest.fixture
def product_versions():
    from toc_interface_updater.update import product_version

    versions = {}
    product_version("wow", versions)
    product_version("wowt", versions)
    product_version("wowxptr", versions)
    product_version("wow_beta", versions)
    product_version("wow_classic", versions)
    product_version("wow_classic_ptr", versions)
    product_version("wow_classic_beta", versions)
    product_version("wow_classic_era", versions)
    product_version("wow_classic_era_ptr", versions)
    # The product exists but there is no version information for it
    # product_version("wow_classic_era_beta", versions)

    return versions