library(randomForestSRC)
library(survival)
library(tidyverse)
library(timeROC)
library(cvTools)

# Set f/u period which you inted to observe (months)
Outcome.Month <-12

FILEPATH = 'PatientData.csv'
Pati.df.entire = read.csv(FILEPATH)

# conditioning of data
Pati.df.entire$rDRI <- factor(Pati.df.entire$rDRI,levels=c("low","int","high","veryhigh"),ordered = FALSE) 
Pati.df.entire$rDRI<-as.integer(Pati.df.entire$rDRI)
Pati.df.entire$OSmonth <- Pati.df.entire$FollowUpDays.OS/30
Pati.df.entire$EFSmonth <- Pati.df.entire$FollowUpDays.EFS/30

# Uniform f/u period
Pati.df.entire$OS.month.1year <- Pati.df.entire$OSmonth
Pati.df.entire$OS.month.1year[Pati.df.entire$OS.month.1year>Outcome.Month] <- Outcome.Month+0.001
Pati.df.entire$EFS.month.1year <- Pati.df.entire$EFSmonth
Pati.df.entire$EFS.month.1year[Pati.df.entire$EFS.month.1year>Outcome.Month] <- Outcome.Month+0.001

selectcolum <- c("Pt.ID",
                 "TimeAlloTx",
                 "Age",
                 "PS",
                 "Condi.intensity",
                 "HLA8Allele.disp",
                 "DonorSource",
                 "HCT.CI",
                 "rDRI",
                 "OS.month.1year",
                 "EFS.month.1year",
                 "Event.OS.1year",
                 "Event.EFS.1year",
                 "EFS.0live.1rel.2death.1year")
Pati.df.entire <- Pati.df.entire[,selectcolum]

# The function to create dataframe (nrow * ncol)
createEmptyDf = function( nrow, ncol, colnames = c() ){
  data.frame( matrix( vector(), nrow, ncol, dimnames = list( c(), colnames ) ) )
}
# Split entire cohort into traning (70%) and test cohort (30%) time-sequentially 
train_c <- seq(1, nrow(Pati.df.entire)*0.7, 1)
Pati.df.train <- Pati.df.entire[train_c,]
Pati.df.test <-  Pati.df.entire[-train_c,]

