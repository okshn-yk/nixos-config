"""Reject real failure modes without storing test credentials in Git."""
import importlib.util
import pathlib
import subprocess
import sys
import tempfile
import unittest
import yaml

sys.dont_write_bytecode = True
ROOT = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('checker', ROOT / 'scripts/check-sops.py')
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)
ENCRYPTED = (ROOT / 'secrets.yaml').read_text()


class SecretsTests(unittest.TestCase):
    def test_encrypted_document(self):
        checker.validate(ENCRYPTED)

    def test_plaintext_is_rejected(self):
        data = yaml.safe_load(ENCRYPTED)
        data['unexpected'] = 'example plaintext'
        with self.assertRaises(ValueError):
            checker.validate(yaml.safe_dump(data))

    def test_duplicate_keys_are_rejected(self):
        key = next(k for k in yaml.safe_load(ENCRYPTED) if k != 'sops')
        with self.assertRaises(ValueError):
            checker.validate(f'{key}: hidden plaintext\n' + ENCRYPTED)

    def test_invalid_yaml_does_not_echo_values(self):
        with self.assertRaises(ValueError) as result:
            checker.validate('unexpected: [sensitive-example')
        self.assertNotIn('sensitive-example', str(result.exception))

    def test_staged_content_and_filenames(self):
        with tempfile.TemporaryDirectory() as directory:
            def git(*args):
                subprocess.run(['git', *args], cwd=directory, check=True, capture_output=True)
            def check():
                return subprocess.run([sys.executable, str(ROOT / 'scripts/check-sops.py'), '--index'], cwd=directory, capture_output=True, text=True)
            git('init', '-q')
            secret = pathlib.Path(directory, 'secrets.yaml')
            secret.write_text(ENCRYPTED + '\nunexpected: staged-plaintext\n')
            git('add', 'secrets.yaml')
            secret.write_text(ENCRYPTED)
            result = check()
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn('staged-plaintext', result.stderr)
            git('add', 'secrets.yaml')
            self.assertEqual(check().returncode, 0)
            pathlib.Path(directory, '.env').write_text('EXAMPLE=value')
            git('add', '.env')
            self.assertNotEqual(check().returncode, 0)

    def test_gitleaks_rejects_staged_token(self):
        with tempfile.TemporaryDirectory() as directory:
            subprocess.run(['git', 'init', '-q', directory], check=True)
            # Synthetic nonfunctional value, assembled at runtime.
            token = 'ghp_' + 'AbCdEf0123456789' * 3
            pathlib.Path(directory, 'config.txt').write_text('token = "' + token + '"\n')
            subprocess.run(['git', 'add', 'config.txt'], cwd=directory, check=True)
            result = subprocess.run(['gitleaks', 'git', '--staged', '--redact', '--no-banner', directory], capture_output=True, text=True)
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertNotIn(token, result.stderr + result.stdout)


if __name__ == '__main__':
    unittest.main()
