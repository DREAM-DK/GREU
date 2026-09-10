# Product tax source assignment

`TaxesData.jl` builds `product_taxes.csv` from the input-output tax matrix,
government and sector-account totals, and `import_product_taxes.csv`.

- [Eurostat T1630](https://ec.europa.eu/eurostat/databrowser/view/naio_10_cp1630/default/table)
  reports net taxes by product and use. It has no domestic/import split for
  Denmark. The `DOM` net-tax accounting row in T1610 equals the `TOTAL` row;
  it does not identify taxes on goods of domestic origin.
- [Eurostat government tax data](https://ec.europa.eu/eurostat/databrowser/view/gov_10a_taxag/default/table)
  reports D212, taxes and duties on imports excluding VAT, and D2121, import
  duties. The refresh uses sector `S13_S212`, which includes both government
  and EU receipts, and unit `MIO_EUR`. D2121 is part of D212; do not add it again.

The product-use gross split retains reported net taxes and total subsidies.
To split gross taxes by origin, first assign reported D212 only to imports.
Estimate its product-use weights from positive import quantities times the
gross product-use tax rate. Exclude exports, inventories, and pairs with a
negative origin quantity. Fail if the reported control exceeds this base.
Then split the remaining gross taxes by purchaser-origin shares. This keeps
each product-use gross and net total and permits different import and domestic
rates. This is an estimate of incidence, not an observed tariff schedule.

Keep subsidies proportional to purchaser-origin quantities because these
sources do not give their origin split. Keep the same rule for signed inventory
flows. A negative inventory tax or subsidy amount can have a nonnegative rate.

Run `julia --project=. model_julia/tests/product_tax_origin.jl` to check the
allocation, signed flows, source totals, and saved output without network access.
`TaxesData.refresh_product_taxes_data!()` fetches the import-tax controls and
rebuilds the product-tax output. The production and product tax section of
`model_julia/RefreshData.jl` also runs this step. The repository ignores CSV
files, so rebuild them locally after pulling this change.
