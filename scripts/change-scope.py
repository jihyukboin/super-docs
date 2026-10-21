"""Conservative documentation-only classification shared by CI and releases."""
import os
import subprocess
import sys


def documentation_only(paths):
    return bool(paths) and all(
        path in {'README.md', 'CONTRIBUTING.md', 'AGENTS.md', '.github/pull_request_template.md'}
        or path.startswith('.github/ISSUE_TEMPLATE/')
        or path.startswith('docs/') and path.endswith('.md')
        for path in paths
    )


def changed_paths(base, head):
    # No rename detection: both the old and new paths must be harmless.
    data = subprocess.check_output(['git', 'diff', '--no-renames', '--name-only', '-z', base, head, '--'])
    return [os.fsdecode(path) for path in data.split(b'\0') if path]


if __name__ == '__main__':
    docs = documentation_only(changed_paths(sys.argv[1], sys.argv[2]))
    value = 'false' if docs else 'true'
    print(f'app_changed={value}')
    if os.environ.get('GITHUB_OUTPUT'):
        with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
            output.write(f'app_changed={value}\n')
