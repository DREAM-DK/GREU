
import numpy as np
import pandas as pd
#import sys
import gamspy as gp
#import gams.core.numpy
'''
This script reads raw data from the excel sheets in the data-folder and produces a .gdx-file called data_DK.gdx.
data_DK is then read into data_from_GR.gms and manipulated before entering the model.

The flow of this script is as such:
Sections labeled 1.x reads data from excel sheets and stores them in pandas dataframes.
Section 2.x retrieves set-objects from the metadata.xlsx file and the index columns of the various dataframes created in section 1.x and turn these into GAMS sets, before then
creating GAMS-variables define on these same sets and exporting them.

Why so many lines of code to simply plug data into a dataframe?

Because of the way these quirky mathematical objects called "functions", "sets" and "variables" work. A set is a collection of elements and a function is a mapping between sets. A "variable"
in the context of a model is best thought of as the output of a function defined on set(s) and mapping onto the real axis. This means, that a variable is something which takes elements from
this thing called a set and associates it with a number. In order for a variable to be well-defined, first a set must be defined. We can do this by simply declaring it. Seeing as a set is a collection of things, 
the way we do it is to simply provide a list of things and giving this list a name such as "i" or "My favorite songs" or "Asbjørn". A variable defined on "My favorite songs" then, takes an element
from "My favorite songs" and give it a number, i.e. the variable x['Ashes to Ashes']=5.
This expression is only meaningful if "Ashes to Ashes" is in "My favorite songs", otherwise the variable is not well-defined.

A naïve computer has no way of knowing that I like David Bowie, therefore I must make sure that I have told it prior to defining the variable and attempting to assign it the value 5 to the set element 
"Ashes to Ashes", that "Ashes to Ashes" is indeed in "My favorite songs".


Likewise, if I want to create a variable vIO_y defined on i,d,t, I must make sure that the things on which I want the variable to take values are members of i,d and t.
Furthermore, if I want to use these sets again in the model, I should take care to not fill these sets with anything unexpected or meaningless.
This is what happens in the 1.x sections. I make sure that the columns in the spreadsheets correspond to the sets we want to use in the model, and that when values inevitably go missing - as I
am sure will happen to you too, that the sets and variables are still well-defined.

It is reasonable therefore to think of each chunk of code in the 1.x sections as "trimming" the data into nice dataframes wherein functions called variables are well-defined (i.e. unique and non-empty),
and the sets are accurate representations of what they are intended as (i.e. "Ashes to Ashes" does not appear in a set called "Grocery list").
'''
#Initialize container
m=gp.Container()
pd.set_option("mode.copy_on_write", True)

'''
"Clean version". No experimentation or debugging here

The data we read in this file is from several different .xlsx sheets. 
The script runs reasonably efficiently with a few exceptions, it does however rely quite heavily on the pandas-package atm.
In terms of robustness, I rely quite heavily on the naming conventions and datastructure in the datasheets.
The names are not extracted, but typed which comes with some risk should those conventions change.
The gp.Set(), gp.Parameter()-functions that I rely on for datatransfer are also snesitive to changes in the data-structure, that is domain-names must be entered in the "correct" order, especially when relying on the
very efficient domain_forwarding for populating sets.
Initially I define a number of dictionaries. They are mostly self-explanatory, but the ones that are not are adressed immediately below.
I see no way around having to do this, as the data here is read into sets and parametres that must correpond to sets in the model for it to run.
For any other application where data is not in exactly the same format will likely mean having to adapt these.
Furthermore, the order of sets is not trivial. Therefore I also must reorder columns for compatibility with the model.
The easiest way to get this correct, I imagine is to look at the actual parametres being exported when gp.Parameter is called.
gp.Parameter takes an input called domain, which is the sets on which the parameter is defined, and the order is the order which corresponds to the order in the model.
Columns are not required to have the same header as the set to which it corresponds, but the data being exported is required to have a column titled "level" which is the values-column.

Note that in section 1.6, I have to manually change datatypes in a dataframe. This is because the pd.read_excel-function is somewhat unreliable when reading smaller datasets.
Standard behavior for this function is to generalize datatypes across columns to the "best fit" across all entries in the column, i.e. if there are decimals in a column, the inferred datatype is float,
if there is text the inferred datatype is str and so forth.
On small datasets, that do not contain any text entries, pd.read_excel have been observed to treat the entire block as numerical matrix and infer float, which causes problems on export since 2020.0 (float)
and 2020 are treated as different objects.

Enable copy_on_write, this will be default in upcoming pandas-version and some methods will become depreciated (including a personal favorite of mine df[col].method(blabla, inplace=True)),
specifically chained assignments and operating on some views of objects which in fringe cases can lead to misassignments, in addition, methods that I use throughout (df.drop,df.rename) are modified 
to return views until modified further since these do not require copies of data resulting in overall performance improving. Excluding all this, copy_on_write will become default anyways, 
meaning that failing to comply with the required specifications for this mode now, will eventually cause the code to fail and users will have to rely on legacy-versions of pandas, or modify the script locally.
If you must use deprecated methods, the latest version of pandas that supports chained assignments and operating on all views is 2.2.3

03/06/25:
Two variables: tEAFG_REmarg and tCO2_REmarg are read from a .gdx-file from the Danish version of the GreenREFORM-model. This is a temporary solution, forced upon us by requirements in the development of the model.
This means that subsection 2.5 is likely to undergo some transformation on the coding side - or be made obsolete.
'''
#Initialize dictionaries
'''dictionaries for mapping from raw data onto GR-set members'''
metadata_dicte=pd.read_excel(r'data_BE\metadata_BE.xlsx',sheet_name='energy_products_pefa_map')
dict_e = dict(zip(metadata_dicte['product_greu'], metadata_dicte['product_greu_txt']))

dict_transaction={'transmis_loss':'transmission_losses','cons_inter':'input_in_production','cons_hh':'household_consumption','import':'imports','invent_change':'inventory'}

dict_ebalitems={'ws_marg':'EAV','ret_marg':'DAV','basic':'BASE','co2_xbio':'co2ubio','co2_eq':'co2e','co2_bio':'co2bio','mvs_marg':'CAV'}

dict_a={'tax_products':'TaxSub','tax_vat':'Moms','emp_comp':'SalEmpl','subs_other_production':'OthSubs','tax_other_production':'OthTax','gross_surplus':'OvProd'} #turister

io_inv_dict={'invest_build':'iB','invest_other':'iM','invest_trans':'iT'}

fixed_assets_dict={'N11P':'iM','N1121':'iB','N1122_3':'iB','N1131':'iT','N115':'iM','N117':'iM','N111':'iB'}
'''since above is not self-explanatory.
N11P is "ICT-equipment, other machinery and stock and weapons systems"
N1122_3 is "facilities"
N1131 is "means of transport"
N115 is "stock of animals"
N117 is "intellectual rights"
N111 is "housing"
'''
'''List of model years'''
t_list=[i for i in range(1980, 2100)]
#Data treatment

# Non energy emissions
non_energy_emissions=pd.read_excel(r'data_BE\non_energy_emissions_BE.xlsx',keep_default_na=True)
non_energy_emissions.set_index(['year','bal','flow','indu'],inplace=True)
#stack to obtain a column of emission-types
non_energy_emissions=non_energy_emissions.stack().to_frame(name='level')
non_energy_emissions.dropna(inplace=True)
#impose ebalitems name
non_energy_emissions.index.rename(['year','bal','transaction','d','ebalitems'],inplace=True)
non_energy_emissions.reset_index(inplace=True)
non_energy_emissions.drop(columns='bal',inplace=True)

non_energy_emissions.replace({'transaction':dict_transaction,'ebalitems':dict_ebalitems},inplace=True)

# set column order
non_energy_emissions = non_energy_emissions[['ebalitems', 'transaction', 'd', 'year', 'level']]

#Energy emissions
energy_and_emissions=pd.read_excel(r'data_BE\energy_and_emissions_BE.xlsx',keep_default_na=True)

