import argparse
from enum import Enum
import os
import re
import socket
from typing import Dict, List, Literal, Set

TestProduct = Literal['wowt', 'wowxptr', 'wow_classic_ptr', 'wow_classic_era_ptr']
BetaProduct = Literal['wow_beta', 'wow_classic_beta', 'wow_classic_era_beta']
FullProduct = Literal['wow', 'wow_classic', 'wow_classic_era']
Product = TestProduct | BetaProduct | FullProduct
VersionCache = Dict[Product, str]

# ANSI escape sequences for colors and formatting
RESET = "\033[0m"
BOLD = "\033[1m"
LIGHT_BLUE = "\033[94m"
GREEN = "\033[32m"
YELLOW = "\033[33m"

line_ending = "\n"

class GameFlavor(Enum):
    WOW = 'wow'
    WOW_CLASSIC = 'wow_classic'
    WOW_CLASSIC_ERA = 'wow_classic_era'


def flavor_type(value):
    flavor_map = {
        'retail': GameFlavor.WOW,
        'mainline': GameFlavor.WOW,
        'classic': GameFlavor.WOW_CLASSIC,
        'cata': GameFlavor.WOW_CLASSIC,
        'classic_era': GameFlavor.WOW_CLASSIC_ERA,
        'vanilla': GameFlavor.WOW_CLASSIC_ERA
    }
    if value.lower() not in flavor_map:
        raise argparse.ArgumentTypeError(f"Invalid flavor: {value}. Allowed values are: {', '.join(flavor_map.keys())}")
    return flavor_map[value.lower()]

def product_version(product: Product, version_cache: VersionCache):
    if product in version_cache:
        return version_cache[product]
    else:
        host = 'us.version.battle.net'
        port = 1119
        request = f"v1/products/{product}/versions\n"

        try:
            with socket.create_connection((host, port), timeout=10) as sock:
                sock.sendall(request.encode())
                response = []
                while True:
                    data = sock.recv(4096)
                    if not data:
                        break
                    response.append(data.decode())
                response_data = ''.join(response)
        except (socket.timeout, socket.error) as e:
            print(f"Error communicating with server: {e}")
            return None

        version = ""
        for line in response_data.splitlines():
            if line.startswith('us'):
                version = line.split('|')[5]
                break
        version = version.rsplit('.', 1)[0]

        [major, minor, patch] = version.split('.')
        # Pad minor and patch to ensure they are two digits
        minor = minor.zfill(2)  # Ensure minor is 2 digits
        patch = patch.zfill(2)  # Ensure patch is 2 digits

        version = f"{major}{minor}{patch}"
        version_cache[product] = version
        return version


