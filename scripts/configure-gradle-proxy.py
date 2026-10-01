"""Use o proxy da plataforma com TLS verificado; grava só configurações locais."""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
from urllib.parse import urlparse

proxy_url = os.environ.get("HTTPS_PROXY") or os.environ.get("https_proxy")
if not proxy_url:
    raise SystemExit(0)
proxy = urlparse(proxy_url)
if proxy.username or proxy.password:
    raise SystemExit("Proxy com credenciais exige configuração protegida própria.")
if not proxy.hostname:
    raise SystemExit("Proxy inválido.")
cache = Path(os.environ.get("GRADLE_USER_HOME", "/workspace/.cache/gradle"))
cache.mkdir(parents=True, exist_ok=True)
settings = {
    "systemProp.http.proxyHost": proxy.hostname,
    "systemProp.http.proxyPort": str(proxy.port or 80),
    "systemProp.https.proxyHost": proxy.hostname,
    "systemProp.https.proxyPort": str(proxy.port or 80),
    "systemProp.http.nonProxyHosts": "localhost|127.*|[::1]",
}
certificate = os.environ.get("CODEX_PROXY_CERT")
if certificate and Path(certificate).is_file():
    java_home = Path(shutil.which("java")).resolve().parent.parent
    truststore = cache / "cloud-cacerts"
    if not truststore.exists():
        shutil.copyfile(java_home / "lib/security/cacerts", truststore)
    alias = "patota-proxy-" + hashlib.sha256(Path(certificate).read_bytes()).hexdigest()[:16]
    common = ["-keystore", str(truststore), "-storepass", "changeit"]
    exists = subprocess.run(["keytool", "-list", "-alias", alias, *common], capture_output=True)
    if exists.returncode:
        subprocess.run(["keytool", "-importcert", "-noprompt", "-trustcacerts",
                        "-alias", alias, "-file", certificate, *common], check=True, capture_output=True)
    settings["systemProp.javax.net.ssl.trustStore"] = str(truststore)
    settings["systemProp.javax.net.ssl.trustStorePassword"] = "changeit"
path = cache / "gradle.properties"
lines = path.read_text().splitlines() if path.exists() else []
lines = [line for line in lines if line.split("=", 1)[0] not in settings]
path.write_text("\n".join(lines + [f"{key}={value}" for key, value in settings.items()]) + "\n")
print("Proxy Java configurado com verificação TLS, fora do repositório.")
