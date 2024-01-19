process PRESTO_MASKPRIMERS_ALIGN {
    tag "$meta.id"
    label "process_high"
    label 'immcantation'

    conda "bioconda::presto=0.7.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/presto:0.7.1--pyhdfd78af_0' :
        'biocontainers/presto:0.7.1--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(R1)
    path(cprimers)

    output:
    tuple val(meta), path("*_R1_primers-pass.fastq") , emit: reads
    path "*_command_log_R1.txt", emit: logs
    path "*_R1.log"
    path "*.tab", emit: log_tab
    path "versions.yml" , emit: versions

    script:
    """
    MaskPrimers.py align --nproc ${task.cpus} \\
    -s $R1 \\
    -p ${cprimers} \\
    --maxlen ${params.primer_maxlen} \\
    --maxerror ${params.primer_r1_maxerror} \\
    --mode ${params.primer_mask_mode} \\
    --skiprc \\
    --outname ${meta.id}_R1 \\
    --log ${meta.id}_R1.log > ${meta.id}_command_log_R1.txt
    ParseLog.py -l ${meta.id}_R1.log -f ID PRIMER ERROR

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        presto: \$( MaskPrimers.py --version | awk -F' '  '{print \$2}' )
    END_VERSIONS
    """
}