'''rename coslumns for compatibility with data loading'''
energy_and_emissions.rename(columns={'indu':'d','product':'e','purp':'es','flow':'transaction'},inplace=True)
energy_and_emissions.set_index(['year','bal','transaction','d','es','e'],drop=True,inplace=True)

energy_and_emissions=energy_and_emissions.stack().to_frame(name='level')
energy_and_emissions.index.set_names(['year','bal','transaction','d','es','e','ebalitems'],inplace=True)
energy_and_emissions.reset_index(inplace=True)
energy_and_emissions.fillna({'es':'unspecified'},inplace=True)
energy_and_emissions.replace({'transaction':dict_transaction,'ebalitems':dict_ebalitems},inplace=True)


'''below "fills" out the d-column where there is a gap in data.
Taking the top line as an example, if there is NaN in d and the transaction is export then 'd' is set to 'xOth'. 
'''
energy_and_emissions['d'] = energy_and_emissions.apply(lambda row: 'xOth' if pd.isna(row['d']) and row['transaction'] == 'export'
                               else ('invt' if pd.isna(row['d']) and row['transaction'] == 'inventory'
                                     else ('tl' if pd.isna(row['d']) and row['transaction'] == 'transmission_losses'
                                           else ('natural_input' if pd.isna(row['d']) and row['transaction'] == 'nat_input'
                                                 else ('residual' if pd.isna(row['d']) and row['transaction'] == 'res_input'
                                                       else ('19000' if pd.isna(row['d']) and row['transaction']=='imports'
                                                            else row['d']))))), axis=1)
'''apply dict_e'''
energy_and_emissions['e']=energy_and_emissions['e'].replace(dict_e)

# set column order
energy_and_emissions = energy_and_emissions[['ebalitems', 'transaction', 'd', 'es', 'e', 'year', 'level']]
'''retrieve unique values from the e-column to populate e and its superset out.
I add some records manually that are explicitly called in the model, but are not present in data.
'''
'''from the e column, construct a list of unique values which we can use later to populate the set we will call "e" '''
e_vals=list(set(energy_and_emissions[['e']].values.flatten()))
out_vals=e_vals.copy()
'''Similarly for out, only I also want to have "out_other" and "WholeAndRetailSaleMarginE" in the set in addition to those in the e-column.'''
out_vals.extend(['out_other','WholeAndRetailSaleMarginE'])

#IO-data
'''gampy does not support domain forwarding from set to set.
To construct a superset of IO-sectors we must initially populate the superset, then provide it as domain for subsets, which we can then populate using the tried and tested domain_forwarding method.
To populate the superset, we must load data from the io-spreadsheets.
On the data:
The Danish IO-tables are received in long-format and matrix-format. I read the long-format for convenience, but the content of the data is better understood when veiwing in matrix-format.
The columns consist of demand-components, which can be either sectors of the economy, export, investment or some final-demand component such as food or housing.
The rows consist of inputs, and can be subdivided into three categories, domestic production, import and primary inputs.
The primary inputs are taxes, subsidies, employee compensation and the likes.
Imported and domestically produced inputs are industry-outputs such that a number in any entry of the IO-matrix can be read as the supply from the row-index to the column-index.
To make this data compatible with the model, we must first inform the model how to interpret the indices. We do this by defining sets.
For instance the set "i" is the set of sectors in the model, we can therefore say that the rows of the import- and domestically produced part of the io-table, consist of members of i. 
The set d is the set of demand-components and corresponds to the columns of the io-tables.
By creating separate variables for imported and domestically produced supply from the io-table, we can define a variable like vIO_y, and define in on [i,d,t], which we can then read as 
domestic sector i's supply to demand component d at year t. Atm, I think the easiest to follow in the extremely likely event that data is not in the exact same format, is the current version
in which I explicitly label columns in the dataframes according to their GR-set-counterparts. 
It is important not to mess with the sets, as they are called explicitly in the model, always by name and on occasion we also refer to specific elements.
The consequence of this is that names have to be inserted here. This will almost certainly need to be edited for other sources of data.
I try to make apparent from the naming throughout where columns and rows are meant to end up in the model which
I suspect will ultimately be more convenient for adapting this code to other datasets than attempting to accomplish the
highest possible degree of automization.
'''
#energy
io_energy=pd.read_excel(r'data_BE\io_energy_long_format_BE.xlsx',keep_default_na=True)
io_energy_forlater=io_energy.copy(deep=True)
io_energy.rename(columns={'row_l2':'i','col_l1':'DELETE','col_l2':'d','value':'level'},inplace=True)

#regular
io=pd.read_excel(r'data_BE\io_long_format_BE.xlsx')
io_forlater=io.copy(deep=True)
io.rename(columns={'row_l2':'i','col_l1':'DELETE','col_l2':'d','value':'level'},inplace=True)

'''fill nans based on previous entries. In Danish dataset, col_l1 contains supercategories for col_l2.
Meanwhile, we use col_l2, which contains useful categories such as sectors (as opposed to cons_inter). 
Categories which do not have a subcategory, such as cons_publ (public consumption) have an empty cell at col_l2.
In this program I create the set of demand components d from its members, so in order to represent the demand components that do
not have multiple subcategories, I run the lines below which fills the appropriate GR-demand component based on the supercategory, i.e.
if row10 supercategory is export, replace NaN in the demand component column of row10 with xOth.
'''
io['d'] = io.apply(lambda row: 'xOth' if pd.isna(row['d']) and row['DELETE'] == 'export'
                               else ('invt' if pd.isna(row['d']) and row['DELETE'] == 'invent_change'
                                     else ('g' if pd.isna(row['d']) and row['DELETE'] == 'cons_publ'
                                           else ('iB' if pd.isna(row['d']) and row['DELETE'] == 'invest_build'
                                                 else ('iT' if pd.isna(row['d']) and row['DELETE'] == 'invest_trans'
                                                       else ('iM' if pd.isna(row['d']) and row['DELETE']=='invest_other'
                                                            else row['d']))))), axis=1)

io_energy['d'] = io_energy.apply(lambda row: 'xOth' if pd.isna(row['d']) and row['DELETE'] == 'export'
                               else ('invt' if pd.isna(row['d']) and row['DELETE'] == 'invent_change'
                                     else ('g' if pd.isna(row['d']) and row['DELETE'] == 'cons_publ'
                                           else ('iB' if pd.isna(row['d']) and row['DELETE'] == 'invest_build'
                                                 else ('iT' if pd.isna(row['d']) and row['DELETE'] == 'invest_trans'
                                                       else ('iM' if pd.isna(row['d']) and row['DELETE']=='invest_other'
                                                            else row['d']))))), axis=1)

