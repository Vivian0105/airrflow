process PRESTO_FILTERSEQ_TRIMQUAL {
    tag "$meta.id"
    label "process_medium"
    label 'immcantation'

    conda "bioconda::presto=0.7.4"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/presto:0.7.4--pyhdfd78af_0' :
        'biocontainers/presto:0.7.4--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*trimqual-pass.fastq") ,  emit: reads
    path "*_command_log.txt" , emit: logs
    path "versions.yml" , emit: versions
    path "*.tab" , emit: log_tab

    script:
    def args = task.ext.args ?: ''
    def args2 = task.ext.args2 ?: ''
    """
    FilterSeq.py trimqual -s $reads \\
        $args \\
        --outname ${meta.id} --log ${reads.baseName}.log --nproc ${task.cpus} > ${meta.id}_trimqual_command_log.txt
    ParseLog.py -l ${reads.baseName}.log $args2

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        presto: \$( FilterSeq.py --version | awk -F' '  '{print \$2}' )
    END_VERSIONS
    """
}