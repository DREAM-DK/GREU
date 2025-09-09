

Set MapBunkering[em,es,e,d] "Map bunkering emissions to energy types";
  MapBunkering(em,es,'Bunkering of Danish operated trucks on foreign territory',d)=yes;
  MapBunkering(em,es,'Bunkering of Danish operated vessels on foreign territory',d)=yes;
  MapBunkering(em,es,'Bunkering of Danish operated planes on foreign territory',d)=yes;

Set MapInternationalAviation[em,es,e,d] "Map international aviation emissions to energy types";
  MapInternationalAviation(em,'transport','jet petroleum','51009')=yes;

Set MapOtherDifferencesShips[em,es,e,d] "Map other differences in ships emissions to energy types";
  MapOtherDifferencesShips(em,'transport','diesel for transport','49509')=yes;

# Set NotThatOne[em,es,e,d] "";

#   # NotThatOne[em,es,e,'0600a'] = yes;
#   # NotThatOne[em,es,e,'19000'] = yes;
#   # NotThatOne[em,es,e,'01011'] = yes;
#   # NotThatOne[em,es,e,'01012'] = yes;
#   # NotThatOne[em,es,e,'23001'] = yes;
 
#   # NotThatOne[em,es,e,'35002'] = yes;
  
#   # NotThatOne[em,es,e,'49024'] = yes;
#   NotThatOne[em,es,e,'35011'] = yes;
  
#   # NotThatOne[em,es,e,'36000'] = yes;
#   # NotThatOne[em,es,e,'37000'] = yes;
  
#   # NotThatOne[em,es,e,'38392'] = yes;
#   # NotThatOne[em,es,e,'38392'] = yes;
#   # NotThatOne[em,es,e,'38393'] = yes;
#   # NotThatOne[em,es,e,'38394'] = yes;
#   # NotThatOne[em,es,e,'38395'] = yes;

Set NotThatOne[i] "";
  NotThatOne['35011'] = yes;




  # power_and_utility .('0600a','19000','35011','35002','36000','37000','38391','38392','38393','38394','38395')