'''Editors note: At the time of writing, the model is not equipped to handle the distinction between con_hh and cons_hh_foreign, therefore
for the time being we simply add them together, I do this by creating a boolean mask to identify rows where the aforementioned supercategory-column 
contains the string cons_hh, which in the GR dataset is both cons_hh and cons_hh_foreign_tou. I then build a dataframe of the entries with only the members of
the original frame(s) that has has cons_hh or cons_hh_foreign_tou as supercategory. I then group entries in this dataset based on entries in the other columns (except of course level) and add them together.
The rows that were selected for this process is then dropped from the original frame(s) and the aggregated rows are added back.
'''
mask=io["DELETE"].str.contains("cons_hh")
mask_ene = io_energy["DELETE"].str.contains("cons_hh")
io_agg = io[mask].groupby(io.columns.difference(["DELETE","level"]).tolist(), as_index=False)["level"].sum()
io_energy_agg= io_energy[mask_ene].groupby(io_energy.columns.difference(["DELETE","level"]).tolist(), as_index=False)["level"].sum()
'''drop rows that had been aggregated'''
io = io[~mask]
io_energy=io_energy[~mask_ene]
'''drop DELETE'''
io.drop(columns=['DELETE'],inplace=True)
io_energy.drop(columns=['DELETE'],inplace=True)
'''reconcat'''
io=pd.concat([io,io_agg])
io_energy=pd.concat([io_energy,io_energy_agg])
'''reorder for consistency with GR-variables'''
io=io[['row_l1','i', 'd', 'year', 'level']]
io_energy=io_energy[['row_l1','i', 'd', 'year', 'level']]
'''separate the io-tables into production, import and primary inputs'''
io_y=io[io['row_l1']=='production']
io_m=io[io['row_l1']=='import']
io_a=io[io['row_l1']=='prim_input']
io_ene_y=io_energy[io_energy['row_l1']=='production']
io_ene_m=io_energy[io_energy['row_l1']=='import']
io_ene_a=io_energy[io_energy['row_l1']=='prim_input']
'''drop columns'''
'''since row_l1 just identifies the type of input, it is no longer required after splitting the io-tables'''
io_y=io_y.drop(columns=['row_l1'])
io_m=io_m.drop(columns=['row_l1'])
io_ene_a=io_ene_a.drop(columns=['row_l1'])
io_ene_y=io_ene_y.drop(columns=['row_l1'])
io_ene_m=io_ene_m.drop(columns=['row_l1'])
io_a=io_a.drop(columns=['row_l1'])
'''apply a_dict'''
io_a.replace({'i':dict_a},inplace=True)
io_ene_a.replace({'i':dict_a},inplace=True)

'''IO-data is a bit weird.
GR-variable vIO_{y,m,a} is the values from the IO-table io.xslx, GR-variable vIOx_{y,m,a} is vIO_{y,m,a}-ioenergy.xlsx.
To obtain these, multiply energy IO's by -1 and add to regular io (call this combined for lack of a better word), while preserving io_{y,m,a} as is in a separate frame.
'''
io_ene_a['level']=io_ene_a['level']*(-1)
io_ene_y['level']=io_ene_y['level']*(-1)
io_ene_m['level']=io_ene_m['level']*(-1)

io_a=io_a.groupby(['d','i','year'],as_index=False).agg({'level':'sum'})
io_combined_a = pd.concat([io_a, io_ene_a]).groupby(io_a.columns.difference(["level"]).tolist(), as_index=False)["level"].sum()
'''add energy to non-energy for vIO_{y,m,a}'''
io_combined_y = pd.concat([io_y, io_ene_y]).groupby(io_y.columns.difference(["level"]).tolist(), as_index=False)["level"].sum()
io_combined_m=pd.concat([io_m, io_ene_m]).groupby(io_m.columns.difference(["level"]).tolist(), as_index=False)["level"].sum()
io_combined_a=io_combined_a.groupby(['d','i','year'],as_index=False).agg({'level':'sum'})

'''change order for GR-compatibility'''
io_a=io_a[['i','d','year','level']]
io_combined_a=io_combined_a[['i','d','year','level']]

'''A list of elements in i'''
i_elements =list(set(io_y['i']).union(set(io_m['i'])))
### Lukas change: changed '_re' by '+re' to not run into error for split with underscore due to industry identifiers also having underscore in Belgium.
i_re_elements=[i+'+re' for i in i_elements]
### OLD ###
# i_re_elements=[i+'_re' for i in i_elements]
'''there is another set "rx" whose elements are those of i, then there is a set which serves the purpose of mapping between rx and re.
Below I construct a list of tuples on the form (x,x_re) where x ∈ re to populate this set.
'''
sorted_i_re_elements=sorted(i_re_elements,key=lambda x: i_elements.index(x.split('+')[0]))
### OLD ###
# sorted_i_re_elements=sorted(i_re_elements,key=lambda x: i_elements.index(x.split('_')[0]))
rx2re_list=list(zip(i_elements,sorted_i_re_elements))

'''a variable defined only on the demand components that are sectors in the model, so not on export, private consumption, etc.'''
io_ene_y_onlys=io_ene_y.loc[io_ene_y['d'].isin(i_elements)]
io_ene_m_onlys=io_ene_m.loc[io_ene_m['d'].isin(i_elements)]
io_ene_a_onlys=io_ene_a.loc[io_ene_a['d'].isin(i_elements)]

'''remultiply by -1 to reobtain positive values'''
io_ene_y_onlys['level']=io_ene_y_onlys['level']*(-1)
io_ene_m_onlys['level']=io_ene_m_onlys['level']*(-1)
io_ene_a_onlys['level']=io_ene_a_onlys['level']*(-1)

#IO-investment
io_inv=pd.read_excel(r'data_BE\io_invest_long_format_BE.xlsx',keep_default_na=True)
io_inv.rename(columns={'col':'i','invest_group':'k','value':'level'},inplace=True)
'''apply dict for GR-compatible codes'''
io_inv['k']=io_inv['k'].replace(io_inv_dict)

'''atm we do not care abt. "sender" of capital, just building qI_k_i'''
io_inv_qI_k_i=io_inv.copy(deep=True)

io_inv_qI_k_i.drop(columns=['row_l1','row_l2'],inplace=True)
io_inv_qI_k_i=io_inv_qI_k_i[['k','i','year','level']]
'''aggregate'''
io_inv_qI_k_i_agg=io_inv_qI_k_i.groupby(['k','i','year'],as_index=False).agg({'level':'sum'})

#Demand-based IO incl. employee compensation
'''extract cons_inter from io_forlater'''
io_qRxE=io_forlater[io_forlater['col_l1']=='cons_inter']

io_qRxE=io_qRxE.rename(columns={'col_l2':'i'})

io_qRxE=io_qRxE.replace({'row_l2':dict_a})

io_l=io_qRxE[io_qRxE['row_l2']=='SalEmpl']
io_l_s=io_l.groupby(['i','year'],as_index=False).agg({'value':'sum'})
'''
Above is the total value of labor from employees. 
This must be upscaled by the contribution of independents
Wages of independents are somewhat complicated. We calculate them by:
wages_employed * hours_independents / hours_employed
and add this to the existing wage sum.
Below reads the data required to compute the expression above:
'''
employed_fullset=pd.read_excel(r'data_BE\employed.xlsx',keep_default_na=True)
employed_fullset.rename(columns={'indu':'i'},inplace=True)
employed_employees=employed_fullset[employed_fullset['type']=='employees'][['year','i', 'hours']]
employed_independent=employed_fullset[employed_fullset['type']=='self-employed'][['year','i', 'hours']]

wagesum=io_l_s[['year','i','value']]
# set index
wagesum.set_index(['year','i'],inplace=True)
employed_employees.set_index(['year','i'],inplace=True)
employed_employees.rename(columns={'hours':'value'},inplace=True)
employed_independent.set_index(['year','i'],inplace=True)
employed_independent.rename(columns={'hours':'value'},inplace=True)

#make sure that all indices are valid
wagesum_index=wagesum.index.union(employed_employees.index).union(employed_independent.index)
wagesum =wagesum.reindex(wagesum_index, fill_value=0)
employed_employees=employed_employees.reindex(wagesum_index, fill_value=0)
employed_independent=employed_independent.reindex(wagesum_index, fill_value=0)

#calculate actual wage compensation
wagesum_=wagesum+wagesum*employed_independent/employed_employees
wagesum_.reset_index(inplace=True)
wagesum_.rename(columns={'value':'level'},inplace=True)

#reorder columns
wagesum_with_t=wagesum_[['i','year','level']]

nemployed_frame=employed_fullset[['year','employed']]
nemployed_frame=nemployed_frame.groupby(['year'],as_index=False).agg({'employed':'sum'})

#Capital, fixed assets
fixed_assets=pd.read_excel(r'data_BE\fixed_assets_BE.xlsx',keep_default_na=True)
'''map onto gr-codes'''
fixed_assets.replace({'asset':fixed_assets_dict},inplace=True)

