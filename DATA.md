# Data

The MIT licence in [LICENSE](LICENSE) covers the code, its documentation and
the data that DREAM has produced. It does not cover the Danish benchmark data
set, which carries its own terms.

## Danish benchmark data set

### Source

Statistics Denmark produced the Danish benchmark data set for GreenREFORM-EU
in 2025, under contract with DREAM for the European Commission's Technical
Support Instrument project 101195159. Statistics Denmark adapted the data it
prepares for the Danish GreenREFORM model. The data set has 57 industries,
25 energy products and five emission types.

Files:

- All `.xlsx` `data/preprocessing/data` - the data set from Statistics
  Denmark.
- `data/data.gdx` and `data/data_DK.gdx` - the data set prepared for the model
  by the scripts in `data/preprocessing/`.

The industry list, the energy products and the emission types are properties
of this data set, not of the model. A country data set gives its own lists.

### Rights and terms of use

Statistics Denmark holds the copyright to the data set. On 13 November 2026
Statistics Denmark allowed it to be made freely available with the model, on
the same terms as data from Statbank Denmark.

Those terms are published by Statistics Denmark at
<https://www.dst.dk/en/presse/kildeangivelse>. In short:

- You may copy, reuse and redistribute the data, for commercial and
  non-commercial purposes alike.
- You must state Statistics Denmark as the source. Statistics Denmark says
  this corresponds to the Creative Commons licence CC BY 4.0.
- If you process the data further, say so.
- You may not use Statistics Denmark's logo.
- Statistics Denmark accepts no liability for loss caused by errors in the
  statistics or in their processing.

### How to cite

For the data set as delivered:

> Source: Statistics Denmark.

For results or data derived from it, including runs of GreenREFORM-EU:

> Source: Own calculations based on data from Statistics Denmark.

## Energy technology data

The energy technology data in `data/Energy_technology_data/` were produced by
DREAM. They are covered by the MIT licence, like the code.
