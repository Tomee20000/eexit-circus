#-
#0072B2   (kék – erős, tiszta)
#F0E442   (sárga – világos, kontrasztos)
#D55E00   (piros helyett narancsos vörös)
#117733   (sötétzöld – eltolva, hogy ne keveredjen)
#CC79A7   (lila / magenta – jól elkülönül)
#FFFFFF   (fehér)

light.set({"power":true, "rgb":"0000FF"})
-#

import mqtt

var input1 = 0 #
var input2 = 0 #
var input3 = 0 #
var input4 = 0 #
var input5 = 0 #
var input6 = 0 #

var color_map = ["FFFFFF","0072B2","F0E442","D55E00","117733","CC79A7"]

class Elephant
    var current_color, last_input, enable
    
    def init()
        self.current_color = 0
        self.last_input = 0
        self.enable = false
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
        light.set({"power":true, "rgb":[self.current_color]})
        mqtt.publish(tasmota.cmd("Topic")["Topic"], [self.current_color])
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
