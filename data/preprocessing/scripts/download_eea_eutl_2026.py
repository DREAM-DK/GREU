"""Download the current official EEA EU ETS / Union Registry bulk release.

The EEA Datahub catalogue points to an anonymous Nextcloud folder through a
stable record alias.  This script resolves the current share URL from that
alias, downloads the complete folder as one ZIP, validates the delivery, and
extracts byte-identical source files for the reconciliation.

Run
---
python data/preprocessing/scripts/download_eea_eutl_2026.py
"""

from __future__ import annotations

import hashlib
import gzip
import pathlib
import re
import time
import zipfile

import requests

RETRIEVAL_DATE = "2026-07-30"
EDITION = "July 2026"
PUBLISHED_DATE = "2026-07-08"
TEMPORAL_COVERAGE = "2005-2025"
RECORD_ID = "a94a5d68-9973-4e2c-9a7a-fd7690ec3473"
CATALOGUE_ID = "98f04097-26de-4fca-86c4-63834818c0c0"
CATALOGUE_URL = (
    "https://www.eea.europa.eu/en/datahub/datahubitem-view/"
    f"{CATALOGUE_ID}/file"
)
RECORD_ALIAS_URL = f"https://sdi.eea.europa.eu/data/{RECORD_ID}"
ACTIVITY_MAPPING_URL = (
    "https://sdi.eea.europa.eu/catalogue/api/records/"
    f"{RECORD_ID}/attachments/Translation%20of%20activity%20codes%20May%202019.xlsx"
)
LEGAL_URL = "https://www.eea.europa.eu/en/legal-notice"
DATA_POLICY_URL = "https://www.eea.europa.eu/en/datahub/eea-data-policy"
UNION_REGISTRY_URL = "https://union-registry-data.ec.europa.eu/"
COMMISSION_LEGAL_URL = "https://commission.europa.eu/legal-notice_en"
OPERATORS_URL = (
    "https://dlsclimabi.blob.core.windows.net/public-data/eutlpublic/"
    "extracts/_all_extracts/operator/operators_daily.csv.gz"
)
YEARLY_ACTIVITY_URL = (
    "https://dlsclimabi.blob.core.windows.net/public-data/eutlpublic/"
    "extracts/_all_extracts/operators_yearly_activity/"
    "operators_yearly_activity_daily.csv.gz"
)

DATA = pathlib.Path(__file__).resolve().parents[1] / "data"
OUT = DATA / "eea_eutl_2026_raw"
ARCHIVE = OUT / "eea_eutl_union_registry_july_2026.zip"
EXTRACTED = OUT / "extracted"
ACTIVITY_MAPPING = EXTRACTED / "Translation of activity codes May 2019.xlsx"
OPERATORS = OUT / "operators_daily.csv.gz"
YEARLY_ACTIVITY = OUT / "operators_yearly_activity_daily.csv.gz"
README = OUT / "README.md"

USER_AGENT = "GREU-EU-data-pilot/1.0 (+public statistical data replication)"


def sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def request_with_retry(
    session: requests.Session, url: str, *, timeout: int = 600
) -> requests.Response:
    last_error: Exception | None = None
    for attempt in range(1, 4):
        try:
            print(f"GET {url} (attempt {attempt})")
            response = session.get(url, timeout=timeout)
            if response.status_code != 200:
                raise ValueError(f"HTTP {response.status_code}")
            return response
        except (requests.RequestException, ValueError) as exc:
            last_error = exc
            if attempt < 3:
                print(f"  transient failure: {exc}; retrying")
                time.sleep(20 * attempt)
    raise RuntimeError(f"failed to retrieve {url}") from last_error


def resolve_share_url(session: requests.Session) -> str:
    """Resolve the official record alias to its anonymous folder ZIP."""
    response = request_with_retry(session, RECORD_ALIAS_URL, timeout=180)
    html = response.text
    match = re.search(
        r'href="(https://sdi\.eea\.europa\.eu/datashare/s/[^"]+/download)"',
        html,
    )
    if not match:
        token = re.search(r'name="sharingToken"\s+value="([^"]+)"', html)
        if not token:
            raise ValueError("EEA record alias did not expose a public share token")
        return (
            "https://sdi.eea.europa.eu/datashare/s/"
            f"{token.group(1)}/download"
        )
    return match.group(1)


