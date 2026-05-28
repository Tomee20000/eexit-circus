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

var DRAWER = 1
var BEEPER = 0
var SCREEN = 7

var CORRECT_CODE = "12345"

class CashRegister
    var code, button_pressed, solved

    def init()
        self.code = "" 
        self.button_pressed = false
        self.solved = false

        tasmota.set_power(BEEPER, false)
        tasmota.set_power(DRAWER, true)
        tasmota.set_power(SCREEN, true)
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
        tasmota.set_timer(100, / -> self.beep_off())
    end
    
    def button_push(message)
        if !self.button_pressed

            if size(self.code) < 5 && message != "ENTER"
                self.beep()
                self.code += message
                tasmota.cmd("DisplayText[zr]")
                tasmota.cmd("DisplayText " + self.code)
                mqtt.publish("CASHREGISTER/KEYBOARD", self.code)
            end

            if message == "ENTER"
                if self.code == CORRECT_CODE
                    self.beep()
                    tasmota.set_power(DRAWER, false)
                else
                    tasmota.set_timer(100, / -> self.beep())
                    tasmota.set_timer(600, / -> self.beep())
                    tasmota.set_timer(1100, / -> self.beep())
                    tasmota.cmd("DisplayText[zr]")
                    self.code = ""
                end
            end
        end
        self.button_pressed = true
    end

    def every_50ms()

        if self.solved
            return
        end

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

        self.button_pressed = false
    end
end
  
var cash_register_driver = CashRegister()
tasmota.add_driver(cash_register_driver)

print("CashRegister driver loaded")