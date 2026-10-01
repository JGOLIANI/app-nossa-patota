"""Prepara Android no cloud Linux x64, com artefatos oficiais e checksums fixos."""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import urllib.request
import zipfile

tools = Path('/workspace/tools')
tools.mkdir(parents=True, exist_ok=True)

def download_verified(url, destination, algorithm, expected):
    if not destination.exists() or digest(destination, algorithm) != expected:
        with urllib.request.urlopen(url, timeout=120) as response, destination.open('wb') as output:
            shutil.copyfileobj(response, output)
    if digest(destination, algorithm) != expected:
        raise RuntimeError('Checksum inválido: o artefato não será utilizado.')

def digest(path, algorithm):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, algorithm).hexdigest()

jdk = tools / 'jdk'
sdk = tools / 'android-sdk'
with tempfile.TemporaryDirectory(prefix='patota-android-') as temporary:
    temporary = Path(temporary)
    if not (jdk / 'bin/javac').exists():
        archive = temporary / 'jdk.tar.gz'
        download_verified(
            'https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12.1+1/'
            'OpenJDK21U-jdk_x64_linux_hotspot_21.0.12.1_1.tar.gz', archive, 'sha256',
            'ce79869e1307ed8ee1e2baa86a412b1eb5b75d10a01006d788a6f968bcfaee94')
        with tarfile.open(archive) as bundle:
            root = bundle.getnames()[0].split('/')[0]
            bundle.extractall(temporary, filter='data')
        shutil.move(str(temporary / root), jdk)
    cli = sdk / 'cmdline-tools/latest/bin/android'
    if not cli.exists():
        archive = temporary / 'android-tools.zip'
        # SHA-1 publicado no repository2-3.xml oficial para o arquivo fixado.
        download_verified(
            'https://dl.google.com/android/repository/commandlinetools-linux-16111833_latest.zip',
            archive, 'sha1', 'e025545c62a8e64c7559119566a569fb1dec5f60')
        with zipfile.ZipFile(archive) as bundle:
            bundle.extractall(temporary)
        cli.parent.parent.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(temporary / 'cmdline-tools'), cli.parent.parent)
        for binary in cli.parent.iterdir():
            binary.chmod(0o755)

environment = dict(os.environ)
environment['JAVA_HOME'] = str(jdk)
environment['ANDROID_USER_HOME'] = '/workspace/.cache/android-user'
subprocess.run([str(cli), '--no-metrics', f'--sdk={sdk}', 'sdk', 'install',
                'platform-tools', 'platforms;android-36', 'platforms;android-35',
                'build-tools;36.0.0', 'ndk;28.2.13676358', 'cmake;3.22.1'],
               env=environment, input='y\n' * 100, text=True, check=True)
print('Android SDK e JDK preparados fora do checkout.')
