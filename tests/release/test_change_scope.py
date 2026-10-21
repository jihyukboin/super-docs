import runpy
import subprocess
import tempfile
import unittest
from pathlib import Path

scope = runpy.run_path(str(Path(__file__).resolve().parents[2] / 'scripts/change-scope.py'))

class ChangeScopeTests(unittest.TestCase):
    def test_only_known_documentation_is_skipped(self):
        self.assertTrue(scope['documentation_only'](['README.md', 'docs/build.md', '.github/ISSUE_TEMPLATE/bug_report.md']))
        for path in ['LICENSE', 'Resources/Info.plist', 'Sources/main.swift', '.github/workflows/ci.yml',
                     'scripts/change-scope.py', 'tests/release/test_release.py', 'package-lock.json',
                     'web/docx/editor.tsx', 'new-unknown-file', 'docs/code.js']:
            self.assertFalse(scope['documentation_only'](['README.md', path]), path)
        self.assertFalse(scope['documentation_only']([]))

    def test_rename_out_of_app_is_not_documentation_only(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def git(*args):
                return subprocess.check_output(['git', '-C', directory, *args])
            git('init', '-q')
            git('config', 'user.email', 'test@example.com')
            git('config', 'user.name', 'Test')
            (root / 'code.swift').write_text('code')
            git('add', '.')
            git('commit', '-qm', 'base')
            base = git('rev-parse', 'HEAD').decode().strip()
            git('mv', 'code.swift', 'README.md')
            git('commit', '-qm', 'rename')
            import os
            previous = os.getcwd()
            try:
                os.chdir(directory)
                paths = scope['changed_paths'](base, 'HEAD')
            finally:
                os.chdir(previous)
            self.assertIn('code.swift', paths)
            self.assertFalse(scope['documentation_only'](paths))

if __name__ == '__main__':
    unittest.main()
