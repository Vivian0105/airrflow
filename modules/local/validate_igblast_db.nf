process VALIDATE_IGBLAST_DB {
    tag "validate_igblast_db"
    label 'process_low'
    label 'immcantation'

    conda "bioconda::changeo=1.3.0 bioconda::igblast=1.22.0 conda-forge::wget=1.20.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-7d8e418eb73acc6a80daea8e111c94cf19a4ecfd:a9ee25632c9b10bbb012da76e6eb539acca8f9cd-1' :
        'biocontainers/mulled-v2-7d8e418eb73acc6a80daea8e111c94cf19a4ecfd:a9ee25632c9b10bbb012da76e6eb539acca8f9cd-1' }"

    input:
    path(igblast_dir)
    path(reference_fasta_dir)

    output:
    path("igblast_base"), emit: igblast
    path "versions.yml", emit: versions

    script:
    """
    mv "${igblast_dir}" input_igblast_base
    validate_igblast_db.sh -i input_igblast_base -r "${reference_fasta_dir}" -o igblast_base

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bash: \$(echo \$(bash --version | head -n 1) | sed 's/^GNU bash, version //; s/(.*\$//')
    END_VERSIONS
    """
}
