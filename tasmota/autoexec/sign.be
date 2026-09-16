#-
var input1 = 21
var input2 = 19
var input3 = 18
var input4 = 17
var input5 = 16
var input6 = 4

switchmode0 2
-#

import mqtt

var HARD_MODE = true

var LED1 = 0 # C1 32
var LED2 = 1 # I 33
var LED3 = 2 # R 25
var LED4 = 3 # C2 26
var LED5 = 4 # U 27
var LED6 = 5 # S 14
var LED_GREENRED = 6

var SENSOR_HOLD_MS = 250
var INPUT_COOLDOWN_MS = 350

var RANDOM_STEP_MS = 80
var CHASE_STEP_MS = 180


class Sign
    var enabled, solved, animating
    var phase, anim_id
    var hard_mode

    var random_seed

    var chase_pos
    var chase_sequence
    var chase_saved_phase
    var chase_saved_animating
    var chase_saved_mask
    var chase_saved_greenred

    var input_pending, input_token, input_last
    var mqtt_topic
    var last_status

    def init()
        self.enabled = false
        self.solved = false
        self.animating = false

        self.phase = 0
        self.anim_id = 0

        self.hard_mode = HARD_MODE

        self.random_seed = 1

        self.chase_pos = 0
        self.chase_sequence = [0, 1, 2, 3, 4, 5, 4, 3, 2, 1]

        self.chase_saved_phase = 0
        self.chase_saved_animating = false
        self.chase_saved_mask = 0
        self.chase_saved_greenred = false

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
        tasmota.set_power(LED_GREENRED, false)
    end

    def get_letters_mask()
        var p = tasmota.get_power()
        var mask = 0

        for i:0..5
            if p[i]
                mask = mask | (1 << i)
            end
        end

        return mask
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

    def stop_animation_timers()
        tasmota.remove_timer("sign_random")
        tasmota.remove_timer("sign_chase")
    end

    def build_status()
        var p = tasmota.get_power()
        var mask = self.get_letters_mask()

        var text = "Inactive"

        if self.solved
            text = "Solved"
        elif self.phase == 4
            text = "Animation - chase"
        elif self.enabled
            if self.phase == 1
                text = "Active - random flicker"
            elif self.phase == 3
                text = "Active - puzzle"
            else
                text = "Active"
            end
        elif self.phase == 1
            text = "Animation - random flicker"
        end

        return '{"enabled":' .. (self.enabled ? "true" : "false") ..
               ',"solved":' .. (self.solved ? "true" : "false") ..
               ',"animating":' .. (self.animating ? "true" : "false") ..
               ',"hard_mode":' .. (self.hard_mode ? "true" : "false") ..
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


    # RANDOM FLICKER

    def start_random()
        self.anim_id = self.anim_id + 1
        var id = self.anim_id

        self.stop_animation_timers()

        self.phase = 1
        self.animating = true

        self.random_seed = (tasmota.millis() % 63) + 1

        tasmota.set_power(LED_GREENRED, false)

        self.last_status = ""
        self.publish_status()

        self.random_step(id)
    end

    def random_step(id)
        if id != self.anim_id || self.phase != 1
            return nil
        end

        self.random_seed = (self.random_seed * 13 + 17) % 64

        self.set_letters_mask(self.random_seed)

        tasmota.set_timer(
            RANDOM_STEP_MS,
            / -> self.random_step(id),
            "sign_random"
        )
    end

    def stop_random_for_input()
        if self.phase != 1
            return false
        end

        self.anim_id = self.anim_id + 1
        tasmota.remove_timer("sign_random")

        self.animating = false

        if self.enabled && !self.solved
            self.phase = 3

            self.clear_input_state()
            self.play_state()

            mqtt.publish(self.mqtt_topic, '{"data":"LAMPOFF"}')

            self.last_status = ""
            self.publish_status()

            return true
        end

        self.phase = 0

        if self.solved
            self.letters_on()
        else
            self.all_off()
        end

        self.last_status = ""
        self.publish_status()

        return false
    end


    # CHASE ANIMATION

    def cmd_chase()
        if self.phase == 4
            tasmota.resp_cmnd_str("Chase already running")
            return
        end

        var p = tasmota.get_power()

        self.chase_saved_phase = self.phase
        self.chase_saved_animating = self.animating
        self.chase_saved_mask = self.get_letters_mask()
        self.chase_saved_greenred = p[LED_GREENRED]

        self.anim_id = self.anim_id + 1
        var id = self.anim_id

        self.stop_animation_timers()

        self.animating = true
        self.phase = 4
        self.chase_pos = 0

        self.all_off()

        self.last_status = ""
        self.publish_status()

        self.chase_step(id)

        tasmota.resp_cmnd_str("Chase started")
    end

    def chase_step(id)
        if id != self.anim_id || self.phase != 4
            return nil
        end

        self.letters_off()
        tasmota.set_power(LED_GREENRED, false)

        var led = self.chase_sequence[self.chase_pos]
        tasmota.set_power(led, true)

        self.chase_pos = self.chase_pos + 1

        if self.chase_pos >= size(self.chase_sequence)
            self.chase_pos = 0
        end

        tasmota.set_timer(
            CHASE_STEP_MS,
            / -> self.chase_step(id),
            "sign_chase"
        )
    end

    def cmd_chasestop()
        if self.phase != 4
            tasmota.resp_cmnd_str("Chase not running")
            return
        end

        self.anim_id = self.anim_id + 1
        tasmota.remove_timer("sign_chase")

        self.phase = self.chase_saved_phase
        self.animating = self.chase_saved_animating

        self.set_letters_mask(self.chase_saved_mask)
        tasmota.set_power(LED_GREENRED, self.chase_saved_greenred)

        if self.phase == 1 && self.animating
            var id = self.anim_id
            self.random_step(id)
        end

        self.last_status = ""
        self.publish_status()

        tasmota.resp_cmnd_str("Chase stopped")
    end


    # GAME

    def cmd_enable(cmd, idx, payload, payload_json)
        self.anim_id = self.anim_id + 1

        self.enabled = true
        self.solved = false
        self.animating = false
        self.phase = 0

        self.clear_input_state()
        self.stop_animation_timers()
        self.all_off()

        self.start_random()

        tasmota.resp_cmnd_done()
    end

    def cmd_disable(cmd, idx, payload, payload_json)
        self.anim_id = self.anim_id + 1

        self.enabled = false
        self.solved = false
        self.animating = false
        self.phase = 0

        self.clear_input_state()
        self.stop_animation_timers()
        self.all_off()

        self.last_status = ""
        self.publish_status()

        tasmota.resp_cmnd_done()
    end

    def cmd_random()
        self.start_random()
        tasmota.resp_cmnd_str("Random flicker started")
    end

    def cmd_hardmode(cmd, idx, payload, payload_json)
        if payload == "1"
            self.hard_mode = true
            tasmota.resp_cmnd_str("Hard mode ON")
        elif payload == "0"
            self.hard_mode = false
            tasmota.resp_cmnd_str("Hard mode OFF")
        else
            if self.hard_mode
                tasmota.resp_cmnd_str("Hard mode ON")
            else
                tasmota.resp_cmnd_str("Hard mode OFF")
            end
        end

        self.last_status = ""
        self.publish_status()
    end

    def check_solved()
        if self.solved
            return nil
        end

        var p = tasmota.get_power()

        if p[LED1] && p[LED2] && p[LED3] &&
           p[LED4] && p[LED5] && p[LED6]

            self.solved = true
            self.enabled = false
            self.animating = false
            self.phase = 0

            self.anim_id = self.anim_id + 1

            self.clear_input_state()
            self.stop_animation_timers()

            mqtt.publish(self.mqtt_topic, '{"data":"SOLVED"}')

            self.last_status = ""
            self.publish_status()
        end
    end

    def apply_input_normal(id)
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
    end

    def apply_input_hard(id)
        if id == 1
            self.toggle_led(LED3)

        elif id == 2
            self.toggle_led(LED2)
            self.toggle_led(LED3)
            self.toggle_led(LED6)

        elif id == 3
            self.toggle_led(LED1)
            self.toggle_led(LED4)
            self.toggle_led(LED5)

        elif id == 4
            self.toggle_led(LED1)
            self.toggle_led(LED2)
            self.toggle_led(LED6)

        elif id == 5
            self.toggle_led(LED3)
            self.toggle_led(LED4)

        elif id == 6
            self.toggle_led(LED6)
        end
    end

    def apply_input(id)
        if !self.enabled || self.solved || self.phase != 3
            return nil
        end

        if self.hard_mode
            self.apply_input_hard(id)
        else
            self.apply_input_normal(id)
        end

        self.input_last[id] = tasmota.millis()

        self.check_solved()
        self.publish_status()
    end

    def finalize_input(id, token)
        if !self.enabled || self.solved || self.phase != 3
            return nil
        end

        if self.input_pending[id] &&
           self.input_token[id] == token

            self.input_pending[id] = false
            self.apply_input(id)
        end
    end

    def handle_input_edge(id)
        if id < 1 || id > 6
            return nil
        end

        if self.phase == 1
            var game_started = self.stop_random_for_input()

            if !game_started
                return nil
            end
        end

        if !self.enabled || self.solved || self.phase != 3
            return nil
        end

        var now = tasmota.millis()

        if self.input_last[id] != 0 &&
           now - self.input_last[id] < INPUT_COOLDOWN_MS
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

        tasmota.set_timer(
            SENSOR_HOLD_MS,
            / -> self.finalize_input(id, token)
        )
    end

    def force_complete()
        self.anim_id = self.anim_id + 1

        self.enabled = false
        self.solved = true
        self.animating = false
        self.phase = 0

        self.clear_input_state()
        self.stop_animation_timers()

        self.all_off()
        self.letters_on()

        mqtt.publish(self.mqtt_topic, '{"data":"SOLVED"}')

        self.last_status = ""
        self.publish_status()

        tasmota.resp_cmnd_str("Sign force completed")
    end

    def every_250ms()
        if !self.animating
            self.publish_status()
        end
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

