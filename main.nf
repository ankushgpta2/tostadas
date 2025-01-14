#!/usr/bin/env nextflow
nextflow.enable.dsl=2

def helpMessage() {
  log.info """
        Usage:
        The general command for running nextflow with values set in config:
        nextflow run main.nf

        To pass in arguments and override params in config:
        nextflow run main.nf --<param name> <param value>

        To access a specific sub-workflow via entrypoint:
        nextflow run main.nf -entry <name of sub workflow>

        Mandatory Arguments (either set in config of passed through command line):
         --meta_path                            Path to the metadata file (accepts string)
         --fasta_path                           Path to the fasta file (accepts string)
         --ref_fasta_path                       Path to the reference fasta file (accepts string)
         --ref_gff_path                         Path to the reference gff file (accepts string)

         --scicomp                              Flag for whether running on scicomp server or not (accepts bool: true/false)
         --docker_container                     Name of the docker container (accepts string)

         --run_submission                       Flag for whether to run submission portion or not (accepts bool: true/false)
         --cleanup                              Flag for whether to run the cleanup process (accepts bool: true/false)

         --clear_nextflow_log                   Defines the cleanup process further: whether to clear the nextflow log files (accepts bool: true/false)
         --clear_work_dir                       Defines the cleanup process further: whether to clear the work directory (accepts bool: true/false)
         --clear_conda_env                      Defines the cleanup process further: whether to clear the conda environment (accepts bool: true/false)
         --clear_nf_results                     Defines the cleanup process further: whether to clear the previous generated results (accepts bool: true/false)

         --env_yml                              Path to the .yml file for building the cond environment from (accepts string)
         --output_dir                           Name of the output directory for the results from nextflow (accepts string)
         --overwrite_output                     Flag for whether to overwrite the existing files in the output directory (accepts bool: true/false)
         --final_liftoff_output_dir             Name of the output directory for the annotation pipeline (accepts string)
         --val_output_dir                       Name of the output directory for the validation pipeline (accepts string)

         --val_date_format_flag                 Flag corresponding to format for date, possible options are 's', 'o', 'v'. Please consult documentation for more info.
         --val_keep_pi                          Flag to keep personal information or not (accepts bool: true/false)

         --lift_print_version_exit              Flag to print out the version of liftoff and exit (accepts bool: true/false)
         --lift_print_help_exit                 Flag to print out the help message for liftoff and exit (accepts bool: true/false)
         --lift_parallel_processes              Number of parallel processes to run when running liftoff (accepts integer)
         --lift_delete_temp_files               Flag to delete temporary files generated during annotation (accepts bool: true/false)
         --lift_coverage_threshold              Designate a feature mapped only if it aligns with coverage ≥A
         --lift_child_feature_align_threshold   Designate a feature mapped only if its child features usually exons/CDS align with sequence identity ≥S
         --lift_unmapped_features_file_name     Name of unmapped features file name
         --lift_copy_threshold                  Minimum sequence identity in exons/CDS for which a gene is considered a copy; must be greater than -s; default is 1.0
         --lift_distance_scaling_factor         Alignment nodes separated by more than a factor of D in the target genome will not be connected in the graph; by default D=2.0
         --lift_flank                           Amount of flanking sequence to align as a fraction [0.0-1.0] of gene length. This can improve gene alignment where gene structure differs between target and reference; by default F=0.0
         --lift_overlap                         Maximum fraction [0.0-1.0] of overlap allowed by 2 features; by default O=0.1
         --lift_mismatch                        Mismatch penalty in exons when finding best mapping; by default M=2
         --lift_gap_open                        Gap open penalty in exons when finding best mapping; by default GO=2
         --lift_gap_extend                      Gap extend penalty in exons when finding best mapping; by default GE=1
         --lift_infer_transcripts               Use if annotation file only includes exon/CDS features and does not include transcripts/mRNA
         --lift_copies                          Look for extra gene copies in the target genome
         --lift_minimap_path                    Path to minimap if you did not use conda or pip
         --lift_feature_database_name           Name of the feature database, if none, then will use ref gff path to construct one

         --submission_only_meta                 Path to the validated metadata directory if calling submission entrypoint (accepts string)
         --submission_only_gff                  Path to the reformatted gff directory if calling submission entrypoint (accepts string)
         --submission_only_fasta                Path to the split fasta files directory if calling submission entrypoint (accepts string)
         --processed_samples                    Path to the directory containing processed samples <batch_name>.<sample name> for update only entrypoint (accepts string)
         --submission_config                    Path to the configuration file used for the submission process (accepts string)
         --req_col_config                       Path to the required_columns.yaml file (accepts string)
         --submission_prod_or_test              Denotes whether to submit as a test or production (accepts string: test/prod)
         --batch_name                           Prefixes the sample names to group together certain samples during submission
         --send_submission_email                Flag for whether or not to send a notification email (specified in submission config) during genbank/table2asn submission (accepts bool: true/false)
         --submission_database                  Name of database for sample submissions; by default is 'submit' (accepts string: submit/genbank/sra/gisaid/biosample/joint_sra_biosample/all)

       Optional arguments:
        --submission_wait_time                  Overwrites the default calculation of (3 * 60 * num samples) in seconds for wait time after initial submission
        --help                                  Flag to call in help statements mentioned in this block
        """
}
    
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                         GET NECESSARY MODULES OR SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
// get the utility processes
include { VALIDATE_PARAMS } from "$projectDir/nf_modules/utility_mods"
include { CLEANUP_FILES } from "$projectDir/nf_modules/utility_mods"
include { SUBMISSION_ENTRY_CHECK } from "$projectDir/nf_modules/utility_mods"
include { PREP_SUBMISSION_ENTRY } from "$projectDir/nf_modules/utility_mods"
include { PREP_UPDATE_SUBMISSION_ENTRY } from "$projectDir/nf_modules/utility_mods"
include { GET_WAIT_TIME } from "$projectDir/nf_modules/utility_mods"

