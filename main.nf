#!/usr/bin/env nextflow
nextflow.enable.dsl=2

/*
 * Generic Pipeline for preprocessing ngs data
 */

/*
========================================================================================
    VALIDATE & PRINT PARAMETER SUMMARY
========================================================================================
*/
WorkflowMain.initialise(workflow, params, log)

/*
 * Download configuration files if requested
 */
if (params.get_config) {
  new File("ngs-preprocess.config").write(new URL ("https://github.com/fmalmeida/ngs-preprocess/raw/master/conf/defaults.config").getText())
  log.info """

  ngs-preprocess.config file saved in working directory
  After configuration, run:
  nextflow run fmalmeida/ngs-preprocess -c ./ngs-preprocess.config
  Nice code

  """.stripIndent()
  exit 0
}

/*
 * Load workflows
 */
include { NANOPORE } from './workflows/nanopore.nf'
include { PACBIO   } from './workflows/pacbio.nf'
include { ILLUMINA } from './workflows/illumina.nf'

/*
 * Define main workflow
 */
workflow {
  /*
   * User has nanopore longreads
   */
  sequencing_summary = (params.nanopore_sequencing_summary) ? Channel.fromPath(params.nanopore_sequencing_summary) : Channel.value('')
  nanopore_fastq = (params.nanopore_fastq) ? Channel.fromPath(params.nanopore_fastq) : Channel.value('')
  if (params.nanopore_fastq || params.nanopore_sequencing_summary) {
    NANOPORE(nanopore_fastq, sequencing_summary)
  }

  /*
   * User has pacbio subreads
   */
  subreads_bam = (params.pacbio_bam) ? Channel.fromPath(params.pacbio_bam) : Channel.value('')
  subreads_h5  = (params.pacbio_h5)  ? Channel.fromPath(params.pacbio_h5)  : Channel.value('')
  subreads_barcodes = (params.pacbio_barcodes) ? Channel.fromPath(params.pacbio_barcodes) : Channel.value('')
  if (params.pacbio_h5 || params.pacbio_bam) {
    PACBIO(subreads_h5, subreads_bam, subreads_barcodes)
  }
  
  /*
   * User has illumina reads
   */
  paired_reads = (params.shortreads && params.shortreads_type == 'paired') ? Channel.fromFilePairs(params.shortreads, flat: true, size: 2) : Channel.value(['', '', ''])
  unpaired_reads = (params.shortreads && params.shortreads_type == 'single') ? Channel.fromPath(params.shortreads) : Channel.value('')
  if (params.shortreads && (params.shortreads_type == 'paired' || params.shortreads_type == 'single')) {
    ILLUMINA(paired_reads, unpaired_reads)
  }
}

workflow.onComplete {
    println ""
    println "Pipeline completed at: $workflow.complete"
    println "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
    println "Execution duration: $workflow.duration"
    println "Thank you for using fmalmeida/ngs-preprocess pipeline!"
}
