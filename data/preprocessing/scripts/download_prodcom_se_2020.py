"""Download Eurostat PRODCOM data for Sweden 2020 (NACE division 16 pilot).

Purpose: feasibility pilot for splitting the Sweden public-core CPA_C16
monetary residual (42.763 bn SEK, chiefly the 40.665 bn SEK export control)
into energy-relevant wood products (chips, pellets/briquettes) vs the rest of
the wood-products industry, using product-level sold-production statistics.

Endpoint finding (verified live 2026-07-31): the docs' claimed dataset code
``prc_stapro`` does NOT exist on the Eurostat dissemination API (HTTP 404:
"not available for dissemination"), and neither does the legacy Comext code
``ds-056120``. PRODCOM is served by the **Comext** dissemination API under
dataflow **DS-059358** ("Sold production, exports and imports", PRODCOM list
under CPA 2.1 — the right vintage for reference year 2020; DS-059367 is the
CPA 2.2 successor and DS-059359 is total production):

    https://ec.europa.eu/eurostat/api/comext/dissemination/sdmx/2.1/data/DS-059358/...
    https://ec.europa.eu/eurostat/api/comext/dissemination/statistics/1.0/data/ds-059358?...

Raw deliveries are preserved byte-for-byte under
``data/preprocessing/data/prodcom_raw/SE/2020/`` with a README and manifest.

Run:  python data/preprocessing/scripts/download_prodcom_se_2020.py
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import time

import requests

DATA = Path(__file__).resolve().parents[1] / "data"
OUT_DIR = DATA / "prodcom_raw" / "SE" / "2020"
RETRIEVAL_DATE = "2026-07-31"

COMEXT_SDMX = "https://ec.europa.eu/eurostat/api/comext/dissemination/sdmx/2.1"
YEAR = "2020"

# EU-27 coverage probe products: pellets/briquettes (the key energy code) and
# one ubiquitous sawnwood code, both current in the 2019+ PRODCOM list.
PROBE_PRODUCTS = "16291500+16101033"

DOWNLOADS = {
    # Full Sweden 2020 delivery, all products and all indicators. Division 16
    # is filtered locally by the reconciliation script so the raw file stays
    # exactly as delivered and other divisions remain available for checks.
    "ds-059358_SE_2020_all_products.csv": {
        "url": f"{COMEXT_SDMX}/data/DS-059358/A.SE../",
        "params": {
            "format": "SDMX-CSV",
            "startPeriod": YEAR,
            "endPeriod": YEAR,
        },
        "kind": "sdmx-csv",
        "note": (
            "Sold production, exports and imports; reporter SE, year 2020, "
            "all PRODCOM codes, all indicators (PRODVAL/EXPVAL/IMPVAL, "
            "quantities, flags, rounding bases, QNTUNIT)."
        ),
    },
    # EU-27 coverage probe: two division-16 products, all reporters.
    "ds-059358_eu_coverage_probe_2020.csv": {
        "url": f"{COMEXT_SDMX}/data/DS-059358/A.{PROBE_PRODUCTS}./".replace(
            f"A.{PROBE_PRODUCTS}", f"A..{PROBE_PRODUCTS}"
        ),
        "params": {
            "format": "SDMX-CSV",
            "startPeriod": YEAR,
            "endPeriod": YEAR,
        },
        "kind": "sdmx-csv",
        "note": (
            "Coverage probe: all reporters, year 2020, products 16291500 "
            "(wood pellets/briquettes) and 16101033 (coniferous sawnwood), "
            "all indicators. Used to check EU-27 availability."
        ),
    },
    # Product codelist (labels for every PRODCOM code in the dataflow).
    "cxt_prodcom2_sold_codelist.xml": {
        "url": f"{COMEXT_SDMX}/codelist/ESTAT/CXT_PRODCOM2_SOLD",
        "params": {},
        "kind": "sdmx-xml",
        "note": "Code labels for the DS-059358 product dimension.",
    },
    # Indicator codelist (documents PRODVAL/EXPVAL/flag semantics).
    "cxt_indicators_codelist.xml": {
        "url": f"{COMEXT_SDMX}/codelist/ESTAT/CXT_INDICATORS",
        "params": {},
        "kind": "sdmx-xml",
        "note": "Indicator labels for the DS-059358 indicators dimension.",
    },
}

README = """# Eurostat PRODCOM raw data — Sweden 2020 (NACE division 16 pilot)

Retrieved {date} from the Eurostat **Comext** dissemination API by
`data/preprocessing/scripts/download_prodcom_se_2020.py`. Files are the raw
deliveries, byte-for-byte; SHA-256 hashes, exact URLs and query parameters are
in `manifest.json`.

## Dataset identification (verified against the live API {date})

