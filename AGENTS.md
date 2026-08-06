# Agent instructions — GREU data work

Instructions for AI agents (Claude Code, Codex, or others) doing data work in this
repository: reading and comparing Excel files, running calculations, fetching data
from the web, and producing new Excel files.

## Project goal

Build an EU-generic version of the model that does **not** rely on Statistics
Denmark data, so any EU member state can use and adapt it. Only use data readily
available for all EU countries, even if less detailed than the Danish data — but
stay as close to the Danish model's structure and detail as possible. The Danish
input files under `data/preprocessing/data/` define the target structure that
EU-sourced data must be mapped onto.

Primary data sources for the EU version:
- **Eurostat**: https://ec.europa.eu/eurostat/data/database (bulk/API access via
  the Eurostat dissemination API is preferred over scraping).
- **JRC FIGARO** input-output tables:
  https://joint-research-centre.ec.europa.eu/projects-and-activities/trade-and-industrial-policy-analysis/input-output-accounts/figaro-tables_en

## Environment

- Windows 11, PowerShell as primary shell.
- Python 3.14 with **pandas 3.0** and **openpyxl 3.1** installed. Use Python scripts
  for all Excel and data processing — do not try to parse `.xlsx` files as text.
- Note pandas 3.x behavior: copy-on-write is always on, and string columns use the
  `str` dtype rather than `object`.

## Where things live

- `data/preprocessing/data/` — the main collection of Excel input files
  (IO tables, energy and emissions, government finances, fixed assets, etc.).
- `data/Energy_technology_data/Excel_data/` — energy technology data.
- `data/preprocessing/` — preprocessing scripts that consume these files.
- `data/preprocessing/data/energy_data_notes.md` — **read this before touching
  the energy data**: column semantics and verified reconciliation principles
  linking `energy_and_emissions.xlsx` to `io_energy_matrix_format.xlsx`.
- `docs/eu_data_mapping.md` — the Danish-input → Eurostat/FIGARO mapping table
  steering the EU data work: verified dataset codes, coverage verdicts, and the
  three structural gaps.
- Put one-off helper scripts for a data task in `data/preprocessing/scripts/`
  (create it if needed) so they can be re-run and reviewed later.

## Working with Excel files

- Before reading a workbook, list its sheet names and inspect the first rows of
  each sheet (`pd.ExcelFile(path).sheet_names`) — never assume layout, header row,
  or sheet names. Many files here have multi-row headers or matrix layouts.
- **Never overwrite an existing input file.** Write results to a new file and say
  where you put it. If a file must be replaced, do it as an explicit, reviewable
  step the user has confirmed.
- When comparing two files/sheets, produce a concrete diff artifact (a small Excel
  or CSV of differing cells with old/new values), not just a prose summary.
- When creating new Excel files: one clear header row, no merged cells unless
  asked, ISO dates, and a `README` or `metadata` sheet noting the source and
  creation date if the file will live in the repo.

## Fetching data from the web

- Record provenance for everything downloaded: source URL, retrieval date, and any
  query/filter parameters. Put this in the output file's metadata sheet or an
  adjacent `.md` note.
- Save the raw downloaded data (CSV/JSON/XLSX as delivered) before transforming
 it, so the transformation is reproducible.
- Raw download directories (`data/preprocessing/data/*_raw/`) are **not committed
 to Git** — they are large and reproducible from the download scripts. Only the
 provenance files inside them are versioned: `README.md`, `manifest.json` and the
 small coverage/nearest-year probe results. Never force-add a raw payload; if a
 new raw file genuinely must be versioned, raise it as an explicit decision.
 Every raw directory's `README.md` must state which `scripts/download_*.py`
 re-creates it, and record hashes so a re-download can be verified.
- Derived artifacts are committed: reconciliation/feasibility workbooks and the
 runtime packages under `data/preprocessing/data/eu_core/<CC>/` (including their
 small `EU_GR_data.gdx`, which is exempted from the repo-wide `*.gdx` ignore).
- Prefer official statistical sources (Statistics Denmark / DST API, Eurostat,
  IEA, etc.) over secondary sites. For DST, the Statbank API
  (`https://api.statbank.dk/v1/`) returns JSON/CSV without scraping.
- Scrape politely: only public data, respect robots.txt, no bulk crawling.

## General workflow

- Do calculations in scripts, not by hand — every number reported should be
  reproducible by re-running a script.
- Sanity-check results: row/column totals, units, year coverage, and magnitude
  against the source before declaring done.
- Keep project documentation synchronized with the work. Update the relevant
  `.md` files whenever findings, assumptions, source coverage, open questions, or
  next steps change. If the EU data roadmap changes, update both
  `docs/EU_data_roadmap.html` and `docs/EU_data_roadmap.pdf` in the same task;
  never leave the PDF behind the Markdown/HTML status.
- If any verdict, pilot result, or source in `docs/eu_data_mapping.md` changes,
  also update the row content in
  `data/preprocessing/scripts/build_eu_data_overview_xlsx.py` and re-run it to
  regenerate `docs/EU_data_overview.xlsx` (the management-facing traffic-light
  overview) in the same task; never leave the overview behind the mapping doc.
- Treat the PDF roadmap as a standalone, pedagogical project overview for readers
  who do not work on GREU. Keep it current with the project's goals, scope,
  progress, verified findings, unresolved gaps, decisions needed, and next steps.
  Explain specialist terms and why findings matter, use clear visual hierarchy
  and plain language, and include enough context that a new reader can understand
  the status without first reading the repository's technical notes.
- Report clearly at the end: what was produced, where files were written, data
  sources used, and anything that looked suspicious in the data.
