#-
#FFFFFF   (fehér)
#0D00FF   (kék – erős, tiszta)
#FF5F15   (sárga – világos, kontrasztos)
#FF0000   (piros helyett narancsos vörös)
#004D1A   (sötétzöld – eltolva, hogy ne keveredjen)
#B10061   (lila / magenta – jól elkülönül)
#000000   (fekete - szünet)

light.set({"power":true, "rgb":"0000FF"})
-#

import mqtt
import json

var UID_MAP = {"F42A6E05": 1,"B357B303": 2, "3FF4F829": 3,"0D807606": 4}
var COLOR_MAP = ["FFFFFF","0D00FF","FF5F15","FF0000","004D1A","B10061"]

class Handgame1
    var enable, elephant_color, next_color, blink_current, blinking, solving_started

    def game_solved_blink()
        light.set({"power":false, "rgb":"008000"})
        tasmota.delay(250)
        light.set({"power":true, "rgb":"008000"})
        tasmota.delay(250)
        light.set({"power":false, "rgb":"008000"})
        tasmota.delay(250)
        light.set({"power":true, "rgb":"008000"})
        tasmota.delay(250)
        light.set({"power":false, "rgb":"008000"})
        tasmota.delay(250)
        light.set({"power":true, "rgb":"008000"})
        tasmota.delay(250)
        light.set({"power":false, "rgb":"008000"})
        tasmota.cmd("State")
    end

    def on_mqtt_message(topic, payload)
        if topic == "tele/CHANDGAME2/SENSOR" && self.enable
            if json.load(payload).find("Switch1", nil) == nil
                return nil
            else
                if self.elephant_color == COLOR_MAP[self.next_color] && self.next_color < 6
                    self.solving_started = true
                    self.next_color += 1

                    light.set({"power":false, "rgb":self.elephant_color})
                    tasmota.delay(250)
                    light.set({"power":true, "rgb":self.elephant_color})
                    tasmota.delay(250)
                    light.set({"power":false, "rgb":self.elephant_color})
                    tasmota.delay(250)
                    light.set({"power":true, "rgb":self.elephant_color})
                    tasmota.delay(250)
                    light.set({"power":false, "rgb":self.elephant_color})
                    tasmota.delay(250)
                    light.set({"power":true, "rgb":self.elephant_color})
                    tasmota.cmd("State")
                elif self.elephant_color != COLOR_MAP[self.next_color] && self.next_color < 6
                    if self.solving_started
                        light.set({"power":false, "rgb":COLOR_MAP[0]})
                        tasmota.cmd("State")
                        self.elephant_color = nil
                        self.next_color = 0
                        self.blink_current = 0
                        self.solving_started = false
                    end
                end

                if self.next_color == 6
                    print("Game solved")
                    self.enable = false
                    self.solving_started = false
                    tasmota.set_timer(1000, / -> self.game_solved_blink())
                end
            end
        elif topic == "CELEPHANT"
            self.elephant_color = payload
            if self.solving_started
                light.set({"power":true, "rgb":self.elephant_color})
                tasmota.cmd("State")
            end
        end
    end

    def init()
        mqtt.subscribe("tele/CHANDGAME2/SENSOR", /t, idx, data, b -> self.on_mqtt_message(t, data))
        mqtt.subscribe("CELEPHANT", /t, idx, data, b -> self.on_mqtt_message(t, data))
        light.set({"power":false, "rgb":"FFFFFF"})
        tasmota.cmd("State")
        self.enable = false
        self.elephant_color = nil
        self.next_color = 0
        self.blink_current = 0
        self.solving_started = false
    end

    def enable_game()
        self.enable = true
        self.solving_started = false
        self.elephant_color = nil
        self.next_color = 0
        self.blink_current = 0
        tasmota.resp_cmnd("Game enabled")
    end

    def disable_game()
        self.enable = false
        light.set({"power":false, "rgb":"FFFFFF"})
        tasmota.cmd("State")
        tasmota.resp_cmnd("Game disabled")
    end

    def every_second()
        if !self.solving_started && self.enable
            if self.blink_current < 6
                mqtt.publish(tasmota.cmd("Topic")["Topic"], COLOR_MAP[self.blink_current])
                light.set({"power":true, "rgb":COLOR_MAP[self.blink_current]})
                self.blink_current += 1
            else    
                self.blink_current = 0
                mqtt.publish(tasmota.cmd("Topic")["Topic"], "000000")
                light.set({"power":false, "rgb":COLOR_MAP[self.blink_current]})
            end
            tasmota.cmd("State")
        end
    end
end

var handgame_driver = Handgame1()
var handgamereaderdriver = Handgamereader()

tasmota.add_driver(handgamereaderdriver)
tasmota.add_driver(handgame_driver)


tasmota.add_cmd("enable", / -> handgame_driver.enable_game())
tasmota.add_cmd("disable", / -> handgame_driver.disable_game())

print("Handgame1 driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("enable - game enabled")
print("disable - game disabled")
print("--------------------------------------------------------------")