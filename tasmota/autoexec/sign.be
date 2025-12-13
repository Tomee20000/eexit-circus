#configoni kell relére, switch-eket switch_d-re

var input1 = 21
var input2 = 19
var input3 = 18
var input4 = 17
var input5 = 16
var input6 = 4

var led1 = 32 #C1 
var led2 = 33 #I
var led3 = 25 #R
var led4 = 26 #C2
var led5 = 27 #U
var led6 = 14 #S



class Sign
    def init()

    end
end


var signdriver = Sign()

tasmota.add_driver(signdriver)

tasmota.add_cmd("pwmdimmer", /cmd, pwm_number, state -> pwm_dimmer(cmd, number(pwm_number), number(state)))


signdriver.all_on_dim()

print ("Ceiling led driver loaded")











