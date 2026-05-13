#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    nf-core/airrflow
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/nf-core/airrflow
    Website: https://nf-co.re/airrflow
    Slack  : https://nfcore.slack.com/channels/airrflow
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { AIRRFLOW                } from './workflows/airrflow'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_airrflow_pipeline'
include { PIPELINE_COMPLETION     } from './subworkflows/local/utils_nfcore_airrflow_pipeline'
include { getGenomeAttribute      } from './subworkflows/local/utils_nfcore_airrflow_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    GENOME PARAMETER VALUES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/



/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run main analysis pipeline depending on type of input
//
workflow NFCORE_AIRRFLOW {

    take:
    samplesheet // channel: samplesheet read in from --input

    main:

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        CONFIG FILES
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */

    ch_multiqc_config        = file("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ? file( params.multiqc_config, checkIfExists: true ) : []
    ch_multiqc_logo          = params.multiqc_logo   ? file( params.multiqc_logo, checkIfExists: true ) : []
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

    // Report files
    ch_report_rmd       = channel.fromPath(params.report_rmd, checkIfExists: true)
    ch_report_css       = channel.fromPath(params.report_css, checkIfExists: true)
    ch_report_logo      = channel.fromPath(params.report_logo, checkIfExists: true)
    ch_report_logo_img  = channel.fromPath(params.report_logo_img, checkIfExists: true)

    //
    // WORKFLOW: Run pipeline
    //
    AIRRFLOW (
        samplesheet,
        params.mode,
        params.library_generation_method,
        params.miairr,
        params.collapseby,
        params.cloneby,
        params.reassign,
        params.genotyping,
        params.skip_clonal_analysis,
        params.translate,
        params.embeddings,
        params.skip_report,
        params.outdir,
        params.skip_multiqc,
        params.multiqc_methods_description,
        ch_report_rmd,
        ch_report_css,
        ch_report_logo,
        ch_report_logo_img,
        ch_multiqc_config,
        ch_multiqc_custom_config,
        ch_multiqc_logo,
        params.fetch_germlines,
        params.reference_igblast,
        params.reference_fasta,
        params.vprimers,
        params.race_linker,
        params.cprimers,
        params.umi_length,
        params.reference_10x,
        params.index_file,
        params.trust4_barcode_whitelist,
        params.trust4_cell_barcode_read,
        params.trust4_umi_read,
        params.trust4_read_format,
        params.skip_alignment_filter,
        params.productive_only,
        params.remove_chimeric,
        params.detect_contamination,
        params.genotypeby,
        params.novel_allele_inference,
        params.single_clone_representative,
        params.genotyping_clonal_threshold,
        params.clonal_threshold,
        params.skip_report_threshold,
        params.skip_all_clones_report,
        params.lineage_trees,
        params.embedding_chain,
        params.adapter_fasta,
        params.maskprimers_extract,
        params.internal_cregion_sequences,
        params.maskprimers_align_race,
        params.umi_position,
        params.umi_start,
        params.save_trimmed,
        params.maskprimers_align,
        params.cprimer_position,
        params.primer_maxlen,
        params.primer_r1_maxerror,
        params.primer_r1_mask_mode,
        params.primer_r2_maxerror,
        params.primer_r2_mask_mode,
        params.cprimer_start,
        params.vprimer_start,
        params.primer_revpr,
        params.primer_r2_extract_len,
        params.primer_r1_extract_len,
        params.cluster_sets,
        params.assemblepairs_sequential,
        params.align_cregion,
        params.cregion_maxlen,
        params.cregion_maxerror,
        params.cregion_mask_mode,
        params.crossby,
        params.singlecell,
        params.lineage_tree_builder,
        params.lineage_tree_exec,
        params.filterseq_q
    )
    emit:
    multiqc_report = AIRRFLOW.out.multiqc_report // channel: /path/to/multiqc_report.html
}
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:
    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION (
        params.version,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.input,
        params.help,
        params.help_full,
        params.show_hidden
    )

    //
    // WORKFLOW: Run main workflow
    //
    NFCORE_AIRRFLOW (
        PIPELINE_INITIALISATION.out.samplesheet
    )
    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION (
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
        NFCORE_AIRRFLOW.out.multiqc_report
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
