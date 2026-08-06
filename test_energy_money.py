from __future__ import annotations

import hashlib
from pathlib import Path
import tempfile
import unittest

import pandas as pd

from data.Modules.energy_money import (
    EnergyMoneyConfig,
    EnergyMoneyConfigurationError,
    EnergyMoneyMode,
    materialize_overlay,
)
from data.Modules.energy_money.config import (
    COUNTRY_ENV,
    GENERATED_ROOT_ENV,
    MODE_ENV,
    PUBLIC_CORE_ROOT_ENV,
)
from data.Modules.energy_money.schema import (
    ENERGY_CONTRACT,
    ENERGY_IO_CONTRACT,
    read_and_validate_workbook,
)


REPO_ROOT = Path(__file__).resolve().parent


def _energy_row(product: str = "electricity", basic: float = 1.0) -> dict:
    row = {column: 0.0 for column in ENERGY_CONTRACT.required_columns}
    row.update(
        {
            "year": 2020,
            "bal": "use",
            "flow": "cons_inter",
            "indu": "A",
            "purp": "process_normal",
            "product": product,
            "pj": 2.0,
            "basic": basic,
            "purch": basic,
        }
    )
    return row


def _io_row(value: float = 1.0, row_l2: str = "A") -> dict:
    return {
        "year": 2020,
        "row_l1": "production",
        "row_l2": row_l2,
        "col_l1": "cons_inter",
        "col_l2": "A",
        "value": value,
    }


def _write_workbook(path: Path, sheet: str, rows: list[dict]) -> None:
    with pd.ExcelWriter(path, engine="openpyxl") as writer:
        pd.DataFrame(rows).to_excel(writer, sheet_name=sheet, index=False)


