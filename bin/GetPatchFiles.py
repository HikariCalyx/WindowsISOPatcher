import json
import requests
import time
import argparse

parser = argparse.ArgumentParser(
    prog='GetPatchFiles.py',
    description='This will get the accumulative update download link from UUPDump to allow security update integration, helpful for LTSC builds.',
    epilog='2015-2024 (C) Hikari Calyx Tech. All Rights Reserved.\r\nWindows is a trademark of Microsoft Corporation.'
)
parser.add_argument('major_build_version', metavar='target_build', type=str, help='Target Build Version, e.g. 19041')
parser.add_argument('architecture', metavar='target_arch', type=str, help='Architecture of target build, only amd64, arm64 and x86 are supported.')

uupdump_base_url = 'https://api.uupdump.net/'

ignore_kbs = ['5003791', '5007401', '5008575', '5032906', '5028310', 'baseless']
known_server_specific_builds = ['20348', '25398']

args = parser.parse_args()
target_build = args.major_build_version
target_arch = args.architecture

if __name__ == '__main__':
    if target_arch in ['x64', 'x86_64']:
        print('W: You should use amd64 as target architecture. ')
        target_arch = 'amd64'
    elif target_arch in ['i386', 'i686', 'ia32']:
        print('W: You should use x86 as target architecture. ')
        target_arch = 'x86'
    elif target_arch in ['aarch64', 'aa64']:
        print('W: You should use arm64 as target architecture. ')
        target_arch = 'arm64'
    elif target_arch not in ['amd64', 'arm64', 'x86']:
        print('ERROR: Invalid Architecture. Should be amd64, arm64 or x86. ')
        exit(1)

    final_build, build_uuid = 'undefined', 'undefined'

    print('Fetching Build...')
    search_result = json.loads(requests.get(uupdump_base_url + 'listid.php?search=' + target_build).text)
    if 'builds' in search_result['response']:
        build_list = search_result['response']['builds']
        for i in build_list:
            if 'server' in build_list[i]['title'].lower() and target_build not in known_server_specific_builds:
                continue
            if build_list[i]['arch'] == target_arch:
                final_build, build_uuid = build_list[i]['build'], build_list[i]['uuid']
                break
    else:
        print('ERROR: No updates found. ')
        exit(1)

    time.sleep(10)
    print('Fetching update...')
    if final_build != 'undefined' and build_uuid != 'undefined':
        files_list = json.loads(requests.get(uupdump_base_url + 'get.php?id=' + build_uuid).text)['response']['files']
        for i in files_list:
            lowi = i.lower()
            if lowi.endswith('.cab') and 'ssu' in lowi:
                with open('patchfilelist_' + target_build + '_' + target_arch + '.txt', 'a+', encoding='utf-8') as entry:
                    entry.writelines([files_list[i]['url'] + '\r\n', ' out=' + i + '\r\n', ' checksum=sha-1=' + files_list[i]['sha1'] + '\r\n', '\r\n'])
            elif lowi.endswith('.cab') and 'kb' in lowi and not any(s in lowi for s in ignore_kbs):
                with open('patchfilelist_' + target_build + '_' + target_arch + '.txt', 'a+', encoding='utf-8') as entry:
                    entry.writelines([files_list[i]['url'] + '\r\n', ' out=' + i + '\r\n', ' checksum=sha-1=' + files_list[i]['sha1'] + '\r\n', '\r\n'])
            elif lowi.endswith('.msu') and lowi.startswith('windows11') and 'kb' in lowi and not any(s in lowi for s in ignore_kbs):
                with open('patchfilelist_' + target_build + '_' + target_arch + '.txt', 'a+', encoding='utf-8') as entry:
                    entry.writelines([files_list[i]['url'] + '\r\n', ' out=' + i + '\r\n', ' checksum=sha-1=' + files_list[i]['sha1'] + '\r\n', '\r\n'])
    else:
        print('ERROR: No updates found. ')
        exit(1)