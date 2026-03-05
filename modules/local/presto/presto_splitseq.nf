process PRESTO_SPLITSEQ {
    tag "$meta.id"
    label "process_low"
    label 'immcantation'

    conda "bioconda::presto=0.7.7"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/c0/c01c6e6bcfd26b9a1a615e18f51a9bbdf8674ae1ab441e19f25d5481eba01248/data' :
        'biocontainers/presto:0.7.7--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("${meta.id}_atleast-*.fasta"), emit: fasta
    path("*_command_log.txt"), emit: logs
    path "versions.yml" , emit: versions

    script:
    def args = task.ext.args ?: ''
    """
    SplitSeq.py group -s $reads \\
    $args \\
    --outname ${meta.id} \\
    --fasta > ${meta.id}_command_log.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        presto: \$( SplitSeq.py --version | awk -F' '  '{print \$2}' )
    END_VERSIONS
    """
}