def _digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class EnergyMoneyConfigurationTests(unittest.TestCase):
    def test_default_is_exact_legacy_denmark_contract(self) -> None:
        config = EnergyMoneyConfig.from_env({}, repo_root=REPO_ROOT)

        self.assertEqual(config.country_code, "DK")
        self.assertIs(config.mode, EnergyMoneyMode.COUNTRY_DETAIL)
        self.assertEqual(
            config.energy_workbook,
            REPO_ROOT
            / "data"
            / "preprocessing"
            / "data"
            / "energy_and_emissions.xlsx",
        )
        self.assertEqual(
            config.energy_io_workbook,
            REPO_ROOT
            / "data"
            / "preprocessing"
            / "data"
            / "io_energy_long_format.xlsx",
        )
        self.assertEqual(
            config.marginal_rate_gdx,
            REPO_ROOT / "data" / "preprocessing" / "data" / "EU_GR_data.gdx",
        )
        self.assertEqual(config.generated_country_gdx, REPO_ROOT / "data_DK.gdx")
        self.assertEqual(
            config.gams_input_path(REPO_ROOT / "model"), "../data_DK.gdx"
        )

    def test_public_core_missing_directory_fails_without_danish_fallback(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            config = EnergyMoneyConfig.from_env(
                {
                    COUNTRY_ENV: "SE",
                    MODE_ENV: "public_core",
                    PUBLIC_CORE_ROOT_ENV: str(Path(temporary) / "eu_core"),
                },
                repo_root=REPO_ROOT,
            )

            with self.assertRaisesRegex(
                EnergyMoneyConfigurationError, "No Danish fallback is permitted"
            ):
                config.validate()

    def test_nonlegacy_output_name_uses_country_code(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            config = EnergyMoneyConfig.from_env(
                {
                    COUNTRY_ENV: "SE",
                    MODE_ENV: "public_core",
                    PUBLIC_CORE_ROOT_ENV: str(Path(temporary) / "eu_core"),
                    GENERATED_ROOT_ENV: str(Path(temporary) / "generated"),
                },
                repo_root=REPO_ROOT,
            )

            self.assertEqual(
                config.generated_country_gdx,
                Path(temporary).resolve() / "generated" / "SE" / "data_SE.gdx",
            )


class WorkbookContractTests(unittest.TestCase):
    def test_duplicate_energy_key_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "energy_and_emissions.xlsx"
            row = _energy_row()
            _write_workbook(path, ENERGY_CONTRACT.sheet, [row, row.copy()])

            with self.assertRaisesRegex(ValueError, "duplicate rows for key"):
                read_and_validate_workbook(path, ENERGY_CONTRACT)

    def test_wrong_sheet_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "io_energy_long_format.xlsx"
            _write_workbook(path, "wrong", [_io_row()])

            with self.assertRaisesRegex(ValueError, "required sheet 'io' is absent"):
                read_and_validate_workbook(path, ENERGY_IO_CONTRACT)


class GamsContractTests(unittest.TestCase):
    def test_country_gdx_macro_has_legacy_default_and_both_load_sites(self) -> None:
        source = (REPO_ROOT / "data" / "data_from_GR.gms").read_text(
            encoding="utf-8"
        )

        self.assertIn(
            "$if not set energy_money_gdx $set energy_money_gdx data_DK.gdx",
            source,
        )
        self.assertIn('$gdxin "%energy_money_gdx%"', source)
        self.assertIn("execute_load '%energy_money_gdx%'", source)


class SwedenPublicCoreTests(unittest.TestCase):
    def test_generated_sweden_package_validates_without_fallback(self) -> None:
        config = EnergyMoneyConfig.from_env(
            {
                COUNTRY_ENV: "SE",
                MODE_ENV: "public_core",
            },
            repo_root=REPO_ROOT,
        )

        config.validate()
        self.assertEqual(
            config.layer_directory,
            REPO_ROOT / "data" / "preprocessing" / "data" / "eu_core" / "SE",
        )
        self.assertNotEqual(
            config.layer_directory,
            REPO_ROOT / "data" / "preprocessing" / "data",
        )

    def test_sweden_component_and_physical_identities_close(self) -> None:
        package = (
            REPO_ROOT / "data" / "preprocessing" / "data" / "eu_core" / "SE"
        )
        energy = read_and_validate_workbook(
            package / "energy_and_emissions.xlsx", ENERGY_CONTRACT
        )
        use = energy[energy["bal"] == "use"].copy()
        components = use[
            [
                "basic", "ws_marg", "ret_marg", "mvs_marg", "ener_tax",
                "co2_tax", "so2_tax", "nox_tax", "pso_tax", "vat",
            ]
        ].sum(axis=1)
        self.assertLess(float((use["purch"] - components).abs().max()), 1e-9)
        balance = energy.groupby(["product", "bal"])["pj"].sum().unstack(
            fill_value=0.0
        )
        self.assertLess(float((balance["sup"] - balance["use"]).abs().max()), 1e-9)

    def test_public_core_branch_preserves_coarse_domains(self) -> None:
        source = (
            REPO_ROOT / "data" / "preprocessing" / "read_data.py"
        ).read_text(encoding="utf-8")
        self.assertIn("if is_public_core:", source)
        self.assertIn("r_not_in_i = []", source)
        self.assertIn(
            "(tEAFG_REmarg_df['r'] == '53000') & (not is_public_core)",
            source,
        )


class OverlayMaterializerTests(unittest.TestCase):
    def test_overlay_is_deterministic_and_never_overwrites_inputs(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            base_dir = root / "base"
            detail_dir = root / "detail"
            base_dir.mkdir()
            detail_dir.mkdir()

            base_energy = base_dir / "energy_and_emissions.xlsx"
            base_io = base_dir / "io_energy_long_format.xlsx"
            detail_energy = detail_dir / "energy_and_emissions.xlsx"
            detail_io = detail_dir / "io_energy_long_format.xlsx"
            marginal_gdx = detail_dir / "EU_GR_data.gdx"

            _write_workbook(
                base_energy,
                ENERGY_CONTRACT.sheet,
                [_energy_row("gas", 3.0), _energy_row("electricity", 1.0)],
            )
            _write_workbook(
                base_io,
                ENERGY_IO_CONTRACT.sheet,
                [_io_row(3.0, "B"), _io_row(1.0, "A")],
            )
            _write_workbook(
                detail_energy,
                ENERGY_CONTRACT.sheet,
                [_energy_row("electricity", 9.0)],
            )
            _write_workbook(
                detail_io,
                ENERGY_IO_CONTRACT.sheet,
                [_io_row(9.0, "A")],
            )
            marginal_gdx.write_bytes(b"complete-selected-gdx")

            inputs = (
                base_energy,
                base_io,
                detail_energy,
                detail_io,
                marginal_gdx,
            )
            before = {path: _digest(path) for path in inputs}

            first = materialize_overlay(
                base_energy_workbook=base_energy,
                base_energy_io_workbook=base_io,
                detail_energy_workbook=detail_energy,
                detail_energy_io_workbook=detail_io,
                selected_marginal_rate_gdx=marginal_gdx,
                output_directory=root / "out1",
                country_code="SE",
                provenance="synthetic unit test",
            )
            second = materialize_overlay(
                base_energy_workbook=base_energy,
                base_energy_io_workbook=base_io,
                detail_energy_workbook=detail_energy,
                detail_energy_io_workbook=detail_io,
                selected_marginal_rate_gdx=marginal_gdx,
                output_directory=root / "out2",
                country_code="SE",
                provenance="synthetic unit test",
            )

            self.assertEqual(before, {path: _digest(path) for path in inputs})
            self.assertEqual(first.energy_workbook.name, "energy_and_emissions.xlsx")
            self.assertEqual(
                first.energy_io_workbook.name, "io_energy_long_format.xlsx"
            )
            self.assertEqual(first.marginal_rate_gdx.name, "EU_GR_data.gdx")
            self.assertEqual(
                first.marginal_rate_gdx.read_bytes(), marginal_gdx.read_bytes()
            )

            first_energy = read_and_validate_workbook(
                first.energy_workbook, ENERGY_CONTRACT
            )
            second_energy = read_and_validate_workbook(
                second.energy_workbook, ENERGY_CONTRACT
            )
            pd.testing.assert_frame_equal(first_energy, second_energy)
            replacement = first_energy.loc[
                first_energy["product"] == "electricity", "basic"
            ].item()
            self.assertEqual(replacement, 9.0)
            self.assertTrue(first.manifest.is_file())

            with self.assertRaises(FileExistsError):
                materialize_overlay(
                    base_energy_workbook=base_energy,
                    base_energy_io_workbook=base_io,
                    detail_energy_workbook=detail_energy,
                    detail_energy_io_workbook=detail_io,
                    selected_marginal_rate_gdx=marginal_gdx,
                    output_directory=root / "out1",
                    country_code="SE",
                    provenance="must not overwrite",
                )


if __name__ == "__main__":
    unittest.main()
