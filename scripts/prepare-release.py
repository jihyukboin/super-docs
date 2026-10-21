"""Choose the next patch version, preserving retry identity and merge ordering."""
import json
import os
import re
import subprocess

def api(path):
    return json.loads(subprocess.check_output(['gh', 'api', f'repos/{os.environ["GITHUB_REPOSITORY"]}/{path}']))

sha = os.environ['RELEASE_SHA']
latest = api('releases/latest')
main = api('commits/main')['sha']
skip = main != sha or latest['target_commitish'] == sha
if skip:
    print('Skipping an already published or superseded merge.')
    outputs = {'skip': 'true'}
else:
    match = re.fullmatch(r'v(\d+)\.(\d+)\.(\d+)', latest['tag_name'])
    if not match:
        raise SystemExit('Latest release must have a vMAJOR.MINOR.PATCH tag')
    major, minor, patch = map(int, match.groups())
    version = f'{major}.{minor}.{patch + 1}'
    tag = 'v' + version
    for release in api('releases?per_page=100'):
        if release['tag_name'] == tag and release['target_commitish'] != sha:
            raise SystemExit('Next version is occupied by another release; resolve that draft before publishing')
    outputs = {'skip': 'false', 'version': version, 'tag': tag}
    print(f'Preparing {tag} from {sha}')
with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
    for name, value in outputs.items():
        output.write(f'{name}={value}\n')