fixed_assets.rename(columns={'asset':'k','indu':'i','value':'level'},inplace=True)
'''reorder columns'''
fixed_assets=fixed_assets[['k','i','year','level']]
'''GR-split of capital is coarser than data, so we must aggregate'''
fixed_assets=fixed_assets.groupby(['k','i','year'],as_index=False).agg({'level':'sum'})

#ets
ets=pd.read_excel(r'data_BE\ets_BE.xlsx',keep_default_na=True)
#reorder columns for free allowances and drop redundants
qCO2_ETS_freeallowances=ets[['indu','year', 'free_allowances']]
#ensure level-column is called level
qCO2_ETS_freeallowances.rename(columns={'free_allowances':'level','indu':'i'},inplace=True)

#emissions_bridge_items
emissions_bridge_items=pd.read_excel(r'data_BE\emissions_brigde_items_BE.xlsx',keep_default_na=True)

qEmmLULUCF = emissions_bridge_items.loc[emissions_bridge_items['item'] == 'lulucf', ['year','co2_eq']]

'''
Year is stored as a floating point number 2020.0 - which is not the same as the string 2020 or the integer 2020.
When exporting without converting to string, this then causes gamspy to look for an element corresponding to the floating point number 2020.0 in t, which it will not find.
One can then ask: Why did this not happen when we loaded nEmployed?
Because when we loaded nEmployed, we actually found it more convenient to construct a dataframe from scratch and populate with the members 2020 and some column sum from the data.
'''
qEmmLULUCF['year'] = qEmmLULUCF['year'].astype('string')

qEmmLULUCF.rename(columns={'co2_eq':'level'},inplace=True)

emissions_bridge_items_bordertrade=emissions_bridge_items.loc[emissions_bridge_items['item']=='bord_trade']
emissions_bridge_items_bordertrade.rename(columns=dict_ebalitems,inplace=True)
emissions_bridge_items_bordertrade=emissions_bridge_items_bordertrade.dropna(axis=1)
#drop item
emissions_bridge_items_bordertrade.drop(columns=['item'],inplace=True)
#stack
emissions_bridge_items_bordertrade.set_index('year',inplace=True)
emissions_bridge_items_bordertrade=emissions_bridge_items_bordertrade.stack().to_frame(name='level').reset_index()
#reorder columns
emissions_bridge_items_bordertrade=emissions_bridge_items_bordertrade[['level_1','year','level']]

#sector data
institutional_financial_accounts=pd.read_excel(r'data_BE\institutional_financial_accounts_BE.xlsx',keep_default_na=True)

institutional_financial_accounts.set_index(['year','var','sector'],inplace=True)
institutional_financial_accounts=institutional_financial_accounts.stack().to_frame(name='level').reset_index()
institutional_financial_accounts.rename(columns={'level_3':'as_li_net'},inplace=True)
#reorder columns
institutional_financial_accounts=institutional_financial_accounts[['var','sector','as_li_net','year','level']]
institutional_financial_accounts
vNetDebtInstruments=institutional_financial_accounts.loc[institutional_financial_accounts['var']=='vNetDebtInstruments']
vNetInterests=institutional_financial_accounts.loc[institutional_financial_accounts['var']=='vNetInterests']
vNetEquity=institutional_financial_accounts.loc[institutional_financial_accounts['var']=='vNetEquity']
vNetDividends=institutional_financial_accounts.loc[institutional_financial_accounts['var']=='vNetDividends']
vNetRevaluations=institutional_financial_accounts.loc[institutional_financial_accounts['var']=='vNetRevaluations']
#drop redundant var cols
vNetDebtInstruments.drop(columns=['var'],inplace=True)
vNetInterests.drop(columns=['var'],inplace=True)
vNetEquity.drop(columns=['var'],inplace=True)
vNetDividends.drop(columns=['var'],inplace=True)
vNetRevaluations.drop(columns=['var'],inplace=True)

#government finances
government_finances=pd.read_excel(r'data_BE\government_finances_BE.xlsx',keep_default_na=True)

'''Note:
In GR, these values come from MAKRO.
This makes it somewhat difficult to make sense of any deviations and/or constructed variables.
Ask, if you find some bigguns
'''
#convert to string
government_finances['year']=government_finances['year'].astype('string')
#value2level
government_finances.rename(columns={'value':'level'},inplace=True)
#transfers to abroad
government_finances_transfertorow=government_finances.loc[government_finances['trans'].isin(['transfer_to_row','cap_transfer_to_row'])]
vGov2Foreign=government_finances_transfertorow[['year','level']]
vGov2Foreign=vGov2Foreign.groupby(['year'],as_index=False).agg({'level':'sum'})
#transfers from abroaD
government_finances_transferfromrow=government_finances.loc[government_finances['trans'].isin(['transfers_from_row','cap_transfers_from_row'])]
vGovReceiveF=government_finances_transferfromrow[['year','level']]
vGovReceiveF=vGovReceiveF.groupby(['year'],as_index=False).agg({'level':'sum'})
#Land rent
government_finances_rent=government_finances.loc[government_finances['trans']=='rent']
vGovRent=government_finances_rent[['year','level']]
#government investments
government_finances_invest = government_finances.loc[government_finances['trans'].isin(['invest', 'invent_change'])]
vGovInv=government_finances_invest[['year','level']]
vGovInv=vGovInv.groupby(['year'],as_index=False).agg({'level':'sum'})
#government subsidies
government_finances_subsidies=government_finances.loc[government_finances['trans']=='subs']
vGovSub=government_finances_subsidies[['year','level']]
#capital transfers to domestic sectors
government_finances_transferstofirms=government_finances.loc[government_finances['trans']=='cap_transfer_to_dom']
vGov2Firms=government_finances_transferstofirms[['year','level']]
#capital transfers from domestic firms
government_finances_transfersfromfirms=government_finances.loc[government_finances['trans']=='cap_transfers_from_dom']
vGovReceiveFirms=government_finances_transfersfromfirms[['year','level']]
#Public expenditures, not including those paid by EU
government_finances_exp = government_finances.loc[(government_finances['balance']=='exp') & (government_finances['trans']!='interest')]
vGovExp=government_finances_exp[['year','level']]
vGovExp=vGovExp.groupby(['year'],as_index=False).agg({'level':'sum'})
#Public revenues (not including interests)
government_finances_rev=government_finances.loc[(government_finances['balance']=='rev') &(government_finances['trans']!='interest')&(government_finances['trans']!='dividends')]
vGovRev=government_finances_rev[['year','level']]
vGovRev=vGovRev.groupby(['year'],as_index=False).agg({'level':'sum'})
#Revenue from income taxation (kildeskatter)
government_finances_source=government_finances.loc[government_finances['trans']=='tax_direct_source']
vtSource=government_finances_source[['year','level']]
#VAT
government_finances_vat=government_finances.loc[government_finances['trans']=='tax_indirect_vat']
vtVAT=government_finances_vat[['year','level']]
#media tax¨
government_finances_media=government_finances.loc[government_finances['trans']=='tax_direct_media']
vtMedia=government_finances_media[['year','level']]
#vehicles
government_finances_vehicles=government_finances.loc[government_finances['trans']=='tax_direct_vehicles']
vtCarWeight=government_finances_vehicles[['year','level']]
#Revenue from indirect taxes (sum)
government_finances_indirect=government_finances.loc[(government_finances['balance']=='rev') & (government_finances['trans'].str.contains('tax_indirect'))]
vtIndirect=government_finances_indirect[['year','level']]
vtIndirect=vtIndirect.groupby(['year'],as_index=False).agg({'level':'sum'})
#Revenue from direct taxes (sum)
government_finances_direct=government_finances.loc[(government_finances['trans'].str.contains('tax_direct'))&(government_finances['balance']=='rev')]
vtDirect=government_finances_direct[['year','level']]
vtDirect=vtDirect.groupby(['year'],as_index=False).agg({'level':'sum'})
#Rest
government_finances_other=government_finances.loc[(government_finances['balance']=='rev')&(~government_finances['trans'].str.contains('tax_direct'))&(~government_finances['trans'].str.contains('tax_indirect'))&(~government_finances['trans'].isin(['dividends','interest','tax_import']))]
vGovRevRest=government_finances_other[['year','level']]
vGovRevRest=vGovRevRest.groupby(['year'],as_index=False).agg({'level':'sum'})
#Dividends
government_finances_dividends=government_finances.loc[government_finances['trans']=='dividends']
vtDividends=government_finances_dividends[['year','level']]
#tax_imports
government_finances_taximport=government_finances.loc[government_finances['trans']=='tax_import']
vtImport=government_finances_taximport[['year','level']]
#final public consumption
government_finances_final=government_finances.loc[government_finances['trans']=='cons_publ']
vG=government_finances_final[['year','level']]
#gov transfers
government_finances_transfer=government_finances.loc[government_finances['trans']=='transfer_to_hh']
vTrans=government_finances_transfer[['year','level']]
# #social contributions
government_finances_social=government_finances.loc[government_finances['trans']=='soc_cont']
vCont=government_finances_social[['year','level']]
#revenue from corporate taxation
government_finances_corp=government_finances.loc[government_finances['trans']=='tax_direct_corp']
vtCorp=government_finances_corp[['year','level']]
#tax on pension
government_finances_pension=government_finances.loc[government_finances['trans']=='tax_direct_pension']
vtPAL=government_finances_pension[['year','level']]
#vGovExpNetRest
government_finances_expnetrest=government_finances.loc[government_finances['trans']=='tax_indirect_other_production']
vGovExpNetRest=government_finances_expnetrest[['year','level']]
#vtCAP_prodsubsidy
government_finances_cap_prodsubsidy=government_finances.loc[government_finances['trans']=='subs_other_production_eu']
vtCAP_prodsubsidy=government_finances_cap_prodsubsidy[['year','level']]
#vtNetproductionRest
government_finances_netproductionrest=government_finances.loc[government_finances['trans']=='tax_indirect_other_production']
vtNetproductionRest=government_finances_netproductionrest[['year','level']]
'''To split taxes on personal income, we use the disaggregated sheet from the same xlsx-file.
Obviously one can just look at it and recognize the numbers in the aggregated sheet and load directly therefrom, but since
they are indistinguishable - in all other ways than the value in the aggregated form, I read from the diaggregated sheet for inspectability.
Here I am forced to use the trans_txt-column to distinguish between the personal income taxes since they are otherwise identically labelled
'''
#tax on labour
government_finances_disagg=pd.read_excel(r'data_BE\government_finances_BE.xlsx',keep_default_na=True)
government_finances_disagg.rename(columns={'value':'level'},inplace=True)
government_finances_disagg['year']=government_finances_disagg['year'].astype('string')
#revenue from contribution to labour market fund
government_finances_taxlaborAM=government_finances_disagg.loc[government_finances_disagg['trans_txt'].str.contains('labour market fund')&(government_finances_disagg['trans']=='tax_direct_other_labor')]
vtAM=government_finances_taxlaborAM[['year','level']]
#other personal income taxes
government_finances_taxlaboroth=government_finances_disagg.loc[(government_finances_disagg['trans']=='tax_direct_other_labor')&(government_finances_disagg['trans_txt'].str.contains('other'))]
vtPersIncRest=government_finances_taxlaboroth[['year','level']]

