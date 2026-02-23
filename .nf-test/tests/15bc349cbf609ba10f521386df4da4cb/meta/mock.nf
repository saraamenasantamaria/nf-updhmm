import groovy.json.JsonGenerator
import groovy.json.JsonGenerator.Converter

nextflow.enable.dsl=2

// comes from nf-test to store json files
params.nf_test_output  = ""

// include dependencies

include { BCFTOOLS_VIEW  } from '/home/u0030001/nf-updhmm_zenodo/subworkflows/local/event_detection/tests/../../../../modules/nf-core/bcftools/view/main.nf'


// include test workflow
include { EVENT_DETECTION } from '/home/u0030001/nf-updhmm_zenodo/subworkflows/local/event_detection/tests/../main.nf'

// define custom rules for JSON that will be generated.
def jsonOutput =
    new JsonGenerator.Options()
        .addConverter(Path) { value -> value.toAbsolutePath().toString() } // Custom converter for Path. Only filename
        .build()

def jsonWorkflowOutput = new JsonGenerator.Options().excludeNulls().build()

workflow {

    // run dependencies
    
    {
        def input = []
        
                input[0] = Channel.of([
                    [ id:'test_trio' ],
                    file(params.modules_testdata_base_path + 'genomics/homo_sapiens/genome/vcf/ped/justhusky_minimal.vcf.gz', checkIfExists: true),
                    []
                ])
                input[1] = []  // regions
                input[2] = []  // targets
                input[3] = []  // samples
                
        BCFTOOLS_VIEW(*input)
    }
    

    // workflow mapping
    def input = []
    
                input[0] = BCFTOOLS_VIEW.out.vcf.map { meta, vcf ->
                    [
                        [ id:'test_trio',
                          proband_id: 'hugelymodelbat',
                          mother_id: 'slowlycivilbuck',
                          father_id: 'earlycasualcaiman' 
                        ],
                        vcf,
                        []
                    ]
                }
                
    //----

    //run workflow
    EVENT_DETECTION(*input)
    
    if (EVENT_DETECTION.output){

        // consumes all named output channels and stores items in a json file
        for (def name in EVENT_DETECTION.out.getNames()) {
            serializeChannel(name, EVENT_DETECTION.out.getProperty(name), jsonOutput)
        }	  
    
        // consumes all unnamed output channels and stores items in a json file
        def array = EVENT_DETECTION.out as Object[]
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
