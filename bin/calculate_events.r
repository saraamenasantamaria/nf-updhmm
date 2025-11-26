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
            default = NULL,
            help = "Number of CPUs for parallel processing", 
            metavar = "integer"),                 
  make_option(c("-a", "--add_ratios"),
              action = "store_true", 
              default = FALSE,
              help = "Add ratios to calculateEvents function"),
  make_option(c("-v", "--verbose"), 
              action = "store_true", 
              default = TRUE,
              help = "Print detailed messages [default]")
)

opt_parser <- OptionParser(option_list = option_list)
opt <- parse_args(opt_parser)

if (is.null(opt$input)) {
  print_help(opt_parser)
  stop("You must specify an input processed VCF RDS file with --input", call. = FALSE)
}

if (!file.exists(opt$input)) {
  stop(paste("The input RDS file does not exist:", opt$input), call. = FALSE)
}

tryCatch({
  
  processedVcf <- readRDS(opt$input)
  
  # Use CPUs parameter if provided, otherwise use all available
  if (!is.null(opt$cpus)) {
    workers <- opt$cpus
  } else {
    workers <- detectCores()
  }
  
  if (workers > 1) {
    bp_param <- MulticoreParam(workers = workers)
  } else {
    bp_param <- SerialParam()
  }
  
  updEvents <- calculateEvents(processedVcf, verbose = opt$verbose, BPPARAM = bp_param, add_ratios = opt$add_ratios)
  
  results_file <- paste0(opt$output_prefix, ".upd_events.txt")
  rds_file <- paste0(opt$output_prefix, ".upd_events.rds")
  
  write.table(updEvents, file = results_file, sep = "\t", row.names = FALSE, quote = FALSE)
  saveRDS(updEvents, file = rds_file)
  
}, error = function(e) {
  stop(paste("Analysis failed:", conditionMessage(e)), call. = FALSE)
})