#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(UPDhmm)
  library(BiocParallel)
  library(parallel)
  library(optparse)
})

option_list <- list(
  make_option(c("-i", "--input"), 
              type = "character", 
              default = NULL,
              help = "Input processed VCF RDS file from vcfCheck", 
              metavar = "character"),
  make_option(c("-o", "--output_prefix"), 
              type = "character", 
              default = "sample",
              help = "Prefix for output files [default= %default]", 
              metavar = "character"),
  make_option(c("-c", "--cpus"), 
              type = "integer", 
              default = 1,
              help = "Number of CPUs for parallel processing [default= %default]", 
              metavar = "integer"),
  make_option(c("-v", "--verbose"), 
              action = "store_true", 
              default = TRUE,
              help = "Print detailed messages [default]")
)

opt_parser <- OptionParser(option_list = option_list)
opt <- parse_args(opt_parser)

# Function to log messages with timestamp
log_message <- function(message, level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  cat(sprintf("[%s] %s: %s\n", timestamp, level, message))
}

# Function to log system information
log_system_info <- function() {
  cat("\n=== SYSTEM INFORMATION ===\n")
  cat("Hostname:", Sys.info()["nodename"], "\n")
  cat("OS:", Sys.info()["sysname"], Sys.info()["release"], "\n")
  cat("R version:", R.version.string, "\n")
  cat("Available CPU cores:", detectCores(), "\n")
  cat("Memory info:\n")
  if (Sys.info()["sysname"] == "Linux") {
    system("free -h | head -2", intern = FALSE)
  }
  cat("==========================\n\n")
}

if (is.null(opt$input)) {
  print_help(opt_parser)
  stop("You must specify an input processed VCF RDS file with --input", call. = FALSE)
}

if (!file.exists(opt$input)) {
  stop(paste("The input RDS file does not exist:", opt$input), call. = FALSE)
}

# Start logging
cat("\n")
cat("########################################\n")
cat("#        UPD ANALYSIS PIPELINE         #\n")
cat("########################################\n")

log_message("Starting UPD analysis pipeline")

# Log system information
if (opt$verbose) {
  log_system_info()
}

# Log input parameters
cat("=== INPUT PARAMETERS ===\n")
cat("Input file:", opt$input, "\n")
cat("Output prefix:", opt$output_prefix, "\n")
cat("Requested CPUs:", opt$cpus, "\n")
cat("Verbose mode:", opt$verbose, "\n")
cat("========================\n\n")

tryCatch({
  
  # Log file information
  log_message("Reading input RDS file...")
  input_size <- file.size(opt$input)
  log_message(sprintf("Input file size: %.2f MB", input_size / (1024^2)))
  
  processedVcf <- readRDS(opt$input)
  log_message("Successfully loaded processed VCF data")
  
  # Log data information
  if (opt$verbose && is.data.frame(processedVcf)) {
    log_message(sprintf("Data dimensions: %d rows x %d columns", nrow(processedVcf), ncol(processedVcf)))
  }
  
  # Setup and log parallel processing configuration
  log_message("Setting up parallel processing...")
  if (opt$cpus > 1) {
    available_cores <- detectCores()
    workers <- min(opt$cpus, available_cores, na.rm = TRUE)
    bp_param <- MulticoreParam(workers = workers)
    
    log_message(sprintf("Parallel processing enabled: using %d out of %d available cores", 
                       workers, available_cores))
  } else {
    bp_param <- SerialParam()
    log_message("Serial processing mode (single core)")
  }
  
  # Log analysis start
  log_message("Starting UPD events calculation...")
  cat("=== ANALYSIS PROGRESS ===\n")
  
  start_time <- Sys.time()
  log_message(sprintf("Analysis started at: %s", format(start_time, "%Y-%m-%d %H:%M:%S")))
  
  # Run the analysis with progress indication
  updEvents <- calculateEvents(processedVcf, verbose = TRUE, BPPARAM = bp_param)
  
  end_time <- Sys.time()
  processing_time <- difftime(end_time, start_time, units = "mins")
  
  log_message(sprintf("Analysis completed at: %s", format(end_time, "%Y-%m-%d %H:%M:%S")))
  log_message(sprintf("Total processing time: %.2f minutes", processing_time))
  cat("=========================\n\n")
  
  # Log results information
  if (is.data.frame(updEvents)) {
    log_message(sprintf("Results generated: %d UPD events detected", nrow(updEvents)))
    if (opt$verbose && ncol(updEvents) > 0) {
      log_message(sprintf("Results columns: %s", paste(colnames(updEvents), collapse = ", ")))
    }
  }
  
  # Save results and log output files
  log_message("Saving results...")
  results_file <- paste0(opt$output_prefix, ".upd_events.txt")
  rds_file <- paste0(opt$output_prefix, ".upd_events.rds")
  
  write.table(updEvents, file = results_file, sep = "\t", row.names = FALSE, quote = FALSE)
  saveRDS(updEvents, file = rds_file)
  
  # Log output file information
  txt_size <- file.size(results_file)
  rds_size <- file.size(rds_file)
  
  log_message(sprintf("Results saved to: %s (%.2f KB)", results_file, txt_size / 1024))
  log_message(sprintf("RDS object saved to: %s (%.2f KB)", rds_file, rds_size / 1024))
  
  # Final summary
  cat("\n=== ANALYSIS SUMMARY ===\n")
  cat("Status: COMPLETED SUCCESSFULLY\n")
  cat("Input file:", opt$input, "\n")
  cat("Processing time:", round(processing_time, 2), "minutes\n")
  cat("CPUs used:", ifelse(opt$cpus > 1, workers, 1), "\n")
  cat("Output files generated:\n")
  cat("  -", results_file, "\n")
  cat("  -", rds_file, "\n")
  cat("========================\n")
  
  log_message("UPD analysis pipeline completed successfully!")
  
}, error = function(e) {
  log_message(sprintf("ANALYSIS FAILED: %s", conditionMessage(e)), "ERROR")
  log_message("Check input file format and parameters", "ERROR")
  cat("\n=== ERROR SUMMARY ===\n")
  cat("Status: FAILED\n")
  cat("Error:", conditionMessage(e), "\n")
  cat("Input file:", opt$input, "\n")
  cat("Parameters used:\n")
  cat("  - CPUs:", opt$cpus, "\n")
  cat("  - Output prefix:", opt$output_prefix, "\n")
  cat("====================\n")
  quit(status = 1)
})