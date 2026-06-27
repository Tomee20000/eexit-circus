#-
var input1 = 21
var input2 = 19
var input3 = 18
var input4 = 17
var input5 = 16
var input6 = 4

switchmode0 2
-#

import string
import mqtt

var MQTT_SUBTOPIC = "SIGN"

var LED1 = 0 #C1 32
var LED2 = 1 #I 33
var LED3 = 2 #R 25
var LED4 = 3 #C2 26
var LED5 = 4 #U 27
var LED6 = 5 #S 14
var LED_GREENRED = 6

var START_LED1 = false
var START_LED2 = true
var START_LED3 = false
var START_LED4 = false
var START_LED5 = false
var START_LED6 = false
var START_GREENRED = false

class Sign
    var enabled, solved, animating
    var anim_pos, anim_leds
    var mqtt_topic

    def init()
        self.enabled = false
        self.solved = false
        self.animating = false
        self.anim_pos = 0
        self.anim_leds = [LED1, LED2, LED3, LED4, LED5, LED6, LED5, LED4, LED3, LED2]

        self.mqtt_topic = "CSIGN"

        self.all_off()
    end

    def all_off()
        for led:0..6
            tasmota.set_power(led, false)
        end
    end

    def start_state()
        self.all_off()

        tasmota.set_power(LED1, START_LED1)
        tasmota.set_power(LED2, START_LED2)
        tasmota.set_power(LED3, START_LED3)
        tasmota.set_power(LED4, START_LED4)
        tasmota.set_power(LED5, START_LED5)
        tasmota.set_power(LED6, START_LED6)
        tasmota.set_power(LED_GREENRED, START_GREENRED)
    end

    def toggle_led(led)
        var p = tasmota.get_power()
        tasmota.set_power(led, !p[led])
    end

    def cmd_enable(cmd, idx, payload, payload_json)
        self.enabled = true
        self.solved = false
        self.animating = true
        self.anim_pos = 0
        self.all_off()
        self.anim_step()
        tasmota.resp_cmnd_done()
    end

    def cmd_disable(cmd, idx, payload, payload_json)
        self.enabled = false
        self.solved = false
        self.animating = false
        self.all_off()
        tasmota.remove_timer("sign_anim")
        tasmota.resp_cmnd_done()
    end

    def anim_step()
        if !self.enabled || !self.animating
            return nil
        end

        self.all_off()

        tasmota.set_power(self.anim_leds[self.anim_pos], true)

        self.anim_pos += 1
        if self.anim_pos >= size(self.anim_leds)
            self.anim_pos = 0
        end

        tasmota.set_timer(500, / -> self.anim_step(), "sign_anim")
    end

    def check_solved()
        if self.solved
            return nil
        end

        var p = tasmota.get_power()

        if p[LED1] && p[LED2] && p[LED3] && p[LED4] && p[LED5] && p[LED6]
            self.solved = true
            self.enabled = false
            self.animating = false
            tasmota.remove_timer("sign_anim")
            mqtt.publish(self.mqtt_topic, '{"data":"SOLVED"}')
        end
    end

    def any_key(cmd, idx)
        var id = number(idx & 0xff)

        if id == 7
            if self.solved
                self.toggle_led(LED_GREENRED)
            end
            return nil
        end

        if !self.enabled || self.solved
            return nil
        end

        if self.animating
            self.animating = false
            tasmota.remove_timer("sign_anim")
            self.start_state()
        end

        if id == 1
            self.toggle_led(LED2)
        elif id == 2
            self.toggle_led(LED4)
            self.toggle_led(LED5)
        elif id == 3
            self.toggle_led(LED6)
        elif id == 4
            self.toggle_led(LED2)
            self.toggle_led(LED3)
        elif id == 5
            self.toggle_led(LED4)
        elif id == 6
            self.toggle_led(LED1)
            self.toggle_led(LED6)
        end

        self.check_solved()
    end
end

var sign_driver = Sign()

tasmota.add_driver(sign_driver)
tasmota.add_cmd("enable", / cmd, idx, payload, payload_json -> sign_driver.cmd_enable(cmd, idx, payload, payload_json))
tasmota.add_cmd("disable", / cmd, idx, payload, payload_json -> sign_driver.cmd_disable(cmd, idx, payload, payload_json))

print("Sign driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("enable - game enabled")
print("disable - game disabled")
print("--------------------------------------------------------------")