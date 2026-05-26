#! /usr/bin/bash

nextflow run nf-core/airrflow -r 5.1.0 \
-profile singularity \
--mode assembled \
--genotyping true \
--single_clone_representative true \
--skip_clonal_analysis true \
--input genotype_samplesheet.tsv \
--outdir test_genotype_results  \
-c resource.config \
-resume
