#!/usr/bin/env nextflow
/*
========================================================================================
    VALIDATE INPUTS
========================================================================================
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowBcellmagic.initialise(params, log)

// Check input path parameters to see if they exist
def checkPathParamList = [ params.input, params.multiqc_config ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input) { ch_input = file(params.input) } else { exit 1, "Please provide input file containing the sample metadata with the '--input' option." }

// Input validation
if (params.input)  {
    file(params.input, checkIfExists: true)
} else {
    exit 1, "Missing mandatory input: --input."
}

if (params.miairr)  {
    file(params.miairr, checkIfExists: true)
}

// If paths to databases are provided
if( params.igblast_base ){
    Channel.fromPath("${params.igblast_base}")
            .ifEmpty { exit 1, "IGBLAST DB not found: ${params.igblast_base}" }
            .set { ch_igblast }
}
if( params.imgtdb_base ){
    Channel.fromPath("${params.imgtdb_base}")
            .ifEmpty { exit 1, "IMGTDB not found: ${params.imgtdb_base}" }
            .set { ch_imgt }
}

/*
========================================================================================
    CONFIG FILES
========================================================================================
*/

ch_multiqc_config        = Channel.fromPath("$projectDir/assets/multiqc_config.yaml", checkIfExists: true)
ch_multiqc_custom_config = params.multiqc_config ? Channel.fromPath(params.multiqc_config) : Channel.empty()

/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

// Don't overwrite global params.modules, create a copy instead and use that within the main script.
def modules = params.modules.clone()

// Modules: local
include { IMMCANTATION  } from '../modules/local/reveal/immcantation_container_version' addParams( options: [:] )
include { CHANGEO_CONVERTDB_FASTA } from '../modules/local/changeo/changeo_convertdb_fasta'  addParams( options: modules['changeo_convertdb_fasta_from_airr'] )
include { FETCH_DATABASES } from '../modules/local/fetch_databases'              addParams( options: [:] )
include { CHANGEO_ASSIGNGENES_REVEAL } from '../modules/local/reveal/changeo_assigngenes_reveal'      addParams( options: modules['changeo_assigngenes_reveal'] )
include { CHANGEO_MAKEDB_REVEAL } from '../modules/local/reveal/changeo_makedb_reveal'                addParams( options: modules['changeo_makedb_reveal'] )
include { FILTER_QUALITY  } from '../modules/local/reveal/filter_quality' addParams( options: modules['filter_quality_reveal'] )
include { CHANGEO_PARSEDB_SPLIT } from '../modules/local/changeo/changeo_parsedb_split'  addParams( options: modules['changeo_parsedb_split_reveal'] )
include { FILTER_JUNCTION_MOD3  } from '../modules/local/reveal/filter_junction_mod3' addParams( options: modules['filter_quality_reveal'] )
include { CHANGEO_CREATEGERMLINES_REVEAL as CREATEGERMLINES } from '../modules/local/reveal/changeo_creategermlines_reveal'  addParams( options: modules['changeo_creategermlines_reveal'] )
include { REMOVE_CHIMERIC  } from '../modules/local/enchantr/remove_chimeric'
include { SINGLE_CELL_QC  } from '../modules/local/enchantr/single_cell_qc' addParams( options: modules['single_cell_qc_reveal'] )
include { ADD_META_TO_TAB  } from '../modules/local/reveal/add_meta_to_tab' addParams( options: modules['add_metadata_reveal'] )
include { DETECT_CONTAMINATION  } from '../modules/local/enchantr/detect_contamination'
include { COLLAPSE_DUPLICATES  } from '../modules/local/enchantr/collapse_duplicates'
include { FIND_THRESHOLD  } from '../modules/local/enchantr/find_threshold'
include { DEFINE_CLONES } from '../modules/local/enchantr/define_clones'
include { DOWSER_LINEAGES } from '../modules/local/enchantr/dowser_lineages'
//include { CHANGEO_CREATEGERMLINES_REVEAL as CREATEGERMLINES_CLONED } from '../modules/local/reveal/changeo_creategermlines_reveal'  addParams( options: modules['changeo_creategermlines_cloned_reveal'], 'args':'--cloned' )
include { REPORT_FILE_SIZE     } from '../modules/local/enchantr/report_file_size'  addParams( options: [:] )

// Local: Sub-workflows
include { REVEAL_INPUT_CHECK } from '../subworkflows/local/reveal_input_check'       addParams( options: [:] )

/*
========================================================================================
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
========================================================================================
*/
include { CUSTOM_DUMPSOFTWAREVERSIONS  } from '../modules/nf-core/modules/custom/dumpsoftwareversions'  addParams( options: [publish_files : ['csv':'']] )