- Correct dataflow: **DS-059358** "Sold production, exports and imports"
  (PRODCOM list, CPA 2.1 vintage — correct for reference year 2020).
- The code `prc_stapro` claimed in `docs/eu_data_mapping.md` does **not**
  exist on the dissemination API (HTTP 404 "not available for dissemination"),
  nor does the legacy Comext code `ds-056120`. PRODCOM is served only through
  the Comext dissemination API
  (`https://ec.europa.eu/eurostat/api/comext/dissemination/...`), not the main
  statistics API. Related dataflows: DS-059367 (PRODCOM list CPA 2.2),
  DS-059359/DS-059368 (total production).

## Files

- `ds-059358_SE_2020_all_products.csv` — SDMX-CSV, reporter SE, year 2020,
  all PRODCOM codes and all indicators (values in euro, quantities, flags).
- `ds-059358_eu_coverage_probe_2020.csv` — SDMX-CSV, all reporters, year 2020,
  products 16291500 (wood pellets/briquettes) and 16101033 (coniferous
  sawnwood): EU-27 availability probe.
- `cxt_prodcom2_sold_codelist.xml` — product codelist (code -> label).
- `cxt_indicators_codelist.xml` — indicator codelist.

## Confidentiality flags (PVALFLAG/PQNTFLAG..., per Eurostat PRODCOM guide)

blank = available; `:` = not available; `:C` = confidential; `:E` = reliable
estimate (published); `:U` = low-reliability estimate suppressed from national
publication (included in EU totals); `:R` = rounded (see rounding base);
`-` = not applicable. Suppressed cells must never be treated as zero.

## Licence / reuse

Eurostat data are subject to the Eurostat re-use policy (CC BY 4.0 for most
Eurostat online data since 2020; see https://ec.europa.eu/eurostat/about-us/policies/copyright).
"""


def sha256(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()


def looks_like_html_error(content: bytes) -> bool:
    head = content[:2048].lower()
    return b"<html" in head or b"temporarily unavailable" in head


def validate(content: bytes, kind: str, name: str) -> None:
    if looks_like_html_error(content):
        raise ValueError(f"{name}: HTML error page returned with HTTP 200")
    if kind == "sdmx-csv":
        if not content.lstrip().startswith(b"DATAFLOW"):
            raise ValueError(f"{name}: response is not SDMX-CSV")
    elif kind == "sdmx-xml":
        if not content.lstrip().startswith(b"<?xml"):
            raise ValueError(f"{name}: response is not XML")


def request(session: requests.Session, name: str, spec: dict) -> bytes:
    last_error: Exception | None = None
    for attempt in range(1, 5):
        try:
            response = session.get(
                spec["url"], params=spec["params"], timeout=900
            )
            if response.status_code != 200:
                raise ValueError(f"HTTP {response.status_code}")
            if not response.content:
                raise ValueError("empty response")
            validate(response.content, spec["kind"], name)
            return response.content
        except (requests.RequestException, ValueError) as exc:
            last_error = exc
            if attempt < 4:
                time.sleep(15 * attempt)
    raise RuntimeError(f"{name}: failed after 4 attempts: {last_error}")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    session = requests.Session()
    session.headers["User-Agent"] = "GREU-data-pipeline/1.0"

    manifest: dict = {
        "retrieval_date": RETRIEVAL_DATE,
        "source": "Eurostat Comext dissemination API",
        "dataflow": "ESTAT:DS-059358(1.0) Sold production, exports and imports",
        "endpoint_finding": (
            "prc_stapro (doc claim) and legacy ds-056120 both return HTTP 404 "
            "on the dissemination API; PRODCOM is served as DS-059358 on "
            "https://ec.europa.eu/eurostat/api/comext/dissemination/ "
            "(verified live 2026-07-31)."
        ),
        "reference_year": 2020,
        "reporter": "SE (plus all-reporter coverage probe)",
        "licence": "Eurostat re-use policy / CC BY 4.0",
        "files": {},
    }

    for name, spec in DOWNLOADS.items():
        content = request(session, name, spec)
        path = OUT_DIR / name
        path.write_bytes(content)
        prepared = requests.PreparedRequest()
        prepared.prepare_url(spec["url"], spec["params"])
        manifest["files"][name] = {
            "url": prepared.url,
            "bytes": len(content),
            "sha256": sha256(content),
            "note": spec["note"],
        }
        print(f"saved {name}: {len(content):,} bytes")

    (OUT_DIR / "manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True), encoding="utf-8"
    )
    (OUT_DIR / "README.md").write_text(
        README.format(date=RETRIEVAL_DATE), encoding="utf-8"
    )
    print(f"done -> {OUT_DIR}")


if __name__ == "__main__":
    main()
