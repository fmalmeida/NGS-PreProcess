#!/usr/bin/env nextflow
nextflow.enable.dsl=2

/*
 * Define help messages
 */
def helpMessage() {
   log.info """

   Usage:
   nextflow run fmalmeida/ngs-preprocess [--help] [ -c nextflow.config ] [OPTIONS] [-with-report] [-with-trace] [-with-timeline]

   Comments:
   This pipeline contains a massive amount of configuration variables and its usage as CLI parameters would
   cause the command to be huge.

   Therefore, it is extremely recommended to use the nextflow.config configuration file in order to make
   parameterization easier and more readable.

   Creating a configuration file:
   nextflow run fmalmeida/ngs-preprocess [--get_illumina_config] [--get_ont_config] [--get_pacbio_config]

   Show command line examples:
   nextflow run fmalmeida/ngs-preprocess --examples

   Execution Reports:
   nextflow run fmalmeida/ngs-preprocess [ -c nextflow.config ] -with-report
   nextflow run fmalmeida/ngs-preprocess [ -c nextflow.config ] -with-trace
   nextflow run fmalmeida/ngs-preprocess [ -c nextflow.config ] -with-timeline

   OBS: These reports can also be enabled through the configuration file.
   OBS 2: Make sure parameters set are double quoted

   OPTIONS:

            # Nextflow tower parameters
            # Used to display the pipeline execution in nextflow tower page
            # very useful when combined with nextflow -bg (for running in backgroung)

    --use_tower                                    Triggers the pipeline to be launched via nextflow tower
    --tower_token <token>                          Your nextflow tower token. Used to launch the pipeline in your nextflow tower account


            # General Parameters -- Mandatory

    --outdir <string>                              Output directory name

    --threads <int>                                Number of threads to use


            # Parameters for short reads preprocessing

    --shortreads <string>                          String Pattern to find short reads. Example: SRR6307304_{1,2}.fastq

    --shortreads_type <string>                     Possibilities: single | paired. Tells wheter input is single or paired end.

    --clip_r1 <int>                                Number of bases to always remove from 5' of read pair 1 or from unpaired read. [Default: 0]

    --clip_r2 <int>                                Number of bases to always remove from 5' of read pair 2. [Default: 0]

    --three_prime_clip_r1 <int>                    Number of bases to always remove from 3' of read pair 1 or from unpaired read. [Default: 0]

    --three_prime_clip_r2 <int>                    Number of bases to always remove from 3' of read pair 2. [Default: 0]

    --quality_trim <int>                           Phred quality threshold for trimming. [Default: 20]

    --lighter_execute                              Tells wheter to run or not Lighter correction tool

    --lighter_kmer <int>                           Lighter k-mer to use in correction step. [Default: 21]

    --lighter_genomeSize <int>                     Approximate genome size

    --lighter_alpha <float>                        Lighter sample rate alpha parameter. Rule of thumb: (7/C) where C is coverage.
                                                   If not set, Lighter will automatically calculate the best value

    --flash_execute                                If set, FLASH will be executed to merge paired end reads


            # Parameters for long reads filtering
            # Works with both nanopore and pacbio

    --lreads_min_length <int>                      If set, the pipeline will filter the longreads by this minimun length.

    --lreads_min_quality <int>                     If set, the pipeline will filter the longreads by this minimun quality.


            # Parameters for preprocessing NANOPORE long reads

    --nanopore_fastq <string>                      Path to ONT basecalled reads.

    --nanopore_is_barcoded                         Inform the pipeline that the data is barcoded. It will split barcodes into single files.

    --nanopore_sequencing_summary                  Path to nanopore 'sequencing_summary.txt'. Using this will make the pipeline render a
                                                   sequencing statistics report using pycoQC


            # Parameters for preprocessing PACBIO long reads
            # PACBIO bam files or legacy h5

    --pacbio_bamPath <string>                      Path to Pacbio subreads.bam. Only used if user wants to basecall subreads.bam to FASTQ.

    --pacbio_h5Path <string>                       Path to directory containing legacy *.bas.h5 data (1 per directory). It will be used to
                                                   extract reads in FASTQ file. All its related files (e.g. bax.h5 files) must be in the same directory.

    --pacbio_barcodes                              Path to xml/fasta file containing barcode information. It will split barcodes into single files.

    --pacbio_barcode_design                        By default, only reads with "same" barcodes are given. You can also select reads with only
                                                   "different" barcodes or any of them. Options: same, different, any

    --pacbio_get_hifi                              Also try to use pbccs to compute subreads consensus and produce HIFI reads. ccs combines multiple subreads
                                                   of the same SMRTbell molecule. Therefore, the bam files used as input must already be merged since this tool
                                                   takes one bam (from one movie) at a time. Can be used for the legacy *.bas.h5 since this pipeline
                                                   automatically creates one subreads.bam for each single movies (each *.bas.h5). If the chemistry is incompatible
                                                   with ccs an error will be thrown and you can re-run the pipeline removing this parameter, using '-resume'.

   """.stripIndent()
}

