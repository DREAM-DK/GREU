"""Runtime configuration for the monetary-energy input boundary."""

from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum
from functools import lru_cache
import os
from pathlib import Path
import re
from typing import Mapping

from .schema import validate_energy_workbook, validate_io_workbook


COUNTRY_ENV = "GREU_COUNTRY_CODE"
MODE_ENV = "GREU_ENERGY_MONEY_MODE"
PUBLIC_CORE_ROOT_ENV = "GREU_ENERGY_MONEY_PUBLIC_CORE_ROOT"
COUNTRY_DETAIL_ROOT_ENV = "GREU_ENERGY_MONEY_COUNTRY_DETAIL_ROOT"
GENERATED_ROOT_ENV = "GREU_ENERGY_MONEY_GENERATED_ROOT"
OUTPUT_GDX_ENV = "GREU_ENERGY_MONEY_OUTPUT_GDX"

ENERGY_WORKBOOK_NAME = "energy_and_emissions.xlsx"
ENERGY_IO_WORKBOOK_NAME = "io_energy_long_format.xlsx"
MARGINAL_GDX_NAME = "EU_GR_data.gdx"
MARGINAL_GDX_COLUMNS = {
    "tEAFG_REmarg": {"t", "energy19", "purpose", "r", "level"},
    "tCO2_REmarg": {"t", "energy19", "purpose", "r", "emm_eq", "level"},
}


class EnergyMoneyConfigurationError(ValueError):
    """Raised when an energy-money layer is missing or incompatible."""


class EnergyMoneyMode(StrEnum):
    """Supported runtime layers."""

    COUNTRY_DETAIL = "country_detail"
    PUBLIC_CORE = "public_core"


