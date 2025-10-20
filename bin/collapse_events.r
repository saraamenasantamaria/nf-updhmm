#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(UPDhmm)
  library(optparse)
})

option_list <- list(
  make_option(c("-i", "--input"), 
              type = "character", 
              default = NULL,
              help = "Input UPD events RDS file from calculateEvents", 
              metavar = "character"),
  make_option(c("-o", "--output_prefix"), 
              type = "character", 
              default = "sample",
              help = "Prefix for output files [default= %default]", 
              metavar = "character"),
  make_option(c("-v", "--verbose"), 
              action = "store_true", 
              default = TRUE,
              help = "Print detailed messages [default]")
)

opt_parser <- OptionParser(option_list = option_list)
opt <- parse_args(opt_parser)

if (is.null(opt$input)) {
  print_help(opt_parser)
  stop("You must specify an input UPD events RDS file with --input", call. = FALSE)
}

if (!file.exists(opt$input)) {
  stop(paste("The input RDS file does not exist:", opt$input), call. = FALSE)
}


tryCatch({

  updEvents <- readRDS(opt$input)
  collapsed <- collapseEvents(updEvents)
  
  collapsed_file <- paste0(opt$output_prefix, ".upd_collapsed.txt")
  collapsed_rds_file <- paste0(opt$output_prefix, ".upd_collapsed.rds")

  write.table(collapsed, file = collapsed_file, sep = "\t", row.names = FALSE, quote = FALSE)
  saveRDS(collapsed, file = collapsed_rds_file)

  
}, error = function(e) {
  cat("ERROR:", conditionMessage(e), "\n")
  quit(status = 1)
})