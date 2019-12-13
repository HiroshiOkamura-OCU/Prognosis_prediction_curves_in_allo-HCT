library(shiny)
library(randomForestSRC)

FILEPATH = "PatientData.csv"
Pati.df = read.csv(FILEPATH)
Pati.df$rDRI <- factor(Pati.df$rDRI,levels=c("low","int","high","veryhigh"),ordered = FALSE) 
Pati.df$rDRI <- as.integer(Pati.df$rDRI)
Pati.df$Fu.month.OS <- Pati.df$FollowUpDays.OS/30
Pati.df$Fu.month.EFS <- Pati.df$FollowUpDays.EFS/30

modelRFSRC.OS <- rfsrc(Surv(Fu.month.OS, Event.OS.1year) ~ 
                  TimeAlloTx
                    +Age
                    +PS
                    +Condi.intensity
                    +HLA8Allele.disp
                    +DonorSource
                    +HCT.CI
                    +rDRI,
                    data = Pati.df,na.action = "na.impute",seed=-2, ntree = 500)

modelRFSRC.EFS <- rfsrc(Surv(Fu.month.EFS, Event.EFS.1year) ~ 
                      TimeAlloTx
                    +Age
                    +PS
                    +Condi.intensity
                    +HLA8Allele.disp
                    +DonorSource
                    +HCT.CI
                    +rDRI,
                    data = Pati.df,na.action = "na.impute",seed=-2, ntree = 500)

modelRFSRC.Rel <- rfsrc(Surv(Fu.month.EFS, EFS.0live.1rel.2death.1year) ~ 
                          TimeAlloTx
                        +Age
                        +PS
                        +Condi.intensity
                        +HLA8Allele.disp
                        +DonorSource
                        +HCT.CI
                        +rDRI,
                        data = Pati.df,na.action = "na.impute",seed=-2, ntree = 500)

modelRFSRC.NRM <- rfsrc(Surv(Fu.month.EFS, EFS.0live.1rel.2death.1year) ~ 
                         TimeAlloTx
                       +Age
                       +PS
                       +Condi.intensity
                       +HLA8Allele.disp
                       +DonorSource
                       +HCT.CI
                       +rDRI,
                       data = Pati.df,na.action = "na.impute",seed=-2, ntree = 500)

