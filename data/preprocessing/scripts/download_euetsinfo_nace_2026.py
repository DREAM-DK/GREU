"""Download the public EUETS.INFO installation-to-NACE package from Zenodo.

This is a secondary, non-official concordance derived from European Commission
carbon-leakage lists.  The complete ZIP is preserved byte-for-byte; only the
installation and NACE tables plus schema are extracted for the feasibility test.

Run
---
python data/preprocessing/scripts/download_euetsinfo_nace_2026.py
"""

from __future__ import annotations

import hashlib
import pathlib
import time
import zipfile

import requests

RETRIEVAL_DATE = "2026-07-30"
RECORD_ID = "21414185"
CONCEPT_DOI = "https://doi.org/10.5281/zenodo.20509230"
VERSION_DOI = "https://doi.org/10.5281/zenodo.21414185"
CATALOGUE_URL = f"https://zenodo.org/records/{RECORD_ID}"
API_URL = f"https://zenodo.org/api/records/{RECORD_ID}"
ARCHIVE_URL = (
    f"https://zenodo.org/api/records/{RECORD_ID}/files/"
    "eutl_data_package_2026-07-21.zip/content"
)
EXPECTED_MD5 = "629595320851d20bd1b610878a2ecd1e"
EXPECTED_SIZE = 498_861_808

DATA = pathlib.Path(__file__).resolve().parents[1] / "data"
OUT = DATA / "euetsinfo_nace_2026_raw"
ARCHIVE = OUT / "eutl_data_package_2026-07-21.zip"
EXTRACTED = OUT / "extracted"
README = OUT / "README.md"
WANTED = {"installations.csv", "nace_mappings.csv", "datapackage.json"}


def digest(path: pathlib.Path, algorithm: str) -> str:
    value = hashlib.new(algorithm)
    with path.open("rb") as source:
        for block in iter(lambda: source.read(4 * 1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def validate_archive(path: pathlib.Path) -> list[str]:
    if not path.exists() or path.stat().st_size != EXPECTED_SIZE:
        raise ValueError(
            f"archive size is {path.stat().st_size if path.exists() else 0}, "
            f"expected {EXPECTED_SIZE}"
        )
    if digest(path, "md5") != EXPECTED_MD5:
        raise ValueError("archive MD5 does not match the Zenodo record")
    with zipfile.ZipFile(path) as archive:
        bad_member = archive.testzip()
        if bad_member:
            raise ValueError(f"ZIP CRC validation failed for {bad_member}")
        names = archive.namelist()
    basenames = {pathlib.PurePosixPath(name).name for name in names}
    missing = WANTED - basenames
    if missing:
        raise ValueError(f"archive is missing expected tables: {sorted(missing)}")
    return names


def download() -> None:
    if ARCHIVE.exists():
        try:
            validate_archive(ARCHIVE)
            print(f"skip (already downloaded and valid): {ARCHIVE}")
            return
        except (ValueError, zipfile.BadZipFile):
            print(f"existing archive is invalid; replacing: {ARCHIVE}")
            ARCHIVE.unlink(missing_ok=True)
    session = requests.Session()
    session.headers["User-Agent"] = "GREU-EU-data-pilot/1.0"
    part = ARCHIVE.with_suffix(".zip.part")
    for attempt in range(1, 4):
        try:
            print(f"GET {ARCHIVE_URL} (attempt {attempt})")
            with session.get(ARCHIVE_URL, stream=True, timeout=900) as response:
                if response.status_code != 200:
                    raise ValueError(f"HTTP {response.status_code}")
                with part.open("wb") as target:
                    for block in response.iter_content(4 * 1024 * 1024):
                        if block:
                            target.write(block)
            part.replace(ARCHIVE)
            validate_archive(ARCHIVE)
            print(f"  -> {ARCHIVE} ({ARCHIVE.stat().st_size:,} bytes)")
            return
        except (requests.RequestException, ValueError, zipfile.BadZipFile) as exc:
            part.unlink(missing_ok=True)
            ARCHIVE.unlink(missing_ok=True)
            if attempt < 3:
                print(f"  invalid response: {exc}; retrying")
                time.sleep(30 * attempt)
                continue
            raise RuntimeError("failed to download valid EUETS.INFO package") from exc


def extract() -> list[pathlib.Path]:
    EXTRACTED.mkdir(parents=True, exist_ok=True)
    written = []
    with zipfile.ZipFile(ARCHIVE) as archive:
        members = {
            pathlib.PurePosixPath(name).name: name
            for name in archive.namelist()
            if pathlib.PurePosixPath(name).name in WANTED
        }
        for basename in sorted(WANTED):
            target = EXTRACTED / basename
            delivered = archive.read(members[basename])
            if target.exists() and target.read_bytes() == delivered:
                print(f"skip (already extracted and identical): {target}")
            else:
                target.write_bytes(delivered)
                print(f"  extracted -> {target}")
            written.append(target)
    return written


def write_readme(extracted: list[pathlib.Path], members: list[str]) -> None:
    lines = [
        "# EUETS.INFO installation-to-NACE data — public feasibility input",
        "",
        f"- Retrieved: {RETRIEVAL_DATE}",
        "- Publisher/author: Jan Abrell, University of Basel",
        "- Release: version 2, published 2026-07-17; archive dated 2026-07-21",
        f"- Concept DOI: {CONCEPT_DOI}",
        f"- Version DOI: {VERSION_DOI}",
        f"- Zenodo record: {CATALOGUE_URL}",
        f"- Record API: {API_URL}",
        f"- Direct archive: {ARCHIVE_URL}",
        "- Query/filter parameters: none; complete static package downloaded",
        "- Access: anonymous, public, no login or API key",
        "- Licence: CC BY 4.0 for the author's compilation and transformations;",
        "  underlying records retain their providers' terms",
        "- Status: secondary/non-official concordance. NACE codes are derived from",
        "  European Commission 2015/2020 carbon-leakage lists. They are not a",
        "  current Union Registry field and must not be treated as authoritative",
        "  company classifications.",
        "",
        "## Preserved delivery",
        "",
        f"- `{ARCHIVE.name}`: {ARCHIVE.stat().st_size:,} bytes",
        f"- MD5: `{digest(ARCHIVE, 'md5')}` (matches Zenodo)",
        f"- SHA-256: `{digest(ARCHIVE, 'sha256')}`",
        f"- ZIP members: {len(members)}; CRC validation passed",
        "",
        "The ZIP is preserved byte-for-byte as delivered. The following members",
        "are copied without modification to `extracted/` for the bridge test:",
        "",
    ]
    lines.extend(
        f"- `{path.name}` — {path.stat().st_size:,} bytes — "
        f"SHA-256 `{digest(path, 'sha256')}`"
        for path in extracted
    )
    lines.extend(
        [
            "",
            "Reproduce with:",
            "",
            "```powershell",
            "python data/preprocessing/scripts/download_euetsinfo_nace_2026.py",
            "```",
            "",
        ]
    )
    README.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    download()
    members = validate_archive(ARCHIVE)
    extracted = extract()
    write_readme(extracted, members)
    print(f"provenance -> {README}")


if __name__ == "__main__":
    main()