def validate_archive(path: pathlib.Path) -> list[str]:
    if not path.exists() or path.stat().st_size < 1_000_000:
        raise ValueError("archive is absent or implausibly small")
    if path.read_bytes()[:4] != b"PK\x03\x04":
        raise ValueError("download does not have a ZIP signature")
    with zipfile.ZipFile(path) as archive:
        bad_member = archive.testzip()
        if bad_member:
            raise ValueError(f"ZIP CRC validation failed for {bad_member}")
        names = [name for name in archive.namelist() if not name.endswith("/")]
    basenames = {pathlib.PurePosixPath(name).name for name in names}
    expected = {
        "ETS_Database_July_2026.xlsx",
        "Translation of activity codes May 2019.xlsx",
        "README.md",
    }
    if not expected.issubset(basenames) or not any(
        name.endswith(".xml") for name in basenames
    ):
        raise ValueError(
            f"delivery is missing expected files: {sorted(expected - basenames)}"
        )
    return names


def validate_xlsx(path: pathlib.Path) -> None:
    if not path.exists() or path.stat().st_size < 10_000:
        raise ValueError("activity mapping is absent or implausibly small")
    if path.read_bytes()[:4] != b"PK\x03\x04":
        raise ValueError("activity mapping does not have an XLSX/ZIP signature")
    with zipfile.ZipFile(path) as archive:
        if archive.testzip() is not None or "[Content_Types].xml" not in archive.namelist():
            raise ValueError("activity mapping XLSX integrity validation failed")


def validate_gzip_csv(path: pathlib.Path, expected_columns: set[str]) -> None:
    if not path.exists() or path.stat().st_size < 100_000:
        raise ValueError(f"{path.name} is absent or implausibly small")
    with path.open("rb") as source:
        if source.read(2) != b"\x1f\x8b":
            raise ValueError(f"{path.name} does not have a GZIP signature")
    with gzip.open(path, "rt", encoding="utf-8-sig", newline="") as source:
        header = source.readline().strip()
        sample = source.readline()
    columns = {item.strip().strip('"') for item in header.split(",")}
    missing = expected_columns - columns
    if missing or not sample:
        raise ValueError(
            f"{path.name} CSV validation failed; missing columns {sorted(missing)}"
        )


def download_archive(session: requests.Session, share_url: str) -> None:
    if ARCHIVE.exists():
        try:
            validate_archive(ARCHIVE)
            print(f"skip (already downloaded and valid): {ARCHIVE}")
            return
        except (ValueError, zipfile.BadZipFile):
            print(f"existing archive is invalid; replacing: {ARCHIVE}")
            ARCHIVE.unlink(missing_ok=True)
    response = request_with_retry(session, share_url)
    if response.content[:4] != b"PK\x03\x04":
        preview = response.content[:120]
        raise ValueError(
            f"EEA folder response is not a ZIP "
            f"({response.headers.get('content-type')}; starts {preview!r})"
        )
    ARCHIVE.write_bytes(response.content)
    validate_archive(ARCHIVE)
    print(f"  -> {ARCHIVE} ({ARCHIVE.stat().st_size:,} bytes)")


def download_gzip_csv(
    session: requests.Session,
    url: str,
    path: pathlib.Path,
    expected_columns: set[str],
) -> dict[str, str]:
    if path.exists():
        try:
            validate_gzip_csv(path, expected_columns)
            print(f"skip (already downloaded and valid): {path}")
            head = session.head(url, timeout=120)
            return {
                "last_modified": head.headers.get("last-modified", ""),
                "etag": head.headers.get("etag", ""),
            }
        except (ValueError, OSError):
            print(f"existing file is invalid; replacing: {path}")
            path.unlink(missing_ok=True)
    response = request_with_retry(session, url)
    path.write_bytes(response.content)
    validate_gzip_csv(path, expected_columns)
    print(f"  -> {path} ({path.stat().st_size:,} bytes)")
    return {
        "last_modified": response.headers.get("last-modified", ""),
        "etag": response.headers.get("etag", ""),
    }


def extract_archive() -> list[pathlib.Path]:
    EXTRACTED.mkdir(parents=True, exist_ok=True)
    written: list[pathlib.Path] = []
    with zipfile.ZipFile(ARCHIVE) as archive:
        for member in validate_archive(ARCHIVE):
            basename = pathlib.PurePosixPath(member).name
            if not basename:
                continue
            target = EXTRACTED / basename
            delivered = archive.read(member)
            if target.exists() and target.read_bytes() == delivered:
                print(f"skip (already extracted and identical): {target}")
            else:
                target.write_bytes(delivered)
                print(f"  extracted -> {target}")
            written.append(target)
    return written


