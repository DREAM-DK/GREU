

Set MapBunkering[em,es,e,d] "Map bunkering emissions to energy types";
  MapBunkering(em,es,'Bunkering of Danish operated trucks on foreign territory',d)=yes;
  MapBunkering(em,es,'Bunkering of Danish operated vessels on foreign territory',d)=yes;
  MapBunkering(em,es,'Bunkering of Danish operated planes on foreign territory',d)=yes;

Set MapInternationalAviation[em,es,e,d] "Map international aviation emissions to energy types";
  MapInternationalAviation(em,'transport','jet petroleum','51009')=yes;

Set MapOtherDifferencesShips[em,es,e,d] "Map other differences in ships emissions to energy types";
  MapOtherDifferencesShips(em,'transport','diesel for transport','49509')=yes;


