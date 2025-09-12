import dreamtools as dt
import pandas as pd

s=dt.Gdx('calibration.gdx')

qEpj=s.d1qEpj
pEpj=s.d1pEpj

qEpj

mgd_ingen_pris = []

for i in qEpj:
    if i[:-1] not in pEpj.droplevel(-1):
        mgd_ingen_pris.append(i[:-1])
mgd_ingen_pris_t_omitted=set(mgd_ingen_pris)
mgd_ingen_pris_t_omitted = pd.MultiIndex.from_tuples(mgd_ingen_pris_t_omitted, names=qEpj.names[:-1])
send = mgd_ingen_pris_t_omitted.to_frame(index=False)

send.to_excel(excel_writer='mgd_ingen_pris_t_udeladt.xlsx')
