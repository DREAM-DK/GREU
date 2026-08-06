"""Download and extract the official JRC-IDEES-2023 Denmark archive.

The country archive is preserved byte-for-byte.  Extracted workbooks are placed
in a separate subfolder so the delivered ZIP remains the auditable raw source.

Run
---
python data/preprocessing/scripts/download_jrc_idees_dk_2023.py
"""

from __future__ import annotations

import hashlib
import pathlib
import time
import zipfile

import requests

RETRIEVAL_DATE = "2026-07-30"
EDITION = "JRC-IDEES-2023"
VERSION = "v1"
COUNTRY = "DK"
BASE_URL = "https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/JRC-IDEES/JRC-IDEES-2023_v1"
ARCHIVE_NAME = f"{EDITION}_{COUNTRY}.zip"
URL = f"{BASE_URL}/{ARCHIVE_NAME}"

DATA = pathlib.Path(__file__).resolve().parents[1] / "data"
OUT = DATA / "jrc_idees_2023_raw"
ARCHIVE = OUT / ARCHIVE_NAME
EXTRACTED = OUT / "extracted"
README = OUT / "README.md"


def sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def validate_archive(path: pathlib.Path) -> list[str]:
    """Validate ZIP integrity and expected country workbooks."""
    if not path.exists() or path.stat().st_size < 1_000_000:
        raise ValueError("archive is absent or implausibly small")
    if path.read_bytes()[:4] != b"PK\x03\x04":
        raise ValueError("download does not have a ZIP signature")
    with zipfile.ZipFile(path) as archive:
        bad_member = archive.testzip()
        if bad_member:
            raise ValueError(f"ZIP CRC validation failed for {bad_member}")
        names = archive.namelist()
    expected = {
        f"{EDITION}_Industry_{COUNTRY}.xlsx",
        f"{EDITION}_Residential_{COUNTRY}.xlsx",
        f"{EDITION}_EnergyBalance_{COUNTRY}.xlsx",
    }
    by_basename = {pathlib.PurePosixPath(name).name for name in names}
    missing = expected - by_basename
    if missing:
        raise ValueError(f"expected workbooks missing from archive: {sorted(missing)}")
    return names


def download() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    if ARCHIVE.exists():
        try:
            validate_archive(ARCHIVE)
            print(f"skip (already downloaded and valid): {ARCHIVE}")
            return
        except (ValueError, zipfile.BadZipFile):
            print(f"existing archive is invalid; replacing: {ARCHIVE}")

    session = requests.Session()
    session.headers["User-Agent"] = "GREU-EU-data-pilot/1.0"
    for attempt in range(1, 4):
        print(f"GET {URL} (attempt {attempt})")
        response = session.get(URL, timeout=600)
        try:
            if response.status_code != 200:
                raise ValueError(f"HTTP {response.status_code}")
            content_type = response.headers.get("content-type", "")
            if response.content[:4] != b"PK\x03\x04":
                raise ValueError(
                    f"response is not a ZIP ({content_type}; "
                    f"starts {response.content[:80]!r})"
                )
            ARCHIVE.write_bytes(response.content)
            validate_archive(ARCHIVE)
        except (ValueError, zipfile.BadZipFile) as exc:
            ARCHIVE.unlink(missing_ok=True)
            if attempt < 3:
                print(f"  invalid response: {exc}; retrying")
                time.sleep(20 * attempt)
                continue
            raise RuntimeError("failed to download a valid IDEES archive") from exc
        print(f"  -> {ARCHIVE} ({ARCHIVE.stat().st_size:,} bytes)")
        return


def extract() -> list[pathlib.Path]:
    EXTRACTED.mkdir(parents=True, exist_ok=True)
    wanted = {
        f"{EDITION}_Industry_{COUNTRY}.xlsx",
        f"{EDITION}_Residential_{COUNTRY}.xlsx",
        f"{EDITION}_EnergyBalance_{COUNTRY}.xlsx",
    }
    written = []
    with zipfile.ZipFile(ARCHIVE) as archive:
        members = {
            pathlib.PurePosixPath(name).name: name
            for name in archive.namelist()
            if pathlib.PurePosixPath(name).name in wanted
        }
        for basename in sorted(wanted):
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
        "# JRC-IDEES-2023 raw Denmark data",
        "",
        f"- Retrieved: {RETRIEVAL_DATE}",
        f"- Edition/version: {EDITION} {VERSION}",
        "- Publisher: European Commission, Joint Research Centre",
        f"- Country selection: `{COUNTRY}` (Denmark country archive)",
        "- Query parameters: none; static country ZIP distribution",
        f"- Direct source: {URL}",
        "- Catalogue record: https://data.jrc.ec.europa.eu/dataset/1f0b480c-6d21-4d95-897d-20c7ca33df6f",
        "- Dataset DOI: https://doi.org/10.2905/JRC.JPXYRT8",
        "- Technical report: https://publications.jrc.ec.europa.eu/repository/handle/JRC144707",
        "- Licence: Creative Commons Attribution 4.0 International (CC BY 4.0)",
        "- Access: direct and anonymous; no registration or authentication",
        "",
        "## Preserved delivery",
        "",
        f"- `{ARCHIVE.name}`: {ARCHIVE.stat().st_size:,} bytes",
        f"- SHA-256: `{sha256(ARCHIVE)}`",
        f"- ZIP members: {len(members)}; CRC validation passed",
        "",
        "The ZIP is preserved byte-for-byte as delivered. The three workbooks needed",
        "for this pilot are copied without modification to `extracted/`:",
        "",
    ]
    lines.extend(f"- `{path.name}` — SHA-256 `{sha256(path)}`" for path in extracted)
    lines.extend(
        [
            "",
            "The Industry workbook supplies industrial process/end-use data. The",
            "Residential workbook is inspected only to compare its household end-use",
            "structure with PEFA. The EnergyBalance workbook is retained to audit the",
            "IDEES energy-balance boundary.",
            "",
            "Reproduce with:",
            "",
            "```powershell",
            "python data/preprocessing/scripts/download_jrc_idees_dk_2023.py",
            "```",
            "",
        ]
    )
    README.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    download()
    members = validate_archive(ARCHIVE)
    extracted = extract()
    write_readme(extracted, members)
    print(f"provenance -> {README}")


if __name__ == "__main__":
    main()
