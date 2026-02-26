#-
var input1 = 21
var input2 = 19
var input3 = 18
var input4 = 17
var input5 = 16
var input6 = 4

switchmode0 1
-#

var led1 = 0 #C1 32
var led2 = 1 #I 33
var led3 = 2 #R 25
var led4 = 3 #C2 26
var led5 = 4 #U 27
var led6 = 5 #S 14

class Sign
    def any_key(cmd, idx)
        var id = number(idx & 0xff)

        if id == 1
            tasmota.set_power(led2,!tasmota.get_power()[led2])
        elif id == 2
            tasmota.set_power(led4,!tasmota.get_power()[led4])
            tasmota.set_power(led5,!tasmota.get_power()[led5])
        elif id == 3
            tasmota.set_power(led6,!tasmota.get_power()[led6])
        elif id == 4
            tasmota.set_power(led2,!tasmota.get_power()[led2])
            tasmota.set_power(led3,!tasmota.get_power()[led3])
        elif id == 5
            tasmota.set_power(led4,!tasmota.get_power()[led4])
        elif id == 6
            tasmota.set_power(led1,!tasmota.get_power()[led1])
            tasmota.set_power(led6,!tasmota.get_power()[led6])
        end
    end
end


var signdriver = Sign()

tasmota.add_driver(signdriver)

print ("Sign driver loaded")