def multiqc_options   = modules['multiqc']
multiqc_options.args += params.multiqc_title ? Utils.joinModuleArgs(["--title \"$params.multiqc_title\""]) : ''

//
// MODULE: Installed directly from nf-core/modules
//
include { MULTIQC               } from '../modules/nf-core/modules/multiqc/main'       addParams( options: multiqc_options )

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

// Info required for completion email and summary
def multiqc_report = []

workflow REVEAL {

    log.warn "\n----------\nREVEAL lifecycle stage: experimental.\n----------\n"

    ch_software_versions = Channel.empty()
    ch_file_sizes = Channel.empty()

    IMMCANTATION()
    ch_software_versions = ch_software_versions.mix(IMMCANTATION.out.version.first().ifEmpty(null))

    // SUBWORKFLOW: Read in samplesheet, validate
    // and emit channels for fasta and tsv files
    REVEAL_INPUT_CHECK (ch_input, params.miairr, params.collapseby, params.cloneby, params.reassign)

    // If reassign requested, generate fasta from the tsv files
    if (params.reassign) {
        CHANGEO_CONVERTDB_FASTA(
            REVEAL_INPUT_CHECK.out.ch_tsv
        )
        ch_fasta_from_tsv = CHANGEO_CONVERTDB_FASTA.out.fasta
        ch_software_versions = ch_software_versions.mix(CHANGEO_CONVERTDB_FASTA.out.version.first().ifEmpty(null))
        ch_file_sizes = ch_file_sizes.mix(CHANGEO_CONVERTDB_FASTA.out.logs)
    } else {
        ch_fasta_from_tsv = Channel.empty()
    }


    // mix all fasta
    ch_fasta = REVEAL_INPUT_CHECK.out.ch_fasta.mix(ch_fasta_from_tsv)

    // FETCH DATABASES
    // TODO: this can take a long time, and the progress shows 0%. Would be
    // nice to have some better progress reporting.
    // And maybe run this as 2 separate steps, one for IMGT and one for IgBLAST?
    if (!params.igblast_base | !params.imgtdb_base) {
        FETCH_DATABASES()
        ch_software_versions = ch_software_versions.mix(FETCH_DATABASES.out.version.first().ifEmpty(null))
        ch_igblast = FETCH_DATABASES.out.igblast
        ch_imgt = FETCH_DATABASES.out.imgt
    }

    // Run Igblast for gene assignment
    CHANGEO_ASSIGNGENES_REVEAL (
        ch_fasta,
        ch_igblast.collect()
    )
    ch_file_sizes = ch_file_sizes.mix(CHANGEO_ASSIGNGENES_REVEAL.out.logs)
    //ch_software_versions = ch_software_versions.mix(CHANGEO_ASSIGNGENES_REVEAL.out.version.first().ifEmpty(null))

    // Parse IgBlast results
    CHANGEO_MAKEDB_REVEAL (
        CHANGEO_ASSIGNGENES_REVEAL.out.fasta,
        CHANGEO_ASSIGNGENES_REVEAL.out.blast,
        ch_imgt.collect()
    )
    ch_file_sizes = ch_file_sizes.mix(CHANGEO_MAKEDB_REVEAL.out.logs)

    // Apply quality filters
    FILTER_QUALITY(CHANGEO_MAKEDB_REVEAL.out.tab)
    ch_file_sizes = ch_file_sizes.mix(FILTER_QUALITY.out.logs)

    // Select only productive sequences and
    // sequences with junction length multiple of 3
    if (params.productive_only) {
        CHANGEO_PARSEDB_SPLIT (
            FILTER_QUALITY.out.tab
        )
        ch_file_sizes = ch_file_sizes.mix(CHANGEO_PARSEDB_SPLIT.out.logs)

        FILTER_JUNCTION_MOD3(
            CHANGEO_PARSEDB_SPLIT.out.tab
        )
        ch_file_sizes = ch_file_sizes.mix(FILTER_JUNCTION_MOD3.out.logs)
        ch_repertoire = FILTER_JUNCTION_MOD3.out.tab
    } else {
        ch_repertoire = FILTER_QUALITY.out.tab
    }

    // Add metadata to the rearrangement files, to be used later
    // for grouping, subsetting, plotting....
    ADD_META_TO_TAB(
        ch_repertoire,
        REVEAL_INPUT_CHECK.out.validated_input
    )
    ch_file_sizes = ch_file_sizes.mix(ADD_META_TO_TAB.out.logs)

    ADD_META_TO_TAB.out.tab
    .branch { it ->
        single: it[0].single_cell == 'true'
                    return it
        bulk:   it[0].single_cell == 'false'
                    return it
    }
    .set{ch_repertoire_by_processing}

    // For bulk datasets, remove chimeric sequences
    // if requested
    if (params.remove_chimeric) {

        // Create germlines (not --cloned)
        CREATEGERMLINES(
            ch_repertoire_by_processing.bulk,
            ch_imgt.collect()
        )
        ch_file_sizes = ch_file_sizes.mix(CREATEGERMLINES.out.logs)

        // Remove chimera
        REMOVE_CHIMERIC(
            CREATEGERMLINES.out.tab,
            ch_imgt.collect()
        )
        ch_file_sizes = ch_file_sizes.mix(REMOVE_CHIMERIC.out.logs)
        ch_bulk_chimeric_pass = REMOVE_CHIMERIC.out.tab

    } else {
        ch_bulk_chimeric_pass = ch_repertoire_by_processing.bulk
    }

    // For Bulk data, detect cross-contamination
    // This is only informative at this time
    // TODO: add a flag to specify remove suspicious sequences
    // and update file size log accordingly
    DETECT_CONTAMINATION(
        ch_bulk_chimeric_pass
            .map{ it -> [ it[1] ] }
            .collect(),
        'id')
    // TODO file size

    COLLAPSE_DUPLICATES(
        ch_bulk_chimeric_pass
            .map{ it -> [ it[1] ] }
            .collect(),
        params.collapseby
    )
    // TODO file size
    // TODO channel by params.cloneby


    // For single cell, specific QC
    // analyze all files together, looking for overlaps
    SINGLE_CELL_QC(
        ch_repertoire_by_processing.single
        .map{ it -> [ it[1] ] }
        .collect()
    )
    ch_file_sizes = ch_file_sizes.mix(SINGLE_CELL_QC.out.logs)

    // If params.threshold is auto,
    // 1) use distToNearest and findThreshold to determine
    // the threshold that will be used to identify sets of clonally
    // related sequences. If threshold found, continue, to 2), else,
    // stop and report a threshold could be identified.
    // 2) create a report with plots of the distToNearest distribution
    // and the threshold.
    // Else
    // Use the threshold to find clones, grouping by params.cloneby and
    // create a report

    if (params.threshold == "auto") {
        FIND_THRESHOLD (
            // TODO: Add cross threshold. Needs all samples!
            COLLAPSE_DUPLICATES.out.tab.mix(SINGLE_CELL_QC.out.tab)
            .map{ it -> [ it[1] ] }
            .collect(),
            params.cloneby,
            params.singlecell
        )
        clone_threshold = FIND_THRESHOLD.out.mean_threshold
        if (clone_threshold == 'NA') {
            log.error "clone_threshold is NA"
            exit 1, "clone_threshold is NA"
        }
    } else {
        clone_threshold = params.threshold
    }

    DEFINE_CLONES(
        SINGLE_CELL_QC.out.tab.mix(COLLAPSE_DUPLICATES.out.tab)
        .map{ it -> [ it[1] ] }
        .collect(),
        params.cloneby,
        params.singlecell,
        clone_threshold,
        ch_imgt.collect()
    )


    DOWSER_LINEAGES(
        DEFINE_CLONES.out.tab
        .map{ it -> [ it[1] ] }
        .flatten()
    )

    // TODO fix file sizes
    // Process logs to report file sizes at each step
    REPORT_FILE_SIZE (
        ch_file_sizes.map { it }.collect()
    )

    // Software versions
    //GET_SOFTWARE_VERSIONS (
    //    ch_software_versions.map { it }.collect()
    //)
    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_software_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    //
    // MODULE: MultiQC
    //
    if (!params.skip_multiqc) {
        workflow_summary    = WorkflowBcellmagic.paramsSummaryMultiqc(workflow, summary_params)
        ch_workflow_summary = Channel.value(workflow_summary)

        ch_multiqc_files = Channel.empty()
        ch_multiqc_files = ch_multiqc_files.mix(ch_multiqc_config)
        ch_multiqc_files = ch_multiqc_files.mix(ch_multiqc_custom_config.collect().ifEmpty([]))
        ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
        ch_multiqc_files = ch_multiqc_files.mix(GET_SOFTWARE_VERSIONS.out.yaml.collect())

        MULTIQC (
            ch_multiqc_files.collect()
        )
        multiqc_report       = MULTIQC.out.report.toList()
        ch_software_versions = ch_software_versions.mix(MULTIQC.out.version.ifEmpty(null))
    }
}

/*
========================================================================================
    COMPLETION EMAIL AND SUMMARY
========================================================================================
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
}

/*
========================================================================================
    THE END
========================================================================================
*/
