library(shiny)
library(rsmFlow)

ui <- fluidPage(
  titlePanel("rsmFlow 0.2.0"),
  sidebarLayout(
    sidebarPanel(
      fileInput("file", "CSV data"),
      textInput("response", "Response", "Yield"),
      textInput("factors", "Quantitative factors (2+ for Gaussian; exactly 2 for GLM/nonlinear/Tier 3)", "N,K"),
      selectInput("engine", "Model engine",
                  c("Gaussian polynomial RSM"="lm",
                    "Generalized RSM (GLM)"="glm",
                    "Nonlinear two-factor surface"="nonlinear",
                    "Tier 3 surrogate"="surrogate")),
      conditionalPanel("input.engine == 'lm' || input.engine == 'glm'",
        selectInput("order", "Surface order", c("First order"=1,"Second order"=2), selected=2)
      ),
      conditionalPanel("input.engine == 'glm'",
        selectInput("family", "GLM family",
                    c("Gaussian"="gaussian","Poisson"="poisson","Quasi-Poisson"="quasipoisson",
                      "Binomial"="binomial","Quasi-binomial"="quasibinomial",
                      "Gamma (log)"="gamma_log","Inverse Gaussian (log)"="inverse_gaussian_log",
                      "Negative binomial"="negative_binomial")),
        textInput("weights", "Optional prior-weight column", "")
      ),
      conditionalPanel("input.engine == 'nonlinear'",
        selectInput("nl_model", "Nonlinear surface", choices=setNames(rsm_nonlinear_models()$model, rsm_nonlinear_models()$model), selected="mitscherlich2_product"),
        selectInput("nl_engine", "Nonlinear backend", c("nlsLM (fallback nls)"="nlsLM","nls"="nls","gnls (Tier 3)"="gnls")),
        selectInput("nl_start", "Initial-parameter search", c("Genetic algorithm"="ga","Random multistart"="multistart"), selected="ga")
      ),
      conditionalPanel("input.engine == 'surrogate'",
        selectInput("surrogate", "Tier 3 surrogate", c("Gaussian process"="gp","GAM / thin-plate"="gam","Random forest"="rf","Neural network"="nn"))
      ),
      actionButton("fit", "Fit model"),
      hr(),
      selectInput("goal", "Optimization goal", c("Maximize"="max", "Minimize"="min")),
      selectInput("optmethod", "Optimization", c("Hybrid"="hybrid","L-BFGS-B"="L-BFGS-B","Genetic algorithm"="GA","Grid"="grid")),
      actionButton("opt", "Optimize")
    ),
    mainPanel(
      tabsetPanel(
        tabPanel("Fit", verbatimTextOutput("fitout")),
        tabPanel("Diagnostics", verbatimTextOutput("diagout")),
        tabPanel("Design audit", verbatimTextOutput("auditout")),
        tabPanel("Canonical", verbatimTextOutput("canonout")),
        tabPanel("Optimum", verbatimTextOutput("optout")),
        tabPanel("Plot", plotOutput("plot"))
      )
    )
  )
)

server <- function(input, output, session) {
  dat <- reactive({
    req(input$file)
    read.csv(input$file$datapath, check.names=FALSE)
  })
  factors <- reactive(trimws(strsplit(input$factors, ",")[[1]]))

  fit <- eventReactive(input$fit, {
    d <- dat(); fs <- factors()
    validate(need(length(fs)>=2L, "Select at least two quantitative factors."))
    if (input$engine %in% c("glm","nonlinear","surrogate"))
      validate(need(length(fs)==2L, "The thin Shiny interface exposes exactly two factors for GLM, nonlinear, and Tier-3 surrogate modules; the R API remains the authoritative interface for broader workflows."))
    if (input$engine == "lm") {
      rsm_fit(d,input$response,fs,order=as.integer(input$order))
    } else if (input$engine == "glm") {
      fam <- switch(input$family,
        gaussian=gaussian(), poisson=poisson(), quasipoisson=quasipoisson(),
        binomial=binomial(), quasibinomial=quasibinomial(),
        gamma_log=Gamma(link="log"), inverse_gaussian_log=inverse.gaussian(link="log"),
        negative_binomial="negative_binomial")
      w <- NULL
      if (nzchar(trimws(input$weights))) {
        validate(need(input$weights %in% names(d), "Prior-weight column was not found."))
        w <- d[[input$weights]]
      }
      rsm_glm_fit(d,input$response,fs,order=as.integer(input$order),family=fam,weights=w)
    } else if (input$engine == "nonlinear") {
      validate(need(input$nl_model != "custom", "Custom nonlinear formulas are available in the R API; the thin Shiny interface exposes built-in models."))
      rsm_nonlinear_fit(d,input$response,fs,model=input$nl_model,start=input$nl_start,engine=input$nl_engine)
    } else {
      rsm_surrogate(d,input$response,fs,method=input$surrogate)
    }
  })

  opt <- eventReactive(input$opt, {
    req(fit())
    rsm_optimize(fit(), goal=input$goal, method=input$optmethod)
  })

  output$fitout <- renderPrint({
    f <- fit()
    if (inherits(f,"rsmFlow_surrogate")) print(f) else summary(f)
  })
  output$diagout <- renderPrint({
    f <- fit()
    tryCatch(rsm_diagnostics(f), error=function(e) cat(conditionMessage(e),"\n"))
  })
  output$auditout <- renderPrint({
    f <- fit()
    if (inherits(f,"rsmFlow_fit")) rsm_design_audit(f)
    else cat("Full design-matrix audit is attached to polynomial Gaussian RSM. GLM/nonlinear models use model-specific diagnostics and response-scale optimization.\n")
  })
  output$canonout <- renderPrint({
    f <- fit()
    if (inherits(f,c("rsmFlow_fit","rsmFlow_glm")) && isTRUE(f$order==2L)) {
      tryCatch(rsm_canonical(f),error=function(e) cat(conditionMessage(e),"\n"))
    } else cat("Canonical polynomial analysis applies to second-order Gaussian/GLM surfaces. Use bounded optimization and profiles for nonlinear/Tier-3 surfaces.\n")
  })
  output$optout <- renderPrint(opt())
  output$plot <- renderPlot({
    f <- fit()
    p <- rsm_plot(f,type="contour",optimum=if(input$opt>0)opt() else NULL)
    if (inherits(p,"ggplot")) print(p)
  })
}

shinyApp(ui,server)
