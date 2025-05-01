var topic = tasmota.cmd("Topic")["Topic"]

var autoload_files_for_topic = {
#    "SUITCASE1_1":"/autoexec/suitcase1.be",   
}
import string
log(string.format("Loading: %s", autoload_files_for_topic[topic]))
load(autoload_files_for_topic[topic])