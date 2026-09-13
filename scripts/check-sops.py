#!/usr/bin/env python3
"""Validate ciphertext without decrypting or printing secret values."""
import pathlib
import re
import subprocess
import sys
import yaml


class UniqueKeyLoader(yaml.SafeLoader):
    pass


def unique_mapping(loader, node, deep=False):
    result = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if not isinstance(key, str) or key in result:
            raise ValueError('duplicate or non-string YAML key')
        result[key] = loader.construct_object(value_node, deep=deep)
    return result


UniqueKeyLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, unique_mapping)


def validate(text):
    try:
        data = yaml.load(text, Loader=UniqueKeyLoader)
    except yaml.YAMLError:
        raise ValueError('invalid YAML') from None
    if not isinstance(data, dict) or not isinstance(data.get('sops'), dict):
        raise ValueError('missing SOPS metadata')
    metadata = data['sops']
    if not isinstance(metadata.get('mac'), str) or not metadata['mac'].startswith('ENC[AES256_GCM,'):
        raise ValueError('missing encrypted SOPS MAC')
    if not metadata.get('age'):
        raise ValueError('missing age recipients')
    leaves = []

    def walk(value):
        if isinstance(value, dict):
            for child in value.values():
                walk(child)
        elif isinstance(value, list):
            for child in value:
                walk(child)
        else:
            leaves.append(value)

    for key, value in data.items():
        if key != 'sops':
            walk(value)
    if not leaves or any(not isinstance(v, str) or not re.fullmatch(r'ENC\[AES256_GCM,.+\]', v) for v in leaves):
        raise ValueError('secret values must all be SOPS ciphertext')


def main():
    if sys.argv[1:] == ['--index']:
        # Inspect exactly what git commit will write, even with partial staging.
        names = subprocess.check_output(['git', 'ls-files', '--cached', '-z']).decode().split('\0')
        forbidden = re.compile(r'(^|/)(\.env(?:\..+)?|credentials(?:[^/]*)\.json|id_(?:rsa|ed25519)|keys\.txt)$|\.(?:key|private|pem|p12|pfx|hm-bak)$|\.(?:invalid|snapshot)\.')
        for name in names:
            if name and forbidden.search(name) and pathlib.PurePosixPath(name).name not in ('.env.example', '.env.sample'):
                raise ValueError('credential/backup filename staged: ' + name)
        text = subprocess.check_output(['git', 'show', ':secrets.yaml']).decode()
    else:
        text = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else 'secrets.yaml').read_text()
    validate(text)
    print('SOPS ciphertext check passed')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        # YAML parser exceptions can include plaintext: never print their context.
        print('SOPS/index check failed: ' + str(error), file=sys.stderr)
        sys.exit(1)
