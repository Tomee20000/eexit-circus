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

var BUTTON1 = 33
var BUTTON2 = 35
var BUTTON3 = 32
var BUTTON4 = 39
var BUTTON5 = 34

var EYE1 = 23
var EYE2 = 22
var EYE3 = 21
var EYE4 = 19
var EYE5 = 18

# ---------------- GAME ----------------

class Clowngame
    var enable, step, state, blink_id, active_clown
    var buttons, noses, eyes, last_buttons, last_noses

    def init()
        self.enable = false
        self.step = 0
        self.state = "idle"
        self.blink_id = 0
        self.active_clown = nil

        self.buttons = [BUTTON1, BUTTON2, BUTTON3, BUTTON4, BUTTON5]
        self.noses = [NOSE1, NOSE2, NOSE3, NOSE4, NOSE5]
        self.eyes = [EYE1, EYE2, EYE3, EYE4, EYE5]

        self.last_buttons = [false, false, false, false, false]
        self.last_noses = [false, false, false, false, false]

        self.all_off()
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

    def button_pressed(i)
        if self.state == "win"
            self.reset_game()
            return nil
        end

        if self.state == "blinking"
            if i == self.active_clown
                self.start_step(i)
            else
                self.reset_game()
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
                self.reset_game()
            end
            return nil
        end

        if self.step == 0 && i != self.expected()
            self.demo_blink(i)
            return nil
        end

        if i == self.expected()
            self.start_step(i)
        else
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

            if self.step >= size(SOLUTION)
                self.win()
            else
                self.show_solved()
                self.read_inputs()
            end
        else
            self.reset_game()
        end
    end

    def start_step(i)
        self.state = "blinking"
        self.active_clown = i
        self.blink(
            self.eyes[i],
            DEMO_BLINKS * 2,
            "blinking"
        )
    end

    def demo_blink(i)
        self.state = "demo"
        self.active_clown = i
        self.blink(
            self.eyes[i],
            DEMO_BLINKS * 2,
            "demo"
        )
    end

    def blink(eye, count, mode)
        self.blink_id = self.blink_id + 1

        if self.step == 0
            self.all_off()
        else
            self.show_solved()
        end

        self._blink_step(
            eye,
            0,
            count,
            mode,
            self.blink_id
        )
    end

    def _blink_step(eye, n, count, mode, id)
        if id != self.blink_id
            return nil
        end

        if n >= count
            gpio.set_pwm(eye, 0)
            self.show_solved()

            if self.state == mode
                self.state = "idle"
                self.active_clown = nil
                self.read_inputs()
            end

            return nil
        end

        self.show_solved()

        gpio.set_pwm(
            eye,
            (n % 2 == 0) ? BRIGHTNESS : 0
        )

        tasmota.set_timer(
            BLINK_MS,
            / -> self._blink_step(
                eye,
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
            gpio.set_pwm(
                self.eyes[SOLUTION[s] - 1],
                BRIGHTNESS
            )
        end
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

    def reset_game()
        self.step = 0
        self.state = "idle"
        self.active_clown = nil
        self.blink_id = self.blink_id + 1
        self.all_off()
        self.read_inputs()
    end

    def win()
        self.state = "win"
        self.step = 0
        self.active_clown = nil
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

        var v =
            (n % 2 == 0) ? BRIGHTNESS : 0

        for i: 0..4
            gpio.set_pwm(
                self.eyes[i],
                v
            )
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
            gpio.set_pwm(
                self.eyes[i],
                0
            )
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
print("MQTT topic: CCLOWNGAME")
print("--------------------------------------------------------------")
print("Commands:")
print("enable - game enabled")
print("disable - game disabled")
print("--------------------------------------------------------------")