tasmota.add_cmd(
    "enable",
    / cmd, idx, payload, payload_json ->
        sign_driver.cmd_enable(cmd, idx, payload, payload_json)
)

tasmota.add_cmd(
    "disable",
    / cmd, idx, payload, payload_json ->
        sign_driver.cmd_disable(cmd, idx, payload, payload_json)
)

tasmota.add_cmd(
    "forcecomplete",
    / -> sign_driver.force_complete()
)

tasmota.add_cmd(
    "randomblink",
    / -> sign_driver.cmd_random()
)

tasmota.add_cmd(
    "chase",
    / -> sign_driver.cmd_chase()
)

tasmota.add_cmd(
    "chasestop",
    / -> sign_driver.cmd_chasestop()
)

tasmota.add_cmd(
    "hardmode",
    / cmd, idx, payload, payload_json ->
        sign_driver.cmd_hardmode(cmd, idx, payload, payload_json)
)


print("Sign driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("enable - enable game and start random flicker")
print("disable - disable game, reset and stop all animations")
print("forcecomplete - turn all letters on and send SOLVED")
print("randomblink - start random flicker")
print("chase - start continuous back-and-forth animation")
print("chasestop - stop chase animation")
print("hardmode 1 - enable hard mode")
print("hardmode 0 - enable original mode")
print("hardmode - show current mode")
print("--------------------------------------------------------------")