// get the main processes
include { METADATA_VALIDATION } from "$projectDir/nf_modules/main_mods"
include { LIFTOFF } from "$projectDir/nf_modules/main_mods"
include { VADR } from "$projectDir/nf_modules/main_mods"
include { SUBMISSION } from "$projectDir/nf_modules/main_mods"
include { UPDATE_SUBMISSION } from "$projectDir/nf_modules/main_mods"

// get the subworkflows
include { RUN_SUBMISSION } from "$projectDir/nf_subworkflows/submission"
include { RUN_UTILITY } from "$projectDir/nf_subworkflows/utility"

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                                    MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
workflow {

    // check if help parameter is set
    if ( params.help == true ) {
        helpMessage()
        exit 0
    }

    // run cleanup
    RUN_UTILITY()

    // run metadata validation process
    METADATA_VALIDATION ( 
        RUN_UTILITY.out, 
        params.meta_path, 
        params.fasta_path 
    )
        
    // run liftoff annotation process 
    LIFTOFF ( 
        RUN_UTILITY.out, 
        params.meta_path, 
        params.fasta_path, 
        params.ref_fasta_path, 
        params.ref_gff_path 
    )

    // run submission for the annotated samples 
    if ( params.run_submission == true ) {

        // pre submission process + get wait time (parallel)
        GET_WAIT_TIME ( 
            METADATA_VALIDATION.out.meta_signal, 
            LIFTOFF.out.liftoff_signal, 
            METADATA_VALIDATION.out.tsv_Files.collect() 
        )

        // call the submission workflow
        RUN_SUBMISSION (
            METADATA_VALIDATION.out.meta_signal, 
            LIFTOFF.out.liftoff_signal,
            METADATA_VALIDATION.out.tsv_Files.sort().flatten(), 
            LIFTOFF.out.fasta.sort().flatten(), 
            LIFTOFF.out.gff.sort().flatten(), 
            false, 
            params.submission_config, 
            params.req_col_config, 
            GET_WAIT_TIME.out 
        )
    }
} 

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                                    SUB WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow only_validate_params {
    main:
        // run the process for validating general parameters
        VALIDATE_PARAMS ()
}

workflow only_cleanup_files {
    main:
        // run process for cleaning up files 
        CLEANUP_FILES (
            'dummy validate params signal' 
        )
}

workflow only_validation {
    main:
        // run metadata validation
        METADATA_VALIDATION (
            'dummy signal signal', 
            params.meta_path, 
            params.fasta_path
        )
}

workflow only_liftoff {
    main:
        // run annotation on files
        LIFTOFF ( 
            'dummy utility signal', 
            params.meta_path, 
            params.fasta_path, 
            params.ref_fasta_path, 
            params.ref_gff_path 
        )
}

workflow only_vadr {
    main:
        // run annotation on files
        VADR ( 
            'dummy utility signal', 
            params.fasta_path 
        )
}

workflow only_submission {
    main:
        // check that certain paths are specified (need to pass in for it to work)
        SUBMISSION_ENTRY_CHECK ()

        // get the parameter paths into proper format 
        PREP_SUBMISSION_ENTRY ( 
            SUBMISSION_ENTRY_CHECK.out,
            params.submission_only_meta, 
            params.submission_only_fasta, 
            params.submission_only_gff, 
            false
        )

        // get the wait time
        GET_WAIT_TIME ( 
            'dummy meta signal', 
            'dummy liftoff signal', 
            PREP_SUBMISSION_ENTRY.out.tsv.collect() 
        )
        
        // call the submission workflow
        RUN_SUBMISSION (
            'dummy meta signal',
            'dummy annotation signal',
            PREP_SUBMISSION_ENTRY.out.tsv.sort().flatten(),
            PREP_SUBMISSION_ENTRY.out.fasta.sort().flatten(),
            PREP_SUBMISSION_ENTRY.out.gff.sort().flatten(), 
            true,
            params.submission_config,
            params.req_col_config,
            GET_WAIT_TIME.out
        )
}

workflow only_initial_submission {
    main:        
        // check that certain paths are specified (need to pass in for it to work)
        SUBMISSION_ENTRY_CHECK ()

        // get the parameter paths into proper format 
        PREP_SUBMISSION_ENTRY ( 
            SUBMISSION_ENTRY_CHECK.out,
            params.submission_only_meta, 
            params.submission_only_fasta, 
            params.submission_only_gff, 
            false
        )

        // call the initial submission portion only
        SUBMISSION (
            PREP_SUBMISSION_ENTRY.out.tsv.sort().flatten(),
            PREP_SUBMISSION_ENTRY.out.fasta.sort().flatten(),
            PREP_SUBMISSION_ENTRY.out.gff.sort().flatten(), 
            true,
            params.submission_config,
            params.req_col_config
        )
}

workflow only_update_submission {
    main:

        // call the check specific to submission
        SUBMISSION_ENTRY_CHECK ()

        // get the parameter paths into proper format 
        PREP_UPDATE_SUBMISSION_ENTRY ( 
            SUBMISSION_ENTRY_CHECK.out,
            true, 
            params.processed_samples
        )

        // call the update submission portion only
        UPDATE_SUBMISSION (
            SUBMISSION_ENTRY_CHECK.out,
            params.submission_config,
            PREP_UPDATE_SUBMISSION_ENTRY.out.samples.flatten()
        )
}
 