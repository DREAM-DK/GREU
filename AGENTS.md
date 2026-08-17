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
- Put one-off helper scripts for a data task in `data/preprocessing/scripts/`
  (create it if needed) so they can be re-run and reviewed later.

## Documentation map — which file answers which question

**Start at `docs/eu_data_mapping.md`.** It is the live working document: current
status, one verdict row per Danish input, the four structural gaps, open items,
and the "Handoff" section at the end, which is the project's working memory.
Read the Handoff first when picking up work, and record new findings and task
handoffs there so the next session can resume cold.

| Question | File |
|---|---|
| What is the status? What should I do next? | `docs/eu_data_mapping.md` (Handoff) |
| Which EU source replaces input X, and how good is it? | `docs/eu_data_mapping.md` (Mapping table) |
| What exactly did pilot Y find? Which numbers? | `docs/eu_data_pilots.md` |
| What do the Danish energy columns mean? | `data/preprocessing/data/energy_data_notes.md` |
| How do I run a non-Danish country? | `data/Modules/energy_money/README.md` |
| Where did a raw download come from? | the `README.md` inside that `*_raw/` directory |
| Management traffic-light view | `docs/EU_data_overview.xlsx` (generated) |
| Explaining the project to an outsider | `docs/EU_data_roadmap.pdf` (generated) |

Read `energy_data_notes.md` before touching the energy data: it holds the
column semantics and verified reconciliation principles linking
`energy_and_emissions.xlsx` to `io_energy_matrix_format.xlsx`, and nothing else
in the repo records them.

## Documentation discipline

These rules exist because the same Sweden figures were once maintained in three
files and drifted, and because reading a long document end to end is the single
largest avoidable token cost in this repo.

- **Search, don't slurp.** `eu_data_mapping.md` and `eu_data_pilots.md` are
  reference documents, not narratives. Grep for the input name, dataset code or
  number you need. Only read a whole file when you are about to restructure it.
- **One source of truth per number.** Pilot results and Sweden package figures
  live in `docs/eu_data_pilots.md` only. Everywhere else links to it. If you
  catch yourself pasting a reconciliation figure into a second file, link
  instead.
- **Live versus archive.** `eu_data_mapping.md` holds only what is currently
  true and currently actionable. When a task finishes, move its narrative into
  `docs/eu_data_pilots.md` and leave a one-line result plus link behind. Do not
  let the live document accumulate a changelog.
- **Keep the working document small.** It is currently ~10k tokens and should
  stay near that. If it grows past roughly 15k, archive the completed material
  again rather than letting every agent pay to read it.

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
  never leave the PDF behind the Markdown/HTML status. Regenerate the PDF from
  the HTML with headless Chrome (no Python HTML-to-PDF library is installed):

  ```powershell
  & "C:\Program Files\Google\Chrome\Application\chrome.exe" --headless --disable-gpu `
    --no-pdf-header-footer --print-to-pdf="C:\GREU\docs\EU_data_roadmap.pdf" `
    "file:///C:/GREU/docs/EU_data_roadmap.html"
  ```

  Chrome prints GCM/registration errors to stderr that are harmless; confirm
  success by checking the page count and extracting text with `pypdf`.
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

## Git commits

- Never add a "Co-authored-by: Cursor", "Made-with: Cursor", or similar agent
  attribution trailer to commit messages or PR descriptions. Commits are
  authored solely by the human contributor whose `git config user.name` /
  `user.email` is set locally.
