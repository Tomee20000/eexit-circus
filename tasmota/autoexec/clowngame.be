import mqtt

var MQTT_TOPIC = "CCLOWNGAME"
var EYE_STATE_TOPIC = "CCLOWNGAME/EYE/"

var SOLUTION = [3, 5, 1, 4, 2]
var BRIGHTNESS = 50
var BLINK_MS = 250
var DEMO_BLINKS = 15
var WIN_BLINKS = 3

# Code clown number -> physical wall button from the left.
var WALL_POSITION = [5, 1, 2, 4, 3]

var NOSE1 = 25
var NOSE2 = 26
var NOSE3 = 27
var NOSE4 = 14
var NOSE5 = 12

var BUTTON1 = 33
var BUTTON2 = 39
var BUTTON3 = 34
var BUTTON4 = 32
var BUTTON5 = 35

var EYE1 = 23
var EYE2 = 22
var EYE3 = 21
var EYE4 = 19
var EYE5 = 18

class Clowngame
    var enable, step, state, blink_id, active_clown
    var buttons, noses, eyes
    var last_buttons, last_noses, last_eye_states
    var last_status

    def init()
        self.enable = false
        self.step = 0
        self.state = "disabled"
        self.blink_id = 0
        self.active_clown = nil
        self.last_status = ""

        self.buttons = [BUTTON1, BUTTON2, BUTTON3, BUTTON4, BUTTON5]
        self.noses = [NOSE1, NOSE2, NOSE3, NOSE4, NOSE5]
        self.eyes = [EYE1, EYE2, EYE3, EYE4, EYE5]

        self.last_buttons = [false, false, false, false, false]
        self.last_noses = [false, false, false, false, false]
        self.last_eye_states = ["", "", "", "", ""]

        self.all_off()
    end

    def wall_position(clown_idx)
        return WALL_POSITION[clown_idx]
    end

    def publish_status()
        var text = ""
        var waiting = "none"
        var next_clown = 0
        var wall_button = 0

        if !self.enable
            text = "Inaktív"

        elif self.state == "win"
            text = "5/5 kész - Bohócos játék megoldva"

        elif self.state == "demo" && self.active_clown != nil
            next_clown = self.expected() + 1
            wall_button = self.wall_position(self.expected())
            waiting = "nose"

            text = str(self.step) ..
                   "/5 kész - Bemutató: " ..
                   str(self.active_clown + 1) ..
                   ". bohóc villog - következő helyes bohóc: " ..
                   str(next_clown)

        else
            next_clown = self.expected() + 1
            wall_button = self.wall_position(self.expected())
            waiting = "button_or_nose"

            text = str(self.step) ..
                   "/5 kész - Következő: " ..
                   str(next_clown) ..
                   ". bohóc - balról " ..
                   str(wall_button) ..
                   ". fali gomb"
        end

        var msg = '{"text":"' ..
                  text ..
                  '","enabled":' ..
                  (self.enable ? "true" : "false") ..
                  ',"state":"' ..
                  self.state ..
                  '","completed":' ..
                  self.step ..
                  ',"total":5,"next_clown":' ..
                  next_clown ..
                  ',"wall_button":' ..
                  wall_button ..
                  ',"waiting_for":"' ..
                  waiting ..
                  '"}'

        if msg == self.last_status
            return
        end

        self.last_status = msg
        mqtt.publish("CCLOWNGAME/STATUS", msg, true)
    end

    def force_complete()
        self.enable = true
        self.win()

        tasmota.resp_cmnd(
            "Clowngame force completed"
        )
    end

    def publish_eye_state(i, state)
        if self.last_eye_states[i] == state
            return
        end

        self.last_eye_states[i] = state

        mqtt.publish(
            EYE_STATE_TOPIC .. str(i + 1),
            state,
            true
        )
    end

    def eye_on(i)
        gpio.set_pwm(
            self.eyes[i],
            BRIGHTNESS
        )

        self.publish_eye_state(
            i,
            "ON"
        )
    end

    def eye_off(i)
        gpio.set_pwm(
            self.eyes[i],
            0
        )

        self.publish_eye_state(
            i,
            "OFF"
        )
    end

    def every_50ms()
        self.publish_status()

        if !self.enable
            return nil
        end

        var ev = nil
        var ev_i = nil

        for i: 0..4
            var bp = !gpio.digital_read(
                self.buttons[i]
            )

            var np = !gpio.digital_read(
                self.noses[i]
            )

            if ev == nil &&
               bp &&
               !self.last_buttons[i]

                ev = "button"
                ev_i = i
            end

            if ev == nil &&
               np &&
               !self.last_noses[i]

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

    def is_solved_clown(i)
        if self.step <= 0
            return false
        end

        for s: 0..(self.step - 1)
            if SOLUTION[s] - 1 == i
                return true
            end
        end

        return false
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

    def wrong_and_reset()
        self.publish_wrong()
        self.reset_game()
    end

    def button_pressed(i)
        if self.state == "win"
            return nil
        end

        if self.is_solved_clown(i)
            return nil
        end

        self.demo_blink(i)
    end

    def nose_pressed(i)
        if self.state == "win"
            return nil
        end

        if i != self.expected()
            self.wrong_and_reset()
            return nil
        end

        self.blink_id = self.blink_id + 1
        self.active_clown = nil
        self.step = self.step + 1
        self.state = "idle"

        if self.step >= size(SOLUTION)
            self.win()
        else
            self.show_solved()
            self.read_inputs()

            self.last_status = ""
            self.publish_status()
        end
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

        self.show_solved()

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

                self.last_status = ""
                self.publish_status()
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
            self.eye_on(
                SOLUTION[s] - 1
            )
        end
    end

    def reset_game()
        self.step = 0
        self.state = "idle"
        self.active_clown = nil
        self.blink_id = self.blink_id + 1

        self.all_off()
        self.read_inputs()

        self.last_status = ""
        self.publish_status()
    end

    def win()
        self.state = "win"
        self.step = size(SOLUTION)
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
            self.state = "win"

            for i: 0..4
                self.eye_on(i)
            end

            self.read_inputs()

            self.last_status = ""
            self.publish_status()

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
            "Game enabled and reset"
        )
    end

    def disable_game()
        self.enable = false
        self.step = 0
        self.state = "disabled"
        self.active_clown = nil
        self.blink_id = self.blink_id + 1

        self.last_eye_states = [
            "",
            "",
            "",
            "",
            ""
        ]

        self.all_off()
        self.read_inputs()

        self.last_status = ""
        self.publish_status()

        tasmota.resp_cmnd(
            "Game disabled and reset"
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

tasmota.add_cmd(
    "forcecomplete",
    / -> clowngamedriver.force_complete()
)

print("Clowngame driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("enable - game enabled")
print("disable - reset game, eyes OFF and retained HA status")
print("forcecomplete - normal win animation and SOLVED event")
print("--------------------------------------------------------------")