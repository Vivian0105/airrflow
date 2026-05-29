process CELLRANGER_MKVDJREF {
    tag "$fasta"
    label 'process_high'

    container "nf-core/cellranger:7.1.0"

    input:
    path fasta
    path gtf
    val reference_name

    output:
    path "${reference_name}", emit: reference
    tuple val("${task.process}"), val('cellranger'), eval('cellranger --version 2>&1 | sed \'s/^.*[^0-9]\\([0-9]*\\.[0-9]*\\.[0-9]*\\).*$/\\1/\''), emit: versions_cellranger, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error "CELLRANGER_MKVDJREF module does not support Conda. Please use Docker / Singularity / Podman instead."
    }
    def args = task.ext.args ?: ''
    """
    cellranger \\
        mkvdjref \\
        --genome=$reference_name \\
        --fasta=$fasta \\
        --genes=$gtf \\
        $args

    """
}
