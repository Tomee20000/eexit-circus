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
    "CHANDGAME1":"/autoexec/handgamereader.be",
    "CHANDGAME2":"/autoexec/handgamereader.be",
    "CHANDGAME3":"/autoexec/handgamereader.be",
    "CHANDGAME4":"/autoexec/handgamereader.be",
    "CBALLGAME1":"/autoexec/ballgame.be",
    "CBALLGAME2":"/autoexec/ballgame.be",
    "CBALLGAME3":"/autoexec/ballgame.be",
    "CBALLGAME4":"/autoexec/ballgame.be",
    "CSAWBOX":"/autoexec/sawbox.be",
}

import string
log(string.format("Loading: %s", autoload_files_for_topic[topic]))
load(autoload_files_for_topic[topic])