#-
#FFFFFF   (fehér)
#0D00FF   (kék – erős, tiszta)
#FF5F15   (sárga – világos, kontrasztos)
#FF0000   (piros helyett narancsos vörös)
#004D1A   (sötétzöld – eltolva, hogy ne keveredjen)
#B10061   (lila / magenta – jól elkülönül)
#000000   (fekete - szünet miatt kell)

light.set({"power":true, "rgb":"0000FF"})
-#

import mqtt
import json

var uid_map = {"F42A6E05": 1,"B357B303": 2, "3FF4F829": 3,"0D807606": 4}
var color_map = ["FFFFFF","0D00FF","FF5F15","FF0000","004D1A","B10061",""]

class Handgame1
    var enable, elephant_color, next_color, blink_current, switched, blinking

    def on_mqtt_message(topic, payload)
        if topic == "tele/CHANDGAME2/SENSOR" && self.enable
            if json.load(payload).find("Switch1", nil) == nil
                return nil
            else
                if self.elephant_color == color_map[self.next_color] && self.next_color < 6
                    self.blinking = false
                    self.next_color += 1
                    light.set({"power":true, "rgb":color_map[self.elephant_color]})
                    tasmota.cmd("State")
                elif self.elephant_color != color_map[self.next_color] && self.next_color < 6
                    self.blinking = true
                    light.set({"power":false, "rgb":"FFFFFF"})
                    tasmota.cmd("State")
                end

                if self.next_color == 6
                    print("Game solved")
                    light.set({"power":true, "rgb":"008000"})
                    tasmota.cmd("State")
                end
            end
        elif topic == "CELEPHANT"
            self.elephant_color = payload
        end
    end

    def init()
        mqtt.subscribe("tele/CHANDGAME2/SENSOR", /t, idx, data, b -> self.on_mqtt_message(t, data))
        mqtt.subscribe("CELEPHANT", /t, idx, data, b -> self.on_mqtt_message(t, data))
        light.set({"power":false, "rgb":"FFFFFF"})
        tasmota.cmd("State")
        self.enable = false
        self.elephant_color = 0
        self.next_color = 0
        self.blink_current = 0
        self.switched = false
        self.blinking = false
    end

    def enable_game()
        self.enable = true
        self.blinking = true
        tasmota.resp_cmnd("Game enabled")
    end

    def disable_game()
        self.enable = false
        self.blinking = false
        light.set({"power":false, "rgb":"FFFFFF"})
        tasmota.cmd("State")
        tasmota.resp_cmnd("Game disabled")
    end

    def every_second()
        if self.blinking
            light.set({"power":true, "rgb":color_map[self.blink_current]})
            tasmota.cmd("State")

            if self.blink_current < 7
                self.blink_current += 1
            else
                self.blink_current = 0
            end
        end
    end

    def every_50ms()
        
    end
end

var handgamedriver = Handgame1()
var handgamereaderdriver = Handgamereader()

tasmota.add_driver(handgamedriver)
tasmota.add_driver(handgamereaderdriver)

tasmota.add_cmd("enable", / -> handgamedriver.enable_game())
tasmota.add_cmd("disable", / -> handgamedriver.disable_game())

print("Handgame1 driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("enable - game enabled")
print("disable - game disabled")
print("--------------------------------------------------------------")