def exampleMessage() {
   log.info """

   Example Usages:

      Illumina paired end reads. Since it will always be a pattern match, example "illumina/SRR9847694_{1,2}.fastq.gz",
      it MUST ALWAYS be double quoted as the example below.

./nextflow run fmalmeida/ngs-preprocess --threads 3 --outdir outputs/illumina_paired --shortreads \
"illumina/SRR9847694_{1,2}.fastq.gz" --shortreads_type "paired" --lighter_execute --lighter_genomeSize 4600000 \
--clip_r1 5 --three_prime_clip_r1 5 --clip_r2 5 --three_prime_clip_r2 5 --quality_trim 30 --flash_execute


      Illumina single end reads. Multiple files at once, using fixed number of bases to be trimmed
      If multiple unpaired reads are given as input at once, pattern MUST be double quoted: "SRR9696*.fastq.gz"

./nextflow run fmalmeida/ngs-preprocess --threads 3 --outdir sample_dataset/outputs/illumina_single \
--shortreads "sample_dataset/illumina/SRR9696*.fastq.gz" --shortreads_type "single" --clip_r1 5 --three_prime_clip_r1 5


      ONT reads (filtering reads by length and quality):

./nextflow run fmalmeida/ngs-preprocess --threads 3 --outdir sample_dataset/outputs/ont \
--nanopore_fastq sample_dataset/ont/kpneumoniae_25X.fastq --lreads_min_length 500 --lreads_min_quality 10


      Pacbio raw (subreads.bam) reads with nextflow general report (filtering reads by length and quality)

./nextflow run fmalmeida/ngs-preprocess --threads 3 --outdir sample_dataset/outputs/pacbio --pacbio_get_hifi \
--pacbio_bamPath sample_dataset/pacbio/m140905_042212_sidney_c100564852550000001823085912221377_s1_X0.subreads.bam \
--lreads_min_length 500 --lreads_min_quality 15


      Pacbio raw (legacy .bas.h5 to subreads.bam) reads

./nextflow run fmalmeida/ngs-preprocess --pacbio_h5Path E01_1/Analysis_Results/ \
--outdir E01_1/Analysis_Results/preprocessed --threads 3

   """.stripIndent()
}

def configMessage() {
  log.info """

  ngs-preprocess.config file saved in working directory
  After configuration, run:
  nextflow run fmalmeida/ngs-preprocess -c ./ngs-preprocess.config
  Nice code

  """.stripIndent()
}

def illuminaMessage() {
  log.info """

  illumina_data.config file saved in working directory
  After configuration, run:
  nextflow run fmalmeida/ngs-preprocess -c ./illumina_data.config
  Nice code

  """.stripIndent()
}

def ontMessage() {
  log.info """

  ont_data.config file saved in working directory
  After configuration, run:
  nextflow run fmalmeida/ngs-preprocess -c ./ont_data.config
  Nice code

  """.stripIndent()
}

def pacbioMessage() {
  log.info """

  pacbio_data.config file saved in working directory
  After configuration, run:
  nextflow run fmalmeida/ngs-preprocess -c ./pacbio_data.config
  Nice code

  """.stripIndent()
}

/*
 * Check if user want some help
 */
params.help = false
if (params.help){
  helpMessage()
  exit 0
}
params.examples = false
if (params.examples){
  exampleMessage()
  exit 0
}

/*
 * Download configuration files if requested
 */
params.get_full_config = false
params.get_illumina_config = false
params.get_ont_config = false
params.get_pacbio_config = false

if (params.get_full_config) {
  new File("ngs-preprocess.config").write(new URL ("https://github.com/fmalmeida/ngs-preprocess/raw/master/nextflow.config").getText())
  configMessage()
  exit 0
}

if (params.get_illumina_config) {
  new File("illumina_data.config").write(new URL ("https://github.com/fmalmeida/ngs-preprocess/raw/master/configuration_example/illumina_data.config").getText())
  illuminaMessage()
  exit 0
}

