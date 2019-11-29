# R/Shiny application for plotting personalized prognosis prediction curves in allo-HCT

<p>"Prognosis_prediction_curves_in_alloHCT.R" is the source code to develop an interactive web application for plotting personalized prognosis prediction curves for 1 year after allogeneic hematopoietic cell transplantation (allo-HCT). Each transplant center could develop a web application using an in-house prognosis prediction model by imputting its past patient data into "PatientData.csv".
"PatientData.csv" consists of patient data as a training cohort, but only column names and three patients' example data are inputted into it now.</p>

# Usage
<p>If each transplant institute or society input its past patient data into "PatientData.csv" and run "Prognosis_prediction_curves_in_alloHCT.R", the web application using the predictive model developed by its data will be available. Therefore, each transplant institute or society can plot the personalized prognosis prediction curves about a new allo-HCT candidate derived from its past patient data .</p>

#####To install and run:
- Run the following commands in your R terminal/ environment.
  
```
install.packages(c('shiny','randomForestSRC'))
```

- Clone this repository, and set your R working directory to the cloned repo's parent directory.
- In R, run `runApp('Prognosis_prediction_curves_in_allo-HCT')`  to launch the app.</li>

#####About "PatientData.csv":
<p>The column of "PatientData.csv"<br/> 
<li>Prognostic predictors;</li>
-Age: recipent's age at allo-HCT<br/> 
  integer; range: 16-70<br/>  
-PS: performance status at allo-HCT<br/> 
  integer; range: 0-3<br/> 
-rDRI: refined Disease Risk Index<br/>  
  factor; "low", "int", "high", or "veryhigh"<br/>  
-HCT.CI: Hematopoietic Cell Transplantation Comorbidity Index<br/> 
  integer; range: 0-10<br/> 
-Condi.intensity: the intensity of conditioning<br/> 
  factor; "MAC" or "RIC"<br/> 
-DonorSource: donor source<br/> 
  factor; "rBM", "rPB", "uBM", "CB", or "HaploPB"<br/> 
-HLA8Allele.disp: HLA disparity by DNA typing for HLA-A, HLA-B, HLA-C, and HLA-DR<br/> 
  factor; "matched" or "mismatched"<br/> 
-TimeAlloTx: the number of allo-HCT<br/>
  integer; range: 1-3</p>

<li>Outcome;</li>
-FollowUpDays.EFS: observed days until event (relapse or death) occurs or 1 year passes after allo-HCT <br/> 
  integer<br/> 
-EFS.0live.1rel.2death.1year: observed status at 1 year after allo-HCT <br/> 
  integer; censoring: 0, relapse: 1, death: 2<br/> 
-Event.EFS.1year: observed status at 1 year after allo-HCT<br/> 
  integer; censoring: 0, relapse: 1, death: 1<br/>
-FollowUpDays.OS: observed days until event (death) occurs or 1 year after allo-HCT is passed<br/>
  integer<br/> 
-Event.OS.1year: observed status at 1 year after allo-HCT (censoring 0, death 1)<br/>
  integer; censoring: 0, death: 1
 </p> 

<p>There are no "uPB (unrelated peripheral blood)" and "HaploBM (haploidentical bone marrow)" as donor source in this code, because we have few uPB and HaploBM.
If you want to include them in this web application, you will have to modify this source code ("Prognosis_prediction_curves_in_alloHCT.R").
</p>

<p>Abbreviation;<br/>
  int: intermediate, MAC: myeloablative conditioning, RIC: reduced intensity conditioning, rBM: related bone marrow, rPB: related peripheral blood, uBM: unrelated bone marrow, CB: cord blood, HaploPB: haploidentical peripheral blood, HLA: human leukocyte antigen
</p>

# Requirements
This application requires the following to run:
<p>
  <li>R version: 3.5.1</li>
</p>
<p> package version
  <li>shiny: ver. 1.3.2</li>
  <li>randomForestSRC: ver. 2.8.0</li>
</p>

# License
This application is licensed under the // license<br/> 
© 2019, Hiroshi Okamura
