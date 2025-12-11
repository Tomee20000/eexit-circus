import autoload
var topic = tasmota.cmd("Topic")["Topic"]

var autoload_files_for_topic = {
    "CCLAWMACHINE_CONTROLLER":"/autoexec/clawmachine.be",  
    "CCASHREGISTER":"/autoexec/cashregister.be",    
    "CDUCKGAME":"/autoexec/duckgame.be",
    "CCEILINGLED":"/autoexec/ceilingled.be",  
}

import string
log(string.format("Loading: %s", autoload_files_for_topic[topic]))
load(autoload_files_for_topic[topic])