def write_readme(
    share_url: str,
    members: list[str],
    extracted: list[pathlib.Path],
    source_headers: dict[str, dict[str, str]],
) -> None:
    lines = [
        "# EEA EU ETS / Union Registry raw data — July 2026",
        "",
        f"- Retrieved: {RETRIEVAL_DATE}",
        f"- Publisher: European Environment Agency (EEA)",
        f"- Source system: European Commission Union Registry (formerly EUTL)",
        f"- Edition: {EDITION}; published {PUBLISHED_DATE}",
        f"- Temporal coverage stated by EEA: {TEMPORAL_COVERAGE}",
        "- Geographic coverage: EU ETS participating countries; the pilot validates",
        "  all EU-27 country codes and filters Denmark (`DK`) for calendar year 2020",
        "- Query/filter parameters: none for the bulk download; Denmark/year filters",
        "  are applied locally and recorded in the reconciliation workbook",
        f"- Catalogue: {CATALOGUE_URL}",
        f"- Stable record alias: {RECORD_ALIAS_URL}",
        f"- Resolved anonymous bulk URL on retrieval date: {share_url}",
        f"- Official activity-code mapping: {ACTIVITY_MAPPING_URL}",
        f"- Union Registry public website: {UNION_REGISTRY_URL}",
        f"- Installation/operator master: {OPERATORS_URL}",
        f"- Installation-year compliance data: {YEARLY_ACTIVITY_URL}",
        "- Access: anonymous public HTTPS; no login, cookie, API key, or manual",
        "  scraping required. The EEA record alias resolves to a read-only bulk ZIP;",
        "  the Commission site exposes stable daily GZIP-CSV bulk endpoints.",
        "- Licence/re-use: the EEA release metadata states CC BY 4.0, copyright",
        "  European Commission and EEA, with no limitations on public access.",
        "  Commission materials are subject to the Commission legal notice/re-use",
        "  policy. Attribute the European Commission Union Registry and EEA.",
        f"- Legal notice: {LEGAL_URL}",
        f"- EEA data policy: {DATA_POLICY_URL}",
        f"- Commission legal notice: {COMMISSION_LEGAL_URL}",
        "",
        "## Preserved delivery",
        "",
        f"- `{ARCHIVE.name}`: {ARCHIVE.stat().st_size:,} bytes",
        f"- SHA-256: `{sha256(ARCHIVE)}`",
        f"- ZIP members: {len(members)}; CRC validation passed",
        f"- Delivered activity map `{ACTIVITY_MAPPING.name}`:",
        f"  {ACTIVITY_MAPPING.stat().st_size:,} bytes; SHA-256 `{sha256(ACTIVITY_MAPPING)}`",
        f"- `{OPERATORS.name}`: {OPERATORS.stat().st_size:,} bytes;",
        f"  SHA-256 `{sha256(OPERATORS)}`; HTTP Last-Modified",
        f"  `{source_headers['operators'].get('last_modified', '')}`;",
        f"  ETag `{source_headers['operators'].get('etag', '')}`",
        f"- `{YEARLY_ACTIVITY.name}`: {YEARLY_ACTIVITY.stat().st_size:,} bytes;",
        f"  SHA-256 `{sha256(YEARLY_ACTIVITY)}`; HTTP Last-Modified",
        f"  `{source_headers['yearly_activity'].get('last_modified', '')}`;",
        f"  ETag `{source_headers['yearly_activity'].get('etag', '')}`",
        "",
        "The EEA ZIP and Commission GZIP-CSV files are preserved byte-for-byte as",
        "delivered. Archive members are copied without transformation to",
        "`extracted/` for inspection and reconciliation:",
        "",
    ]
    lines.extend(
        f"- `{path.name}` — {path.stat().st_size:,} bytes — SHA-256 `{sha256(path)}`"
        for path in extracted
    )
    lines.extend(
        [
            "",
            "Reproduce with:",
            "",
            "```powershell",
            "python data/preprocessing/scripts/download_eea_eutl_2026.py",
            "```",
            "",
        ]
    )
    README.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    session = requests.Session()
    session.headers["User-Agent"] = USER_AGENT
    share_url = resolve_share_url(session)
    print(f"resolved anonymous share: {share_url}")
    download_archive(session, share_url)
    source_headers = {
        "operators": download_gzip_csv(
            session,
            OPERATORS_URL,
            OPERATORS,
            {"INSTALLATION_IDENTIFIER", "REGISTRY_CODE", "ACTIVITY_TYPE_CODE"},
        ),
        "yearly_activity": download_gzip_csv(
            session,
            YEARLY_ACTIVITY_URL,
            YEARLY_ACTIVITY,
            {"INSTALLATION_IDENTIFIER", "PERIOD_YEAR", "VERIFIED_EMISSIONS", "ALLOCATION"},
        ),
    }
    members = validate_archive(ARCHIVE)
    extracted = extract_archive()
    validate_xlsx(ACTIVITY_MAPPING)
    write_readme(share_url, members, extracted, source_headers)
    print(f"provenance -> {README}")


if __name__ == "__main__":
    main()
