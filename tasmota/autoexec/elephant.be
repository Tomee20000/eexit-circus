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

var color_map = ["FFFFFF","0D00FF","FF5F15","FF0000","004D1A","B10061"]

class Elephant
    var current_color, last_input, enable
    
    def init()
        self.current_color = 0
        self.last_input = 0
        self.enable = false
        light.set({"power":false, "rgb":[0]})
    end

    def enable_game()
        self.enable = true
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
        if self.enable
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

            if self.last_input != self.current_color
                self.last_input = self.current_color
                self.change_color()
            end
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
