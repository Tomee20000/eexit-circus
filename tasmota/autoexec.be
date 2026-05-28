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
    "CHANDGAME2":"/autoexec/handgame.be",
    "CHANDGAME3":"/autoexec/handgame.be",
    "CHANDGAME4":"/autoexec/handgame.be",
    "CBALLGAME1":"/autoexec/ballgame.be",
    "CBALLGAME2":"/autoexec/ballgame.be",
    "CBALLGAME3":"/autoexec/ballgame.be",
    "CBALLGAME4":"/autoexec/ballgame.be",
    "CBALLGAME5":"/autoexec/ballgame.be",
    "CBALLGAME6":"/autoexec/ballgame.be",
    "CSAWBOX":"/autoexec/sawbox.be",
    "CCLOWNGAME":"/autoexec/clowngame.be",
    "CLASERGUN":"/autoexec/lasergun.be",
    "CSERVICE3":"/autoexec/bicycle.be",
}

import string
log(string.format("Loading: %s", autoload_files_for_topic[topic]))
load(autoload_files_for_topic[topic])