if (params.get_ont_config) {
  new File("ont_data.config").write(new URL ("https://github.com/fmalmeida/ngs-preprocess/raw/master/configuration_example/ont_data.config").getText())
  ontMessage()
  exit 0
}

if (params.get_pacbio_config) {
  new File("pacbio_data.config").write(new URL ("https://github.com/fmalmeida/ngs-preprocess/raw/master/configuration_example/pacbio_data.config").getText())
  pacbioMessage()
  exit 0
}

/*
 * Load general parameters and establish defaults
 */
params.outdir = 'output'
params.threads = 2

/*
 * Parameters for short reads
 */
params.shortreads = ''
params.shortreads_type = 'paired' //paired or single
params.clip_r1 = 0
params.clip_r2 = 0
params.three_prime_clip_r1 = 0
params.three_prime_clip_r2 = 0
params.quality_trim = 20
params.lighter_execute = false
params.lighter_kmer = 21
params.lighter_genomeSize = false
params.lighter_alpha = false
params.flash_execute = false

/*
 * Parameters for longreads filtering
 */
params.lreads_min_quality = false
params.lreads_min_length  = false

/*
 * Parameters for nanopore longreads
 */
params.nanopore_fastq = ''
params.nanopore_is_barcoded = false
params.nanopore_sequencing_summary = ''

/*
 * Parameters for pacbio longreads
 */
params.pacbio_bamPath = ''
params.pacbio_h5Path = ''
params.pacbio_barcodes = ''
params.pacbio_barcode_design = 'same'
params.pacbio_get_hifi = false

/*
 * Define log message
 */
log.info "==================================="
log.info " fmalmeida/ngs-preprocess pipeline "
log.info "==================================="
def summary = [:]
summary['Output dir']   = params.outdir
if(workflow.revision) summary['Pipeline Release'] = workflow.revision
summary['Current home']   = "$HOME"
summary['Current user']   = "$USER"
summary['Current path']   = "$PWD"
log.info summary.collect { k,v -> "${k.padRight(15)}: $v" }.join("\n")
log.info "==================================="

/*
 * Include modules
 */
include { porechop } from './modules/porechop.nf' params(outdir: params.outdir)

include { nanopack; nanopack as nanopack_hifi } from './modules/nanopack.nf' params(outdir: params.outdir)

include { lreads_filter; lreads_filter as lreads_filter_hifi } from './modules/lreads_filter.nf' params(outdir: params.outdir,
  lreads_min_length: params.lreads_min_length, lreads_min_quality: params.lreads_min_quality)

include { pycoQC } from './modules/pycoQC.nf' params(outdir: params.outdir)

include { pacbio_bam2fastq } from './modules/pacbio_bam2fastq.nf' params(outdir: params.outdir,
  pacbio_barcodes: params.pacbio_barcodes, pacbio_barcode_design: params.pacbio_barcode_design,
  threads: params.threads)

include { pacbio_bam2hifi } from './modules/pacbio_bam2hifi.nf' params(outdir: params.outdir,
  pacbio_barcodes: params.pacbio_barcodes, pacbio_barcode_design: params.pacbio_barcode_design,
  threads: params.threads)

include { pacbio_h52bam } from './modules/pacbio_h52bam.nf' params(outdir: params.outdir)

include { fastqc } from './modules/fastqc.nf' params(outdir: params.outdir,
  shortreads_type: params.shortreads_type)

include { trimgalore } from './modules/trimgalore.nf' params(outdir: params.outdir,
  shortreads_type: params.shortreads_type, clip_r1: params.clip_r1,
  clip_r2: params.clip_r2, three_prime_clip_r1: params.three_prime_clip_r1,
  three_prime_clip_r2: params.three_prime_clip_r2, quality_trim: params.quality_trim)

include { lighter } from './modules/lighter.nf' params(outdir: params.outdir,
  lighter_kmer: params.lighter_kmer, lighter_alpha: params.lighter_alpha,
  shortreads_type: params.shortreads_type, lighter_genomeSize: params.lighter_genomeSize)

include { flash } from './modules/flash.nf' params(outdir: params.outdir)

/*
 * Define custom workflows
 */
workflow nanopore_nf {
  take:
    reads
    threads
    barcode
  main:
    porechop(reads, threads, barcode)
    nanopack(porechop.out[0].flatten(), threads)
    if (params.lreads_min_length || params.lreads_min_quality) {
      lreads_filter(porechop.out[0].flatten())
    }
}

