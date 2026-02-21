import groovy.json.JsonGenerator
import groovy.json.JsonGenerator.Converter

nextflow.enable.dsl=2

// comes from nf-test to store json files
params.nf_test_output  = ""

// include dependencies


// include test workflow
include { FILTER_LOWCONF } from '/home/u0030001/nf-updhmm_zenodo/subworkflows/local/filter_lowconf/tests/../main.nf'

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
                        id: 'trio_test',
                        sv_p: '-',
                        sv_m: '-', 
                        sv_f: '-'
                    ],
                    file('/home/u0030001/nf-updhmm_zenodo/subworkflows/local/filter_lowconf/tests/data/trio_test.vcf.gz', checkIfExists: true),
                    file('/home/u0030001/nf-updhmm_zenodo/subworkflows/local/filter_lowconf/tests/data/trio_test.vcf.gz.tbi', checkIfExists: true)
                ])
                input[1] = false
                input[2] = true
                
    //----

    //run workflow
    FILTER_LOWCONF(*input)
    
    if (FILTER_LOWCONF.output){

        // consumes all named output channels and stores items in a json file
        for (def name in FILTER_LOWCONF.out.getNames()) {
            serializeChannel(name, FILTER_LOWCONF.out.getProperty(name), jsonOutput)
        }	  
    
        // consumes all unnamed output channels and stores items in a json file
        def array = FILTER_LOWCONF.out as Object[]
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