# Gridsearch hyperparameter (mtry) of RSF (mtry) in traning cohort
AUC.per.mtry.tROC = createEmptyDf(8, 5, colnames = c("mtry", "AUC_OS","AUC_EFS","AUC_Rel","AUC_NRM"))
for (nmtry in 1:8){
    print(paste("mtry: ", nmtry))

    # Create subtrain and validation cohort for 5-fold cross validation
    k<-5 # the number of fold
    n <- dim(Pati.df.train)[1]
    folds <- cvFolds(n, K = k) # randomly 5 fold splitting
    indices <- as.data.frame(list(fold = folds$which)) %>%
    mutate(idx = row_number())
      
    # Create dataframe for Cross Validation AUC value
    AUC.tROC.for.CV = createEmptyDf(k, 4, colnames = c( "AUC_OS", "AUC_EFS","AUC_Rel","AUC_NRM" ))
    for (l in 1:k) {
      
      train <- Pati.df.train[(indices %>% filter(fold != l))$idx,]
      validation <- Pati.df.train[(indices %>% filter(fold == l))$idx,]
      validation <- na.omit(validation)
      
      modelRFSRC.OS <- rfsrc(Surv(OS.month.1year, Event.OS.1year) ~ 
                            TimeAlloTx
                          +Age
                          +PS
                          +Condi.intensity
                          +HLA8Allele.disp
                          +DonorSource
                          +HCT.CI
                          +rDRI,
                          data = train,seed = -2, ntree = 500, mtry =nmtry)
      modelRFSRC.EFS <- rfsrc(Surv(EFS.month.1year, Event.EFS.1year) ~ 
                            TimeAlloTx
                          +Age
                          +PS
                          +Condi.intensity
                          +HLA8Allele.disp
                          +DonorSource
                          +HCT.CI
                          +rDRI,
                          data = train,seed = -2, ntree = 500, mtry =nmtry)
      modelRFSRC.CI <- rfsrc(Surv(EFS.month.1year, EFS.0live.1rel.2death.1year) ~ 
                            TimeAlloTx
                          +Age
                          +PS
                          +Condi.intensity
                          +HLA8Allele.disp
                          +DonorSource
                          +HCT.CI
                          +rDRI,
                          data = train,seed = -2 ,ntree = 500, mtry =nmtry)
      
      # The function to returin predicted OS rate at fu.month after allo-HCT per one patient(x)
      predict_OS_rfsrc <- function(x,fu.month){
        y <- which( predict(modelRFSRC.OS, x)$time.interest <= fu.month)
        return (predict(modelRFSRC.OS, x)$survival[,max(y)])
      }
      # The function to returin predicted EFS rate at fu.month after allo-HCT per one patient(x)  
      predict_EFS_rfsrc <- function(x,fu.month){
        y <- which( predict(modelRFSRC.EFS, x)$time.interest <= fu.month)
        return (predict(modelRFSRC.EFS, x)$survival[,max(y)])
      }
      # The function to returin predicted Relapse rate at fu.month after allo-HCT per one patient(x)  
      predict_Relapse_rfsrc <- function(x,fu.month){
        RFSRC.Pred.CI <- predict(modelRFSRC.CI, x)
        y <- which( RFSRC.Pred.CI$time.interest <= fu.month)
        cif <- apply(RFSRC.Pred.CI$cif, c(2, 3), mean, na.rm = TRUE)
        return (cif[,1][max(y)])
      }
      # The function to returin predicted NRM rate at fu.month after allo-HCT per one patient(x) 
      predict_NRM_rfsrc <- function(x,fu.month){
        RFSRC.Pred.CI <- predict(modelRFSRC.CI, x)
        y <- which( RFSRC.Pred.CI$time.interest <= fu.month)
        cif <- apply(RFSRC.Pred.CI$cif, c(2, 3), mean, na.rm = TRUE)
        return (cif[,2][max(y)])
      }
    
      # Create dataframe to input predicted rate in validation patients for every 1 year outcome
      rfsrc.predict = createEmptyDf(nrow(validation), 5, colnames = c( "Pt.ID", "rfsrc.predict.OS" , "rfsrc.predict.EFS", "rfsrc.predict.Rel", "rfsrc.predict.NRM") )
      # Input Patient ID and prediction rate for 1 year outcome
      for( i in 1:nrow(validation) ){
        rfsrc.predict[ i, "Pt.ID" ] = validation[i,"Pt.ID"]
        rfsrc.predict[ i, "rfsrc.predict.OS" ] = predict_OS_rfsrc(validation[i,],Outcome.Month)
        rfsrc.predict[ i, "rfsrc.predict.EFS" ] = predict_EFS_rfsrc(validation[i,],Outcome.Month)
        rfsrc.predict[ i, "rfsrc.predict.Rel" ] = predict_Relapse_rfsrc(validation[i,],Outcome.Month)
        rfsrc.predict[ i, "rfsrc.predict.NRM" ] = predict_NRM_rfsrc(validation[i,],Outcome.Month)
      }

      #　Merge validation and every prediction rate by Patient ID
      validation <- merge(validation, rfsrc.predict, by="Pt.ID", all=T)
      rm(rfsrc.predict)
      
      # Calculate AUC for 1 year OS by timeROC
      rfsrc.tROC.OS <-timeROC(T=validation$OS.month.1year,
                                  delta=validation$Event.OS.1year,marker=(1-validation$rfsrc.predict.OS),
                                  cause=1,weighting="marginal",
                                  times=c(Outcome.Month),
                                  iid=FALSE)
      # Calculate AUC for 1 year EFS by timeROC
      rfsrc.tROC.EFS <-timeROC(T=validation$EFS.month.1year,
                               delta=validation$Event.EFS.1year,marker=(1-validation$rfsrc.predict.EFS),
                               cause=1,weighting="marginal",
                               times=c(Outcome.Month),
                               iid=FALSE)
      # Calculate AUC for 1 year Relapse by timeROC
      rfsrc.tROC.Relapse <-timeROC(T=validation$EFS.month.1year,
                                      delta=validation$EFS.0live.1rel.2death.1year,marker=(validation$rfsrc.predict.Rel),
                                      cause=1,weighting="marginal",
                                      times=c(Outcome.Month),
                                      iid=FALSE)
      # Calculate AUC for 1 year NRM by timeROC
      rfsrc.tROC.NRM <-timeROC(T=validation$EFS.month.1year,
                                  delta=validation$EFS.0live.1rel.2death.1year,marker=(validation$rfsrc.predict.NRM),
                                  cause=2,weighting="marginal",
                                  times=c(Outcome.Month),
                                  iid=FALSE)

      AUC.tROC.for.CV[ l, "AUC_OS" ] = round(rfsrc.tROC.OS$AUC[[2]],3)
      AUC.tROC.for.CV[ l, "AUC_EFS" ] = round(rfsrc.tROC.EFS$AUC[[2]],3)
      AUC.tROC.for.CV[ l, "AUC_Rel" ] = round(rfsrc.tROC.Relapse$AUC_1[[2]],3)
      AUC.tROC.for.CV[ l, "AUC_NRM" ] = round(rfsrc.tROC.NRM$AUC_2[[2]],3)

    }
    
    print("AUCs calculated by timeROC")
    AUC.tROC.for.CV = na.omit(AUC.tROC.for.CV)
    print(mean(AUC.tROC.for.CV[,"AUC_OS"]))
    print(mean(AUC.tROC.for.CV[,"AUC_EFS"]))
    print(mean(AUC.tROC.for.CV[,"AUC_Rel"]))
    print(mean(AUC.tROC.for.CV[,"AUC_NRM"]))

    AUC.per.mtry.tROC[nmtry, "mtry"] = nmtry
    AUC.per.mtry.tROC[nmtry, "AUC_OS"] = mean(AUC.tROC.for.CV[,"AUC_OS"])
    AUC.per.mtry.tROC[nmtry, "AUC_EFS"] = mean(AUC.tROC.for.CV[,"AUC_EFS"])
    AUC.per.mtry.tROC[nmtry, "AUC_Rel"] = mean(AUC.tROC.for.CV[,"AUC_Rel"])
    AUC.per.mtry.tROC[nmtry, "AUC_NRM"] = mean(AUC.tROC.for.CV[,"AUC_NRM"])
  
}