workflow pycoQC_nf {
  take:
    input
  main:
    pycoQC(input)
}

workflow pacbio_bam_nf {
  take:
    subreads
    barcodes
    threads
  main:
    pacbio_bam2fastq(subreads, barcodes)
    nanopack(pacbio_bam2fastq.out[0].flatten(), threads)
    if (params.lreads_min_length || params.lreads_min_quality) {
      lreads_filter(pacbio_bam2fastq.out[0].flatten())
    }

    // User wants to get hifi?
    if (params.pacbio_get_hifi) {
      pacbio_bam2hifi(subreads, barcodes)
      nanopack_hifi(pacbio_bam2hifi.out[0].flatten(), threads)
      if (params.lreads_min_length || params.lreads_min_quality) {
        lreads_filter_hifi(pacbio_bam2hifi.out[0].flatten())
      }
    }
}

workflow pacbio_bas_nf {
  take:
    h5bas
    h5bas_dir
    barcodes
    threads
  main:
    pacbio_h52bam(h5bas, h5bas_dir)
    bams = pacbio_h52bam.out[0]
    pacbio_bam2fastq(bams, barcodes)
    nanopack(pacbio_bam2fastq.out[0].flatten(), threads)
    if (params.lreads_min_length || params.lreads_min_quality) {
      lreads_filter(pacbio_bam2fastq.out[0].flatten())
    }

    // User wants to get hifi?
    if (params.pacbio_get_hifi) {
      pacbio_bam2hifi(bams, barcodes)
      nanopack_hifi(pacbio_bam2hifi.out[0].flatten(), threads)
      if (params.lreads_min_length || params.lreads_min_quality) {
        lreads_filter_hifi(pacbio_bam2hifi.out[0].flatten())
      }
    }
}

workflow shortreads_nf {
  take:
    preads
    sreads
    threads
  main:
    fastqc(preads, sreads, threads)
    trimgalore(preads, sreads, threads)

    // Paired
    if (params.shortreads_type == 'paired') {
      if (params.lighter_execute && params.flash_execute) {
        lighter(trimgalore.out[0], threads)
        flash(lighter.out[0], threads)
      } else if (params.lighter_execute && !params.flash_execute) {
        lighter(trimgalore.out[0], threads)
      } else if (!params.lighter_execute && params.flash_execute) {
        flash(trimgalore.out[0], threads)
      }
    }

    // Single
    if (params.shortreads_type == 'single') {
      if (params.lighter_execute) {
        lighter(trimgalore.out[1].flatten(), threads)
      }
    }
}

/*
 * Define main workflow
 */
workflow {
  /*
   * User has nanopore longreads
   */
  if (params.nanopore_fastq) {
    nanopore_nf(Channel.fromPath(params.nanopore_fastq), params.threads, params.nanopore_is_barcoded)
  }

  /*
   * User wants to render a report with pycoQC
   */
  if (params.nanopore_sequencing_summary) {
    pycoQC_nf(Channel.fromPath(params.nanopore_sequencing_summary))
  }

  /*
   * User has pacbio subreads in bam format
   */
  if (params.pacbio_bamPath) {
    pacbio_bam_nf(Channel.fromPath(params.pacbio_bamPath),
                  (params.pacbio_barcodes) ? Channel.fromPath(params.pacbio_barcodes) : Channel.value(''),
                  params.threads)
  }

  /*
   * User has pacbio subreads in legacy h5 (bas and bax) files
   */
  if (params.pacbio_h5Path) {
    pacbio_bas_nf(Channel.fromPath(params.pacbio_h5Path),
                  Channel.fromPath(params.pacbio_h5Path, type: 'dir'),
                  (params.pacbio_barcodes) ? Channel.fromPath(params.pacbio_barcodes) : Channel.value(''),
                  params.threads)
  }

  /*
   * User has short paired end reads
   */
  if (params.shortreads && params.shortreads_type == 'paired') {
    shortreads_nf(Channel.fromFilePairs(params.shortreads, flat: true, size: 2),
                  Channel.value(''), params.threads)
  }

  /*
   * User has short single end reads
   */
  if (params.shortreads && params.shortreads_type == 'single') {
    shortreads_nf(Channel.value(['', '', '']), Channel.fromPath(params.shortreads), params.threads)
  }
}

workflow.onComplete {
    println ""
    println "Pipeline completed at: $workflow.complete"
    println "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
    println "Execution duration: $workflow.duration"
    println "Thank you for using fmalmeida/ngs-preprocess pipeline!"
}
