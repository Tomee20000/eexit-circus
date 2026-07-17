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

var INTRO_MS = 60000
var SENSOR_HOLD_MS = 250
var INPUT_COOLDOWN_MS = 350
var GLITCH_STEP_MS = 120

class Sign
    var enabled, solved, animating
    var phase, anim_id, glitch_pos
    var glitch_masks
    var input_pending, input_token, input_last
    var mqtt_topic
    var last_status

    def init()
        self.enabled = false
        self.solved = false
        self.animating = false
        self.phase = 0
        self.anim_id = 0
        self.glitch_pos = 0

        self.glitch_masks = [
            63, 0, 63, 2, 63, 18, 50, 0,
            32, 63, 40, 0, 48, 32, 34, 0,
            63, 8, 0, 32
        ]

        self.input_pending = [false, false, false, false, false, false, false]
        self.input_token = [0, 0, 0, 0, 0, 0, 0]
        self.input_last = [0, 0, 0, 0, 0, 0, 0]

        self.mqtt_topic = "CSIGN"
        self.last_status = ""

        self.all_off()
        self.publish_status()
    end

    def all_off()
        for led:0..6
            tasmota.set_power(led, false)
        end
    end

    def letters_off()
        for led:0..5
            tasmota.set_power(led, false)
        end
    end

    def letters_on()
        for led:0..5
            tasmota.set_power(led, true)
        end
    end

    def play_state()
        self.letters_off()
        tasmota.set_power(LED6, true)
    end

    def set_letters_mask(mask)
        var i = 0

        while i < 6
            tasmota.set_power(i, (mask & (1 << i)) != 0)
            i = i + 1
        end
    end

    def toggle_led(led)
        var p = tasmota.get_power()
        tasmota.set_power(led, !p[led])
    end

    def clear_input_state()
        var i = 1

        while i <= 6
            self.input_pending[i] = false
            self.input_token[i] = self.input_token[i] + 1
            self.input_last[i] = 0
            i = i + 1
        end
    end

    def build_status()
        var p = tasmota.get_power()
        var mask = 0

        for i: 0..5
            if p[i]
                mask = mask | (1 << i)
            end
        end

        var text = "Inaktív"
        if self.solved
            text = "Megoldva"
        elif self.enabled
            if self.phase == 1
                text = "Aktív - bevezető animáció"
            elif self.phase == 2
                text = "Aktív - villogás"
            elif self.phase == 3
                text = "Aktív - feladvány"
            else
                text = "Aktív"
            end
        end

        return '{"enabled":' .. (self.enabled ? "true" : "false") ..
               ',"solved":' .. (self.solved ? "true" : "false") ..
               ',"animating":' .. (self.animating ? "true" : "false") ..
               ',"phase":' .. self.phase ..
               ',"letters_mask":' .. mask ..
               ',"greenred":' .. (p[LED_GREENRED] ? "true" : "false") ..
               ',"text":"' .. text .. '"}'
    end

    def publish_status()
        var msg = self.build_status()
        if msg == self.last_status
            return
        end

        self.last_status = msg
        mqtt.publish("CSIGN/STATUS", msg, true)
    end

    def cmd_enable(cmd, idx, payload, payload_json)
        self.anim_id = self.anim_id + 1
        var id = self.anim_id

        self.enabled = true
        self.solved = false
        self.animating = true
        self.phase = 1
        self.glitch_pos = 0

        self.clear_input_state()
        tasmota.remove_timer("sign_intro")
        tasmota.remove_timer("sign_glitch")

        self.letters_on()
        tasmota.set_power(LED_GREENRED, false)

        tasmota.set_timer(INTRO_MS, / -> self.start_glitch(id), "sign_intro")

        self.last_status = ""
        self.publish_status()
        tasmota.resp_cmnd_done()
    end

    def cmd_disable(cmd, idx, payload, payload_json)
        self.anim_id = self.anim_id + 1

        self.enabled = false
        self.solved = false
        self.animating = false
        self.phase = 0

        self.clear_input_state()
        self.all_off()

        tasmota.remove_timer("sign_intro")
        tasmota.remove_timer("sign_glitch")

        self.last_status = ""
        self.publish_status()
        tasmota.resp_cmnd_done()
    end

    def start_glitch(id)
        if id != self.anim_id || !self.enabled || self.solved || self.phase != 1
            return nil
        end

        self.phase = 2
        self.glitch_pos = 0
        self.clear_input_state()

        tasmota.remove_timer("sign_intro")
        self.publish_status()
        self.glitch_step(id)
    end

    def glitch_step(id)
        if id != self.anim_id || !self.enabled || self.solved || self.phase != 2
            return nil
        end

        if self.glitch_pos >= size(self.glitch_masks)
            self.finish_glitch(id)
            return nil
        end

        self.set_letters_mask(self.glitch_masks[self.glitch_pos])

        self.glitch_pos = self.glitch_pos + 1

        tasmota.set_timer(GLITCH_STEP_MS, / -> self.glitch_step(id), "sign_glitch")
    end

    def finish_glitch(id)
        if id != self.anim_id || !self.enabled || self.solved
            return nil
        end

        self.phase = 3
        self.animating = false
        self.clear_input_state()
        self.play_state()

        mqtt.publish(self.mqtt_topic, '{"data":"LAMPOFF"}')
        self.publish_status()
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
            self.phase = 0

            self.clear_input_state()
            tasmota.remove_timer("sign_intro")
            tasmota.remove_timer("sign_glitch")

            mqtt.publish(self.mqtt_topic, '{"data":"SOLVED"}')
            self.publish_status()
        end
    end

    def apply_input(id)
        if !self.enabled || self.solved || self.phase != 3
            return nil
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

        self.input_last[id] = tasmota.millis()
        self.check_solved()
        self.publish_status()
    end

    def finalize_input(id, token)
        if !self.enabled || self.solved || self.phase != 3
            return nil
        end

        if self.input_pending[id] && self.input_token[id] == token
            self.input_pending[id] = false
            self.apply_input(id)
        end
    end

    def handle_input_edge(id)
        if id < 1 || id > 6
            return nil
        end

        if !self.enabled || self.solved
            return nil
        end

        if self.phase == 1
            self.start_glitch(self.anim_id)
            return nil
        end

        if self.phase != 3
            return nil
        end

        var now = tasmota.millis()

        if self.input_last[id] != 0 && now - self.input_last[id] < INPUT_COOLDOWN_MS
            return nil
        end

        if self.input_pending[id]
            self.input_pending[id] = false
            self.input_token[id] = self.input_token[id] + 1
            self.apply_input(id)
            return nil
        end

        self.input_pending[id] = true
        self.input_token[id] = self.input_token[id] + 1

        var token = self.input_token[id]

        tasmota.set_timer(SENSOR_HOLD_MS, / -> self.finalize_input(id, token))
    end

    def force_complete()
        self.anim_id = self.anim_id + 1
        self.enabled = false
        self.solved = true
        self.animating = false
        self.phase = 0
        self.clear_input_state()
        tasmota.remove_timer("sign_intro")
        tasmota.remove_timer("sign_glitch")
        self.letters_on()
        mqtt.publish(self.mqtt_topic, '{"data":"SOLVED"}')
        self.last_status = ""
        self.publish_status()
        tasmota.resp_cmnd("Sign force completed")
    end

    def every_50ms()
        self.publish_status()
    end

    def any_key(cmd, idx)
        var id = number(idx & 0xff)

        if id == 7
            if self.solved
                self.toggle_led(LED_GREENRED)
                self.publish_status()
            end
            return nil
        end

        self.handle_input_edge(id)
    end
end

var sign_driver = Sign()

tasmota.add_driver(sign_driver)
tasmota.add_cmd("enable", / cmd, idx, payload, payload_json -> sign_driver.cmd_enable(cmd, idx, payload, payload_json))
tasmota.add_cmd("disable", / cmd, idx, payload, payload_json -> sign_driver.cmd_disable(cmd, idx, payload, payload_json))
tasmota.add_cmd("forcecomplete", / -> sign_driver.force_complete())

print("Sign driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("enable - game enabled from clean state")
print("disable - game disabled and fully reset")
print("forcecomplete - all letters on and SOLVED event")
print("--------------------------------------------------------------")
