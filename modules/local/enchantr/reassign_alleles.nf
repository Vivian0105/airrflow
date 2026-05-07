def asString (args) {
    if (args.size() == 0 || args[0] == 'none') return ""
    return args.keySet().sort().collect { param ->
        def value = args[param].toString()
        value = value.isNumber() ? value : "'${value}'"
        ",'${param}'=${value}"
    }.join('')
}

process REASSIGN_ALLELES {
    tag "${meta.id}"

    label 'process_long_parallelized'
    label 'immcantation'

    container "docker.io/immcantation/airrflow:5.1.0dev"

    input:
    tuple val(meta), path(tabs), path(reference_fasta) // meta, sequence tsv in AIRR format, reference fasta
    val segments // which segments to reassign alleles to
    val outputby // which field to use for output
    //TODO: did we want to handle all segments at once? Then this val channel would not be needed.
    // *After novel alleles we just need to change the V, it's a time waste to go over all segments.
    //TODO: Check if we need the outputby parameter. Right now this is the same as the genotypeby parameter.
    output:
    tuple val(meta), path("*/*/*reassign-pass.tsv"), emit: tab // reassigned repertoire
    path("*/*_command_log.txt"), emit: logs //process logs
    path "*_report"
    path "versions.yml", emit: versions


    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error "nf-core/airrflow currently does not support Conda. Please use a container profile instead."
    }
    def args = task.ext.args ? asString(task.ext.args) : ''
    def segs = segments.join(",")
    def input = tabs.join(',')

    """
    Rscript -e "enchantr::enchantr_report('reassign_alleles', \\
                                        report_params=list('input'='${input}', \\
                                        'imgt_db'='${reference_fasta}', \\
                                        'species'='auto', \\
                                        'outputby'='${outputby}', \\
                                        'segments'='${segs}', \\
                                        'outdir'=getwd(), \\
                                        'log'='${meta.id}_reassign_alleles_command_log' ${args}))"

    cp -r enchantr ${meta.id}_reassign_alleles_report && rm -rf enchantr

    echo "${task.process}": > versions.yml
    Rscript -e "cat(paste0('  enchantr: ',packageVersion('enchantr'),'\n'))" >> versions.yml
    """
}
