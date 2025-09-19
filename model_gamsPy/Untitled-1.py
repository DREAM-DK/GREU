--- Job ? Start 09/19/25 14:21:04 49.5.0 b32bf9f5 LEX-LEG x86 64bit/Linux
*** 
*** GAMS Base Module 49.5.0 b32bf9f5 Apr 29, 2025          LEG x86 64bit/Linux    
*** 
*** GAMS Development Corporation
*** support@gams.com, www.gams.com
*** 
*** GAMS Release     : 49.5.0 b32bf9f5 LEX-LEG x86 64bit/Linux
*** Release Date     : Apr 29, 2025         
*** To use this release, you must have a valid license file for
*** this platform with maintenance expiration date later than
*** Feb 15, 2025
*** System Directory : /services/tools/gams/49.5.0/
***
*** License          : /dpdream/home/pinkar/.local/share/GAMS/gamslice.txt
*** Machine Based License                          G240618|0002CO-LNX
*** DREAM, Danish Rational Economic Agents Model                     
*** DC16922-01CO                                                     
*** License Admin: Martin K. Bonde, mkb@dreammodel.dk                
***
*** Licensed platform                             : x86 64bit Linux
*** The installed license is valid.
*** Maintenance expiration date (GAMS base module): Jul 13, 2025
*** Note: For solvers, other expiration dates may apply.
*** Status: Normal completion
--- Job ? Stop 09/19/25 14:21:04 elapsed 0:00:00.008

---------------------------------------------------------------------------
GamspyException                           Traceback (most recent call last)
Cell In[20], line 8
      6 import gamspy as gp
      7 m=gp.Container()
----> 8 t=gp.Set(m)

File ~/.local/lib/python3.12/site-packages/gamspy/_symbols/set.py:679, in Set.__init__(self, container, name, domain, is_singleton, records, domain_forwarding, description, uels_on_axes, is_miro_input, is_miro_output)
    677 else:
    678     self.modified = False
--> 679     self.container._synch_with_gams(
    680         gams_to_gamspy=self._is_miro_input
    681     )
    683 container._options.miro_protect = previous_state

File ~/.local/lib/python3.12/site-packages/gamspy/_container.py:566, in Container._synch_with_gams(self, relaxed_domain_mapping, gams_to_gamspy)
    560 def _synch_with_gams(
    561     self,
    562     relaxed_domain_mapping: bool = False,
    563     gams_to_gamspy: bool = False,
    564 ) -> DataFrame | None:
    565     runner = backend_factory(self, self._options, output=self.output)
--> 566     summary = runner.run(relaxed_domain_mapping, gams_to_gamspy)
    568     if self._options and self._options.seed is not None:
    569         # Required for correct seeding. Seed can only be set in the first run.
...
**** Current license content:
     GAMS_Demo,_for_EULA_and_demo_limitations_see___G250131/0001CB-GEN
     https://www.gams.com/latest/docs/UG%5FLicense.html_______________
     1496579900_______________________________________________________
     0801370405_______________________________________________________
Output is truncated. View as a scrollable element or open in a text editor. Adjust cell output settings...