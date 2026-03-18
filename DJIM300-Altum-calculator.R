
library(shiny)
library(bslib)
library(scales)

calc_values <- function(time_min, req_speed, altitude, hfov, vfov, side_ol, front_ol, trigger_sec, efficiency, bands, storage_per_capture_mb) {
  footprint_width  <- 2 * altitude * tan((hfov * pi / 180) / 2)
  footprint_height <- 2 * altitude * tan((vfov * pi / 180) / 2)
  track_spacing    <- footprint_width * (1 - side_ol)
  capture_spacing  <- footprint_height * (1 - front_ol)
  max_speed        <- ifelse(trigger_sec > 0, capture_spacing / trigger_sec, NA_real_)
  actual_speed     <- min(req_speed, max_speed, na.rm = TRUE)
  time_between     <- ifelse(actual_speed > 0, capture_spacing / actual_speed, NA_real_)
  raw_area_rate    <- actual_speed * track_spacing
  net_area_rate    <- raw_area_rate * efficiency
  area_ha          <- net_area_rate * time_min * 60 / 10000
  area_km2         <- area_ha / 100
  captures         <- ifelse(is.na(time_between) || time_between <= 0, NA_real_, (time_min * 60 * efficiency) / time_between)
  images           <- captures * bands
  storage_gb       <- captures * storage_per_capture_mb / 1024
  area_acre_hr     <- net_area_rate * 3600 / 4046.8564224
  
  list(
    footprint_width = footprint_width,
    footprint_height = footprint_height,
    track_spacing = track_spacing,
    capture_spacing = capture_spacing,
    max_speed = max_speed,
    actual_speed = actual_speed,
    time_between = time_between,
    raw_area_rate = raw_area_rate,
    net_area_rate = net_area_rate,
    area_ha = area_ha,
    area_km2 = area_km2,
    captures = captures,
    images = images,
    storage_gb = storage_gb,
    area_acre_hr = area_acre_hr,
    trigger_limited = req_speed > max_speed
  )
}

fmt_num <- function(x, digits = 1) format(round(x, digits), nsmall = digits, trim = TRUE)
fmt_int <- function(x) format(round(x, 0), big.mark = ",", trim = TRUE, scientific = FALSE)
fmt_duration <- function(time_min) {
  hrs <- floor(time_min / 60)
  mins <- round(time_min %% 60)
  paste0(hrs, " hours ", mins, " minutes")
}

ui <- page_sidebar(
  title = "DJI M300 + MicaSense Altum Coverage Calculator",
  theme = bs_theme(version = 5, bootswatch = "flatly"),
  sidebar = sidebar(
    numericInput("time_min", "Usable mapping time (min)", 28, min = 1, step = 1),
    numericInput("req_speed", "Requested mapping speed (m/s)", 2.24, min = 0.1, step = 0.01),
    numericInput("altitude", "Altitude AGL (m)", 121.92, min = 1, step = 0.01),
    numericInput("hfov", "Altum horizontal FOV (deg)", 48, min = 1, step = 0.1),
    numericInput("vfov", "Altum vertical FOV (deg)", 36.8, min = 1, step = 0.1),
    sliderInput("side_ol", "Side overlap", min = 0.40, max = 0.90, value = 0.80, step = 0.01),
    sliderInput("front_ol", "Front overlap", min = 0.40, max = 0.90, value = 0.80, step = 0.01),
    numericInput("trigger_sec", "Minimum trigger interval (sec)", 1.0, min = 0.1, step = 0.1),
    sliderInput("efficiency", "Turn / setup efficiency", min = 0.50, max = 0.99, value = 0.85, step = 0.01),
    numericInput("bands", "Number of bands", 5, min = 1, step = 1),
    numericInput("storage_per_capture_mb", "Storage per capture (MB)", 31.2, min = 0.1, step = 0.1),
    hr(),
    p("Tip: replace the trigger interval, storage assumption, and usable flight time with your field values.")
  ),
  layout_column_wrap(
    width = 1/3,
    value_box(title = "Estimated area / flight", value = textOutput("area_ha"), theme = "primary"),
    value_box(title = "Area per hour", value = textOutput("area_acre_hr"), theme = "secondary"),
    value_box(title = "Number of captures", value = textOutput("captures"), theme = "info"),
    value_box(title = "Storage space", value = textOutput("storage_gb"), theme = "success"),
    value_box(title = "Actual mapping speed used", value = textOutput("actual_speed"), theme = "warning"),
    value_box(title = "Trigger-limited?", value = textOutput("trigger_limited"), theme = "danger")
  ),
  card(
    card_header("Derived values"),
    tableOutput("derived_tbl")
  ),
  card(
    card_header("Method"),
    p("Coverage is estimated as: actual mapping speed × effective line spacing × usable mapping time × efficiency."),
    p("Forward overlap sets the required capture spacing, which can cap the achievable speed based on the trigger interval."),
    p("Captures, image count, and storage are planning estimates based on the selected efficiency, number of bands, and per-capture storage assumption.")
  )
)

server <- function(input, output, session) {
  vals <- reactive({
    calc_values(
      time_min = input$time_min,
      req_speed = input$req_speed,
      altitude = input$altitude,
      hfov = input$hfov,
      vfov = input$vfov,
      side_ol = input$side_ol,
      front_ol = input$front_ol,
      trigger_sec = input$trigger_sec,
      efficiency = input$efficiency,
      bands = input$bands,
      storage_per_capture_mb = input$storage_per_capture_mb
    )
  })
  
  output$area_ha <- renderText(paste0(fmt_num(vals()$area_ha, 2), " ha (", fmt_num(vals()$area_km2, 3), " km²)"))
  output$area_acre_hr <- renderText(paste0(fmt_num(vals()$area_acre_hr, 2), " acre/hr"))
  output$captures <- renderText(fmt_int(vals()$captures))
  output$storage_gb <- renderText(paste0(fmt_num(vals()$storage_gb, 2), " GB"))
  output$actual_speed <- renderText(paste0(fmt_num(vals()$actual_speed, 2), " m/s"))
  output$trigger_limited <- renderText(if (isTRUE(vals()$trigger_limited)) "YES" else "NO")
  
  output$derived_tbl <- renderTable({
    data.frame(
      Metric = c(
        "Time between capture (seconds)",
        "Flight time",
        "Footprint Width (m)",
        "Footprint Height (m)",
        "Distance between capture (m)",
        "Distance between track (m)",
        "Max speed allowed by trigger (m/s)",
        "Number of images (all bands)",
        "Raw area rate (m²/s)",
        "Net area rate (m²/s)"
      ),
      Value = c(
        fmt_num(vals()$time_between, 2),
        fmt_duration(input$time_min),
        fmt_num(vals()$footprint_width, 2),
        fmt_num(vals()$footprint_height, 2),
        fmt_num(vals()$capture_spacing, 2),
        fmt_num(vals()$track_spacing, 2),
        fmt_num(vals()$max_speed, 2),
        fmt_int(vals()$images),
        fmt_num(vals()$raw_area_rate, 2),
        fmt_num(vals()$net_area_rate, 2)
      )
    )
  }, striped = TRUE, bordered = FALSE, spacing = "m")
}

shinyApp(ui, server)