def update_versions(file: str, product: FullProduct, multi: bool, beta: bool, test: bool, version_cache: VersionCache, modified_files: List[str]):
    print(f"{LIGHT_BLUE}Checking {RESET}{BOLD}{file}{RESET}{LIGHT_BLUE} ({product})...{RESET} ", end='')

    # Read the original file content
    with open(file, 'r') as f:
        original_content = f.read()

    # Normalize line endings for comparison (convert to Unix-style \n for processing)
    original_content_normalized = original_content.replace('\r\n', '\n').replace('\r', '\n')

    # Get base version
    base_version = product_version(product, version_cache)
    versions: Set[str] = set()
    versions.add(base_version)

    # Handle beta versions
    if beta:
        beta_products: List[BetaProduct] = []
        if product == 'wow':
            beta_products.append('wow_beta')
        elif product == 'wow_classic':
            beta_products.append('wow_classic_beta')

        for beta_product in beta_products:
            beta_version = product_version(beta_product, version_cache)
            if beta_version > base_version:
                versions.add(beta_version)

    # Handle test versions
    if test:
        test_products: List[TestProduct] = []
        if product == 'wow':
            test_products.extend(['wowt', 'wowxptr'])
        elif product == 'wow_classic':
            test_products.append('wow_classic_ptr')
        elif product == 'wow_classic_era':
            test_products.append('wow_classic_era_ptr')

        for test_product in test_products:
            test_version = product_version(test_product, version_cache)
            if test_version > base_version:
                versions.add(test_version)

    # Format multiple interface versions
    interface: str = ', '.join(sorted(versions, key=lambda x: int(x)))

    # Check if we need to replace the version in the content
    updated_content = original_content_normalized

    single_line_multi: bool = False
    single_line_pattern = re.compile(r'^(## Interface:).*\,.*$', flags=re.MULTILINE)
    if single_line_pattern.search(updated_content):
        single_line_multi = not multi
        detected_versions = single_line_pattern.search(updated_content).group(0).split(':')[1].strip().split(',')
        versions: Set[str] = set()
        for d_version in detected_versions:
            if d_version.strip() not in versions:
                major = int(d_version.strip()[:-4])
                if major == 1:
                    versions.add(product_version("wow_classic_era", version_cache))
                    if test:
                        classic_era_ptr_version = product_version("wow_classic_era_ptr", version_cache)
                        if int(d_version) < int(classic_era_ptr_version):
                            versions.add(classic_era_ptr_version)
                elif major < 11:
                    versions.add(product_version("wow_classic", version_cache))
                    if beta:
                        classic_beta_version = product_version("wow_classic_beta", version_cache)
                        if int(d_version) < int(classic_beta_version):
                            versions.add(classic_beta_version)
                    if test:
                        classic_ptr_version = product_version("wow_classic_ptr", version_cache)
                        if int(d_version) < int(classic_ptr_version):
                            versions.add(classic_ptr_version)
                else:
                    versions.add(product_version("wow", version_cache))
                    if beta:
                        beta_version = product_version("wow_beta", version_cache)
                        if int(d_version) < int(beta_version):
                            versions.add(beta_version)
                        print(f"Beta detected, single line multi: {versions}")
                    if test:
                        ptr_version = product_version("wowt", version_cache)
                        if int(d_version) < int(ptr_version):
                            versions.add(ptr_version)
                        ptr_version = product_version("wowxptr", version_cache)
                        if int(d_version) < int(ptr_version):
                            versions.add(ptr_version)
                        print(f"Test detected, single line multi: {versions}")

        sorted_versions = sorted(versions, key=lambda x: int(x))
        interface = ', '.join(sorted_versions)

    if multi and not single_line_multi:
        if product == 'wow_classic':
            updated_content = re.sub(r'^(## Interface-Cata:).*$', f"## Interface-Cata: {interface}", updated_content, flags=re.MULTILINE)
            updated_content = re.sub(r'^(## Interface-Classic:).*$', f"## Interface-Classic: {interface}", updated_content, flags=re.MULTILINE)
        elif product == 'wow_classic_era':
            updated_content = re.sub(r'^(## Interface-Vanilla:).*$', f"## Interface-Vanilla: {interface}", updated_content, flags=re.MULTILINE)
    else:
        updated_content = re.sub(r'^(## Interface:).*$', f"## Interface: {interface}", updated_content, flags=re.MULTILINE)

    # Only write the file if there is a real change (ignoring whitespace or line endings)
    if updated_content != original_content_normalized:
        # Restore the original line endings before writing back to the file
        updated_content_with_original_line_endings = updated_content.replace('\n', line_ending)
        
        with open(file, 'w', newline='') as f:  # Ensure the newline='' to allow custom line endings
            f.write(updated_content_with_original_line_endings)

        modified_files.append(file)
        print(f"{GREEN}Updated{RESET}")
    else:
        print(f"{YELLOW}No change{RESET}")


def main():
    parser = argparse.ArgumentParser(description='Version Replacer')
    parser.add_argument('-b', '--beta', action='store_true', help='Include beta versions')
    parser.add_argument('-p', '--ptr', action='store_true', help='Include test versions')
    parser.add_argument('-f', '--flavor', type=flavor_type, default=GameFlavor.WOW, help='Game flavor (retail, mainline, classic, cata, classic_era, vanilla)')
    args = parser.parse_args()

    beta: bool = args.beta
    test: bool = args.ptr
    flavor: str = args.flavor.value

    version_cache: VersionCache = {}
    modified_files: List[str] = []

    # Regular expression to match both _ and - before Mainline, Classic, Cata, Vanilla
    pattern = re.compile(r'[-_](Mainline|Classic|Cata|Vanilla)\.toc$')

    for root, _, files in os.walk('.'):
        for file in files:
            if file.endswith('.toc'):
                file_path = os.path.join(root, file)

                # Check if the file matches the pattern (with both _ and - support)
                if not pattern.search(file_path):
                    update_versions(file_path, flavor, False, beta, test, version_cache, modified_files)
                    update_versions(file_path, 'wow_classic', True, beta, test, version_cache, modified_files)
                    update_versions(file_path, 'wow_classic_era', True, beta, test, version_cache, modified_files)
                elif pattern.search(file_path):
                    if 'Mainline' in file_path:
                        update_versions(file_path, 'wow', False, beta, test, version_cache, modified_files)
                    elif 'Classic' in file_path or 'Cata' in file_path:
                        update_versions(file_path, 'wow_classic', False, beta, test, version_cache, modified_files)
                    elif 'Vanilla' in file_path:
                        update_versions(file_path, 'wow_classic_era', False, beta, test, version_cache, modified_files)

    if modified_files:
        print(f"\n{GREEN}Files modified:")
        for modified_file in modified_files:
            print(f"{GREEN}{modified_file}{RESET}")
    else:
        print(f"\n{YELLOW}No files were modified.{RESET}")

if __name__ == '__main__':
    main()
