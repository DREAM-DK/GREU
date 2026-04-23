'''typical workflow'''
import os
os.chdir(r'C:\greu-debug\GREU\model_gamsPy')

#gamspy is imported and a container is defined, the container stores our GAMS objects
import gamspy as gp
import pandas as pd
container=gp.Container()
#retrieve data from excel
some_parameter=pd.read_excel(r'data\some_parameter.xlsx',header=0)

#do some manipulation because the people who made the spreadsheets forgot something, i.e. by applying a dictionary....
dict_color={'bluuu':'blue'}
some_parameter.replace({'adjectives':dict_color},inplace=True)
#sets are defined
adjectives_set=gp.Set(container,name='adjectives',description='mostly colors really..',records=some_parameter['adjectives'])
nouns_set=gp.Set(container,name='nouns',description='Things immediately preceeded by an article',records=some_parameter['nouns'])
letters_set=gp.Set(container,name='letters',description='symbols which represent a sound that can be strung together to form words',records=['A','B','C'])
#parameter is defined
some_parameter=gp.Parameter(container,name='some_parameter',domain=[letters_set,nouns_set,adjectives_set],description='idk',records=some_parameter.values.tolist())
#export

'''how to debug'''

#I want to define another parameter on the same sets

other_parameter=pd.read_excel(r'data\other_parameter.xlsx',header=0)
other_parameter
#Since sets are already defined I try to define my parameter, turning on the command below will fail.
#other_parameter=gp.Parameter(container,domain=[letters_set,adjectives_set],description='idk2',records=other_parameter.values.tolist())

#####To debug:

#write a .gdx (or if you feel pythonically inclined you can perform this check in python)
container.write('debug_session.gdx')

#view the non-level columns of the dataframe - these correspond to sets
print(other_parameter)

#Compare these columns with the corresponding sets. In this example there are two problems which are by far the most common

#1: I have a NaN-entry, GAMS cannot handle these
other_parameter.dropna(inplace=True)
other_parameter_casea=other_parameter.copy()
other_parameter_caseb=other_parameter.copy()
#2: In the domain of our parameter is something that is not included in the corresponding set,
# in this case D is not in letters. There are now two options:

#2a: D should not be in the set letters, we then drop it from the dataframe like so:
other_parameter_casea = other_parameter_casea[other_parameter_casea['letters'] != 'D']

other_parameter_casea=gp.Parameter(container,name='other_parameter_casea',domain=[letters_set,adjectives_set],description='idk2a',records=other_parameter_casea)

#2b: D should be in the set letters, we then go back to look at how we defined letters (line below is copy-pasted)

letters_set=gp.Set(container,name='letters',description='symbols which represent a sound that can be strung together to form words',records=['A','B','C'])

#Observe that letters is hardcoded, we have tried to avoid this whenever possible, but sometimes it was the best we could do :'(
#Simply just include D in the definition and you're good - note that if letters has a superset (i.e. symbols), we should make sure that
#D is also included in symbols using the same recipe. Here, it is pretty simple to make sure D is indeed in the set letters
letters_set=gp.Set(container,name='letters',description='symbols which represent a sound that can be strung together to form words',records=['A','B','C','D'])
other_parameter_caseb=gp.Parameter(container,name='other_parameter_caseb',domain=[letters_set,adjectives_set],description='idk2',records=other_parameter_caseb)

container.write('trial_complete.gdx')
#Extra note, most sets are defined directly from metadata.xlsx, so please make sure this is consistent with your datasheets :)