library(shiny)

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
                       h3("The number of Transplantations"),
                       min = 1,
                       max = 3,
                       value = 1)),
  column(8,plotOutput("distPlot")),
  column(8,htmlOutput("OS_text"))
  )
)