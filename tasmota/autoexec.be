import autoload
var topic = tasmota.cmd("Topic")["Topic"]

var autoload_files_for_topic = {
    "CCLAWMACHINE1":"/autoexec/clawmachine.be",  
    "CCASHREGISTER":"/autoexec/cashregister.be",    
    "CDUCKGAME":"/autoexec/duckgame.be",
    "CCEILINGLED":"/autoexec/ceilingled.be",
    "CSIGN":"/autoexec/sign.be",
    "CANIMALWHEEL":"/autoexec/animalwheel.be",
    "CCYLINDER":"/autoexec/cylinder.be",
    "CKNIFEGAME":"/autoexec/knifegame.be",  
    "CELEPHANT":"/autoexec/elephant.be",
    "CHANDGAME1":"/autoexec/handgame1.be",
    "CHANDGAME2":"/autoexec/handgame2.be",
    "CHANDGAME3":"/autoexec/handgame3.be",
    "CHANDGAME4":"/autoexec/handgame4.be",
}

import string
log(string.format("Loading: %s", autoload_files_for_topic[topic]))
load(autoload_files_for_topic[topic])