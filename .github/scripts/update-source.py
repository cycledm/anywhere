import json
import os
import plistlib
from pathlib import Path
from urllib.parse import quote
from zipfile import ZipFile


def version_key(version):
    return tuple(
        tuple(map(int, version[field].split(".")))
        for field in ("version", "buildVersion")
    )


release_dir = Path(os.environ["RUNNER_TEMP"])
release = json.loads((release_dir / "release.json").read_text())
if release["isDraft"] or release["isPrerelease"] or not release["publishedAt"]:
    raise SystemExit("The source only lists published stable releases")

ipa = release_dir / "Anywhere.ipa"
with ZipFile(ipa) as archive:
    info = plistlib.loads(archive.read("Payload/Anywhere.app/Info.plist"))

source_path = Path("source.json")
source = json.loads(source_path.read_text())
app = next(
    (app for app in source["apps"] if app["bundleIdentifier"] == info["CFBundleIdentifier"]),
    None,
)
if app is None:
    raise SystemExit("The IPA bundle identifier is missing from source.json")

tag = quote(os.environ["RELEASE_TAG"], safe="")
repository = os.environ["GITHUB_REPOSITORY"]
version = {
    "version": info["CFBundleShortVersionString"],
    "buildVersion": info["CFBundleVersion"],
    "date": release["publishedAt"],
    "downloadURL": f"https://github.com/{repository}/releases/download/{tag}/{ipa.name}",
    "size": ipa.stat().st_size,
    "minOSVersion": info["MinimumOSVersion"],
}
key = version_key(version)
previous = next((entry for entry in app["versions"] if version_key(entry) == key), {})
version["localizedDescription"] = (
    (previous.get("localizedDescription") or "").strip()
    or (release.get("body") or "").strip()
    or f"Anywhere {version['version']} (Build {version['buildVersion']})."
)
versions = [entry for entry in app["versions"] if version_key(entry) != key]
app["versions"] = sorted([version, *versions], key=version_key, reverse=True)
source_path.write_text(json.dumps(source, ensure_ascii=False, indent=2) + "\n")
