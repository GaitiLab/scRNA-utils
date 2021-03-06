#!/usr/bin/env nextflow

nextflow.enable.dsl=2


include {concat_pattern_dir; addRecursiveSearch; formatFASTQInputForFastQC } from "../../utils/utils.nf"


process fastqc {

     label 'fastqc'

     publishDir path: "${output_dir}/fastqc/", mode: "copy"
   
     input:
     tuple val(name), path(reads)
     path output_dir
     
     output: 
     path ("*.zip"), emit: fastqc_outputs
     path ("*.html"), emit: fastqc_htmls
     


     script: 
     """
     fastqc --outdir . \
     -t ${task.cpus} \
     ${reads}
     """

}


process multiqc {

     label 'multiqc'

     publishDir path: "${output_dir}/multiqc/", mode: "copy"

     input: 
     path fastqc_outputs
     path output_dir
     val multiqc_title

     output: 
     path('multiqc_report.html')
     path('multiqc_report_data/multiqc_general_stats.txt')

     script: 
     """
     mkdir -p ${output_dir}/multiqc/
     multiqc --force --interactive \
     --title ${multiqc_title} \
     --filename "multiqc_report.html" \
     ${fastqc_outputs}
     """

}


workflow qc_workflow {

       main:

        fastqs = Channel.fromFilePairs( params.input_dir + '/' + addRecursiveSearch(params.recursive_search) + params.fastq_pattern )
        .ifEmpty { exit 1, "Cannot find any reads matching: ${params.input_dir} with recursive set to: ${params.recursive_search}\n" }

       // imitate a flat channel with a placeholder name and collected fastq paths
       files_for_fastqc = formatFASTQInputForFastQC(fastqs)

       fastqc(files_for_fastqc, params.output_dir)
 
       if ( params.multiqc ) {

       multiqc(fastqc.out.fastqc_outputs.collect(), params.output_dir, params.multiqc_title)

}      

}


workflow {

     main: 

      qc_workflow()

}



      
