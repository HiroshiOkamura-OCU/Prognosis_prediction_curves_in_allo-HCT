# Personalized prognosis prediction curves in allo-HCT

<p>"Prognosis_prediction_curves_in_alloHCT.R" is the source code to develop an interactive web application for plotting personalized prognosis prediction curves in allogeneic hematopoietic cell transplantation (allo-HCT).<br/> 
"PatientData.csv" is patients' data, but only column names are inputted into it now.</p>

<p>If each institute or society input its past patient data into "PatientData.csv" and run "Prognosis_prediction_curves_in_alloHCT.R", the web application using the predictive model developed by its data will be available.</p>

<p>The column of "PatientData.csv"<br/> 
Prognostic predictors<br/> 
Age: recipent's age at allo-HCT<br/> 
PS: performance status at allo-HCT<br/> 
rDRI: refined Disease Risk Index<br/>  
HCT.CI: Hematopoietic Cell Transplantation Comorbidity Index<br/> 
Condi.intensity: the intensity of conditioning<br/> 
DonorSource: donor source<br/> 
HLA8Allele.disp: HLA disparity by DNA typing for HLA-A, HLA-B, HLA-C, and HLA-DR<br/> 
TimeAlloTx: the number of allo-HCT</p> 

<p>Outcome<br/> 
FollowUpDays.EFS: observed days until event (relapse or death) occurs or 3 years after allo-HCT is passed<br/> 
EFS.0live.1rel.2Death.3year: observed status at 3 years after allo-HCT (censoring 0, relapse 1, death 2)<br/> 
Event.EFS.3year: observed status at 3 years after allo-HCT (censoring 0, relapse 1, death 1)<br/> 
FollowUpDays.OS: observed days until event (death) occurs or 3 years after allo-HCT is passed<br/> 
Event.OS.3year: observed status at 3 years after allo-HCT (censoring 0, death 1)</p> 
