<h1>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/nf-core-updhmm_logo_dark.png">
    <img alt="nf-core/updhmm" src="docs/images/nf-core-updhmm_logo_light.png">
  </picture>
</h1>

[![GitHub Actions CI Status](https://github.com/nf-core/updhmm/actions/workflows/ci.yml/badge.svg)](https://github.com/nf-core/updhmm/actions/workflows/ci.yml)
[![GitHub Actions Linting Status](https://github.com/nf-core/updhmm/actions/workflows/linting.yml/badge.svg)](https://github.com/nf-core/updhmm/actions/workflows/linting.yml)[![AWS CI](https://img.shields.io/badge/CI%20tests-full%20size-FF9900?labelColor=000000&logo=Amazon%20AWS)](https://nf-co.re/updhmm/results)[![Cite with Zenodo](http://img.shields.io/badge/DOI-10.5281/zenodo.XXXXXXX-1073c8?labelColor=000000)](https://doi.org/10.5281/zenodo.XXXXXXX)
[![nf-test](https://img.shields.io/badge/unit_tests-nf--test-337ab7.svg)](https://www.nf-test.com)

[![Nextflow](https://img.shields.io/badge/version-%E2%89%A524.04.2-green?style=flat&logo=nextflow&logoColor=white&color=%230DC09D&link=https%3A%2F%2Fnextflow.io)](https://www.nextflow.io/)
[![nf-core template version](https://img.shields.io/badge/nf--core_template-3.3.1-green?style=flat&logo=nfcore&logoColor=white&color=%2324B064&link=https%3A%2F%2Fnf-co.re)](https://github.com/nf-core/tools/releases/tag/3.3.1)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![Launch on Seqera Platform](https://img.shields.io/badge/Launch%20%F0%9F%9A%80-Seqera%20Platform-%234256e7)](https://cloud.seqera.io/launch?pipeline=https://github.com/nf-core/updhmm)

[![Get help on Slack](http://img.shields.io/badge/slack-nf--core%20%23updhmm-4A154B?labelColor=000000&logo=slack)](https://nfcore.slack.com/channels/updhmm)[![Follow on Bluesky](https://img.shields.io/badge/bluesky-%40nf__core-1185fe?labelColor=000000&logo=bluesky)](https://bsky.app/profile/nf-co.re)[![Follow on Mastodon](https://img.shields.io/badge/mastodon-nf__core-6364ff?labelColor=FFFFFF&logo=mastodon)](https://mstdn.science/@nf_core)[![Watch on YouTube](http://img.shields.io/badge/youtube-nf--core-FF0000?labelColor=000000&logo=youtube)](https://www.youtube.com/c/nf-core)

---
## Introduction

**CIBERER/GdTBioinfo-nf-UPDhmm** is a best-practice analysis pipeline for the **detection of uniparental disomy (UPD)** in trio sequencing data, using [UPDhmm](https://github.com/saraamenasantamaria/UPDhmm-project) and additional preprocessing and postprocessing steps tailored to clinical datasets.

The pipeline is built using [Nextflow](https://www.nextflow.io) DSL2, enabling portability across HPC and cloud infrastructures. Each process runs within its own container, ensuring reproducibility and simplifying software management. Containers from [Biocontainers](https://biocontainers.pro/) are used whenever possible.  

Where appropriate, modules are reused or patched from [nf-core/modules](https://github.com/nf-core/modules); custom modules are implemented locally following nf-core guidelines.

---

## Pipeline summary

This pipeline standardizes the detection of uniparental disomy (UPD) events in trio sequencing data.  
It includes preprocessing of raw VCF files to ensure compatibility with the UPDhmm R package, application of a Hidden Markov Model to detect UPD segments, and postprocessing filters to refine the final set of events.

Default steps:

1. **Preprocessing (`PREPROCESS_VCF`)**  
   Prepares the trio data by combining individual VCFs (if required) and applying filters to keep only high-quality biallelic SNVs.
   
   - **`REMOVE_ANNOTATIONS`** – filters autosomes, removes annotations from individual VCF files, and regroups by family.
   - **`COMBINE_VCF`** – merges the VCFs from father, mother, and proband into a joint file, keeping either only variants shared by all three individuals (`perform_intersection = TRUE`) or all variants (`perform_intersection = FALSE`).
   - **`SV_MASK_BED`** *(optional)* – removes variants overlapping large structural changes using BED files.
   - **`FILTER_LOWCONF`** – applies hard filters to generate the final preprocessed VCF per family.

        - **`BCFTOOLS_VIEW_BIALLELIC`** – retains only biallelic sites.
        - **`BCFTOOLS_VIEW_QUAL_MIN`** – filters variants by minimum genotype quality (GQ) and depth (DP).  
        - **`BCFTOOLS_VIEW_REFHOMO_EXCLUDE`** – excludes variants homozygous for the reference allele (0/0 or 0|0) in all trio members.
        - **`BCFTOOLS_VIEW_EXCL_ALL`** – excludes problematic genomic regions (centromeres, segmental duplications, and highly polymorphic HLA/KIR regions).

> **Note:** If merging is performed instead of intersection, the **SETGT** module is applied to convert missing genotypes in VCF files to homozygous reference.
> This ensures that all genotypes are explicitly defined before downstream analysis.

2. **UPD detection (`UPD_ANALYSIS`)**  
   Runs the UPDhmm core functions to detect genomic blocks consistent with UPD.  
   - **`VCF_CHECK`** – validates and formats the combined VCF as a `largeCollapsedVcf` object.  
   - **`CALCULATE_EVENTS`** – applies the HMM (Viterbi algorithm) to infer hidden states, groups variants into blocks, and annotates each block with confidence metrics.
   - **`COLLAPSE_EVENTS`** – merges overlapping blocks of the same UPD type within a chromosome.

> Each step is implemented as a separate DSL2 module. Outputs are organized by step and method.

---

## Usage

### Input samplesheet

Prepare a **CSV file** with your input data.  
Each row represents a family (trio), with identifiers for father, mother, and proband, and paths to the corresponding VCFs.  
Structural variant VCFs can also be included (set to `-` if not available).

`samplesheet.csv`:

```csv
fam_id,proband_id,mother_id,father_id,path_vcf_proband,path_vcf_mother,path_vcf_father,path_sv_proband,path_sv_mother,path_sv_father
FAM001,FAM001_PROBAND,FAM001_MOTHER,FAM001_FATHER,/path/to/proband.vcf.gz,/path/to/mother.vcf.gz,/path/to/father.vcf.gz,/path/to/proband.bed,/path/to/mother.sv.bed,/path/to/father.sv.bed
```

**Field description:**

- fam_id: family identifier  
- proband_id: proband sample identifier
- mother_id: mother sample identifier   
- father_id: father sample identifier  
- path_vcf_proband: SNV VCF file for the proband
- path_vcf_mother: SNV VCF file for the mother  
- path_vcf_father: SNV VCF file for the father   
- path_sv_proband: structural variant VCF for the proband (- if not available)
- path_sv_mother: structural variant VCF for the mother (- if not available)
- path_sv_father: structural variant VCF for the father (- if not available)  


Then, you can run the pipeline using:

<!-- TODO nf-core: update the following command to include all required parameters for a minimal example -->

```bash
nextflow run nf-core/updhmm \
   -profile <docker/singularity/.../institute,test> \
   --input samplesheet.csv \
   --outdir <OUTDIR> \
   --genome_build <hg38/hg19> \
   --perform_intersection <TRUE/FALSE>
```

## Output summary

For each trio, the pipeline generates two main tab-delimited files:  

1. **Raw events (`<trio>.raw.txt`)**  
   Direct output of the `UPDhmm::calculateEvents` function. This file contains all detected UPD candidate events without additional filtering.  

The core UPDhmm function, `calculateEvents`, returns a **data.frame** containing all detected UPD events for a given trio.  
If no events are found, an empty data.frame is returned.  

**Output columns:**  

| Column name          | Description                                                                 |
|----------------------|-----------------------------------------------------------------------------|
| seqnames             | Chromosome                                                                 |
| start                | Start position of the block                                                |
| end                  | End position of the block                                                  |
| n_snps               | Number of variants within the event                                        |
| group                | Predicted UPD state (e.g. iso_mat, het_fat)                                |
| log_likelihood       | Log likelihood ratio for the inferred block                                |
| p_value              | Statistical significance of the event                                      |
| n_mendelian_error    | Number of Mendelian errors supporting the event                            |
| ratio_proband        | Ratio of average depth inside vs. outside the event for the proband        |
| ratio_mother         | Ratio of average depth inside vs. outside the event for the mother         |
| ratio_father         | Ratio of average depth inside vs. outside the event for the father         |

2. **Collapsed events (`<trio>.collapsed.txt`)**  
   Postprocessed and filtered results. Overlapping events of the same type within the same chromosome (e.g. paternal isodisomy) are merged into a single representative block.  
   Additional columns report the start and end coordinates of the merged region, together with a semicolon-separated list of all original raw events collapsed.


**Example collapsed output:**  

| chromosome | UPD type | n_events | total_mendelian_error | collapsed_event_ranges                                      | min_start | max_end   |
|------------|----------|----------|-----------------------|-------------------------------------------------------------|-----------|-----------|
| chr12      | iso_mat  | 2        | 108                   | chr12:16885604-25756939; chr12:25866874-29838830            | 16885604  | 29838830  |
| chr17      | het_mat  | 1        | 3                     | chr17:45990746-46714277                                     | 45990746  | 46714277  |
| chr7       | het_mat  | 1        | 11                    | chr7:55624055-56153077                                      | 55624055  | 56153077  |
| chr2       | het_fat  | 1        | 3                     | chr2:89791539-96090799                                      | 89791539  | 96090799  |


## Test execution

You can test the pipeline using the small example dataset provided in this repository.  
The test dataset contains two trios (subset of a single chromosome):  
- One trio includes a **simulated UPD event**  
- The other trio is a **negative control** without UPD  

The dataset is available at [Zenodo (10.5281/zenodo.17193905)](https://zenodo.org/records/17193905).  

Run the pipeline in **test mode** with:  

```bash
nextflow run nf-core/updhmm \
   -profile <docker/singularity>,test \
   --outdir <OUTDIR> \
   --genome_build <hg38/hg19> \
   --perform_intersection <TRUE/FALSE>
```

## Credits

nf-core/updhmm was originally written by Marta Sevilla Porras, Sara Mena Santamaría and Carlos Ruiz Arenas.


## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).


## Citations (pending)

<!-- TODO nf-core: Add citation for pipeline after first release. Uncomment lines below and update Zenodo doi and badge at the top of this file. -->
<!-- If you use nf-core/updhmm for your analysis, please cite it using the following doi: [10.5281/zenodo.XXXXXX](https://doi.org/10.5281/zenodo.XXXXXX) -->

<!-- TODO nf-core: Add bibliography of tools and data used in your pipeline -->

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

You can cite the `nf-core` publication as follows:

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
