import mqtt

# ---------------- CONFIG ----------------

var MQTT_TOPIC = "CCLOWNGAME"

var SOLUTION = [3, 5, 1, 4, 2]
var BRIGHTNESS = 50
var BLINK_MS = 250
var DEMO_BLINKS = 15
var WIN_BLINKS = 3

# ---------------- GPIO ----------------

var NOSE1 = 25
var NOSE2 = 26
var NOSE3 = 27
var NOSE4 = 14
var NOSE5 = 12

var BUTTON1 = 39
var BUTTON2 = 34
var BUTTON3 = 35
var BUTTON4 = 32
var BUTTON5 = 33

var EYE1 = 23
var EYE2 = 22
var EYE3 = 21
var EYE4 = 19
var EYE5 = 18

# HA power channels for eyes
var EYE_POWER1 = 0
var EYE_POWER2 = 1
var EYE_POWER3 = 2
var EYE_POWER4 = 3
var EYE_POWER5 = 4

# ---------------- GAME ----------------

class Clowngame
    var enable, step, state, blink_id, active_clown
    var buttons, noses, eyes, eye_powers
    var last_buttons, last_noses
    var solving_started

    def init()
        self.enable = false
        self.step = 0
        self.state = "idle"
        self.blink_id = 0
        self.active_clown = nil
        self.solving_started = false

        self.buttons = [BUTTON1, BUTTON2, BUTTON3, BUTTON4, BUTTON5]
        self.noses = [NOSE1, NOSE2, NOSE3, NOSE4, NOSE5]
        self.eyes = [EYE1, EYE2, EYE3, EYE4, EYE5]
        self.eye_powers = [EYE_POWER1, EYE_POWER2, EYE_POWER3, EYE_POWER4, EYE_POWER5]

        self.last_buttons = [false, false, false, false, false]
        self.last_noses = [false, false, false, false, false]

        self.all_off()
    end

    def eye_on(i)
        tasmota.set_power(self.eye_powers[i], true)
        gpio.set_pwm(self.eyes[i], BRIGHTNESS)
    end

    def eye_off(i)
        tasmota.set_power(self.eye_powers[i], false)
        gpio.set_pwm(self.eyes[i], 0)
    end

    def every_50ms()
        if !self.enable
            return nil
        end

        var ev = nil
        var ev_i = nil

        for i: 0..4
            var bp = !gpio.digital_read(self.buttons[i])
            var np = !gpio.digital_read(self.noses[i])

            if ev == nil && bp && !self.last_buttons[i]
                ev = "button"
                ev_i = i
            end

            if ev == nil && np && !self.last_noses[i]
                ev = "nose"
                ev_i = i
            end

            self.last_buttons[i] = bp
            self.last_noses[i] = np
        end

        if ev == "button"
            self.button_pressed(ev_i)
        elif ev == "nose"
            self.nose_pressed(ev_i)
        end
    end

    def expected()
        return SOLUTION[self.step] - 1
    end

    def publish_wrong()
        var payload = '{"data":"WRONG"}'

        mqtt.publish(
            MQTT_TOPIC,
            payload
        )

        print(
            "MQTT: " ..
            MQTT_TOPIC ..
            " = " ..
            payload
        )
    end

    def publish_solved()
        var payload = '{"data":"SOLVED"}'

        mqtt.publish(
            MQTT_TOPIC,
            payload
        )

        print(
            "MQTT: " ..
            MQTT_TOPIC ..
            " = " ..
            payload
        )
    end

    def button_pressed(i)
        if self.state == "win"
            self.reset_game()
            return nil
        end

        if self.state == "blinking"
            if i == self.active_clown
                self.start_step(i)
            else
                if self.solving_started
                    self.publish_wrong()
                    self.reset_game()
                else
                    self.demo_blink(i)
                end
            end

            return nil
        end

        if self.state == "demo"
            if self.step == 0
                if i == self.expected()
                    self.start_step(i)
                else
                    self.demo_blink(i)
                end
            else
                self.publish_wrong()
                self.reset_game()
            end

            return nil
        end

        if i == self.expected()
            self.start_step(i)

        elif self.step == 0 && !self.solving_started
            self.demo_blink(i)

        else
            self.publish_wrong()
            self.reset_game()
        end
    end

    def nose_pressed(i)
        if self.state == "blinking" &&
           i == self.active_clown &&
           i == self.expected()

            self.blink_id = self.blink_id + 1
            self.step = self.step + 1
            self.state = "idle"
            self.active_clown = nil
            self.solving_started = true

            if self.step >= size(SOLUTION)
                self.win()
            else
                self.show_solved()
                self.read_inputs()
            end

        else
            if self.solving_started ||
               self.step > 0 ||
               self.state == "blinking"

                self.publish_wrong()
            end

            self.reset_game()
        end
    end

    def start_step(i)
        self.solving_started = true
        self.state = "blinking"
        self.active_clown = i

        self.blink(
            i,
            DEMO_BLINKS * 2,
            "blinking"
        )
    end

    def demo_blink(i)
        self.state = "demo"
        self.active_clown = i

        self.blink(
            i,
            DEMO_BLINKS * 2,
            "demo"
        )
    end

    def blink(i, count, mode)
        self.blink_id = self.blink_id + 1

        if self.step == 0
            self.all_off()
        else
            self.show_solved()
        end

        self._blink_step(
            i,
            0,
            count,
            mode,
            self.blink_id
        )
    end

    def _blink_step(i, n, count, mode, id)
        if id != self.blink_id
            return nil
        end

        if n >= count
            self.eye_off(i)
            self.show_solved()

            if self.state == mode
                self.state = "idle"
                self.active_clown = nil
                self.read_inputs()
            end

            return nil
        end

        self.show_solved()

        if n % 2 == 0
            self.eye_on(i)
        else
            self.eye_off(i)
        end

        tasmota.set_timer(
            BLINK_MS,
            / -> self._blink_step(
                i,
                n + 1,
                count,
                mode,
                id
            )
        )
    end

    def show_solved()
        if self.step <= 0
            return nil
        end

        for s: 0..(self.step - 1)
            self.eye_on(SOLUTION[s] - 1)
        end
    end

    def reset_game()
        self.step = 0
        self.state = "idle"
        self.active_clown = nil
        self.solving_started = false
        self.blink_id = self.blink_id + 1
        self.all_off()
        self.read_inputs()
    end

    def win()
        self.state = "win"
        self.step = 0
        self.active_clown = nil
        self.solving_started = false
        self.blink_id = self.blink_id + 1

        self.publish_solved()

        self.all_off()
        self.read_inputs()

        tasmota.set_timer(
            BLINK_MS,
            / -> self.win_blink(
                0,
                self.blink_id
            )
        )
    end

    def win_blink(n, id)
        if id != self.blink_id
            return nil
        end

        if n >= WIN_BLINKS * 2
            self.state = "idle"
            self.all_off()
            self.read_inputs()
            return nil
        end

        if n % 2 == 0
            for i: 0..4
                self.eye_on(i)
            end
        else
            for i: 0..4
                self.eye_off(i)
            end
        end

        tasmota.set_timer(
            BLINK_MS,
            / -> self.win_blink(
                n + 1,
                id
            )
        )
    end

    def all_off()
        for i: 0..4
            self.eye_off(i)
        end
    end

    def read_inputs()
        for i: 0..4
            self.last_buttons[i] =
                !gpio.digital_read(
                    self.buttons[i]
                )

            self.last_noses[i] =
                !gpio.digital_read(
                    self.noses[i]
                )
        end
    end

    def enable_game()
        self.enable = true
        self.reset_game()
        self.read_inputs()

        tasmota.resp_cmnd(
            "Game enabled"
        )
    end

    def disable_game()
        self.enable = false
        self.reset_game()
        self.read_inputs()

        tasmota.resp_cmnd(
            "Game disabled"
        )
    end
end

var clowngamedriver = Clowngame()

tasmota.add_driver(
    clowngamedriver
)

tasmota.add_cmd(
    "enable",
    / -> clowngamedriver.enable_game()
)

tasmota.add_cmd(
    "disable",
    / -> clowngamedriver.disable_game()
)

print("Clowngame driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("enable - game enabled")
print("disable - game disabled")
print("--------------------------------------------------------------")