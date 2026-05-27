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

var input1 = 26 #
var input2 = 27 #
var input3 = 14 #
var input4 = 13 #
var input5 = 23 #
var input6 = 22 #

var color_map = ["FF0000","FFFFFF","B10061","0D00FF","004D1A","FF5F15"]

class Elephant
    var current_color, last_input, enable, blink_current, solving_started, blink_round

    def on_mqtt_message(topic, payload)
        if topic == "CHANDGAME1" && self.enable
            if !self.solving_started && payload == "000000"
                    light.set({"power":false, "rgb":"FFFFFF"})
                self.blink_round += 1
            elif !self.solving_started
                light.set({"power":true, "rgb":payload})
            end
            tasmota.cmd("State")
        end
    end
    
    def init()
        self.current_color = 0
        self.last_input = nil
        self.enable = false
        self.blink_current = 0
        self.solving_started = false
        self.blink_round = 0
        light.set({"power":false, "rgb":"FFFFFF"})
        tasmota.cmd("State")

        mqtt.subscribe("CHANDGAME1", /t, idx, data, b -> self.on_mqtt_message(t, data))

    end

    def enable_game()
        self.enable = true
        self.blink_current = 0
        self.solving_started = false
        self.blink_round = 0
        tasmota.resp_cmnd("Game enabled")
    end

    def disable_game()
        self.enable = false
        light.set({"power":false, "rgb":[0]})
        tasmota.resp_cmnd("Game disabled")
    end

    def change_color() 
        light.set({"power":true, "rgb":color_map[self.current_color]})
        mqtt.publish(tasmota.cmd("Topic")["Topic"], color_map[self.current_color])
        tasmota.cmd("State")
    end

    def every_50ms()
        if gpio.digital_read(input1)
            self.current_color = 0
        elif gpio.digital_read(input2)
            self.current_color = 1
        elif gpio.digital_read(input3)
            self.current_color = 2
        elif gpio.digital_read(input4)
            self.current_color = 3
        elif gpio.digital_read(input5)
            self.current_color = 4
        elif gpio.digital_read(input6)
            self.current_color = 5
        end

        if self.last_input == nil
            self.last_input = self.current_color
        elif self.last_input != self.current_color && self.enable && self.blink_round >= 1
            self.last_input = self.current_color
            self.change_color()
            self.solving_started = true
        end
    end
end


var elephantdriver = Elephant()

tasmota.add_driver(elephantdriver)

tasmota.add_cmd("enable", / -> elephantdriver.enable_game())
tasmota.add_cmd("disable", / -> elephantdriver.disable_game())

print("Elephant driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("enable - game enabled")
print("disable - game disabled")
print("--------------------------------------------------------------")