#Institutional financial accounts
institutional_financial_accounts=pd.read_excel(r'data_BE\institutional_financial_accounts_BE.xlsx',keep_default_na=True)
#make sure year is string
institutional_financial_accounts['year']=institutional_financial_accounts['year'].astype('string')

#gov interests
vGovInterest=institutional_financial_accounts.loc[(institutional_financial_accounts['var']=='vNetInterests')&(institutional_financial_accounts['sector']=='gov')]
#net
vGovNetInterest=vGovInterest[['year','net']]
vGovNetInterest.rename(columns={'net':'level'})
#assets
vInterestGovAssets=vGovInterest[['year','as']]
vInterestGovAssets.rename(columns={'as':'level'})
#debt
vInterestGovDebt=vGovInterest[['year','li']]
vInterestGovDebt.rename(columns={'as':'level'})

#Metadata for sets + set_txt

#populate c and add text
metadata_cons_hh=pd.read_excel(r'data_BE\metadata_BE.xlsx',sheet_name='cons_hh',keep_default_na=True)
c_records = list(metadata_cons_hh.itertuples(index=False, name=None))
#populate i and re (with text)
metadata_industries=pd.read_excel(r'data_BE\metadata_BE.xlsx',sheet_name='industries',keep_default_na=True)
i_records = list(metadata_industries.itertuples(index=False, name=None))
i_records_fortot=i_records.copy()
re_records = [(str(x) + '_re', y) for x, y in i_records]
#populate es (w. text)
metadata_energy_purposes=pd.read_excel(r'data_BE\metadata_BE.xlsx',sheet_name='energy_purposes',keep_default_na=True)
es_records = list(metadata_energy_purposes.itertuples(index=False, name=None))
#ppulate a_rows_ (w. text)
metadata_flows=pd.read_excel(r'data_BE\metadata_BE.xlsx',sheet_name='flows',keep_default_na=True)
metadata_flows_a=metadata_flows[metadata_flows['flow_type']=='prim_input']
metadata_flows_a['flow']=metadata_flows_a['flow'].replace(dict_a)
a_records=list(metadata_flows_a[['flow','flow_txt']].itertuples(index=False, name=None))
#populate k (w. text)
metadata_flows_k=metadata_flows[metadata_flows['flow'].str.contains('invest')]
metadata_flows_k['flow']=metadata_flows_k['flow'].replace(io_inv_dict)
k_records=list(metadata_flows_k[['flow','flow_txt']].itertuples(index=False, name=None))
k_records_fortot=k_records.copy()
'''
populate ebalitems, currently 'EAFG_tax is called explicitly in the model and is not present in data, so I add it manually to the set ebalitems and the subset etaxes.
'''
ebalitems_records=list(set(non_energy_emissions['ebalitems']).union(set(energy_and_emissions['ebalitems'])))
ebalitems_records.append('EAFG_tax')
#etaxes records
etaxes_records=[s for s in ebalitems_records if '_tax' in s]

#Ordering d + manual population of sets
re_records=['energy']
g_records=['g']
invt_records=['invt']
invt_ene_records=['Invt_Ene']
x_records=['xOth','xEne']
tl_records=['tl']
env_res=['env','res']
dupes=set()
subsets_of_d=[i_records,c_records,g_records,k_records,invt_records,invt_ene_records,x_records,re_records,tl_records,env_res]
d_records=[x for subset in subsets_of_d for x in subset if not (x in dupes or dupes.add(x))]
#ensure records are tuples
d_records = [(x,) if isinstance(x, str) else x for x in d_records]
#energy and non-energy split
d_ene_records = [
    item for item in d_records
    if (isinstance(item, tuple) and isinstance(item[0], str) and "ene" in item[0].lower())
    or (isinstance(item, str) and "ene" in item.lower())
]
d_ene_records = [(x,) if isinstance(x, str) else x for x in d_ene_records]
d_non_ene_records = [item for item in d_records if item not in d_ene_records]

t=gp.Set(m,'t',description='year',records=t_list)

