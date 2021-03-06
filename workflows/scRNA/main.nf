#!/usr/bin/env nextflow

nextflow.enable.dsl=2

import java.nio.file.Path
import java.nio.file.Paths


include { fastqc; multiqc; } from "../../modules/fastqc_multiqc/main.nf"

include { pb_splitpipe } from "../../modules/split-pipe/main.nf"

include { scrublet } from "../../modules/scrublet/main.nf"

include { spaceSplit; makeCombinedMatrixPath; concat_pattern_dir; use_introns; toTranspose; addRecursiveSearch;
formatFASTQInputForFastQC } from "../../utils/utils.nf"

include { cellranger } from "../../modules/cellranger/main.nf"


/* scRNA workflow
Toggle between running split-pipe or cellranger count on scRNA samples
THe pipeline will create count matrices from FASTQ files, as well as
run FastQC, multiQC (optional), and scrublet detection */


workflow scRNA {
     
     main: 

     if ( params.method == "cellranger" || params.method == "split-pipe") {

     if (params.method == "cellranger") {

     cellranger()

     if (! params.cellranger.sample_sheet ) {

     fastqc_input = formatFASTQInputForFastQC(cellranger.out.fastq_files)
     

     fastqc(fastqc_input, params.output_dir) 
     
     if ( params.multiqc ) {
       multiqc(fastqc.out.fastqc_outputs.collect(), params.output_dir, params.multiqc_title)

       }  
     }
     scrublet_input = cellranger.out.matrices


     } else if ( params.method == "split-pipe" ) {

     pb_splitpipe()


     fastqc_input = formatFASTQInputForFastQC(pb_splitpipe.out.samples)
     
     fastqc(fastqc_input, params.output_dir)
     if ( params.multiqc ) {
       multiqc(fastqc.out.fastqc_outputs.collect(), params.output_dir, params.multiqc_title)

     }

     if (params.combine) {
     
     combine_out = pb_splitpipe.out.paths

     sample_names = Channel.fromList(file(params.sample_list).readLines()).map { i -> spaceSplit(i)[0] }

     scrublet_input = sample_names.combine(combine_out).map { i, j -> [ i,
      makeCombinedMatrixPath(j, i)] }


     }  

}

scrublet(scrublet_input, params.output_dir, params.expected_rate, params.min_counts, params.min_cells,
     params.gene_variability, params.princ_components, toTranspose(params.transpose)) 


}  else {
     println("Error: incorrect scRNA method specified. Please select one of cellranger or split-pipe.")
     System.exit(1)
}

}

workflow {
     main:
     scRNA()
}

