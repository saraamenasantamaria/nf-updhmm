#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(UPDhmm)
  library(VariantAnnotation)
  library(optparse)
})

option_list <- list(
  make_option(c("-i", "--input"), 
              type = "character", 
              default = NULL,
              help = "Input VCF file", 
              metavar = "character"),
  make_option(c("-o", "--output_prefix"), 
              type = "character", 
              default = "sample",
              help = "Prefix for output files [default= %default]", 
              metavar = "character"),
  make_option(c("-g", "--genome_build"), 
              type = "character", 
              default = "hg38",
              help = "Genome version (hg19, hg38) [default= %default]", 
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
  stop("You must specify an input VCF file with --input", call. = FALSE)
}

if (!file.exists(opt$input)) {
  stop(paste("The VCF file does not exist:", opt$input), call. = FALSE)
}


tryCatch({

  vcf <- readVcf(opt$input, opt$genome_build)
  sample_names <- colnames(geno(vcf)$GT)
  
  processedVcf <- vcfCheck(vcf, 
                           proband = sample_names[1], 
                           mother = sample_names[2], 
                           father = sample_names[3])
  
 
  processed_rds_file <- paste0(opt$output_prefix, ".processed.rds") 
  saveRDS(processedVcf, file = processed_rds_file)
  
}, error = function(e) {
  cat("ERROR:", conditionMessage(e), "\n")
  quit(status = 1)
})