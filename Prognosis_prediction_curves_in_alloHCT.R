library(shiny)
library(randomForestSRC)

FILEPATH = "Tramp_OS_EFS_for_app.csv"
Pati.df = read.csv(FILEPATH)
Pati.df$rDRI <- factor(Pati.df$rDRI,levels=c("low","int","high","veryhigh"),ordered = FALSE) 
Pati.df$rDRI <- as.integer(Pati.df$rDRI)
Pati.df$Fu.month.OS <- Pati.df$FollowUpDays.OS/30
Pati.df$Fu.month.EFS <- Pati.df$FollowUpDays.EFS/30

modelRFSRC.OS <- rfsrc(Surv(Fu.month.OS, Event.OS.3year) ~ 
                  TimeAlloTx
                    +Age
                    +PS
                    +Condi.intensity
                    +HLA8Allele.disp
                    +DonorSource
                    +HCT.CI
                    +rDRI,
                    data = Pati.df,na.action = "na.impute",seed=-2, ntree = 500)

modelRFSRC.EFS <- rfsrc(Surv(Fu.month.EFS, Event.EFS.3year) ~ 
                      TimeAlloTx
                    +Age
                    +PS
                    +Condi.intensity
                    +HLA8Allele.disp
                    +DonorSource
                    +HCT.CI
                    +rDRI,
                    data = Pati.df,na.action = "na.impute",seed=-2, ntree = 500)

modelRFSRC.CI <- rfsrc(Surv(Fu.month.EFS, EFS.0live.1rel.2Death.3year) ~ 
                          TimeAlloTx
                        +Age
                        +PS
                        +Condi.intensity
                        +HLA8Allele.disp
                        +DonorSource
                        +HCT.CI
                        +rDRI,
                        data = Pati.df,na.action = "na.impute",seed=-2, ntree = 500)

