GDP_table = pd.DataFrame({
    'Quantity change (%)': {
        'Total GDP': (s.qGDP[2030]/b.qGDP[2030]-1)*100,
        'Private consumption': (s.qC[2030]/b.qC[2030]-1)*100,
        'Investments': (s.qI[2030]/b.qI[2030]-1)*100,
        'Government consumption': (s.qG[2030]/b.qG[2030]-1)*100,
        'Exports': (s.qX[2030]/b.qX[2030]-1)*100,
        'Imports': (s.qM[2030]/b.qM[2030]-1)*100,
    },
    'Price change (%)': {
        'Total GDP': (s.pGDP[2030]/b.pGDP[2030] - 1)*100,
        'Private consumption': (s.pC[2030]/b.pC[2030] - 1)*100,
        'Investments': (s.pI[2030]/b.pI[2030] - 1)*100,
        'Government consumption': (s.pG[2030]/b.pG[2030] - 1)*100,
        'Exports': (s.pX[2030]/b.pX[2030] - 1)*100,
        'Imports': (s.pM[2030]/b.pM[2030] - 1)*100,
    }
})
print("\nGDP in 2030:")
print(GDP_table)



