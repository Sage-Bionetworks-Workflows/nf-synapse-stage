#!/usr/bin/env nextflow


/*
========================================================================================
    SETUP PARAMS
========================================================================================
*/

// Ensure DSL1
nextflow.enable.dsl = 1

params.synapse_config = false  // Default
ch_synapse_config = params.synapse_config ? Channel.value(file(params.synapse_config)) : "null"

input_file = file(params.input, checkIfExists: true)

workdir = "${workDir.parent}/${workDir.name}"
params.outdir = "${workDir.scheme}://${workdir}/synstage/"
outdir = params.outdir.replaceAll('/$', '')


// Parse Synapse URIs from input file
synapse_uris = (input_file.text =~ 'syn://(syn[0-9]+)').findAll()
// Parse SBG URIs from input file
sbg_uris = (input_file.text =~ 'sbg://(.+)').findAll()
// Synapse channel
Channel
  .fromList(synapse_uris)
  .set { ch_synapse_ids }  // channel: [ syn://syn98765432, syn98765432 ]
// SBG channel
Channel
  .fromList(sbg_uris)
  .set { ch_sbg_ids } // channel: [ sbg://63b717559fd1ad5d228550a0, 63b717559fd1ad5d228550a0]

params.name = workflow.runName
run_name = params.name


/*
========================================================================================
    SETUP PROCESSES
========================================================================================
*/


// Download files from Synapse
process synapse_get {

  publishDir "${outdir}/${syn_id}/", mode: 'copy'

  secret 'SYNAPSE_AUTH_TOKEN'

  input:
  tuple val(syn_uri), val(syn_id)   from ch_synapse_ids
  file  syn_config                  from ch_synapse_config

  output:
  tuple val(syn_uri), val(syn_id), path("*")    into ch_synapse_files

  when:
  synapse_uris.size() > 0

  script:
  if ( params.synapse_config ) {
    """
    synapse --configPath ${syn_config} get ${syn_id}
    rm ${syn_config}
    """
  } else {
    """
    # Using SYNAPSE_AUTH_TOKEN secret from the environment
    synapse get ${syn_id}
    """
  }

}

// Download files from SevenBridges
process sbg_get {

  container "quay.io/biocontainers/sevenbridges-python:2.9.1--pyhdfd78af_0"

  publishDir "${outdir}/${sbg_id}/", mode: 'copy'

  secret 'SB_API_ENDPOINT'
  secret 'SB_AUTH_TOKEN'

  input:
  tuple val(sbg_uri), val(sbg_id)   from ch_sbg_ids

  output:
  tuple val(sbg_uri), val(sbg_id), path("*")    into ch_sbg_files

  when:
  sbg_uris.size() > 0

  script:
  """

  #!/usr/bin/env python3

  import sevenbridges as sbg

  api = sbg.Api()
  download_file = api.files.get('${sbg_id}')
  download_file.download(download_file.name)

  """

}
// Mix channels, allowing for either of them to be null
if (ch_synapse_files == null) {
    ch_all_files = ch_sbg_files
} else if (ch_sbg_files == null) {
  ch_all_files = ch_synapse_files
} else {
  ch_all_files = ch_synapse_files.mix(ch_sbg_files)
}

// Convert Mixed URIs and staged locations into sed expressions
ch_all_files
  .map { uri, id, file -> /-e 's|\b${uri}\b|${outdir}\/${id}\/${file.name}|g'/ }
  .reduce { a, b -> "${a} ${b}" }
  .set { ch_stage_sed }

// Update Synapse URIs in input file with staged locations
process update_input {

  publishDir "${input_file.scheme}://${input_file.parent}/synstage/",  mode: 'copy'
  publishDir "${outdir}/${run_name}/",          mode: 'copy'

  input:
  path "input.txt"    from input_file
  val  exprs          from ch_stage_sed

  output:
  path "${input_file.name}"  into ch_input_tweaked

  when:
  synapse_uris.size() > 0 || sbg_uris.size() > 0

  script:
  """
  sed -E ${exprs} input.txt > ${input_file.name}
  """

}