# Choose optimal mtry for every 1 year outcome
optim.mtry.OS <- which.max(AUC.per.mtry.tROC$AUC_OS)
optim.mtry.EFS <- which.max(AUC.per.mtry.tROC$AUC_EFS)
optim.mtry.Rel <- which.max(AUC.per.mtry.tROC$AUC_Rel)
optim.mtry.NRM <- which.max(AUC.per.mtry.tROC$AUC_NRM)

print(paste("Optimal mtry for 1-year OS is ", optim.mtry.OS , " ."))
print(paste("Optimal mtry for 1-year EFS is ", optim.mtry.EFS , " ."))
print(paste("Optimal mtry for 1-year Relapse is ", optim.mtry.Rel , " ."))
print(paste("Optimal mtry for 1-year NRM is ", optim.mtry.NRM , " ."))

print("AUCs per mtry in training cohort:")
print(AUC.per.mtry.tROC)

# Culculate AUCs per a month of RSF, Cox, DRI, and HCT-CI from 3 to 12 months after allo-HCT
test.OS.AUC.per.month <- createEmptyDf(Outcome.Month, 5, colnames = c("month", "RSF_AUC","COX_AUC","DRI_AUC","HCTCI_AUC"))
test.EFS.AUC.per.month <- createEmptyDf(Outcome.Month, 5, colnames = c("month", "RSF_AUC","COX_AUC","DRI_AUC","HCTCI_AUC"))
test.Rel.AUC.per.month <- createEmptyDf(Outcome.Month, 4, colnames = c("month", "RSF_AUC","DRI_AUC","HCTCI_AUC"))
test.NRM.AUC.per.month <- createEmptyDf(Outcome.Month, 4, colnames = c("month", "RSF_AUC","DRI_AUC","HCTCI_AUC"))
for (permonth in 3:Outcome.Month){
  
  # Create event per a month in ?.event.per.month column
  for( i in 1:nrow(Pati.df.test) ){
    if(Pati.df.test[i,'OS.month.1year'] < permonth && Pati.df.test[i,'Event.OS.1year'] ==1){
      Pati.df.test[i,'OS.event.per.month'] = 1
    }else{
      Pati.df.test[i,'OS.event.per.month'] = 0
    }
    
    if(Pati.df.test[i,'EFS.month.1year'] < permonth && Pati.df.test[i,'Event.EFS.1year'] ==1){
      Pati.df.test[i,'EFS.event.per.month'] = 1
    }else{
      Pati.df.test[i,'EFS.event.per.month'] = 0
    }
    
    if(Pati.df.test[i,'EFS.month.1year'] < permonth && Pati.df.test[i,'EFS.0live.1rel.2death.1year'] ==1){
      Pati.df.test[i,'Rel.NRM.event.per.month'] = 1
    }
    else if(Pati.df.test[i,'EFS.month.1year'] < permonth && Pati.df.test[i,'EFS.0live.1rel.2death.1year'] ==2){
      Pati.df.test[i,'Rel.NRM.event.per.month'] = 2
    }
    else{
      Pati.df.test[i,'Rel.NRM.event.per.month'] = 0
    }
  }
  
  # develop RSF model with optimal mtry using traning cohort
  modelRFSRC.train.OS <- rfsrc(Surv(OS.month.1year, Event.OS.1year) ~ 
                        TimeAlloTx
                      +Age
                      +PS
                      +Condi.intensity
                      +HLA8Allele.disp
                      +DonorSource
                      +HCT.CI
                      +rDRI,
                      data = Pati.df.train, seed = -2, ntree = 500, mtry = optim.mtry.OS)
  
  modelRFSRC.train.EFS <- rfsrc(Surv(EFS.month.1year, Event.EFS.1year) ~ 
                              TimeAlloTx
                            +Age
                            +PS
                            +Condi.intensity
                            +HLA8Allele.disp
                            +DonorSource
                            +HCT.CI
                            +rDRI,
                            data = Pati.df.train, seed = -2, ntree = 500, mtry = optim.mtry.EFS)
  
  modelRFSRC.train.Rel <- rfsrc(Surv(EFS.month.1year, EFS.0live.1rel.2death.1year) ~ 
                                  TimeAlloTx
                                +Age
                                +PS
                                +Condi.intensity
                                +HLA8Allele.disp
                                +DonorSource
                                +HCT.CI
                                +rDRI,
                                data = Pati.df.train, seed = -2, ntree = 500, mtry = optim.mtry.Rel)
  
  modelRFSRC.train.NRM <- rfsrc(Surv(EFS.month.1year, EFS.0live.1rel.2death.1year) ~ 
                                  TimeAlloTx
                                +Age
                                +PS
                                +Condi.intensity
                                +HLA8Allele.disp
                                +DonorSource
                                +HCT.CI
                                +rDRI,
                                data = Pati.df.train, seed = -2, ntree = 500, mtry = optim.mtry.NRM)
  
  # The function to returin predicted OS rate at fu.month after allo-HCT per one patient(x) 
  predict_OS_by_train_model_rfsrc <- function(x,fu.month){
    y <- which( predict(modelRFSRC.train.OS, x)$time.interest <= fu.month)
    return (predict(modelRFSRC.train.OS, x)$survival[,max(y)])
  }
  # The function to returin predicted EFS rate at fu.month after allo-HCT per one patient(x)  
  predict_EFS_by_train_model_rfsrc <- function(x,fu.month){
    y <- which( predict(modelRFSRC.train.EFS, x)$time.interest <= fu.month)
    return (predict(modelRFSRC.train.EFS, x)$survival[,max(y)])
  }
  # The function to returin predicted Relapse rate at fu.month after allo-HCT per one patient(x)
  predict_Relapse_by_train_model_rfsrc <- function(x,fu.month){
    RFSRC.Pred.Rel <- predict(modelRFSRC.train.Rel, x)
    y <- which( RFSRC.Pred.Rel$time.interest <= fu.month)
    cif <- apply(RFSRC.Pred.Rel$cif, c(2, 3), mean, na.rm = TRUE)
    return (cif[,1][max(y)])
  }
  # The function to returin predicted NRM rate at fu.month after allo-HCT per one patient(x)
  predict_NRM_by_train_model_rfsrc <- function(x,fu.month){
    RFSRC.Pred.NRM <- predict(modelRFSRC.train.NRM, x)
    y <- which( RFSRC.Pred.NRM$time.interest <= fu.month)
    cif <- apply(RFSRC.Pred.NRM$cif, c(2, 3), mean, na.rm = TRUE)
    return (cif[,2][max(y)])
  }
  
  #　Create df which consits of Pt.ID, predicted OS rate, and predicted EFS rate by RSF
  rfsrc.p.month.test = createEmptyDf(nrow(Pati.df.test), 5, colnames = c( "Pt.ID", "rfsrc.p.month.OS" , "rfsrc.p.month.EFS", "rfsrc.p.month.Rel", "rfsrc.p.month.NRM") )
  for( i in 1:nrow(Pati.df.test) ){
    rfsrc.p.month.test[ i, "Pt.ID" ] = Pati.df.test[i,"Pt.ID"]
    rfsrc.p.month.test[ i, "rfsrc.p.month.OS" ] = predict_OS_by_train_model_rfsrc(Pati.df.test[i,],permonth)
    rfsrc.p.month.test[ i, "rfsrc.p.month.EFS" ] = predict_EFS_by_train_model_rfsrc(Pati.df.test[i,],permonth)
    rfsrc.p.month.test[ i, "rfsrc.p.month.Rel" ] = predict_Relapse_by_train_model_rfsrc(Pati.df.test[i,],permonth)
    rfsrc.p.month.test[ i, "rfsrc.p.month.NRM" ] = predict_NRM_by_train_model_rfsrc(Pati.df.test[i,],permonth)
  }
  #　merge Pati.df.test and rfsrc.p.month.test by Pt.ID
  Pati.df.test <- merge(Pati.df.test, rfsrc.p.month.test, by="Pt.ID", all=T)
  
  # Culculate AUC for OS in test cohort using timeROC
  rfsrc.tROC.OS.for.test <-timeROC(T=Pati.df.test$OS.month.1year,
                           delta=Pati.df.test$OS.event.per.month,marker=(1-Pati.df.test$rfsrc.p.month.OS),
                           cause=1,weighting="marginal",
                           times=c(permonth),
                           iid=TRUE)
  plot(rfsrc.tROC.OS.for.test,time=permonth)
  confint(rfsrc.tROC.OS.for.test)
  
  DRI.tROC.OS.for.test <-timeROC(T=Pati.df.test$OS.month.1year,
                           delta=Pati.df.test$OS.event.per.month,marker=Pati.df.test$rDRI,
                           cause=1,weighting="marginal",
                           times=c(permonth),
                           iid=TRUE)
  plot(DRI.tROC.OS.for.test,time=permonth)
  confint(DRI.tROC.OS.for.test)
  
  HCTCI.tROC.OS.for.test <-timeROC(T=Pati.df.test$OS.month.1year,
                         delta=Pati.df.test$OS.event.per.month,marker=Pati.df.test$HCT.CI,
                         cause=1,weighting="marginal",
                         times=c(permonth),
                         iid=TRUE)
  plot(HCTCI.tROC.OS.for.test,time=permonth)
  confint(HCTCI.tROC.OS.for.test)
  
  # Culculate AUC for EFS in test cohort using timeROC
  rfsrc.tROC.EFS.for.test <-timeROC(T=Pati.df.test$EFS.month.1year,
                           delta=Pati.df.test$EFS.event.per.month,marker=(1-Pati.df.test$rfsrc.p.month.EFS),
                           cause=1,weighting="marginal",
                           times=c(permonth),
                           iid=TRUE)
  plot(rfsrc.tROC.EFS.for.test,time=permonth)
  confint(rfsrc.tROC.EFS.for.test)
  
  DRI.tROC.EFS.for.test <-timeROC(T=Pati.df.test$EFS.month.1year,
                         delta=Pati.df.test$EFS.event.per.month,marker=Pati.df.test$rDRI,
                         cause=1,weighting="marginal",
                         times=c(permonth),
                         iid=TRUE)
  plot(DRI.tROC.EFS.for.test,time=permonth)
  confint(DRI.tROC.EFS.for.test)
  
  HCTCI.tROC.EFS.for.test <-timeROC(T=Pati.df.test$EFS.month.1year,
                           delta=Pati.df.test$EFS.event.per.month,marker=Pati.df.test$HCT.CI,
                           cause=1,weighting="marginal",
                           times=c(permonth),
                           iid=TRUE)
  plot(HCTCI.tROC.EFS.for.test,time=permonth)
  confint(HCTCI.tROC.EFS.for.test)
  
  
  # Culculate AUC for Relapse in test cohort using timeROC
  rfsrc.tROC.Rel.for.test <-timeROC(T=Pati.df.test$EFS.month.1year,
                                  delta=Pati.df.test$Rel.NRM.event.per.month,marker=(Pati.df.test$rfsrc.p.month.Rel),
                                  cause=1,weighting="marginal",
                                  times=c(permonth),
                                  iid=TRUE)
  plot(rfsrc.tROC.Rel.for.test,time=permonth)
  confint(rfsrc.tROC.Rel.for.test)
  
  DRI.tROC.Rel.for.test <-timeROC(T=Pati.df.test$EFS.month.1year,
                         delta=Pati.df.test$Rel.NRM.event.per.month,marker=Pati.df.test$rDRI,
                         cause=1,weighting="marginal",
                         times=c(permonth),
                         iid=TRUE)
  plot(DRI.tROC.Rel.for.test,time=permonth)
  confint(DRI.tROC.Rel.for.test)
  
  HCTCI.tROC.Rel.for.test <-timeROC(T=Pati.df.test$EFS.month.1year,
                           delta=Pati.df.test$Rel.NRM.event.per.month,marker=Pati.df.test$HCT.CI,
                           cause=1,weighting="marginal",
                           times=c(permonth),
                           iid=TRUE)
  plot(HCTCI.tROC.Rel.for.test,time=permonth)
  confint(HCTCI.tROC.Rel.for.test)
  
  
  # Culculate AUC for NRM in test cohort using timeROC
  rfsrc.tROC.NRM.for.test <-timeROC(T=Pati.df.test$EFS.month.1year,
                              delta=Pati.df.test$Rel.NRM.event.per.month,marker=(Pati.df.test$rfsrc.p.month.NRM),
                              cause=2,weighting="marginal",
                              times=c(permonth),
                              iid=TRUE)
  plot(rfsrc.tROC.NRM.for.test,time=permonth)
  confint(rfsrc.tROC.NRM.for.test)
  
  DRI.tROC.NRM.for.test <-timeROC(T=Pati.df.test$EFS.month.1year,
                             delta=Pati.df.test$Rel.NRM.event.per.month,marker=Pati.df.test$rDRI,
                             cause=2,weighting="marginal",
                             times=c(permonth),
                             iid=TRUE)
  plot(DRI.tROC.NRM.for.test,time=permonth)
  confint(DRI.tROC.NRM.for.test)
  
  HCTCI.tROC.NRM.for.test <-timeROC(T=Pati.df.test$EFS.month.1year,
                               delta=Pati.df.test$Rel.NRM.event.per.month,marker=Pati.df.test$HCT.CI,
                               cause=2,weighting="marginal",
                               times=c(permonth),
                               iid=TRUE)
  plot(HCTCI.tROC.NRM.for.test,time=permonth)
  confint(HCTCI.tROC.NRM.for.test)
  
  # develop COX model for 1-year OS and EFS using traning cohort
  modelCOX.train.OS <- coxph(Surv(OS.month.1year, Event.OS.1year) ~ 
                            TimeAlloTx
                          +Age
                          +PS
                          +Condi.intensity
                          +HLA8Allele.disp
                          +DonorSource
                          +HCT.CI
                          +rDRI,
                          data = Pati.df.train)
  
  modelCOX.train.EFS <- coxph(Surv(EFS.month.1year, Event.EFS.1year) ~ 
                                TimeAlloTx
                              +Age
                              +PS
                              +Condi.intensity
                              +HLA8Allele.disp
                              +DonorSource
                              +HCT.CI
                              +rDRI,
                              data = Pati.df.train)
  
  # The function to returin predicted OS rate at fu.month after allo-HCT per one patient(x) using Cox
  predict_OS_by_train_model_COX <- function(x,fu.month){
    y <- which( summary(survfit(modelCOX.train.OS,newdata=x))$time <= fu.month)
    return (summary(survfit(modelCOX.train.OS,newdata=x))$surv[max(y)])
  }
  # The function to returin predicted EFS rate at fu.month after allo-HCT per one patient(x) using Cox
  predict_EFS_by_train_model_COX <- function(x,fu.month){
    y <- which( summary(survfit(modelCOX.train.EFS,newdata=x))$time <= fu.month)
    return (summary(survfit(modelCOX.train.EFS,newdata=x))$surv[max(y)])
  }
  
  #　Create df which consits of Pt.ID, predicted OS rate, and predicted EFS rate by Cox
  Cox.p.month = createEmptyDf(nrow(Pati.df.test), 3, colnames = c( "Pt.ID", "Cox.p.month.OS","Cox.p.month.EFS") )
  for( i in 1:nrow(Pati.df.test) ){
    Cox.p.month[ i, "Pt.ID" ] = Pati.df.test[i,"Pt.ID"]
    Cox.p.month[ i, "Cox.p.month.OS" ] = predict_OS_by_train_model_COX(Pati.df.test[i,],permonth)
    Cox.p.month[ i, "Cox.p.month.EFS" ] = predict_EFS_by_train_model_COX(Pati.df.test[i,],permonth)
  }
  #　merge Pati.df.test and Cox.p.month by Pt.ID
  Pati.df.test <- merge(Pati.df.test, Cox.p.month, by="Pt.ID", all=T)
  
  COX.tROC.OS.for.test <-timeROC(T=Pati.df.test$OS.month.1year,
                         delta=Pati.df.test$OS.event.per.month,marker=(1-Pati.df.test$Cox.p.month.OS),
                         cause=1,weighting="marginal",
                         times=c(permonth),
                         iid=TRUE)
  plot(COX.tROC.OS.for.test,time=permonth)
  confint(COX.tROC.OS.for.test)
  
  COX.tROC.EFS.for.test <-timeROC(T=Pati.df.test$EFS.month.1year,
                         delta=Pati.df.test$EFS.event.per.month,marker=(1-Pati.df.test$Cox.p.month.EFS),
                         cause=1,weighting="marginal",
                         times=c(permonth),
                         iid=TRUE)
  plot(COX.tROC.EFS.for.test,time=permonth)
  confint(COX.tROC.EFS.for.test)
  
  test.OS.AUC.per.month[permonth,"month"] <- permonth
  test.OS.AUC.per.month[permonth,"RSF_AUC"] <- round(rfsrc.tROC.OS.for.test$AUC[[2]],3)
  test.OS.AUC.per.month[permonth,"COX_AUC"] <- round(COX.tROC.OS.for.test$AUC[[2]],3)
  test.OS.AUC.per.month[permonth,"DRI_AUC"] <- round(DRI.tROC.OS.for.test$AUC[[2]],3)
  test.OS.AUC.per.month[permonth,"HCTCI_AUC"] <- round(HCTCI.tROC.OS.for.test$AUC[[2]],3)

  test.EFS.AUC.per.month[permonth,"month"] <- permonth
  test.EFS.AUC.per.month[permonth,"RSF_AUC"] <- round(rfsrc.tROC.EFS.for.test$AUC[[2]],3)
  test.EFS.AUC.per.month[permonth,"COX_AUC"] <- round(COX.tROC.EFS.for.test$AUC[[2]],3)
  test.EFS.AUC.per.month[permonth,"DRI_AUC"] <- round(DRI.tROC.EFS.for.test$AUC[[2]],3)
  test.EFS.AUC.per.month[permonth,"HCTCI_AUC"] <- round(HCTCI.tROC.EFS.for.test$AUC[[2]],3)
  
  test.Rel.AUC.per.month[permonth,"month"] <- permonth
  test.Rel.AUC.per.month[permonth,"RSF_AUC"] <- round(rfsrc.tROC.Rel.for.test$AUC_1[[2]],3)
  test.Rel.AUC.per.month[permonth,"DRI_AUC"] <- round(DRI.tROC.Rel.for.test$AUC_1[[2]],3)
  test.Rel.AUC.per.month[permonth,"HCTCI_AUC"] <- round(HCTCI.tROC.Rel.for.test$AUC_1[[2]],3)
  
  test.NRM.AUC.per.month[permonth,"month"] <- permonth
  test.NRM.AUC.per.month[permonth,"RSF_AUC"] <- round(rfsrc.tROC.NRM.for.test$AUC_2[[2]],3)
  test.NRM.AUC.per.month[permonth,"DRI_AUC"] <- round(DRI.tROC.NRM.for.test$AUC_2[[2]],3)
  test.NRM.AUC.per.month[permonth,"HCTCI_AUC"] <- round(HCTCI.tROC.NRM.for.test$AUC_2[[2]],3)
  
  Pati.df.test$rfsrc.p.month.OS <- NULL
  Pati.df.test$rfsrc.p.month.EFS <- NULL
  Pati.df.test$rfsrc.p.month.Rel <- NULL
  Pati.df.test$rfsrc.p.month.NRM <- NULL
  Pati.df.test$Cox.p.month.OS <- NULL
  Pati.df.test$Cox.p.month.EFS <- NULL
}