#Construction of GAMS-objects
'''sets'''
transaction=gp.Set(m,name='transaction',description='set of transaction types',records=['households'])
es=gp.Set(m,'es',description='energy service',records=es_records)
out=gp.Set(m,'out',description='output types',records=out_vals)
e=gp.Set(m,'e',domain=[out],description='energy products by industry',records=e_vals)
t=gp.Set(m,'t',description='year',records=t_list)
t1=gp.Set(m,'t1',domain=[t],description='t1',is_singleton=True,records=['2020'])
a_rows_=gp.Set(m,'a_rows_',description='other rows in the input-output table',records=a_records)
k=gp.Set(m,name="k",description='capital types',records=k_records)
'''ebalitems + subsets, some are manually populated since they lack a sufficiently universal identifier in the data'''
ebalitems=gp.Set(m,'ebalitems',description='identifiers tax joules prices etc for energy components by demand components',records=ebalitems_records)
em=gp.Set(m,name='em',domain=[ebalitems],description='emission types',records=['ch4','co2ubio','n2o','co2e','co2bio'])
etaxes=gp.Set(m,name='etaxes',domain=[ebalitems],description='taxes from ebalitems',records=etaxes_records)
'''d + subsets of d'''
d=gp.Set(m,'d',description='demand components',records=d_records)
re=gp.Set(m,'re',domain=[d],description='intermediate import',records=re_records)
invt=gp.Set(m,name='invt',domain=[d],description='Inventories',is_singleton=True,records=invt_records)
i=gp.Set(m,name='i',domain=[d],description='sectors',records=i_records)
tl=gp.Set(m,name='tl',domain=[d],description='Transmission losses',is_singleton=True ,records=tl_records)
x=gp.Set(m,name='x',domain=[d],description='export types',records=x_records)
g=gp.Set(m,name='g',domain=[d],description='public consumption',records=g_records)
c=gp.Set(m,name='c',domain=[d],description='private consumption groups',records=c_records)
rx=gp.Set(m,name='rx',domain=[d],description='Non-energy intermediate input types, this is just equal to i ATM.',records=i_records)
Invt_Ene=gp.Set(m,name='Invt_Ene',domain=[d],description='https://www.youtube.com/watch?v=dQw4w9WgXcQ',is_singleton=True,records=invt_ene_records)
ene_types=gp.Set(m,name='ene_types',domain=d,records=re_records)
d_ene=gp.Set(m,name='d_ene',domain=[d],records=d_ene_records)
d_non_ene=gp.Set(m,name='d_non_ene',domain=[d],records=d_non_ene_records)

'''non-energy emissions'''
non_energy_emissions=gp.Parameter(m,name='NonEnergyEmissions',domain=[ebalitems,transaction,d,t],description='emission from consumption of non-energy',records=non_energy_emissions.values.tolist(),domain_forwarding=True)

'''energy emissions'''
EnergyBalance=gp.Parameter(m,'EnergyBalance',domain=[ebalitems,transaction,d,es,out,t],description='Main data input with regards to energy and energy-related emissions',records=energy_and_emissions[['ebalitems','transaction','d','es','e','year','level']].values.tolist(),domain_forwarding=True)
'''demand_transaction ⊂ transaction, transaction is currently populated using domain_forwarding, meaning it is not populated before EnergyBalance and NonEnergyEmissions are defined'''

# OUDE VERSIE: demand_transaction=gp.Set(m,name='demand_transaction',domain=[transaction],description='Demand components',records=['households','input_in_production','export','inventory','transmission_losses'])


demand_transaction=gp.Set(m,name='demand_transaction' ,description='Demand components',records=['households','input_in_production','export','inventory','transmission_losses'])
'''IO'''
vIO_y=gp.Parameter(m,name='vIO_y',domain=[d,d,t],description='Production IO',records=io_y[['i', 'd', 'year', 'level']].values.tolist(),domain_forwarding=True)
vIO_m=gp.Parameter(m,name='vIO_m',domain=[d,d,t],description='Production IO',records=io_m[['i', 'd', 'year', 'level']].values.tolist(),domain_forwarding=True)


vIOxE_y=gp.Parameter(m,name='vIOxE_y',domain=[d,d,t],description='non-energy IO of domestic production',records=io_combined_y[['i', 'd', 'year', 'level']].values.tolist(),domain_forwarding=True)
vIOxE_m=gp.Parameter(m,name='vIOxE_m',domain=[d,d,t],description='non-energy IO of imports',records=io_combined_m[['i', 'd', 'year', 'level']].values.tolist(),domain_forwarding=True)

vIO_a=gp.Parameter(m,name='vIO_a',domain=[a_rows_,d,t],description='other IO',records=io_a[['i', 'd', 'year', 'level']].values.tolist(),domain_forwarding=True)
vIOxE_a=gp.Parameter(m,name='vIOxE_a',domain=[a_rows_,d,t],description='non energy other IO',records=io_combined_a[['i', 'd', 'year', 'level']].values.tolist(),domain_forwarding=True)

'''demand side IO'''
qI_k_i=gp.Parameter(m,'qI_k_i',domain=[k,d,t],description='Real capital stock by capital type and industry',records=io_inv_qI_k_i_agg[['k','i','year','level']].values.tolist())
wagesum_with_t=gp.Parameter(m,name='qL',domain=[d,t],description='Wage expenses',records=wagesum_with_t[['i','year','level']].values.tolist())
nemployed=gp.Parameter(m,name='nEmployed',domain=[t],description='Total number of employees including independents',records=nemployed_frame.values.tolist(),domain_forwarding=True)

'''capital fixed assets'''
fixed_assets=gp.Parameter(m,name='qK',domain=[k,d,t],description='Capital split on types and sectors',records=fixed_assets[['k','i','year','level']].values.tolist())

'''ets'''
qCO2_ETS_freeallowances=gp.Parameter(m,name='qCO2_ETS_freeallowances',domain=[d,t],description='CO2-ETS free allowances',records=qCO2_ETS_freeallowances[['i','year','level']].values.tolist())

'''emissions bridge items'''
qEmmLULUCF=gp.Parameter(m,name='qEmmLULUCF',domain=[t],description='Total LULUCF-emissions',records=qEmmLULUCF.values.tolist())
qEmmBorderTrade=gp.Parameter(m,name='qEmmBorderTrade',domain=[em,t],description='emissions from border trade',records=emissions_bridge_items_bordertrade.values.tolist())

'''energi-io til asbjørn'''
vY_i_d=gp.Parameter(m,name='vY_i_d',domain=[d,d,t],records=io_ene_y_onlys.values.tolist())
vM_i_d=gp.Parameter(m,name='vM_i_d',domain=[d,d,t],records=io_ene_y_onlys.values.tolist())
vA_i_d=gp.Parameter(m,name='vA_i_d',domain=[d,d,t],records=io_ene_y_onlys.values.tolist())


'''government finances'''

