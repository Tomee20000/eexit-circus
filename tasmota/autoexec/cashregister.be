#releket configolni kell, switcheket switch_d-re kell configolni

import mqtt
#gpio
var IN1 = 26
var IN2 = 27
var IN3 = 14
var IN4 = 12
var IN5 = 13
var IN6 = 23

var OUT2 = 22
var OUT3 = 21
var OUT6 = 19

#ser number
var DRAWER = 1

var BEEPER = 7

var correct_code = "12345"

class CashRegisterDriver
    var code, isButtonPushed, solved

    def init()
        self.code = "" 
        self.isButtonPushed = false
        self.solved = false

        tasmota.set_power(BEEPER, false)
        tasmota.cmd("DisplayText[zr]")
    end

    def beep_on()
        tasmota.set_power(BEEPER, true)
    end

    def beep_off()
        tasmota.set_power(BEEPER, false)
    end 

    def beep()
        tasmota.set_power(BEEPER, true)
        tasmota.set_timer(100,self.beep_off)
    end
    
    def button_push(message)
        if !self.isButtonPushed
            self.beep()

            if size(self.code) < 5
                self.code += message
                tasmota.cmd("DisplayText[zr]")
                tasmota.cmd("DisplayText " + message)
                mqtt.publish("CASHREGISTER/KEYBOARD",self.code)
            end

            if size(self.code) == 5 && message == "ENTER"
                if self.code == correct_code
                    tasmota.set_power(DRAWER, false)
                else
                    tasmota.set_timer(100,self.beep)
                    tasmota.set_timer(200,self.beep)
                    tasmota.set_timer(300,self.beep)
                    tasmota.set_timer(400,self.beep)
                    tasmota.set_timer(500,self.beep)
                    tasmota.cmd("DisplayText[zr]")
                    self.code = ""
                end
            end
        end
        self.isButtonPushed = true
    end

    def every_50ms()

        if self.solved
            return

        gpio.digital_write(OUT2, gpio.HIGH)
        gpio.digital_write(OUT3, gpio.LOW) 
        gpio.digital_write(OUT6, gpio.LOW)

        if gpio.digital_read(IN1)
            self.button_push("5")
            return
        elif gpio.digital_read(IN2) 
            self.button_push("4")
            return
        elif gpio.digital_read(IN3) 
            self.button_push("3")
            return
        elif gpio.digital_read(IN4)
            self.button_push("2")
            return
        elif gpio.digital_read(IN5) 
            self.button_push("1")
            return
        elif gpio.digital_read(IN6) 
            self.button_push("0")
            return
        end

        gpio.digital_write(OUT2, gpio.LOW)
        gpio.digital_write(OUT3, gpio.HIGH) 

        #-if gpio.digital_read(IN2) 
            self.button_push("00")
            return
        -#
        if gpio.digital_read(IN3) 
            self.button_push("8")
            return
        elif gpio.digital_read(IN4) 
            self.button_push("9")
            return
        elif gpio.digital_read(IN5) 
            self.button_push("7")
            return
        elif gpio.digital_read(IN6) 
            self.button_push("6")
            return
        end

        gpio.digital_write(OUT3, gpio.LOW)
        gpio.digital_write(OUT6, gpio.HIGH) 

        #-if gpio.digital_read(IN1)
            self.button_push("+")
            return
        -#
        if gpio.digital_read(IN5)
            self.button_push("ENTER")
            return
        end

        self.isButtonPushed = false
    end
end
  
d1 = CashRegisterDriver()

tasmota.add_driver(d1)

print ("Cashregister driver loaded")