@dataclass(frozen=True)
class EnergyMoneyConfig:
    """Resolved monetary-energy paths for one country and runtime mode."""

    repo_root: Path
    country_code: str
    mode: EnergyMoneyMode
    layer_directory: Path
    energy_workbook: Path
    energy_io_workbook: Path
    marginal_rate_gdx: Path
    generated_country_gdx: Path

    @classmethod
    def from_env(
        cls,
        environ: Mapping[str, str] | None = None,
        *,
        repo_root: Path | None = None,
    ) -> "EnergyMoneyConfig":
        """Resolve configuration from environment variables without I/O."""

        env = os.environ if environ is None else environ
        root = (
            Path(repo_root).resolve()
            if repo_root is not None
            else Path(__file__).resolve().parents[3]
        )
        country_code = env.get(COUNTRY_ENV, "DK").strip().upper()
        raw_mode = env.get(MODE_ENV, EnergyMoneyMode.COUNTRY_DETAIL.value).strip()
        try:
            mode = EnergyMoneyMode(raw_mode)
        except ValueError as exc:
            supported = ", ".join(item.value for item in EnergyMoneyMode)
            raise EnergyMoneyConfigurationError(
                f"Unsupported {MODE_ENV}={raw_mode!r}; expected one of: {supported}."
            ) from exc

        if not re.fullmatch(r"[A-Z]{2}", country_code):
            raise EnergyMoneyConfigurationError(
                f"{COUNTRY_ENV} must be a two-letter country code; got "
                f"{country_code!r}."
            )

        legacy_directory = root / "data" / "preprocessing" / "data"

        def configured_path(variable: str, default: Path) -> Path:
            candidate = Path(env[variable]) if variable in env else default
            return candidate if candidate.is_absolute() else root / candidate

        if mode is EnergyMoneyMode.COUNTRY_DETAIL:
            if country_code == "DK" and COUNTRY_DETAIL_ROOT_ENV not in env:
                layer_directory = legacy_directory
            else:
                detail_root = configured_path(
                    COUNTRY_DETAIL_ROOT_ENV,
                    root / "data" / "preprocessing" / "data" / "country_detail",
                )
                layer_directory = detail_root / country_code
        else:
            public_root = configured_path(
                PUBLIC_CORE_ROOT_ENV,
                root / "data" / "preprocessing" / "data" / "eu_core",
            )
            layer_directory = public_root / country_code

        output_override = env.get(OUTPUT_GDX_ENV)
        if output_override:
            generated_country_gdx = configured_path(
                OUTPUT_GDX_ENV, root / "data_DK.gdx"
            )
        elif (
            mode is EnergyMoneyMode.COUNTRY_DETAIL
            and country_code == "DK"
            and COUNTRY_DETAIL_ROOT_ENV not in env
        ):
            # Exact legacy output location used by read_data.py from model/.
            generated_country_gdx = root / "data_DK.gdx"
        else:
            generated_root = configured_path(
                GENERATED_ROOT_ENV,
                root / "data" / "generated" / "energy_money",
            )
            generated_country_gdx = (
                generated_root / country_code / f"data_{country_code}.gdx"
            )

        return cls(
            repo_root=root,
            country_code=country_code,
            mode=mode,
            layer_directory=layer_directory.resolve(),
            energy_workbook=(layer_directory / ENERGY_WORKBOOK_NAME).resolve(),
            energy_io_workbook=(layer_directory / ENERGY_IO_WORKBOOK_NAME).resolve(),
            marginal_rate_gdx=(layer_directory / MARGINAL_GDX_NAME).resolve(),
            generated_country_gdx=generated_country_gdx.resolve(),
        )

    def validate(self) -> None:
        """Fail fast unless the selected layer satisfies the full input contract."""

        if self.mode is EnergyMoneyMode.PUBLIC_CORE and not self.layer_directory.is_dir():
            raise EnergyMoneyConfigurationError(
                "Public-core artifacts are absent for "
                f"{self.country_code}: expected generated directory "
                f"{self.layer_directory}. No Danish fallback is permitted."
            )

        required = {
            "energy workbook": self.energy_workbook,
            "energy IO workbook": self.energy_io_workbook,
            "complete marginal-rate GDX": self.marginal_rate_gdx,
        }
        missing = [f"{label}: {path}" for label, path in required.items() if not path.is_file()]
        if missing:
            fallback_note = (
                " Public-core mode never falls back to Danish inputs."
                if self.mode is EnergyMoneyMode.PUBLIC_CORE
                else ""
            )
            raise EnergyMoneyConfigurationError(
                "Selected energy-money layer is incomplete:\n- "
                + "\n- ".join(missing)
                + fallback_note
            )

        if self.marginal_rate_gdx.stat().st_size == 0:
            raise EnergyMoneyConfigurationError(
                f"Marginal-rate GDX is empty: {self.marginal_rate_gdx}. "
                "Provide one complete compatible file containing tEAFG_REmarg "
                "and tCO2_REmarg; GDX layers are not merged."
            )
        self._validate_marginal_rate_gdx()
        if self.generated_country_gdx.suffix.lower() != ".gdx":
            raise EnergyMoneyConfigurationError(
                f"Generated country output must end in .gdx: "
                f"{self.generated_country_gdx}"
            )

        input_paths = {
            self.energy_workbook,
            self.energy_io_workbook,
            self.marginal_rate_gdx,
        }
        if self.generated_country_gdx in input_paths:
            raise EnergyMoneyConfigurationError(
                "Generated country GDX must not overwrite an input artifact."
            )

        try:
            validate_energy_workbook(self.energy_workbook)
            validate_io_workbook(self.energy_io_workbook)
        except ValueError as exc:
            raise EnergyMoneyConfigurationError(str(exc)) from exc

    def _validate_marginal_rate_gdx(self) -> None:
        """Check the symbols and record domains consumed later by read_data.py."""

        try:
            import gamspy as gp

            container = gp.Container(str(self.marginal_rate_gdx))
        except Exception as exc:
            raise EnergyMoneyConfigurationError(
                f"Cannot read marginal-rate GDX {self.marginal_rate_gdx}: {exc}"
            ) from exc

        for symbol_name, required_columns in MARGINAL_GDX_COLUMNS.items():
            try:
                records = container[symbol_name].records
            except KeyError as exc:
                raise EnergyMoneyConfigurationError(
                    f"{self.marginal_rate_gdx}: required symbol "
                    f"{symbol_name!r} is absent. GDX layers must be complete "
                    "and are not merged."
                ) from exc
            if records is None:
                raise EnergyMoneyConfigurationError(
                    f"{self.marginal_rate_gdx}: required symbol "
                    f"{symbol_name!r} has no records."
                )
            missing_columns = sorted(required_columns.difference(records.columns))
            if missing_columns:
                raise EnergyMoneyConfigurationError(
                    f"{self.marginal_rate_gdx}: symbol {symbol_name!r} is "
                    f"incompatible; missing record columns {missing_columns}."
                )

    def prepare_output_directory(self) -> None:
        """Create only the generated-output directory, never an input directory."""

        self.generated_country_gdx.parent.mkdir(parents=True, exist_ok=True)

    def gams_input_path(self, working_directory: Path) -> str:
        """Return a portable GAMS macro value relative to its working directory."""

        try:
            relative = os.path.relpath(
                self.generated_country_gdx, start=Path(working_directory).resolve()
            )
            value = Path(relative).as_posix()
        except ValueError:
            # Windows cannot express a relative path across drive letters.
            value = self.generated_country_gdx.as_posix()
        if any(character in value for character in ('"', "'", "%")):
            raise EnergyMoneyConfigurationError(
                f"Generated GDX path is unsafe for a GAMS macro: {value!r}."
            )
        return value


@lru_cache(maxsize=1)
def get_energy_money_config() -> EnergyMoneyConfig:
    """Return one validated configuration shared by run.py and read_data.py."""

    config = EnergyMoneyConfig.from_env()
    config.validate()
    return config


def clear_energy_money_config_cache() -> None:
    """Clear the process cache (primarily for tests and interactive sessions)."""

    get_energy_money_config.cache_clear()
