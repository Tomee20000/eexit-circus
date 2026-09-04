import mqtt

var RED = 0xFF0000
var GREEN = 0x027821
var BLUE = 0x0000FF
var YELLOW = 0xFFFF00
var WHITE = 0xFFFFFF
var OFF = 0x000000

var HOLE1 = 19
var HOLE2 = 14
var HOLE3 = 26
var HOLE4 = 21
var HOLE5 = 5
var HOLE6 = 13
var HOLE7 = 22
var HOLE8 = 18
var HOLE9 = 27

var LED_MAP = {
    1 : [0,7,8,9],
    2 : [1,5,6,7],
    3 : [2,3,4,5],
    4 : [8,12,11,10],
    5 : [6,14,13,12],
    6 : [4,16,15,14],
    7 : [11,21,22,23],
    8 : [13,19,20,21],
    9 : [15,17,18,19]
}

var RED_SOLUTION = [0,1,2]
var GREEN_SOLUTION = [22,20,18]
var BLUE_SOLUTION = [3,16,17]
var YELLOW_SOLUTION = [9,10,23]

var RED_START = [21,13,19]
var GREEN_START = [5,6,7]
var BLUE_START = [8,11,12]
var YELLOW_START = [4,14,15]

var MIX_SEQUENCE = [
    7,9,7,9,8,4,3,3,1,1,
    2,8,6,6,2,5,5,4,7,8,
    5,4,9,6,3,2,1,4,5
]

var MIX_SEQUENCE_COUNT = 29
var MIX_STEP_MS = 275
var MIX_START_DELAY_MS = 300

