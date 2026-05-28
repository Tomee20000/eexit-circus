#-
var input1 = 21
var input2 = 19
var input3 = 18
var input4 = 17
var input5 = 16
var input6 = 4

switchmode0 1
-#

var LED1 = 0 #C1 32
var LED2 = 1 #I 33
var LED3 = 2 #R 25
var LED4 = 3 #C2 26
var LED5 = 4 #U 27
var LED6 = 5 #S 14

class Sign
    def any_key(cmd, idx)
        var id = number(idx & 0xff)

        if id == 1
            tasmota.set_power(LED2,!tasmota.get_power()[LED2])
        elif id == 2
            tasmota.set_power(LED4,!tasmota.get_power()[LED4])
            tasmota.set_power(LED5,!tasmota.get_power()[LED5])
        elif id == 3
            tasmota.set_power(LED6,!tasmota.get_power()[LED6])
        elif id == 4
            tasmota.set_power(LED2,!tasmota.get_power()[LED2])
            tasmota.set_power(LED3,!tasmota.get_power()[LED3])
        elif id == 5
            tasmota.set_power(LED4,!tasmota.get_power()[LED4])
        elif id == 6
            tasmota.set_power(LED1,!tasmota.get_power()[LED1])
            tasmota.set_power(LED6,!tasmota.get_power()[LED6])
        end
    end
end


var sign_driver = Sign()

tasmota.add_driver(sign_driver)

print("Sign driver loaded")
