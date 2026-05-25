#-
#FFFFFF   (fehér)
#0D00FF   (kék – erős, tiszta)
#FF5F15   (sárga – világos, kontrasztos)
#FF0000   (piros helyett narancsos vörös)
#004D1A   (sötétzöld – eltolva, hogy ne keveredjen)
#B10061   (lila / magenta – jól elkülönül)

light.set({"power":true, "rgb":"0000FF"})
-#

import mqtt
import json

var uid_map = {"F42A6E05": 1,"B357B303": 2, "3FF4F829": 3,"0D807606": 4}
var color_map = ["FFFFFF","0D00FF","FF5F15","FF0000","004D1A","B10061"]

class Handgame1
    var enable, current_color, blink_current

    def on_mqtt_message(topic, payload)
        if topic == "CELEPHANT" && self.enable
            light.set({"power": true, "rgb": payload})
            tasmota.cmd("State")
        end
    end

    def init()
        mqtt.subscribe("CELEPHANT", /t, idx, data, b -> self.on_mqtt_message(t, data))
        light.set({"power":false, "rgb":"FFFFFF"})
        self.enable = false
        self.current_color = 0
        self.blink_current = 0
    end

    def enable_game()
        self.enable = true
        tasmota.resp_cmnd("Game enabled")
    end

    def disable_game()
        self.enable = false
        light.set({"power":false, "rgb":"FFFFFF"})
        tasmota.resp_cmnd("Game disabled")
    end

    def every_second()
        if self.current_color == 0

        end
    end
end

var handgamedriver = Handgame1()
tasmota.add_driver(handgamedriver)

tasmota.add_cmd("enable", / -> handgamedriver.enable_game())
tasmota.add_cmd("disable", / -> handgamedriver.disable_game())

print("Handgame1 driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("enable - game enabled")
print("disable - game disabled")
print("--------------------------------------------------------------")