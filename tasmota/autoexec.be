var topic = tasmota.cmd("Topic")["Topic"]

var autoload_files_for_topic = {
    "CLAWMACHINE_CONTROLLER":"/autoexec/clawmachine.be",   
}
import string
log(string.format("Loading: %s", autoload_files_for_topic[topic]))
load(autoload_files_for_topic[topic])