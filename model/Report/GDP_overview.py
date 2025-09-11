GDP_table = pd.DataFrame({
    'Quantity change (%)': {
        'Total GDP': (s.qGDP[2040]/b.qGDP[2040]-1)*100,
        'Private consumption': (s.qC[2040]/b.qC[2040]-1)*100,
        'Investments': (s.qI[2040]/b.qI[2040]-1)*100,
        'Government consumption': (s.qG[2040]/b.qG[2040]-1)*100,
        'Exports': (s.qX[2040]/b.qX[2040]-1)*100,
        'Imports': (s.qM[2040]/b.qM[2040]-1)*100,
    },
    'Price change (%)': {
        'Total GDP': (s.pGDP[2040]/b.pGDP[2040] - 1)*100,
        'Private consumption': (s.pC[2040]/b.pC[2040] - 1)*100,
        'Investments': (s.pI[2040]/b.pI[2040] - 1)*100,
        'Government consumption': (s.pG[2040]/b.pG[2040] - 1)*100,
        'Exports': (s.pX[2040]/b.pX[2040] - 1)*100,
        'Imports': (s.pM[2040]/b.pM[2040] - 1)*100,
    }
})
print("\nGDP in 2040:")
print(GDP_table)



