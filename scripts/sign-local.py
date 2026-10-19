#!/usr/bin/env python3
"""Sign a local Vo1cy build with a persistent, private development identity.

Uses a dedicated keychain; never changes certificate trust or TCC grants.
Not a substitute for Developer ID signing/notarization for distribution.
"""
from pathlib import Path
import os
import secrets
import subprocess
import sys
import tempfile


def run(args):
    result = subprocess.run(args, capture_output=True, text=True)
    if result.returncode:
        # Do not include command arguments: some contain the keychain password.
        raise RuntimeError(result.stderr.strip())
    return result.stdout


def main():
    if len(sys.argv) != 2:
        raise RuntimeError("Usage: sign-local.py /path/to/Vo1cy.app")
    app = Path(sys.argv[1]).resolve()
    identifier = run(["/usr/libexec/PlistBuddy", "-c", "Print :CFBundleIdentifier", str(app / "Contents/Info.plist")]).strip()
    if identifier != "app.vo1cy.mac":
        raise RuntimeError("Refusing to sign a bundle other than Vo1cy")
    os.umask(0o077)
    root = Path.home() / "Library/Application Support/Vo1cy Development Signing"
    root.mkdir(mode=0o700, exist_ok=True)
    keychain = root / "local.keychain-db"
    password_file = root / "keychain-password"
    identity_file = root / "identity.txt"
    if not keychain.exists():
        if identity_file.exists():
            raise RuntimeError("Signing keychain missing. Restore it instead of silently replacing the identity.")
        password_file.write_text(secrets.token_hex(32))
        run(["security", "create-keychain", "-p", password_file.read_text(), str(keychain)])
    password = password_file.read_text()
    run(["security", "unlock-keychain", "-p", password, str(keychain)])
    run(["security", "set-keychain-settings", "-t", "21600", str(keychain)])
    if not identity_file.exists():
        with tempfile.TemporaryDirectory(prefix="vo1cy-signing-") as temporary:
            tmp = Path(temporary)
            config = tmp / "openssl.cnf"
            config.write_text("""[req]
 distinguished_name=dn
 x509_extensions=ext
 prompt=no
 [dn]
 CN=Vo1cy Local Development
 O=Vo1cy Local
 [ext]
 basicConstraints=critical,CA:false
 keyUsage=critical,digitalSignature
 extendedKeyUsage=critical,codeSigning
 subjectKeyIdentifier=hash
 """)
            # Apple's OpenSSL produces a PKCS#12 format accepted by Keychain.
            run(["/usr/bin/openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "3650", "-config", str(config), "-keyout", str(tmp / "key.pem"), "-out", str(tmp / "cert.pem")])
            run(["/usr/bin/openssl", "pkcs12", "-export", "-inkey", str(tmp / "key.pem"), "-in", str(tmp / "cert.pem"), "-out", str(tmp / "identity.p12"), "-passout", "pass:" + password])
            run(["security", "import", str(tmp / "identity.p12"), "-k", str(keychain), "-P", password, "-T", "/usr/bin/codesign"])
            fingerprint = run(["/usr/bin/openssl", "x509", "-in", str(tmp / "cert.pem"), "-noout", "-fingerprint", "-sha1"]).strip().split("=")[1].replace(":", "")
            run(["security", "set-key-partition-list", "-S", "apple-tool:,apple:", "-s", "-k", password, str(keychain)])
            (root / "certificate.pem").write_text((tmp / "cert.pem").read_text())
            identity_file.write_text(fingerprint + "\n")
    identity = identity_file.read_text().strip()
    if len(identity) != 40 or any(c not in "0123456789abcdefABCDEF" for c in identity):
        raise RuntimeError("Invalid local signing identity")
    run(["codesign", "--force", "--sign", identity, "--keychain", str(keychain), "--timestamp=none", "--entitlements", str(Path(__file__).resolve().parent.parent / "Resources/Vo1cy.entitlements"), str(app)])
    run(["codesign", "--verify", "--deep", "--strict", str(app)])
    print("Signed with persistent local Vo1cy identity; no system trust changes.")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
