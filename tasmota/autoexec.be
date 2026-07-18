import string

var autoload_mod = nil
try
    import autoload
    autoload_mod = autoload
except .. as e, m
    log(string.format("Autoload import failed: %s (%s)", e, m))
end

var topic = tasmota.cmd("Topic")["Topic"]
var script_file = nil

if autoload_mod != nil
    try
        autoload_mod.init()
        script_file = autoload_mod.file_for_topic(topic)
    except .. as e, m
        log(string.format("Autoload module failed: %s (%s)", e, m))
        script_file = nil
    end
end

if script_file == nil
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
        "CCAROUSEL":"/autoexec/carousel.be",
    }

    try
        script_file = autoload_files_for_topic[topic]
    except .. as e, m
        script_file = nil
    end
end

if script_file == nil
    log(string.format("No script mapping for topic: %s", topic))
else
    log(string.format("Loading: %s", script_file))
    load(script_file)
end