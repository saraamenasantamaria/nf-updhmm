import groovy.json.JsonGenerator
import groovy.json.JsonGenerator.Converter

nextflow.enable.dsl=2

// comes from nf-test to store json files
params.nf_test_output  = ""

// include dependencies


// include test workflow
include { COMBINE_VCF } from '/home/u0030001/nf-updhmm_zenodo/subworkflows/local/combine_vcf/tests/../main.nf'

// define custom rules for JSON that will be generated.
def jsonOutput =
    new JsonGenerator.Options()
        .addConverter(Path) { value -> value.toAbsolutePath().toString() } // Custom converter for Path. Only filename
        .build()

def jsonWorkflowOutput = new JsonGenerator.Options().excludeNulls().build()

workflow {

    // run dependencies
    

    // workflow mapping
    def input = []
    
                input[0] = Channel.of([
                    [
                        id: 'family1',
                        sv_p: '-',
                        sv_m: '-', 
                        sv_f: '-'
                    ],
                    [
                        file('/home/u0030001/nf-updhmm_zenodo/subworkflows/local/combine_vcf/tests/data/family_01.vcf.gz', checkIfExists: true),
                        file('/home/u0030001/nf-updhmm_zenodo/subworkflows/local/combine_vcf/tests/data/family_02.vcf.gz', checkIfExists: true),
                        file('/home/u0030001/nf-updhmm_zenodo/subworkflows/local/combine_vcf/tests/data/family_03.vcf.gz', checkIfExists: true)
                    ],
                    [
                        file('/home/u0030001/nf-updhmm_zenodo/subworkflows/local/combine_vcf/tests/data/family_01.vcf.gz.tbi', checkIfExists: true),
                        file('/home/u0030001/nf-updhmm_zenodo/subworkflows/local/combine_vcf/tests/data/family_02.vcf.gz.tbi', checkIfExists: true),
                        file('/home/u0030001/nf-updhmm_zenodo/subworkflows/local/combine_vcf/tests/data/family_03.vcf.gz.tbi', checkIfExists: true)
                    ]
                ])
                
    //----

    //run workflow
    COMBINE_VCF(*input)
    
    if (COMBINE_VCF.output){

        // consumes all named output channels and stores items in a json file
        for (def name in COMBINE_VCF.out.getNames()) {
            serializeChannel(name, COMBINE_VCF.out.getProperty(name), jsonOutput)
        }	  
    
        // consumes all unnamed output channels and stores items in a json file
        def array = COMBINE_VCF.out as Object[]
        for (def i = 0; i < array.length ; i++) {
            serializeChannel(i, array[i], jsonOutput)
        }    	

    }
}


def serializeChannel(name, channel, jsonOutput) {
    def _name = name
    def list = [ ]
    channel.subscribe(
        onNext: {
            list.add(it)
        },
        onComplete: {
              def map = new HashMap()
              map[_name] = list
              def filename = "${params.nf_test_output}/output_${_name}.json"
              new File(filename).text = jsonOutput.toJson(map)		  		
        } 
    )
}


workflow.onComplete {

    def result = [
        success: workflow.success,
        exitStatus: workflow.exitStatus,
        errorMessage: workflow.errorMessage,
        errorReport: workflow.errorReport
    ]
    new File("${params.nf_test_output}/workflow.json").text = jsonWorkflowOutput.toJson(result)
    
}
