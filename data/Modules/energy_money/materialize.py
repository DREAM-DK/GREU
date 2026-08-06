"""Deterministic materialization of a public core with country-detail rows."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date
import hashlib
import json
from pathlib import Path
import shutil
from typing import Any

import pandas as pd

from .config import (
    ENERGY_IO_WORKBOOK_NAME,
    ENERGY_WORKBOOK_NAME,
    MARGINAL_GDX_NAME,
)
from .schema import (
    ENERGY_CONTRACT,
    ENERGY_IO_CONTRACT,
    METADATA_SHEET,
    WorkbookContract,
    read_and_validate_workbook,
    validate_frame,
)


@dataclass(frozen=True)
class MaterializedEnergyMoneyLayer:
    """Paths produced by one overlay materialization."""

    directory: Path
    energy_workbook: Path
    energy_io_workbook: Path
    marginal_rate_gdx: Path
    manifest: Path


def _file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _key_token(values: tuple[Any, ...]) -> tuple[str, ...]:
    return tuple(
        "<NULL>" if pd.isna(value) else f"{type(value).__name__}:{value}"
        for value in values
    )


def overlay_rows(
    base: pd.DataFrame,
    detail: pd.DataFrame,
    contract: WorkbookContract,
) -> pd.DataFrame:
    """Replace complete base rows by key, then add new detail keys.

    The detail layer wins for every matching key. Rows present only in the
    detail layer are appended. The final table is sorted by a type-stable string
    representation of the full key, making output independent of input order.
    """

    validate_frame(base, contract, source="base frame")
    validate_frame(detail, contract, source="detail frame")

    detail_keys = {
        _key_token(values)
        for values in detail.loc[:, list(contract.key)].itertuples(
            index=False, name=None
        )
    }
    keep_base = [
        _key_token(values) not in detail_keys
        for values in base.loc[:, list(contract.key)].itertuples(
            index=False, name=None
        )
    ]
    combined = pd.concat(
        [base.loc[keep_base], detail],
        ignore_index=True,
    ).loc[:, list(contract.required_columns)]
    combined["_sort_key"] = [
        "\x1f".join(_key_token(values))
        for values in combined.loc[:, list(contract.key)].itertuples(
            index=False, name=None
        )
    ]
    combined = (
        combined.sort_values("_sort_key", kind="stable")
        .drop(columns="_sort_key")
        .reset_index(drop=True)
    )
    validate_frame(combined, contract, source="materialized frame")
    return combined


def _write_workbook(
    frame: pd.DataFrame,
    path: Path,
    *,
    data_sheet: str,
    metadata: dict[str, str],
) -> None:
    metadata_frame = pd.DataFrame(
        [{"field": key, "value": value} for key, value in metadata.items()]
    )
    with pd.ExcelWriter(path, engine="openpyxl") as writer:
        frame.to_excel(writer, sheet_name=data_sheet, index=False)
        metadata_frame.to_excel(writer, sheet_name=METADATA_SHEET, index=False)


def materialize_overlay(
    *,
    base_energy_workbook: Path,
    base_energy_io_workbook: Path,
    detail_energy_workbook: Path,
    detail_energy_io_workbook: Path,
    selected_marginal_rate_gdx: Path,
    output_directory: Path,
    country_code: str,
    provenance: str,
) -> MaterializedEnergyMoneyLayer:
    """Build a complete runtime layer without modifying any source artifact.

    Workbook rows use deterministic key replacement. GDX internals are never
    merged: ``selected_marginal_rate_gdx`` must already be one complete,
    compatible layer and is copied byte-for-byte.
    """

    source_paths = tuple(
        Path(path).resolve()
        for path in (
            base_energy_workbook,
            base_energy_io_workbook,
            detail_energy_workbook,
            detail_energy_io_workbook,
            selected_marginal_rate_gdx,
        )
    )
    output_directory = Path(output_directory).resolve()
    if any(output_directory == path.parent for path in source_paths):
        raise ValueError(
            "Materialized artifacts require a separate output directory; "
            "an input directory was selected."
        )

    energy_output = output_directory / ENERGY_WORKBOOK_NAME
    io_output = output_directory / ENERGY_IO_WORKBOOK_NAME
    gdx_output = output_directory / MARGINAL_GDX_NAME
    manifest_output = output_directory / "energy_money_manifest.json"
    outputs = (energy_output, io_output, gdx_output, manifest_output)
    existing = [path for path in outputs if path.exists()]
    if existing:
        raise FileExistsError(
            "Refusing to overwrite materialized artifacts: "
            + ", ".join(str(path) for path in existing)
        )

    selected_gdx = source_paths[4]
    if not selected_gdx.is_file() or selected_gdx.stat().st_size == 0:
        raise ValueError(
            f"Selected marginal-rate GDX must be a complete non-empty file: "
            f"{selected_gdx}."
        )

    base_energy = read_and_validate_workbook(source_paths[0], ENERGY_CONTRACT)
    base_io = read_and_validate_workbook(source_paths[1], ENERGY_IO_CONTRACT)
    detail_energy = read_and_validate_workbook(source_paths[2], ENERGY_CONTRACT)
    detail_io = read_and_validate_workbook(source_paths[3], ENERGY_IO_CONTRACT)
    materialized_energy = overlay_rows(base_energy, detail_energy, ENERGY_CONTRACT)
    materialized_io = overlay_rows(base_io, detail_io, ENERGY_IO_CONTRACT)

    output_directory.mkdir(parents=True, exist_ok=True)
    created = date.today().isoformat()
    common_metadata = {
        "country_code": country_code.upper(),
        "created": created,
        "provenance": provenance,
        "overlay_semantics": (
            "complete detail rows replace matching public-core keys; "
            "detail-only keys are added; output is key-sorted"
        ),
        "marginal_rate_boundary": (
            "selected complete GDX copied byte-for-byte; GDX symbols are not merged"
        ),
    }
    _write_workbook(
        materialized_energy,
        energy_output,
        data_sheet=ENERGY_CONTRACT.sheet,
        metadata={
            **common_metadata,
            "base_source": str(source_paths[0]),
            "detail_source": str(source_paths[2]),
        },
    )
    _write_workbook(
        materialized_io,
        io_output,
        data_sheet=ENERGY_IO_CONTRACT.sheet,
        metadata={
            **common_metadata,
            "base_source": str(source_paths[1]),
            "detail_source": str(source_paths[3]),
        },
    )
    shutil.copy2(selected_gdx, gdx_output)

    manifest = {
        **common_metadata,
        "artifacts": {
            ENERGY_WORKBOOK_NAME: {
                "rows": len(materialized_energy),
                "sha256": _file_sha256(energy_output),
            },
            ENERGY_IO_WORKBOOK_NAME: {
                "rows": len(materialized_io),
                "sha256": _file_sha256(io_output),
            },
            MARGINAL_GDX_NAME: {
                "sha256": _file_sha256(gdx_output),
                "selected_source": str(selected_gdx),
                "selected_source_sha256": _file_sha256(selected_gdx),
            },
        },
        "inputs": {
            str(path): _file_sha256(path)
            for path in source_paths
        },
    }
    manifest_output.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    return MaterializedEnergyMoneyLayer(
        directory=output_directory,
        energy_workbook=energy_output,
        energy_io_workbook=io_output,
        marginal_rate_gdx=gdx_output,
        manifest=manifest_output,
    )