class KnifeGame
    var strip, color_state
    var enable, mixing
    var stable_cnt, last_input, triggered, sound_sent
    var solved, last_status, run_id
    var brightness

    def init()
        self.strip = Leds(
            24,
            gpio.pin(gpio.WS2812, 3)
        )

        self.color_state = [
            OFF,OFF,OFF,OFF,OFF,OFF,
            OFF,OFF,OFF,OFF,OFF,OFF,
            OFF,OFF,OFF,OFF,OFF,OFF,
            OFF,OFF,OFF,OFF,OFF,OFF
        ]

        self.enable = false
        self.mixing = false

        self.stable_cnt = 0
        self.last_input = 0
        self.triggered = 0

        self.sound_sent = false
        self.solved = false

        self.last_status = ""
        self.run_id = 0
        self.brightness = 100

        self.render_state()
    end

    def brightness_raw()
        var value = int(
            (self.brightness * 255) / 100
        )

        if value < 0
            value = 0
        elif value > 255
            value = 255
        end

        return value
    end

    def render_state()
        var raw = self.brightness_raw()

        for i: 0..23
            self.strip.set_pixel_color(
                i,
                self.color_state[i],
                raw
            )
        end

        self.strip.show()
    end

    def clear_state(color)
        for i: 0..23
            self.color_state[i] = color
        end
    end

    def set_start_pattern()
        self.clear_state(WHITE)

        for i: 0..2
            self.color_state[RED_START[i]] = RED
            self.color_state[GREEN_START[i]] = GREEN
            self.color_state[BLUE_START[i]] = BLUE
            self.color_state[YELLOW_START[i]] = YELLOW
        end

        self.render_state()
    end

    def set_solved_pattern()
        self.clear_state(WHITE)

        for i: 0..2
            self.color_state[RED_SOLUTION[i]] = RED
            self.color_state[GREEN_SOLUTION[i]] = GREEN
            self.color_state[BLUE_SOLUTION[i]] = BLUE
            self.color_state[YELLOW_SOLUTION[i]] = YELLOW
        end

        self.render_state()
    end

    def reset_input()
        self.stable_cnt = 0
        self.last_input = 0
        self.triggered = 0
    end

    def publish_first()
        if self.sound_sent
            return
        end

        mqtt.publish(
            "CKNIFEGAME",
            '{"data":"FIRST"}'
        )

        mqtt.publish(
            "cmnd/CANIMALWHEEL/i2splay",
            "mp3/knife.mp3"
        )

        self.sound_sent = true
    end

    def build_status()
        var msg = '{"enabled":' ..
            (self.enable ? "true" : "false") ..
            ',"mixing":' ..
            (self.mixing ? "true" : "false") ..
            ',"solved":' ..
            (self.solved ? "true" : "false") ..
            ',"first_used":' ..
            (self.sound_sent ? "true" : "false") ..
            ',"brightness":' ..
            self.brightness ..
            ',"colors":['

        for i: 0..23
            if i > 0
                msg = msg .. ","
            end

            msg = msg ..
                '"' ..
                format(
                    "%06X",
                    self.color_state[i]
                ) ..
                '"'
        end

        msg = msg .. "]}"

        return msg
    end

    def publish_status()
        var msg = self.build_status()

        if msg == self.last_status
            return
        end

        self.last_status = msg

        mqtt.publish(
            "CKNIFEGAME/STATUS",
            msg,
            true
        )
    end

    def set_brightness(level)
        level = int(level)

        if level < 0
            level = 0
        elif level > 100
            level = 100
        end

        self.brightness = level

        self.render_state()
        self.publish_status()

        tasmota.resp_cmnd(
            "Brightness set to " ..
            level ..
            "%"
        )
    end

    def init_colors()
        self.run_id += 1
        self.mixing = false
        self.solved = false

        self.reset_input()
        self.set_start_pattern()

        self.last_status = ""
        self.publish_status()

        tasmota.resp_cmnd(
            "Start colors initialized"
        )
    end

    def show_solved()
        self.run_id += 1

        self.enable = false
        self.mixing = false
        self.solved = false
        self.sound_sent = false

        self.reset_input()
        self.set_solved_pattern()

        self.last_status = ""
        self.publish_status()

        tasmota.resp_cmnd(
            "Solved preview shown"
        )
    end

    def rotate_internal(idx)
        idx = int(idx)

        if idx < 1 || idx > 9
            return false
        end

        var a = LED_MAP[idx][0]
        var b = LED_MAP[idx][1]
        var c = LED_MAP[idx][2]
        var d = LED_MAP[idx][3]

        var tmp = self.color_state[a]

        self.color_state[a] =
            self.color_state[b]

        self.color_state[b] =
            self.color_state[c]

        self.color_state[c] =
            self.color_state[d]

        self.color_state[d] = tmp

        self.render_state()

        return true
    end

    def rotate(idx)
        if self.mixing
            tasmota.resp_cmnd(
                "Mix animation active"
            )
            return
        end

        idx = int(idx)

        if !self.rotate_internal(idx)
            tasmota.resp_cmnd(
                "Bad hole"
            )
            return
        end

        self.publish_status()

        tasmota.resp_cmnd(
            "Block " ..
            idx ..
            " rotated"
        )
    end

    def delayed_rotate(idx, id)
        if !self.enable ||
           self.mixing ||
           id != self.run_id
            return
        end

        self.rotate_internal(idx)

        if self.solution_check()
            self.game_solved()
        else
            self.publish_status()
        end
    end

    def solution_check()
        for i: 0..2
            if self.color_state[
                RED_SOLUTION[i]
            ] != RED
                return false
            end

            if self.color_state[
                GREEN_SOLUTION[i]
            ] != GREEN
                return false
            end

            if self.color_state[
                BLUE_SOLUTION[i]
            ] != BLUE
                return false
            end

            if self.color_state[
                YELLOW_SOLUTION[i]
            ] != YELLOW
                return false
            end
        end

        return true
    end

    def game_solved()
        self.enable = false
        self.mixing = false
        self.solved = true

        mqtt.publish(
            "CKNIFEGAME",
            '{"data":"SOLVED"}'
        )

        print("Game solved")
        print(
            'MQTT: CKNIFEGAME = {"data":"SOLVED"}'
        )

        self.publish_status()
    end

    def stab(idx)
        idx = int(idx)

        if !self.enable ||
           self.mixing ||
           idx < 1 ||
           idx > 9

            tasmota.resp_cmnd(
                "Knife game inactive or bad hole"
            )
            return
        end

        self.publish_first()

        self.rotate_internal(idx)

        if self.solution_check()
            self.game_solved()
        else
            self.publish_status()
        end

        tasmota.resp_cmnd(
            "Virtual stab " ..
            idx
        )
    end

    def force_first()
        self.publish_first()
        self.publish_status()

        tasmota.resp_cmnd(
            "First usage forced"
        )
    end

    def force_complete()
        self.run_id += 1

        self.enable = true
        self.mixing = false
        self.solved = false

        self.reset_input()

        self.publish_first()
        self.set_solved_pattern()
        self.game_solved()

        tasmota.resp_cmnd(
            "Knife game force completed"
        )
    end

    def enable_game()
        self.run_id += 1

        self.enable = true
        self.mixing = false
        self.solved = false
        self.sound_sent = false

        self.reset_input()
        self.set_start_pattern()

        self.last_status = ""
        self.publish_status()

        tasmota.resp_cmnd(
            "Game enabled"
        )
    end

    def disable_game()
        self.run_id += 1

        self.enable = false
        self.mixing = false
        self.solved = false
        self.sound_sent = false

        self.reset_input()

        mqtt.publish(
            "cmnd/CANIMALWHEEL/i2sstop",
            ""
        )

        self.clear_state(OFF)
        self.render_state()

        self.last_status = ""
        self.publish_status()

        tasmota.resp_cmnd(
            "Game disabled, reset and leds off"
        )
    end

    def led_off()
        self.disable_game()
    end

    def finish_mix(id)
        if id != self.run_id
            return
        end

        self.mixing = false
        self.enable = true
        self.solved = false
        self.sound_sent = false

        self.reset_input()

        self.last_status = ""
        self.publish_status()

        print("Mix animation done")
        print("Knife inputs enabled")

        tasmota.resp_cmnd(
            "Mix animation done, game ready"
        )
    end

    def mix_step(step, id)
        if id != self.run_id ||
           !self.mixing
            return
        end

        self.rotate_internal(
            MIX_SEQUENCE[step]
        )

        self.publish_status()

        if step + 1 <
           MIX_SEQUENCE_COUNT

            tasmota.set_timer(
                MIX_STEP_MS,
                / -> self.mix_step(
                    step + 1,
                    id
                )
            )

            return
        end

        self.finish_mix(id)
    end

    def mix_to_start()
        self.run_id += 1

        self.enable = false
        self.mixing = true
        self.solved = false
        self.sound_sent = false

        self.reset_input()

        self.set_solved_pattern()

        self.last_status = ""
        self.publish_status()

        var id = self.run_id

        tasmota.set_timer(
            MIX_START_DELAY_MS,
            / -> self.mix_step(
                0,
                id
            )
        )

        tasmota.resp_cmnd(
            "Mix animation started"
        )
    end

    def every_50ms()
        self.publish_status()

        if !self.enable ||
           self.mixing
            return
        end

        var current = 0

        if !gpio.digital_read(HOLE1)
            current = 1
        elif !gpio.digital_read(HOLE2)
            current = 2
        elif !gpio.digital_read(HOLE3)
            current = 3
        elif !gpio.digital_read(HOLE4)
            current = 4
        elif !gpio.digital_read(HOLE5)
            current = 5
        elif !gpio.digital_read(HOLE6)
            current = 6
        elif !gpio.digital_read(HOLE7)
            current = 7
        elif !gpio.digital_read(HOLE8)
            current = 8
        elif !gpio.digital_read(HOLE9)
            current = 9
        end

        if current != 0 &&
           current == self.last_input

            self.stable_cnt += 1
        else
            self.stable_cnt = 1
            self.last_input = current
        end

        if self.stable_cnt == 10 &&
           current != 0

            if !self.triggered ||
               self.triggered != current

                self.triggered = current

                self.publish_first()

                var rotate_current =
                    current

                var id = self.run_id

                tasmota.set_timer(
                    50,
                    / -> self.delayed_rotate(
                        rotate_current,
                        id
                    )
                )
            end

        elif self.stable_cnt == 30 &&
             current != 0

            self.stable_cnt = 1
            self.triggered = 0
        end

        if current == 0
            self.triggered = 0
        end
    end
