import json
import os
from pathlib import Path
import runpy
import tempfile
import subprocess
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[2] / 'scripts/prepare-release.py'

class ReleaseVersionTests(unittest.TestCase):
    def run_version(self, main='merged-sha', published='previous-sha', drafts=None, tag='v0.1.0', files=None):
        latest = {'tag_name': tag, 'target_commitish': published}
        def gh(command):
            if command[0] == 'git':
                return ('\0'.join(files if files is not None else ['Sources/SuperDocs/main.swift']) + '\0').encode()
            path = command[-1]
            if path.endswith('/commits/main'):
                result = {'sha': main}
            elif path.endswith('/releases/latest'):
                result = latest
            else:
                result = drafts or []
            return json.dumps(result).encode()
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'output'
            env = {'GITHUB_REPOSITORY': 'owner/repo', 'RELEASE_SHA': 'merged-sha', 'GITHUB_OUTPUT': str(output)}
            with patch.dict(os.environ, env), patch('subprocess.check_output', side_effect=gh):
                runpy.run_path(str(SCRIPT))
            return dict(line.split('=', 1) for line in output.read_text().splitlines())

    def test_next_patch(self):
        self.assertEqual(self.run_version(), {'skip': 'false', 'version': '0.1.1', 'tag': 'v0.1.1'})

    def test_documentation_only_does_not_release(self):
        self.assertEqual(self.run_version(files=['README.md', 'CONTRIBUTING.md']), {'skip': 'true'})

    def test_packaged_license_still_releases(self):
        self.assertEqual(self.run_version(files=['LICENSE'])['skip'], 'false')

    def test_already_published_is_noop(self):
        self.assertEqual(self.run_version(published='merged-sha'), {'skip': 'true'})

    def test_superseded_merge_cannot_replace_newer_release(self):
        self.assertEqual(self.run_version(main='newer-main'), {'skip': 'true'})

    def test_never_overwrites_another_release(self):
        draft = {'tag_name': 'v0.1.1', 'target_commitish': 'different-sha'}
        with self.assertRaises(SystemExit):
            self.run_version(drafts=[draft])

class StaplingTests(unittest.TestCase):
    def run_staple(self, status, succeed_at=3):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'xcrun').write_text('''#!/bin/bash
echo "$*" >> "$STAPLE_TEST_LOG"
if [ "$2" = staple ]; then
  count=$(wc -l < "$STAPLE_TEST_LOG")
  if [ "$count" -lt "$STAPLE_TEST_SUCCEED_AT" ]; then exit "$STAPLE_TEST_STATUS"; fi
fi
''')
            (root / 'sleep').write_text('#!/bin/bash\nexit 0\n')
            for name in ('xcrun', 'sleep'):
                (root / name).chmod(0o700)
            env = dict(os.environ, PATH=directory + os.pathsep + os.environ['PATH'],
                       STAPLE_TEST_LOG=str(root / 'calls'), STAPLE_TEST_STATUS=str(status),
                       STAPLE_TEST_SUCCEED_AT=str(succeed_at))
            script = SCRIPT.parent / 'staple.sh'
            result = subprocess.run(['bash', str(script), 'Test App.app'], env=env, capture_output=True)
            return result.returncode, (root / 'calls').read_text().splitlines()

    def test_transient_network_failure_retries(self):
        code, calls = self.run_staple(68)
        self.assertEqual(code, 0)
        self.assertEqual(calls, ['stapler staple Test App.app'] * 3)

    def test_permanent_error_is_not_retried(self):
        code, calls = self.run_staple(77)
        self.assertEqual(code, 77)
        self.assertEqual(len(calls), 1)

    def test_retries_are_bounded(self):
        code, calls = self.run_staple(68, succeed_at=99)
        self.assertEqual(code, 68)
        self.assertEqual(len(calls), 5)

if __name__ == '__main__':
    unittest.main()
