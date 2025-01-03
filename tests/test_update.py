import pytest
import os
from toc_interface_updater.update import main

def test_update_toc_files(toc_files, product_versions, monkeypatch):
    # Change the working directory to the temporary directory with the .toc files
    monkeypatch.chdir(toc_files)

    # Simulate running the script without any flags
    monkeypatch.setattr('sys.argv', ['update.py'])

    # Run the update script
    main()

    # Check the contents of the updated files
    expected_content = {
        "default.toc": f"## Interface: {product_versions['wow']}\n\nfile.lua\n",
        "specific-Classic.toc": f"## Interface: {product_versions['wow_classic']}\n\nfile.lua\n",
        "multi.toc": f"## Interface: {product_versions['wow']}\n## Interface-Vanilla: {product_versions['wow_classic_era']}\n## Interface-Classic: {product_versions['wow_classic']}\n## Interface-Cata: {product_versions['wow_classic']}\n\nfile.lua\n",
        "multi-oneline.toc": f"## Interface: {product_versions['wow_classic_era']}, {product_versions['wow_classic']}, {product_versions['wow']}\n\nfile.lua\n",
        "specific-Mainline.toc": f"## Interface: {product_versions['wow']}\n\nfile.lua\n",
        "specific_Cata.toc": f"## Interface: {product_versions['wow_classic']}\n\nfile.lua\n"
    }

    for filename, expected in expected_content.items():
        file_path = toc_files / filename
        assert file_path.read_text() == expected, f"File: {filename}"

def test_update_toc_files_with_ptr_flag(toc_files, product_versions, monkeypatch):
    # Change the working directory to the temporary directory with the .toc files
    monkeypatch.chdir(toc_files)

    # Simulate the PTR flag
    monkeypatch.setattr('sys.argv', ['update.py', '--ptr'])

    base_retail_version = product_versions['wow']
    retail_ptr_versions = set()
    retail_ptr_versions.add(base_retail_version)
    retail_ptr_check = product_versions['wowt']
    if int(retail_ptr_check) > int(base_retail_version):
        retail_ptr_versions.add(retail_ptr_check)
    retail_ptr_check = product_versions['wowxptr']
    if int(retail_ptr_check) > int(base_retail_version):
        retail_ptr_versions.add(retail_ptr_check)
    retail_ptr_versions = ', '.join(sorted(retail_ptr_versions, key=lambda x: int(x)))

    base_classic_version = product_versions['wow_classic']
    classic_ptr_versions = set()
    classic_ptr_versions.add(base_classic_version)
    classic_ptr_check = product_versions['wow_classic_ptr']
    if int(classic_ptr_check) > int(base_classic_version):
        classic_ptr_versions.add(classic_ptr_check)
    classic_ptr_versions = ', '.join(sorted(classic_ptr_versions, key=lambda x: int(x)))

    base_classic_era_version = product_versions['wow_classic_era']
    classic_era_ptr_versions = set()
    classic_era_ptr_versions.add(base_classic_era_version)
    classic_era_ptr_check = product_versions['wow_classic_era_ptr']
    if int(classic_era_ptr_check) > int(base_classic_era_version):
        classic_era_ptr_versions.add(classic_era_ptr_check)
    classic_era_ptr_versions = ', '.join(sorted(classic_era_ptr_versions, key=lambda x: int(x)))

    # Run the update script
    main()

    # Check the contents of the updated files
    expected_content = {
        "default.toc": f"## Interface: {retail_ptr_versions}\n\nfile.lua\n",
        "specific-Classic.toc": f"## Interface: {classic_ptr_versions}\n\nfile.lua\n",
        "multi.toc": f"## Interface: {retail_ptr_versions}\n## Interface-Vanilla: {classic_era_ptr_versions}\n## Interface-Classic: {classic_ptr_versions}\n## Interface-Cata: {classic_ptr_versions}\n\nfile.lua\n",
        "multi-oneline.toc": f"## Interface: {classic_era_ptr_versions}, {classic_ptr_versions}, {retail_ptr_versions}\n\nfile.lua\n",
        "specific-Mainline.toc": f"## Interface: {retail_ptr_versions}\n\nfile.lua\n",
        "specific_Cata.toc": f"## Interface: {classic_ptr_versions}\n\nfile.lua\n"
    }

    for filename, expected in expected_content.items():
        file_path = toc_files / filename
        assert file_path.read_text() == expected, f"File: {filename}"

def test_update_toc_files_with_beta_flag(toc_files, product_versions, monkeypatch):
    # Change the working directory to the temporary directory with the .toc files
    monkeypatch.chdir(toc_files)

    # Simulate the Beta flag
    monkeypatch.setattr('sys.argv', ['update.py', '--beta'])


    retail_beta_versions = set()
    base_retail_version = product_versions['wow']
    retail_beta_versions.add(base_retail_version)
    retail_beta_check = product_versions['wow_beta']
    if int(retail_beta_check) > int(base_retail_version):
        retail_beta_versions.add(retail_beta_check)
    retail_beta_versions = ', '.join(sorted(retail_beta_versions, key=lambda x: int(x)))

    classic_beta_versions = set()
    base_classic_version = product_versions['wow_classic']
    classic_beta_versions.add(base_classic_version)
    classic_beta_check = product_versions['wow_classic_beta']
    if int(classic_beta_check) > int(base_classic_version):
        classic_beta_versions.add(classic_beta_check)
    classic_beta_versions = ', '.join(sorted(classic_beta_versions, key=lambda x: int(x)))

    classic_era_beta_versions = set()
    base_classic_era_version = product_versions['wow_classic_era']
    classic_era_beta_versions.add(base_classic_era_version)
    # classic_era_beta_check = product_versions['wow_classic_era_beta']
    # if int(classic_era_beta_check) > int(base_classic_era_version):
    #     classic_era_beta_versions.add(classic_era_beta_check)
    classic_era_beta_versions = ', '.join(sorted(classic_era_beta_versions, key=lambda x: int(x)))

    # Run the update script
    main()

    # Check the contents of the updated files
    expected_content = {
        "default.toc": f"## Interface: {retail_beta_versions}\n\nfile.lua\n",
        "specific-Classic.toc": f"## Interface: {classic_beta_versions}\n\nfile.lua\n",
        "multi.toc": f"## Interface: {retail_beta_versions}\n## Interface-Vanilla: {classic_era_beta_versions}\n## Interface-Classic: {classic_beta_versions}\n## Interface-Cata: {classic_beta_versions}\n\nfile.lua\n",
        "multi-oneline.toc": f"## Interface: {classic_era_beta_versions}, {classic_beta_versions}, {retail_beta_versions}\n\nfile.lua\n",
        "specific-Mainline.toc": f"## Interface: {retail_beta_versions}\n\nfile.lua\n",
        "specific_Cata.toc": f"## Interface: {classic_beta_versions}\n\nfile.lua\n"
    }

    for filename, expected in expected_content.items():
        file_path = toc_files / filename
        assert file_path.read_text() == expected, f"File: {filename}"