"""Workbook contracts for the GREU monetary-energy boundary."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import pandas as pd


ENERGY_SHEET = "ems_energy"
ENERGY_IO_SHEET = "io"
METADATA_SHEET = "metadata"

ENERGY_KEY = ("year", "bal", "flow", "indu", "purp", "product")
ENERGY_VALUE_COLUMNS = (
    "ch4",
    "co2_bio",
    "co2_xbio",
    "n2o",
    "co2_eq",
    "pj",
    "basic",
    "ws_marg",
    "ret_marg",
    "mvs_marg",
    "ener_tax",
    "co2_tax",
    "so2_tax",
    "nox_tax",
    "pso_tax",
    "vat",
    "purch",
)
ENERGY_REQUIRED_COLUMNS = ENERGY_KEY + ENERGY_VALUE_COLUMNS
ENERGY_REQUIRED_NON_NULL = ("year", "bal", "flow", "product")

ENERGY_IO_KEY = ("year", "row_l1", "row_l2", "col_l1", "col_l2")
ENERGY_IO_REQUIRED_COLUMNS = ENERGY_IO_KEY + ("value",)
ENERGY_IO_REQUIRED_NON_NULL = ("year", "row_l1", "col_l1")


@dataclass(frozen=True)
class WorkbookContract:
    """A single-header Excel table consumed by read_data.py."""

    sheet: str
    key: tuple[str, ...]
    required_columns: tuple[str, ...]
    required_non_null: tuple[str, ...]


ENERGY_CONTRACT = WorkbookContract(
    ENERGY_SHEET,
    ENERGY_KEY,
    ENERGY_REQUIRED_COLUMNS,
    ENERGY_REQUIRED_NON_NULL,
)
ENERGY_IO_CONTRACT = WorkbookContract(
    ENERGY_IO_SHEET,
    ENERGY_IO_KEY,
    ENERGY_IO_REQUIRED_COLUMNS,
    ENERGY_IO_REQUIRED_NON_NULL,
)


def _format_records(frame: pd.DataFrame, columns: Iterable[str]) -> str:
    return frame.loc[:, list(columns)].head(5).to_dict(orient="records").__repr__()


def validate_frame(
    frame: pd.DataFrame,
    contract: WorkbookContract,
    *,
    source: str,
    allow_extra_columns: bool = False,
) -> None:
    """Validate required columns, non-null dimensions, and unique row keys."""

    columns = list(frame.columns)
    if len(columns) != len(set(columns)):
        duplicates = sorted({column for column in columns if columns.count(column) > 1})
        raise ValueError(f"{source}: duplicate column names: {duplicates}.")

    missing = [column for column in contract.required_columns if column not in frame]
    if missing:
        raise ValueError(f"{source}: missing required columns: {missing}.")

    if not allow_extra_columns:
        extra = [column for column in frame if column not in contract.required_columns]
        if extra:
            raise ValueError(f"{source}: unexpected columns: {extra}.")

    empty_dimensions = frame.loc[:, list(contract.required_non_null)].isna().any()
    empty_columns = empty_dimensions[empty_dimensions].index.tolist()
    if empty_columns:
        examples = frame.loc[
            frame.loc[:, empty_columns].isna().any(axis=1), list(contract.key)
        ]
        raise ValueError(
            f"{source}: null values in required dimensions {empty_columns}; "
            f"examples: {_format_records(examples, contract.key)}."
        )

    duplicate_mask = frame.duplicated(subset=list(contract.key), keep=False)
    if duplicate_mask.any():
        duplicates = frame.loc[duplicate_mask, list(contract.key)]
        raise ValueError(
            f"{source}: duplicate rows for key {list(contract.key)}; "
            f"examples: {_format_records(duplicates, contract.key)}."
        )


def read_and_validate_workbook(
    path: Path, contract: WorkbookContract
) -> pd.DataFrame:
    """Read a contract workbook after checking its sheet layout."""

    path = Path(path)
    with pd.ExcelFile(path) as excel:
        sheet_names = excel.sheet_names
        allowed_sheets = {contract.sheet, METADATA_SHEET}
        if contract.sheet not in sheet_names:
            raise ValueError(
                f"{path}: required sheet {contract.sheet!r} is absent; "
                f"found {sheet_names}."
            )
        unexpected_sheets = [
            sheet for sheet in sheet_names if sheet not in allowed_sheets
        ]
        if unexpected_sheets:
            raise ValueError(
                f"{path}: unexpected sheets {unexpected_sheets}; allowed sheets are "
                f"{sorted(allowed_sheets)}."
            )
        if sheet_names[0] != contract.sheet:
            raise ValueError(
                f"{path}: {contract.sheet!r} must be the first sheet because "
                "read_data.py reads the default sheet."
            )

        frame = pd.read_excel(
            excel, sheet_name=contract.sheet, keep_default_na=True
        )
    validate_frame(frame, contract, source=str(path))
    return frame


def validate_energy_workbook(path: Path) -> None:
    """Validate energy_and_emissions.xlsx."""

    read_and_validate_workbook(path, ENERGY_CONTRACT)


def validate_io_workbook(path: Path) -> None:
    """Validate io_energy_long_format.xlsx."""

    read_and_validate_workbook(path, ENERGY_IO_CONTRACT)
