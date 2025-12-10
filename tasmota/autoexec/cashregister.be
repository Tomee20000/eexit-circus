#releket configolni kell, switcheket switch_d-re kell configolni

import mqtt

var IN1 = 26
var IN2 = 27
var IN3 = 14
var IN4 = 12
var IN5 = 13
var IN6 = 23

var OUT2 = 22
var OUT3 = 21
var OUT6 = 19

var BEEPER = 4

var isButtonPushed = false

def beep_off()
    gpio.digital_write(BEEPER, gpio.LOW)
end

def button_push(message)
    if !isButtonPushed
        mqtt.publish("CASHREGISTER/KEYBOARD",message)
        tasmota.cmd("DisplayText[zr]")
        tasmota.cmd("DisplayText " + message)
        gpio.digital_write(BEEPER, gpio.HIGH)
        tasmota.set_timer(100,beep_off)
    end
    isButtonPushed = true
end

class CashRegisterDriver
    def every_100ms()
        gpio.digital_write(OUT2, gpio.HIGH)
        gpio.digital_write(OUT3, gpio.LOW) 
        gpio.digital_write(OUT6, gpio.LOW)

        if gpio.digital_read(IN1)
            button_push("5")
            return
        elif gpio.digital_read(IN2) 
            button_push("4")
            return
        elif gpio.digital_read(IN3) 
            button_push("3")
            return
        elif gpio.digital_read(IN4)
            button_push("2")
            return
        elif gpio.digital_read(IN5) 
            button_push("1")
            return
        elif gpio.digital_read(IN6) 
            button_push("0")
            return
        end

        gpio.digital_write(OUT2, gpio.LOW)
        gpio.digital_write(OUT3, gpio.HIGH) 

        if gpio.digital_read(IN2) 
            button_push("00")
            return
        elif gpio.digital_read(IN3) 
            button_push("8")
            return
        elif gpio.digital_read(IN4) 
            button_push("9")
            return
        elif gpio.digital_read(IN5) 
            button_push("7")
            return
        elif gpio.digital_read(IN6) 
            button_push("6")
            return
        end

        gpio.digital_write(OUT3, gpio.LOW)
        gpio.digital_write(OUT6, gpio.HIGH) 

        if gpio.digital_read(IN1)
            button_push("+")
            return
        elif gpio.digital_read(IN5)
            button_push("SUBTOTAL")
            return
        end

        isButtonPushed = false
    end
end
  
d1 = CashRegisterDriver()

tasmota.add_driver(d1)

print ("Cashregister driver loaded")