# ui
ui = fluidPage(
  fluidRow(
    column(5,
           br(),
           tags$head(tags$style(HTML('#theme+ div>.selectize-input { font-size: 25px; 
                                     line-height: 25px;} .selectize-dropdown { font-size: 25px; 
                                     line-height: 25px; }'))),
           selectInput("theme",NULL,
                       choices = list("Overall Survival" = 0,
                                      "Progression Free Survival" = 1,
                                      "Relapse/Progression" = 2,
                                      "Non Relapse Mortarity" = 3),
                       width = "100%"),
           br(),
           tags$head(
             tags$style(HTML('#go{background-color:darkcyan;font-size:18px;color: white}'))),
           actionButton("go","Prediction")),
    column(7,offset = 7)
  ),
  fluidRow(
    column(2,style = "background-color:ghostwhite",
           sliderInput("Age",
                       h3("Age"),
                       min = 16,
                       max = 70,
                       value = 30),
           
           selectInput("rDRI",
                       h3("Refined DRI"),
                       choices = list("low"=1,"int"=2,"high"=3,"veryhigh"=4),
                       selected = "low"),
           
           sliderInput("PS",
                       h3("PS"),
                       min = 0,
                       max = 3,
                       value = 0),
           
           sliderInput("HCT.CI",
                        h3("HCT-CI"),
                        min = 0,
                        max = 10,
                        value = 0)),

    column(2,style = "background-color:ghostwhite",
           selectInput("Condi.intensity",
                       h3("Conditioning Intensity"),
                       choices = list("MAC","RIC")
           ),
           
           selectInput("HLA8Allele.disp",
                       h3("HLA 8 allele compatibility"),
                       choices = list("matched","mismatched")
           ),
           
           selectInput("DonorSource",
                       h3("Donor Source"),
                       choices = list("rBM","rPB","uBM","CB","HaploPB")
           ),
           
           sliderInput("TimeAlloTx",
                       h3("The number of Transplantation"),
                       min = 1,
                       max = 3,
                       value = 1)),
  column(8,plotOutput("distPlot")),
  column(8,htmlOutput("OS_text"))
  )
)

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
                xlim=c(0,36), ylim=c(0,1),
                main = "Predicted OS by Random Survival Forest",cex.main = 1.6,
                cex.lab=1.5,cex.axis=1.5,lwd=2,col="midnightblue",
                type = "l", lty = 1)
        } 
      else if(input$theme == "1"){ # plot Predicted PFS
          RFSRC.Pred.EFS <- predict(modelRFSRC.EFS, patient1)
          matplot(RFSRC.Pred.EFS$time.interest, t(RFSRC.Pred.EFS$survival),
                  xlab = "Months after transplantation", ylab = "Progression Free Survival",
                  xlim=c(0,36), ylim=c(0,1),
                  main = "Predicted PFS by Random Survival Forest",cex.main = 1.6,
                  cex.lab=1.5,cex.axis=1.5,lwd=2,col="midnightblue",
                  type = "l", lty = 1)
      }
      else if(input$theme == "2"){ # plot Predicted Relapse/Progression
        RFSRC.Pred.CI <- predict(modelRFSRC.CI, patient1)
        cif <- apply(RFSRC.Pred.CI$cif, c(2, 3), mean, na.rm = TRUE)
        matplot(RFSRC.Pred.CI$time.interest, cif[,1],
                xlab = "Months after transplantation", ylab = "Relapse/Progression",
                xlim=c(0,36), ylim=c(0,1),
                main = "Predicted Relapse/Progression by Random Survival Forest",cex.main = 1.6,
                cex.lab=1.5,cex.axis=1.5,lwd=2,col="midnightblue",
                type = "l", lty = 1)
      }
      else if(input$theme == "3"){ # plot Predicted NRM
        RFSRC.Pred.CI <- predict(modelRFSRC.CI, patient1)
        cif <- apply(RFSRC.Pred.CI$cif, c(2, 3), mean, na.rm = TRUE)
        matplot(RFSRC.Pred.CI$time.interest, cif[,2],
                xlab = "Months after transplantation", ylab = "Non Relapse Mortality",
                xlim=c(0,36), ylim=c(0,1),
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
        RFSRC.Pred.CI <- predict(modelRFSRC.CI, x)
        y <- which( RFSRC.Pred.CI$time.interest <= fu_month)
        cif <- apply(RFSRC.Pred.CI$cif, c(2, 3), mean, na.rm = TRUE)
        return (cif[,1][max(y)])
      }
      search_predict_NRMrate_fu_rfsrc <- function(x,fu_month){
        RFSRC.Pred.CI <- predict(modelRFSRC.CI, x)
        y <- which( RFSRC.Pred.CI$time.interest <= fu_month)
        cif <- apply(RFSRC.Pred.CI$cif, c(2, 3), mean, na.rm = TRUE)
        return (cif[,2][max(y)])
      }
      if(input$theme == "0"){ # display Predicted OS rate at 3years
        pred_3yOS = search_predict_OSrate_fu_rfsrc(patient1,36)
        c_index <- (1-modelRFSRC.OS$err.rate[length(modelRFSRC.OS$err.rate)])
        div(
          p(
            class = "plane-paragraph",
            paste("Predicted 3-yeras OS rate is ", round(pred_3yOS*100, digits = 1) , " %.")
          ),
          p(
            class = "plane-paragraph",
            paste("Harrell's c-index calculated using out-of-bag(OOB) data is", round(c_index, digits = 2), ".")
          )
        )
      }
      else if(input$theme == "1"){ # display Predicted PFS rate at 3years
        pred_3yEFS = search_predict_EFSrate_fu_rfsrc(patient1,36)
        c_index <- (1-modelRFSRC.EFS$err.rate[length(modelRFSRC.EFS$err.rate)])
        div(
          p(
            class = "plane-paragraph",
            paste("Predicted 3-yeras PFS rate is ", round(pred_3yEFS*100, digits = 1) , " %")
          ),
          p(
            class = "plane-paragraph",
            paste("Harrell's c-index calculated using out-of-bag(OOB) data is", round(c_index, digits = 2), ".")
          )
        )
      }
      else if(input$theme == "2"){ # display Predicted Relapse rate at 3years
        pred_3yRelapse = search_predict_Relapserate_fu_rfsrc(patient1,36)
        c_index <- (1-modelRFSRC.CI$err.rate[[length(modelRFSRC.CI$err.rate)/2,1]])
        div(
          p(
            class = "plane-paragraph",
            paste("Predicted 3-yeras Relapse/Progression rate is ", round(pred_3yRelapse*100, digits = 1) , " %")
          ),
          p(
            class = "plane-paragraph",
            paste("Harrell's c-index calculated using out-of-bag(OOB) data is", round(c_index, digits = 2), ".")
          )
        )
      }
      else if(input$theme == "3"){ # display Predicted NRM rate at 3years
        pred_3yNRM = search_predict_NRMrate_fu_rfsrc(patient1,36)
        c_index <- (1-modelRFSRC.CI$err.rate[[length(modelRFSRC.CI$err.rate)/2,2]])
        div(
          p(
            class = "plane-paragraph",
            paste("Predicted 3-yeras NRM rate is ", round(pred_3yNRM*100, digits = 1) , " %")
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

# Run the application 
shinyApp(ui = ui, server = server)