end

var knife_game_driver = KnifeGame()

tasmota.add_driver(
    knife_game_driver
)

tasmota.add_cmd(
    "enable",
    / -> knife_game_driver.enable_game()
)

tasmota.add_cmd(
    "init",
    / -> knife_game_driver.init_colors()
)

tasmota.add_cmd(
    "showsolved",
    / -> knife_game_driver.show_solved()
)

tasmota.add_cmd(
    "mix",
    / -> knife_game_driver.mix_to_start()
)

tasmota.add_cmd(
    "brightness",
    /cmd, i, level ->
        knife_game_driver.set_brightness(
            number(level)
        )
)

tasmota.add_cmd(
    "off",
    / -> knife_game_driver.led_off()
)

tasmota.add_cmd(
    "disable",
    / -> knife_game_driver.disable_game()
)

tasmota.add_cmd(
    "rotate",
    /cmd, i, idx ->
        knife_game_driver.rotate(
            number(idx)
        )
)

tasmota.add_cmd(
    "stab",
    /cmd, i, idx ->
        knife_game_driver.stab(
            number(idx)
        )
)

tasmota.add_cmd(
    "forcefirst",
    / -> knife_game_driver.force_first()
)

tasmota.add_cmd(
    "forcecomplete",
    / -> knife_game_driver.force_complete()
)

print("KnifeGame driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("enable - load start pattern and enable game")
print("init - load fixed start pattern")
print("showsolved - show solved pattern without SOLVED event")
print("mix - solved to start animation, then enable game")
print("brightness <0-100> - set LED brightness")
print("off - disable game and turn LEDs off")
print("disable - disable game and turn LEDs off")
print("rotate <n> - rotate block <n>")
print("stab <n> - virtual physical stab")
print("forcefirst - force first-use event")
print("forcecomplete - set solved pattern and send SOLVED")
print("--------------------------------------------------------------")