print("AUCs per a month for OS in test cohort: ")
print(test.OS.AUC.per.month)

print("AUCs per a month for PFS in test cohort: ")
print(test.EFS.AUC.per.month)

print("AUCs per a month for Relapse in test cohort: ")
print(test.Rel.AUC.per.month)

print("AUCs per a month for NRM in test cohort: ")
print(test.NRM.AUC.per.month)

# plot per a montht
matplot(test.OS.AUC.per.month$month,select(test.OS.AUC.per.month, 2, 4, 5, 3),type="l",lwd=2.5,lty=1,pch=1:4,cex.lab = 1.5,
        cex.axis = 1.2,ylim=c(0.3,1),panel.first = grid(NA, NULL, lty = 2, col = "#E9DECA"),xlab="Months after transplantation",ylab="AUCs")
legend("topleft",c("RSF","DRI-R","HCT-CI","Cox PH"), bty="n",lwd=2.5,cex=1.2,ncol=2,col=1:4,lty=1)

matplot(test.EFS.AUC.per.month$month,select(test.EFS.AUC.per.month, 2, 4, 5, 3),type="l",lwd=2.5,lty=1,pch=1:4,cex.lab = 1.5,
        cex.axis = 1.2,ylim=c(0.3,1),panel.first = grid(NA, NULL, lty = 2, col = "#E9DECA"),xlab="Months after transplantation",ylab="AUCs")
