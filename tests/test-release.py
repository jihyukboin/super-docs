import json
import os
from pathlib import Path
import runpy
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/prepare-release.py'

class ReleaseVersionTests(unittest.TestCase):
    def run_version(self, main='merged-sha', published='previous-sha', drafts=None, tag='v0.1.0'):
        latest = {'tag_name': tag, 'target_commitish': published}
        def gh(command):
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

    def test_already_published_is_noop(self):
        self.assertEqual(self.run_version(published='merged-sha'), {'skip': 'true'})

    def test_superseded_merge_cannot_replace_newer_release(self):
        self.assertEqual(self.run_version(main='newer-main'), {'skip': 'true'})

    def test_retry_reuses_own_draft(self):
        draft = {'tag_name': 'v0.1.1', 'target_commitish': 'merged-sha'}
        self.assertEqual(self.run_version(drafts=[draft])['tag'], 'v0.1.1')

    def test_never_overwrites_another_release(self):
        draft = {'tag_name': 'v0.1.1', 'target_commitish': 'different-sha'}
        with self.assertRaises(SystemExit):
            self.run_version(drafts=[draft])

    def test_invalid_previous_tag_fails_closed(self):
        with self.assertRaises(SystemExit):
            self.run_version(tag='unexpected')

if __name__ == '__main__':
    unittest.main()
