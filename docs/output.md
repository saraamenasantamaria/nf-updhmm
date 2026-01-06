# nf-core/updhmm: Output

## Introduction

This document describes the output produced by the pipeline. 

The directories listed below will be created in the results directory after the pipeline has finished. All paths are relative to the top-level results directory specified with `--outdir`.

<!-- TODO nf-core: Write this documentation describing your workflow's output -->

## Pipeline overview

The pipeline processes trio VCF/gVCF files through multiple filtering and analysis stages to detect uniparental disomy (UPD) events. The workflow consists of two main phases:

### 1. Preprocessing

Prepares trio data by combining individual VCFs/GVCFs and applying filters to retain only high-quality biallelic SNVs.

**Annotation removal and filtering:**

- `REMOVE_ANNOTATIONS` – Indexes VCF/GVCF files, filters for autosomes (chr1-22), removes unused annotations, and regroups files by family. Optionally extracts variants with ambiguous variant allele frequency (VAF) for downstream masking (`--apply_vaf_filter`).

**Trio combination:**

- `COMBINE_VCF` – Merges VCFs from proband, mother, and father into a joint file. Retains either all variants (union mode, default) or only shared variants (intersection mode, `--perform_intersection true`).
- `COMBINE_GVCF` – For gVCF input (`--is_gvcf true`), performs GVCF combination and joint genotyping using GATK to generate a single combined VCF per family trio.

**Variant masking:**

- `SV_MASK_BED` – Removes variants overlapping structural variants and regions with ambiguous VAF if mask files are provided.

**Quality filtering:**

- `FILTER_LOWCONF` – Applies hard filters to generate the final preprocessed VCF per family:
  - Genotype correction (optional):
    - `SETGT` – Sets missing genotypes to homozygous reference (0/0) when `--perform_intersection false`
    - `SETGT_VAF` – Corrects genotypes based on VAF thresholds when `--apply_vaf_correction true`
  - Variant filtering:
    - Retain only biallelic SNVs
    - Apply minimum genotype quality (GQ = `--GQ_min`) and depth (DP = `--DP_min`) thresholds
    - Exclude variants where all trio members are homozygous reference (0/0 or 0|0)
    - Exclude problematic genomic regions (centromeres, segmental duplications, HLA/KIR loci)

### 2. UPD Detection

Runs the UPDhmm core functions to identify genomic blocks consistent with uniparental disomy patterns.

- `VCF_CHECK` – Trio VCF preprocessing with quality-aware genotype encoding
- `CALCULATE_EVENTS` – Hidden Markov Model (HMM)-based UPD event detection across autosomes
- `COLLAPSE_EVENTS` – Event collapsing to merge adjacent/overlapping UPD regions per family 

## UPD Detection Results

<details markdown="1">
<summary>Output files</summary>

- `event_detection/`
  - `<fam_id>.upd_events.txt`: All detected UPD candidate events before collapsing.
  - `<fam_id>.upd_collapsed.txt`: Filtered and merged UPD events.

</details>

These are the primary results of the pipeline. For each trio (family), two tab-delimited files are generated containing candidate UPD regions identified by the Hidden Markov Model.

The **upd events file** contains all UPD candidate events detected without post-processing. Each row represents a distinct genomic region with statistical evidence of uniparental inheritance. If no events are detected for a trio, the file will contain only the header row.

**Column descriptions (upd_events.txt):**
| Column              | Type    | Description                                                      |
| ------------------- | ------- | ---------------------------------------------------------------- |
| `ID`                | String  | Identifier of the proband (child sample)                          |
| `chromosome`        | String  | Chromosome identifier                                            |
| `start`             | Integer | Start genomic position of the UPD block                           |
| `end`               | Integer | End genomic position of the UPD block                             |
| `group`             | String  | Predicted UPD type (`iso_mat`, `iso_fat`, `het_mat`, `het_fat`)  |
| `n_snps`            | Integer | Number of informative SNVs within the event                      |
| `ratio_proband`     | Float   | Ratio of average read depth inside the event vs. the genome-wide average (including the event) for the proband. A value close to 1 indicates balanced coverage; deviations may suggest copy-number changes. |
| `ratio_mother`      | Float   | Ratio of average read depth inside the event vs. genome-wide average (including the event) for the mother |
| `ratio_father`      | Float   | Ratio of average read depth inside the event vs. genome-wide average (including the event) for the father |
| `n_mendelian_error` | Integer | Number of Mendelian inheritance errors supporting the event      |

The **upd collapsed events file** contains post-processed results where overlapping or adjacent events of the same UPD type within a chromosome are merged into a single representative block. This file is recommended for clinical interpretation as it provides a simplified view of UPD regions.

**Column descriptions (upd_collapsed.txt):**

| Column                 | Type    | Description                                                                 |
|------------------------|---------|-----------------------------------------------------------------------------|
| `ID`                   | String  | Identifier of the proband (child sample)                                    |
| `chromosome`           | String  | Chromosome identifier                                                        |
| `start`                | Integer | Start genomic position of the UPD block                                      |
| `end`                  | Integer | End genomic position of the UPD block                                        |
| `group`                | String  | Predicted UPD type (`iso_mat`, `iso_fat`, `het_mat`, `het_fat`)             |
| `n_events`             | Integer | Number of raw events that were collapsed into this entry                     |
| `total_mendelian_error`| Integer | Sum of Mendelian errors from all collapsed events                             |
| `total_size`           | Integer | Total genomic span covered by the collapsed events                           |
| `total_snps`           | Integer | Total number of SNPs in the overlapping events                               |
| `prop_covered`         | Float   | Proportion of the region covered by the merged events                        |
| `collapsed_events`     | String  | Comma-separated list of the original event coordinates that were merged      |
| `ratio_proband`        | Float   | Weighted mean ratio of read depth for the proband across the collapsed events |
| `ratio_mother`         | Float   | Weighted mean ratio of read depth for the mother across the collapsed events  |
| `ratio_father`         | Float   | Weighted mean ratio of read depth for the father across the collapsed events  |

### Pipeline information

<details markdown="1">
<summary>Output files</summary>

- `pipeline_info/`
  - Reports generated by Nextflow: `execution_report.html`, `execution_timeline.html`, `execution_trace.txt` and `pipeline_dag.dot`/`pipeline_dag.svg`.
  - Reports generated by the pipeline: `pipeline_report.html`, `pipeline_report.txt` and `software_versions.yml`. The `pipeline_report*` files will only be present if the `--email` / `--email_on_fail` parameter's are used when running the pipeline.
  - Reformatted samplesheet files used as input to the pipeline: `samplesheet.valid.csv`.
  - Parameters used by the pipeline run: `params.json`.

</details>

[Nextflow](https://www.nextflow.io/docs/latest/tracing.html) provides excellent functionality for generating various reports relevant to the running and execution of the pipeline. This will allow you to troubleshoot errors with the running of the pipeline, and also provide you with other information such as launch commands, run times and resource usage.