# server
server = function(input, output) {
  patient1 = observeEvent(input$go,{
    patient1=data.frame(TimeAlloTx=input$TimeAlloTx,
                        Age=input$Age,
                        PS=input$PS,
                        Condi.intensity=input$Condi.intensity,
                        HLA8Allele.disp=input$HLA8Allele.disp,
                        DonorSource=input$DonorSource,
                        rDRI=as.numeric(input$rDRI),
                        HCT.CI =input$HCT.CI)
    output$distPlot <- renderPlot({
      if(input$theme == "0"){ # plot Predicted OS
        RFSRC.Pred.OS <- predict(modelRFSRC.OS, patient1)
        matplot(RFSRC.Pred.OS$time.interest, t(RFSRC.Pred.OS$survival),
                xlab = "Months after transplantation", ylab = "Overall Survival",
                xlim=c(0,12), ylim=c(0,1),
                main = "Predicted OS by Random Survival Forest",cex.main = 1.6,
                cex.lab=1.5,cex.axis=1.5,lwd=2,col="midnightblue",
                type = "l", lty = 1)
        } 
      else if(input$theme == "1"){ # plot Predicted PFS
          RFSRC.Pred.EFS <- predict(modelRFSRC.EFS, patient1)
          matplot(RFSRC.Pred.EFS$time.interest, t(RFSRC.Pred.EFS$survival),
                  xlab = "Months after transplantation", ylab = "Progression Free Survival",
                  xlim=c(0,12), ylim=c(0,1),
                  main = "Predicted PFS by Random Survival Forest",cex.main = 1.6,
                  cex.lab=1.5,cex.axis=1.5,lwd=2,col="midnightblue",
                  type = "l", lty = 1)
      }
      else if(input$theme == "2"){ # plot Predicted Relapse/Progression
        RFSRC.Pred.Rel <- predict(modelRFSRC.Rel, patient1)
        cif <- apply(RFSRC.Pred.Rel$cif, c(2, 3), mean, na.rm = TRUE)
        matplot(RFSRC.Pred.Rel$time.interest, cif[,1],
                xlab = "Months after transplantation", ylab = "Relapse/Progression",
                xlim=c(0,12), ylim=c(0,1),
                main = "Predicted Relapse/Progression by Random Survival Forest",cex.main = 1.6,
                cex.lab=1.5,cex.axis=1.5,lwd=2,col="midnightblue",
                type = "l", lty = 1)
      }
      else if(input$theme == "3"){ # plot Predicted NRM
        RFSRC.Pred.NRM <- predict(modelRFSRC.NRM, patient1)
        cif <- apply(RFSRC.Pred.NRM$cif, c(2, 3), mean, na.rm = TRUE)
        matplot(RFSRC.Pred.NRM$time.interest, cif[,2],
                xlab = "Months after transplantation", ylab = "Non Relapse Mortality",
                xlim=c(0,12), ylim=c(0,1),
                main = "Predicted NRM by Random Survival Forest",cex.main = 1.6,
                cex.lab=1.5,cex.axis=1.5,lwd=2,col="midnightblue",
                type = "l", lty = 1)
      }
      
    })
    
    output$OS_text <- renderUI({
      # These functions return predictive OS and EFS rate of Patient:x at fu_month after allo-HCT
      search_predict_OSrate_fu_rfsrc <- function(x,fu_month){
        y <- which( predict(modelRFSRC.OS, x)$time.interest <= fu_month)
        return (predict(modelRFSRC.OS, x)$survival[,max(y)])
      }
      search_predict_EFSrate_fu_rfsrc <- function(x,fu_month){
        y <- which( predict(modelRFSRC.EFS, x)$time.interest <= fu_month)
        return (predict(modelRFSRC.EFS, x)$survival[,max(y)])
      }
      search_predict_Relapserate_fu_rfsrc <- function(x,fu_month){
        RFSRC.Pred.Rel <- predict(modelRFSRC.Rel, x)
        y <- which( RFSRC.Pred.Rel$time.interest <= fu_month)
        cif <- apply(RFSRC.Pred.Rel$cif, c(2, 3), mean, na.rm = TRUE)
        return (cif[,1][max(y)])
      }
      search_predict_NRMrate_fu_rfsrc <- function(x,fu_month){
        RFSRC.Pred.NRM <- predict(modelRFSRC.NRM, x)
        y <- which( RFSRC.Pred.NRM$time.interest <= fu_month)
        cif <- apply(RFSRC.Pred.NRM$cif, c(2, 3), mean, na.rm = TRUE)
        return (cif[,2][max(y)])
      }
      if(input$theme == "0"){ # display Predicted OS rate at 3years
        pred_1yOS = search_predict_OSrate_fu_rfsrc(patient1,12)
        c_index <- (1-modelRFSRC.OS$err.rate[length(modelRFSRC.OS$err.rate)])
        div(
          p(
            class = "plane-paragraph",
            paste("Predicted 1-year OS rate is ", round(pred_1yOS*100, digits = 1) , " %.")
          ),
          p(
            class = "plane-paragraph",
            paste("Harrell's c-index calculated using out-of-bag(OOB) data is", round(c_index, digits = 2), ".")
          )
        )
      }
      else if(input$theme == "1"){ # display Predicted PFS rate at 3years
        pred_1yEFS = search_predict_EFSrate_fu_rfsrc(patient1,12)
        c_index <- (1-modelRFSRC.EFS$err.rate[length(modelRFSRC.EFS$err.rate)])
        div(
          p(
            class = "plane-paragraph",
            paste("Predicted 1-year PFS rate is ", round(pred_1yEFS*100, digits = 1) , " %")
          ),
          p(
            class = "plane-paragraph",
            paste("Harrell's c-index calculated using out-of-bag(OOB) data is", round(c_index, digits = 2), ".")
          )
        )
      }
      else if(input$theme == "2"){ # display Predicted Relapse/Progression rate at 3years
        pred_1yRelapse = search_predict_Relapserate_fu_rfsrc(patient1,12)
        c_index <- (1-modelRFSRC.Rel$err.rate[[nrow(modelRFSRC.Rel$err.rate),'event.1']])
        print(c_index)
        div(
          p(
            class = "plane-paragraph",
            paste("Predicted 1-year Relapse/Progression rate is ", round(pred_1yRelapse*100, digits = 1) , " %")
          ),
          p(
            class = "plane-paragraph",
            paste("Harrell's c-index calculated using out-of-bag(OOB) data is", round(c_index, digits = 2), ".")
          )
        )
      }
      else if(input$theme == "3"){ # display Predicted NRM rate at 3years
        pred_1yNRM = search_predict_NRMrate_fu_rfsrc(patient1,12)
        c_index <- (1-modelRFSRC.NRM$err.rate[[nrow(modelRFSRC.NRM$err.rate),'event.2']])
        div(
          p(
            class = "plane-paragraph",
            paste("Predicted 1-year NRM rate is ", round(pred_1yNRM*100, digits = 1) , " %")
          ),
          p(
            class = "plane-paragraph",
            paste("Harrell's c-index calculated using out-of-bag(OOB) data is", round(c_index, digits = 2), ".")
          )
        )
      }
    })
  })
}  