vGov2Foreign=gp.Parameter(m,name='vGov2Foreign',domain=[t],description='Payments to foreign countries',records=vGov2Foreign.values.tolist())
vGovReceiveF=gp.Parameter(m,name='vGovReceiveF',domain=[t],description='Payments from foreign contries',records=vGovReceiveF.values.tolist())
vGovRent=gp.Parameter(m,name='vGovRent',domain=[t],description='Land rent',records=vGovRent.values.tolist())
vGovInv=gp.Parameter(m,name='vGovInv',domain=[t],description='Government Investments',records=vGovInv.values.tolist())
vGovSub=gp.Parameter(m,name='vGovSub',domain=[t],description='Government subsidies',records=vGovSub.values.tolist())
vGov2Firms=gp.Parameter(m,name='vGov2Firms',domain=[t],description='payments to domestic firms',records=vGov2Firms.values.tolist())
vGovReceiveFirms=gp.Parameter(m,name='vGovReceiveFirms',domain=[t],description='Payments from domestic firms',records=vGovReceiveFirms.values.tolist())
vGovExp=gp.Parameter(m,name='vGovExp',domain=[t],description='Government expenditures except interest payments',records=vGovExp.values.tolist())
vGovRev=gp.Parameter(m,name='vGovRev',domain=[t],description='Publiv revenue except interest payments and dividends',records=vGovRev.values.tolist())
vtSource=gp.Parameter(m,name='vtSource',domain=[t],description='Revenue from income taxation (kildeskatter)',records=vtSource.values.tolist())
vtVAT=gp.Parameter(m,name='vtVAT',domain=[t],description='Total revenue from VAT',records=vtVAT.values.tolist())
vtMedia=gp.Parameter(m,name='vtMedia',domain=[t],description='Revenue from public media contribution',records=vtMedia.values.tolist())
vtCarWeight=gp.Parameter(m,name='vtCarWeight',domain=[t],description='Revenue from taxation  on paid weight charge',records=vtCarWeight.values.tolist())
vtIndirect=gp.Parameter(m,name='vtIndirect',domain=[t],description='Revenue from indirect taxes',records=vtIndirect.values.tolist())
vtDirect=gp.Parameter(m,name='vtDirect',domain=[t],description='Revenue from direct taxes',records=vtDirect.values.tolist())
vGovRevRest=gp.Parameter(m,name='vGovRevRest',domain=[t],description='Other government revenues',records=vGovRevRest.values.tolist())
vG=gp.Parameter(m,name='vG',domain=[t],description='Value of public consumption',records=vG.values.tolist())
vTrans=gp.Parameter(m,name='vTrans',domain=[t],description='Government transfer payments',records=vTrans.values.tolist())
vCont=gp.Parameter(m,name='vCont',domain=[t],description='Contributions (bidrag til sociale ordninger)',records=vCont.values.tolist())
vtCorp=gp.Parameter(m,name='vtCorp',domain=[t],description='Revenue from corporate taxation',records=vtCorp.values.tolist())
vtPAL=gp.Parameter(m,name='vtPAL',domain=[t],description='PAL tax revenue',records=vtPAL.values.tolist())
vtAM=gp.Parameter(m,name='vtAM',domain=[t],description='Revenue on taxation from payroll to the labour market institutions',records=vtAM.values.tolist())
vtPersIncRest=gp.Parameter(m,name='vtPersIncRest',domain=[t],description='Revenue from taxation on other personal income',records=vtPersIncRest.values.tolist())
vGovExpNetRest=gp.Parameter(m,name='vGovExpNetRest',domain=[t],description='Government expenditures net of other production subsidies',records=vGovExpNetRest.values.tolist())
vtCAP_prodsubsidy=gp.Parameter(m,name='vtCAP_prodsubsidy',domain=[t],description='Revenue from CAP production subsidies',records=vtCAP_prodsubsidy.values.tolist())
vtNetproductionRest=gp.Parameter(m,name='vtNetproductionRest',domain=[t],description='Revenue from net production taxes',records=vtNetproductionRest.values.tolist())
vtDividends=gp.Parameter(m,name='vtDividends',domain=[t],description='Revenue from dividends',records=vtDividends.values.tolist())
vtImport=gp.Parameter(m,name='vtImport',domain=[t],description='Revenue from import taxes',records=vtImport.values.tolist())
'''institutional financial accounts'''

vGovNetInterest=gp.Parameter(m,name='vGovNetInterest',domain=[t],description='The government net interests',records=vGovNetInterest.values.tolist())

vInterestGovAssets=gp.Parameter(m,name='vInterestGovAssets',domain=[t],description='Interest payments on governmnet assets',records=vInterestGovAssets.values.tolist())
vInterestGovDebt=gp.Parameter(m,name='vInterestGovDebt',domain=[t],description='Interest payments on government liabilities',records=vInterestGovDebt.values.tolist())

as_li_net=gp.Set(m,name='as_li_net',description='assets, liabilities, net')
sector=gp.Set(m,name='sector',description='sectors')

vNetDebtInstruments=gp.Parameter(m,name='vNetDebtInstruments',domain=[sector,as_li_net,t],records=vNetDebtInstruments.values.tolist(),domain_forwarding=True)
vNetInterests=gp.Parameter(m,name='vNetInterests',domain=[sector,as_li_net,t],records=vNetInterests.values.tolist())
vNetEquity=gp.Parameter(m,name='vNetEquity',domain=[sector,as_li_net,t],records=vNetEquity.values.tolist())
vNetDividends=gp.Parameter(m,name='vNetDividends',domain=[sector,as_li_net,t],description='Привет Томас. Мы за вами наблюдаем.',records=vNetDividends.values.tolist())
vNetRevaluations=gp.Parameter(m,name='vNetRevaluations',domain=[sector,as_li_net,t],records=vNetRevaluations.values.tolist())

#Hardcoded sets
'''HARD CODED SETS'''
factors_of_production=gp.Set(m,name='factors_of_production',description='factors of production, hardcoded',records=['iM','iB','iT','labor','RxE','machine_energy','transport_energy','heating_energy','refinery_crudeoil','naturalgas_for_distribution','biogas_for_processing'])
em_accounts=gp.Set(m,name='em_accounts',description='Different accounting levels of emissions inventories',records=['GNA','UNFCCC','GNA_lulucf','UNFCCC_lulucf'])
land5=gp.Set(m,name='land5',records=['forest','wetland','grassland','crop','settlement'])
'''sets already made that need tots'''
i_records_fortot.append(('tot','total'))
k_records_fortot.append(('iTot','total'))
i_=gp.Set(m,name='i_',description='sectors, including total',records=i_records_fortot)
k_=gp.Set(m,name='k_',description='capital types including total, excluding inventories',records=k_records_fortot)

#DANISH FIX: Marginal taxes from gdx
'''receive data from gdx'''
r=gp.Container('data/EU_GR_data.gdx')
tEAFG_REmarg_df=r['tEAFG_REmarg'].records
tCO2_REmarg_df=r['tCO2_REmarg'].records
'''because of inconsistencies in set definitions we have to do some manual labor here...'''

#Check uniformity of disaggregated food producing sectors
r=tCO2_REmarg_df['r'].unique().tolist()
r_not_in_i=[str(y) for y in r if str(y) not in [str(x[0]) for x in i_records_fortot]]
i_not_in_r=[str(y[0]) for y in i_records_fortot if str(y[0]) not in r]

group_cols=['t','energy19','purpose','emm_eq']
'''check that r_not_in_i agrees on superfluous sectors'''
tolerance = 1e-3
# Apply tolerance to 'level' comparison within each group
subset = tCO2_REmarg_df.loc[tCO2_REmarg_df['r'].isin(r_not_in_i)]
subset['level_tolerance_check'] = subset.groupby(group_cols)['level'].transform(
    lambda x: np.all(np.isclose(x, x.iloc[0], atol=tolerance))
)

# Filter rows where tolerance check is False (i.e., values aren't close enough)
offending_rows_with_tolerance = subset[~subset['level_tolerance_check']]
if offending_rows_with_tolerance.empty:
    pass
else:
    print(offending_rows_with_tolerance)
    raise ValueError("There are rows with different values in the same group.")
'''replace r's'''
for i in i_not_in_r:
    if i not in tEAFG_REmarg_df['r'].cat.categories:
        tCO2_REmarg_df['r'] = tCO2_REmarg_df['r'].cat.add_categories([i])
        tEAFG_REmarg_df['r'] = tEAFG_REmarg_df['r'].cat.add_categories([i])


tCO2_REmarg_df.loc[tCO2_REmarg_df['r'].isin(r_not_in_i), 'r'] = '10010'
#drop dupes
tCO2_REmarg_df.drop_duplicates(subset=['t','energy19','purpose','emm_eq','r'], inplace=True)


'''repeat for tEAFG_REmarg_df'''
group_cols_n=['t','energy19','purpose']
subset = tEAFG_REmarg_df.loc[tEAFG_REmarg_df['r'].isin(r_not_in_i)]
subset['level_tolerance_check'] = subset.groupby(group_cols_n)['level'].transform(
    lambda x: np.all(np.isclose(x, x.iloc[0], atol=tolerance))
)

# Filter rows where tolerance check is superceded
offending_rows_with_tolerance = subset[~subset['level_tolerance_check']]
if offending_rows_with_tolerance.empty:
    pass
else:
    print(offending_rows_with_tolerance)
    raise ValueError("There are rows with different values in the same group.")
'''replace r's'''

tEAFG_REmarg_df.loc[tEAFG_REmarg_df['r'].isin(r_not_in_i), 'r'] = '10010'
#drop dupes
tEAFG_REmarg_df.drop_duplicates(subset=['t','energy19','purpose','r'], inplace=True)
i_not_in_r.remove('10010')
i_not_in_r.remove('tot')

