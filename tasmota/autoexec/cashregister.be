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

var CORRECT_CODE = "5317813775"

class CashRegister
    var code, submitted_code, solved, enabled
    var held_key
    var beep_active, beep_deadline
    var wrong_beeps_left, next_wrong_beep
    var clear_wrong_deadline, clear_wrong_active
    var fast_loop_closure
    var last_status

    def init()
        self.enabled = true
        self.fast_loop_closure = / -> self.fast_loop()

        self.code = ""
        self.submitted_code = ""
        self.solved = false
        self.held_key = nil

        self.beep_active = false
        self.beep_deadline = 0

        self.wrong_beeps_left = 0
        self.next_wrong_beep = 0

        self.clear_wrong_deadline = 0
        self.clear_wrong_active = false
        self.last_status = ""

        self.reset()

        tasmota.add_fast_loop(self.fast_loop_closure)
    end

    def all_rows_off()
        gpio.digital_write(OUT2, gpio.LOW)
        gpio.digital_write(OUT3, gpio.LOW)
        gpio.digital_write(OUT6, gpio.LOW)
    end

    def stop_beeper()
        self.beep_active = false
        self.beep_deadline = 0
        tasmota.set_power(BEEPER, false)
    end

    def beep()
        if !self.enabled
            return
        end

        self.beep_deadline = tasmota.millis(90)

        if !self.beep_active
            self.beep_active = true
            tasmota.set_power(BEEPER, true)
        end
    end

    def service_beeper()
        if self.beep_active && tasmota.time_reached(self.beep_deadline)
            self.beep_active = false
            tasmota.set_power(BEEPER, false)
        end

        if self.wrong_beeps_left > 0
            if tasmota.time_reached(self.next_wrong_beep)
                self.beep()
                self.wrong_beeps_left -= 1

                if self.wrong_beeps_left > 0
                    self.next_wrong_beep = tasmota.millis(500)
                end
            end
        end
    end

    def service_display_timer()
        if self.clear_wrong_active
            if tasmota.time_reached(self.clear_wrong_deadline)
                self.clear_wrong_active = false

                if self.enabled && !self.solved
                    self.code = ""
                    tasmota.cmd("DisplayText[zr]")
                end
            end
        end
    end

    def code_payload(value)
        return '{"data":"' .. value .. '"}'
    end

    def publish_current_code()
        mqtt.publish(
            "CASHREGISTER/CURRENT_CODE",
            self.code_payload(self.code),
            true
        )
    end

    def publish_submitted_code()
        mqtt.publish(
            "CASHREGISTER/SUBMITTED_CODE",
            self.code_payload(self.submitted_code),
            true
        )
    end

    def build_status()
        return '{"enabled":' .. (self.enabled ? "true" : "false") .. ',"solved":' .. (self.solved ? "true" : "false") .. ',"code":"' .. self.code .. '","submitted_code":"' .. self.submitted_code .. '","drawer_open":' .. (!tasmota.get_power()[DRAWER] ? "true" : "false") .. '}'
    end

    def publish_status()
        var msg = self.build_status()

        if msg == self.last_status
            return
        end

        self.last_status = msg
        mqtt.publish("CASHREGISTER/STATUS", msg, true)
    end

    def reset()
        self.code = ""
        self.submitted_code = ""
        self.solved = false
        self.held_key = nil

        self.wrong_beeps_left = 0
        self.clear_wrong_active = false

        self.stop_beeper()
        self.all_rows_off()

        tasmota.set_power(DRAWER, true)

        if self.enabled
            tasmota.set_power(SCREEN, true)
            tasmota.cmd("DisplayText[zr]")
        else
            tasmota.set_power(SCREEN, false)
        end

        mqtt.publish("CASHREGISTER/KEYBOARD", "-", true)
        self.publish_current_code()
        self.publish_submitted_code()
        self.last_status = ""
        self.publish_status()
    end

    def show_code()
        if !self.enabled
            return
        end

        tasmota.cmd("DisplayText[zr]")
        tasmota.cmd("DisplayText " + self.code)
    end

    def wrong_code()
        mqtt.publish(
            "CASHREGISTER",
            '{"data":"WRONG"}'
        )

        self.code = ""
        mqtt.publish("CASHREGISTER/KEYBOARD", "-", true)
        self.publish_current_code()

        tasmota.cmd("DisplayText[zr]")
        tasmota.cmd("DisplayText WRONG CODE")

        self.wrong_beeps_left = 3
        self.next_wrong_beep = tasmota.millis(100)

        self.clear_wrong_active = true
        self.clear_wrong_deadline = tasmota.millis(2000)
        self.publish_status()
    end

    def correct_code()
        mqtt.publish(
            "CASHREGISTER",
            '{"data":"SOLVED"}'
        )

        self.wrong_beeps_left = 0
        self.clear_wrong_active = false

        self.beep()
        self.solved = true
        self.code = ""

        self.all_rows_off()

        tasmota.cmd("DisplayText[zr]")
        tasmota.cmd("DisplayText CORRECT CODE")
        tasmota.set_power(DRAWER, false)
        mqtt.publish("CASHREGISTER/KEYBOARD", "-", true)
        self.publish_current_code()
        self.publish_status()
    end

    def button_push(key)
        if !self.enabled || self.solved
            return
        end

        if key == "ENTER"
            self.submitted_code = self.code
            self.publish_submitted_code()

            if self.code == CORRECT_CODE
                self.correct_code()
            else
                self.wrong_code()
            end

            return
        end

        if size(self.code) < size(CORRECT_CODE)
            self.beep()
            self.code += key
            self.show_code()
            mqtt.publish("CASHREGISTER/KEYBOARD", self.code, true)
            self.publish_current_code()
            self.publish_status()
        end
    end

    def read_row_1()
        self.all_rows_off()
        gpio.digital_write(OUT2, gpio.HIGH)
        tasmota.delay(1)

        if gpio.digital_read(IN1)
            return "5"
        elif gpio.digital_read(IN2)
            return "4"
        elif gpio.digital_read(IN3)
            return "3"
        elif gpio.digital_read(IN4)
            return "2"
        elif gpio.digital_read(IN5)
            return "1"
        elif gpio.digital_read(IN6)
            return "0"
        end

        return nil
    end

    def read_row_2()
        self.all_rows_off()
        gpio.digital_write(OUT3, gpio.HIGH)
        tasmota.delay(1)

        #- IN2 = "00" -#

        if gpio.digital_read(IN3)
            return "8"
        elif gpio.digital_read(IN4)
            return "9"
        elif gpio.digital_read(IN5)
            return "7"
        elif gpio.digital_read(IN6)
            return "6"
        end

        return nil
    end

    def read_row_3()
        self.all_rows_off()
        gpio.digital_write(OUT6, gpio.HIGH)
        tasmota.delay(1)

        #- IN1 = "+" -#

        if gpio.digital_read(IN5)
            return "ENTER"
        end

        return nil
    end

    def read_keyboard()
        var key = self.read_row_1()

        if key == nil
            key = self.read_row_2()
        end

        if key == nil
            key = self.read_row_3()
        end

        self.all_rows_off()
        return key
    end

    def fast_loop()
        self.service_beeper()
        self.service_display_timer()

        if !self.enabled || self.solved
            self.all_rows_off()
            return
        end

        var key = self.read_keyboard()

        if key == nil
            self.held_key = nil
            return
        end

        if self.held_key == nil
            self.held_key = key
            self.button_push(key)
        elif self.held_key != key
            self.held_key = key
            self.button_push(key)
        end
    end

    def enable_game()
        self.enabled = true
        self.reset()
        tasmota.resp_cmnd("Cash register enabled and reset")
    end

    def force_complete()
        self.enabled = true
        if !self.solved
            self.correct_code()
        end
        self.enabled = false
        self.held_key = nil
        self.all_rows_off()
        self.last_status = ""
        self.publish_status()
        tasmota.resp_cmnd("Cash register force completed")
    end

    def disable_game()
        self.enabled = false
        self.reset()
        tasmota.resp_cmnd("Cash register disabled and reset")
    end
end

var cash_register_driver = CashRegister()
tasmota.add_driver(cash_register_driver)

def cash_reset_cmd()
    cash_register_driver.reset()
    tasmota.resp_cmnd_done()
end

def cash_enable_cmd()
    cash_register_driver.enable_game()
end

def cash_disable_cmd()
    cash_register_driver.disable_game()
end

tasmota.add_cmd("CashReset", cash_reset_cmd)
tasmota.add_cmd("enable", cash_enable_cmd)
tasmota.add_cmd("disable", cash_disable_cmd)
tasmota.add_cmd("forcecomplete", / -> cash_register_driver.force_complete())

print("CashRegister driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("CashReset - reset")
print("enable - keyboard and screen enabled")
print("disable - keyboard and screen disabled")
print("forcecomplete - normal solved end state")
print("--------------------------------------------------------------")
