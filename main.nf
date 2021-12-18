#!/usr/bin/env nextflow


/*
========================================================================================
    SETUP PARAMS
========================================================================================
*/


synapse_config_file = file(params.synapse_config, checkIfExists: true)
input_file = file(params.input, checkIfExists: true)
outdir = params.outdir.replaceAll('/$', '')


// Parse Synapse URIs from input file
synapse_uris = (input_file.text =~ 'syn://(syn[0-9]+)').findAll()


Channel
  .fromList(synapse_uris)
  .set { ch_synapse_ids }  // channel: [ syn://syn98765432, syn98765432 ]

params.name = false
run_name = params.name ?: workflow.runName


/*
========================================================================================
    SETUP PROCESSES
========================================================================================
*/


// Download files from Synapse
process synapse_get {

  publishDir "${outdir}/${syn_id}/", mode: 'copy'

  input:
  tuple val(syn_uri), val(syn_id)   from ch_synapse_ids
  path  syn_config                  from synapse_config_file

  output:
  tuple val(syn_uri), val(syn_id), path("*")    into ch_synapse_files

  script:
  """
  synapse --configPath ${syn_config} get --manifest 'suppress' ${syn_id}
  """

}


// Convert Synapse URIs and staged locations into sed expressions
ch_synapse_files
  .map { syn_uri, syn_id, syn_file -> /-e 's|\b${syn_uri}\b|${outdir}\/${syn_id}\/${syn_file.name}|g'/ }
  .reduce { a, b -> "${a} ${b}" }
  .set { ch_synapse_sed }


// Update Synapse URIs in input file with staged locations
process update_input {

  publishDir "${input_file.getParent()}/",  mode: 'copy'
  publishDir "${outdir}/${run_name}/",      mode: 'copy'

  input:
  path input    from input_file
  val  exprs    from ch_synapse_sed

  output:
  path "${output}"    into ch_input_tweaked

  script:
  output = "${input_file.getBaseName()}.staged.${input_file.getExtension()}"
  """
  sed -E ${exprs} ${input} > ${output}
  """

}
