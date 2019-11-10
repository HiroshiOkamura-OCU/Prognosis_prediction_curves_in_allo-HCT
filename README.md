# Personalized prognosis prediction curves in allo-HCT

"Prognosis_prediction_curves_in_alloHCT.R" is the source code to develop an interactive web application for plotting personalized prognosis prediction curves in allogeneic hematopoietic cell transplantation (allo-HCT).
"PatientData.csv" is patients' data, but only column names are inputted into it now.

If each institute or society input its past patient data into "PatientData.csv" and run "Prognosis_prediction_curves_in_alloHCT.R", the web application using the predictive model developed by its data will be available.

The column of "PatientData.csv"
Prognostic predictors
Age: recipent's age at allo-HCT
PS: performance status at allo-HCT
rDRI: refined Disease Risk Index
HCT.CI: Hematopoietic Cell Transplantation Comorbidity Index
Condi.intensity: the intensity of conditioning
DonorSource: donor source
HLA8Allele.disp: HLA disparity by DNA typing for HLA-A, HLA-B, HLA-C, and HLA-DR.
TimeAlloTx: the number of allo-HCT

Outcome
FollowUpDays.EFS: observed days until event (relapse or death) occurs or 3 years after allo-HCT is passed
EFS.0live.1rel.2Death.3year: observed status at 3 years after allo-HCT (censoring 0, relapse 1, death 2)
Event.EFS.3year: observed status at 3 years after allo-HCT (censoring 0, relapse 1, death 1)
FollowUpDays.OS: observed days until event (death) occurs or 3 years after allo-HCT is passed
Event.OS.3year: observed status at 3 years after allo-HCT (censoring 0, death 1)