legend("topleft",c("RSF","DRI-R","HCT-CI","Cox PH"), bty="n",lwd=2.5,cex=1.2,ncol=2,col=1:4,lty=1)

matplot(test.Rel.AUC.per.month$month,select(test.Rel.AUC.per.month, 2, 3, 4),type="l",lwd=2.5,lty=1,pch=1:3,col=1:3,cex.lab = 1.5,
        cex.axis = 1.2,ylim=c(0.3,1),panel.first = grid(NA, NULL, lty = 2, col = "#E9DECA"),xlab="Months after transplantation",ylab="AUCs")
legend("topleft",c("RSF","DRI-R","HCT-CI"), bty="n",lwd=2.5,cex=1.2,ncol=2,col=1:3,lty=1)

matplot(test.NRM.AUC.per.month$month,select(test.NRM.AUC.per.month, 2, 3, 4),type="l",lwd=2.5,lty=1,pch=1:3,col=1:3,cex.lab = 1.5,
        cex.axis = 1.2,ylim=c(0.3,1),panel.first = grid(NA, NULL, lty = 2, col = "#E9DECA"),xlab="Months after transplantation",ylab="AUCs")
legend("topleft",c("RSF","DRI-R","HCT-CI"), bty="n",lwd=2.5,cex=1.2,ncol=2,col=1:3,lty=1)