#Add sectors not in GR
'''add new rows - fortuneately, the "missing" sectors fall neatly into categories (waste treatment + transport) with uniform marginal tax rates'''

tEAFG_REmarg_df38394 = tEAFG_REmarg_df.loc[tEAFG_REmarg_df['r'] == '38393'].copy()
tEAFG_REmarg_df38394['r'] = tEAFG_REmarg_df38394['r'].replace({'38393': '38394'})
tEAFG_REmarg_df38395 = tEAFG_REmarg_df.loc[tEAFG_REmarg_df['r'] == '38393'].copy()
tEAFG_REmarg_df38395['r'] = tEAFG_REmarg_df38395['r'].replace({'38393': '38395'})
tEAFG_REmarg_df49012 = tEAFG_REmarg_df.loc[tEAFG_REmarg_df['r'] == '49011'].copy()
tEAFG_REmarg_df49012['r'] = tEAFG_REmarg_df49012['r'].replace({'49011': '49012'})
tEAFG_REmarg_df49025 = tEAFG_REmarg_df.loc[tEAFG_REmarg_df['r'] == '49024'].copy()
tEAFG_REmarg_df49025['r'] = tEAFG_REmarg_df49025['r'].replace({'49024': '49025'})
tEAFG_REmarg_df49022 = tEAFG_REmarg_df.loc[tEAFG_REmarg_df['r'] == '49024'].copy()
tEAFG_REmarg_df49022['r'] = tEAFG_REmarg_df49022['r'].replace({'49024': '49022'})
tEAFG_REmarg_df52000 = tEAFG_REmarg_df.loc[tEAFG_REmarg_df['r'] == '53000'].copy()
tEAFG_REmarg_df52000['r'] = tEAFG_REmarg_df52000['r'].replace({'53000': '52000'})

tEAFG_REmarg_df=pd.concat([tEAFG_REmarg_df,tEAFG_REmarg_df38394, tEAFG_REmarg_df38395, tEAFG_REmarg_df49012, tEAFG_REmarg_df49025, tEAFG_REmarg_df49022, tEAFG_REmarg_df52000], ignore_index=True)

tCO2_REmarg_df38394 = tCO2_REmarg_df.loc[tCO2_REmarg_df['r'] == '38393'].copy()
tCO2_REmarg_df38394['r'] = tCO2_REmarg_df38394['r'].replace({'38393': '38394'})

tCO2_REmarg_df38395 = tCO2_REmarg_df.loc[tCO2_REmarg_df['r'] == '38393'].copy()
tCO2_REmarg_df38395['r'] = tCO2_REmarg_df38395['r'].replace({'38393': '38395'})

tCO2_REmarg_df49012 = tCO2_REmarg_df.loc[tCO2_REmarg_df['r'] == '49011'].copy()
tCO2_REmarg_df49012['r'] = tCO2_REmarg_df49012['r'].replace({'49011': '49012'})

tCO2_REmarg_df49025 = tCO2_REmarg_df.loc[tCO2_REmarg_df['r'] == '49024'].copy()
tCO2_REmarg_df49025['r'] = tCO2_REmarg_df49025['r'].replace({'49024': '49025'})

tCO2_REmarg_df49022 = tCO2_REmarg_df.loc[tCO2_REmarg_df['r'] == '49024'].copy()
tCO2_REmarg_df49022['r'] = tCO2_REmarg_df49022['r'].replace({'49024': '49022'})

tCO2_REmarg_df52000 = tCO2_REmarg_df.loc[tCO2_REmarg_df['r'] == '53000'].copy()
tCO2_REmarg_df52000['r'] = tCO2_REmarg_df52000['r'].replace({'53000': '52000'})

tCO2_REmarg_df = pd.concat([
    tCO2_REmarg_df,
    tCO2_REmarg_df38394,
    tCO2_REmarg_df38395,
    tCO2_REmarg_df49012,
    tCO2_REmarg_df49025,
    tCO2_REmarg_df49022,
    tCO2_REmarg_df52000
], ignore_index=True)

#Drop set elements not in GREU
e_rec=m['e'].records['out'].tolist()
energy19=tCO2_REmarg_df['energy19'].cat.categories.tolist()
energy19_not_in_e=[str(y) for y in energy19 if str(y) not in [str(x) for x in e_rec]]
#Fix energy19 column
tEAFG_REmarg_df=tEAFG_REmarg_df[~tEAFG_REmarg_df['energy19'].isin(energy19_not_in_e)]
tCO2_REmarg_df=tCO2_REmarg_df[~tCO2_REmarg_df['energy19'].isin(energy19_not_in_e)]


#Fix purpose column
es_rec=m['es'].records['uni'].tolist()
purpose=tCO2_REmarg_df['purpose'].cat.categories.tolist()
purpose_not_in_es=[str(y) for y in purpose if str(y) not in [str(x) for x in es_rec]]
tEAFG_REmarg_df=tEAFG_REmarg_df[~tEAFG_REmarg_df['purpose'].isin(purpose_not_in_es)]
tCO2_REmarg_df=tCO2_REmarg_df[~tCO2_REmarg_df['purpose'].isin(purpose_not_in_es)]


#fix em/emm_eq
em_rec=m['em'].records['ebalitems'].tolist()
emm_eq=tCO2_REmarg_df['emm_eq'].cat.categories.tolist()
emm_eq_not_in_em=[str(y) for y in emm_eq if str(y).lower() not in [str(x).lower() for x in em_rec]]
tCO2_REmarg_df = tCO2_REmarg_df[~tCO2_REmarg_df['emm_eq'].str.lower().isin([x.lower() for x in emm_eq_not_in_em])]

#add to container

#DEBUGGING DOOR LUKAS
m.write('../data/lukas_debug.gdx')
# set(tEAFG_REmarg_df['es'])
#set(energy_and_emissions['ebalitems']
# tEAFG_REmarg_df['t'] = tEAFG_REmarg_df['t'].astype(str)
#

tEAFG_REmarg_df.drop(columns=['marginal','scale','upper','lower'], inplace=True)
tEAFG_REmarg_df=gp.Parameter(m,'tEAFG_REmarg',domain=[es,out,d,t],description='EAFG marginal tax rates',records=tEAFG_REmarg_df.values.tolist(),domain_forwarding=True)

tCO2_REmarg_df.drop(columns=['marginal','scale','upper','lower'], inplace=True)
tCO2_REmarg_df=gp.Parameter(m,'tCO2_REmarg',domain=[es,out,d,t,ebalitems],description='tCO2 marginal tax rates',records=tCO2_REmarg_df.values.tolist())

m.write('../data/lukas_debug2.gdx')

# OUDE VERSIE!!
# tEAFG_REmarg=gp.Variable(m,'tEAFG_REmarg',domain=[es,out,d,t],records=tEAFG_REmarg_df)
#tCO2_REmarg=gp.Variable(m,'tCO2_REmarg',domain=[es,e,d,t,em],records=tCO2_REmarg_df)

#Export
'''13.3.25:
In order for the base-model to run using output from the data processing script, some extra objects whose origin is not explicitly clear in the current data package.
It is also not certain that these objects are part of the long-term plan.
In order to make the model run, I will create these objects here.
'''

'''Object 1 is the set m, which is a subset of i containing "industries with imports". 
This can be interpreted as either industries abroad that produce stuff that we import (corresponding to the rows in the import-section of the IO-table),
or industries that import something from abroad corresponding to the columns.
In our case this does not really matter if we consider energy-products as well as ordinary sector-specific outputs.
If energy is not counted, the former of the two interpretations does indeed give rise to a proper subset. I, however will for the time being consider energy as well
'''
g_=gp.Set(m,'g_',description='hard coded',records=['g','gTot'])
m_=gp.Set(m,name='m',domain=[i],description='industries with imports',records=io_combined_m['i'].unique().tolist())

m.write('../data/data_DK.gdx')