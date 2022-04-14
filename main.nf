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

params.outdir = "${workDir.scheme}://${workDir.parent}/synstage/"
outdir = params.outdir.replaceAll('/$', '')


// Parse Synapse URIs from input file
synapse_uris = (input_file.text =~ 'syn://(syn[0-9]+)').findAll()


Channel
  .fromList(synapse_uris)
  .set { ch_synapse_ids }  // channel: [ syn://syn98765432, syn98765432 ]

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


// Convert Synapse URIs and staged locations into sed expressions
ch_synapse_files
  .map { syn_uri, syn_id, syn_file -> /-e 's|\b${syn_uri}\b|${outdir}\/${syn_id}\/${syn_file.name}|g'/ }
  .reduce { a, b -> "${a} ${b}" }
  .set { ch_synapse_sed }


// Update Synapse URIs in input file with staged locations
process update_input {

  publishDir "${input_file.scheme}://${input_file.parent}/synstage/",  mode: 'copy'
  publishDir "${outdir}/${run_name}/",          mode: 'copy'

  input:
  path "input.txt"    from input_file
  val  exprs          from ch_synapse_sed

  output:
  path "${input_file.name}"  into ch_input_tweaked

  when:
  synapse_uris.size() > 0

  script:
  """
  sed -E ${exprs} input.txt > ${input_file.name}
  """

}
