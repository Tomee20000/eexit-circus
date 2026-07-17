import math
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

class KnifeGame
    var strip, color_map, color_state, rnd
    var enable, stable_cnt, last_input, triggered, sound_sent
    var solved, last_status, run_id

    def init()
        self.strip = Leds(
            24,
            gpio.pin(gpio.WS2812, 3)
        )

        self.rnd = [
            4,5,6,7,8,11,
            12,13,14,15,19,21
        ]

        self.color_map = [
            18,21,22,13,19,20,
            3,4,16,15,17,14,
            8,9,10,11,12,23,
            0,1,2,5,6,7
        ]

        self.color_state = [
            OFF,OFF,OFF,OFF,OFF,OFF,
            OFF,OFF,OFF,OFF,OFF,OFF,
            OFF,OFF,OFF,OFF,OFF,OFF,
            OFF,OFF,OFF,OFF,OFF,OFF
        ]

        self.enable = false
        self.stable_cnt = 0
        self.last_input = 0
        self.triggered = 0
        self.sound_sent = false
        self.solved = false
        self.last_status = ""
        self.run_id = 0

        self.strip.clear()
        self.strip.show()

        math.srand(tasmota.millis())

        for i: 0..11
            var j = math.rand() % 12
            var tmp = self.rnd[i]

            self.rnd[i] = self.rnd[j]
            self.rnd[j] = tmp
        end
    end

    def publish_first()
        if self.sound_sent
            return
        end
        mqtt.publish("CKNIFEGAME", '{"data":"FIRST"}')
        mqtt.publish("cmnd/CANIMALWHEEL/i2splay", "mp3/knife.mp3")
        self.sound_sent = true
    end

    def build_status()
        var msg = '{"enabled":' .. (self.enable ? "true" : "false") .. ',"solved":' .. (self.solved ? "true" : "false") .. ',"first_used":' .. (self.sound_sent ? "true" : "false") .. ',"colors":['
        for i: 0..23
            if i > 0
                msg = msg .. ","
            end
            msg = msg .. '"' .. format("%06X", self.color_state[i]) .. '"'
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
        mqtt.publish("CKNIFEGAME/STATUS", msg, true)
    end

    def stab(idx)
        idx = int(idx)
        if !self.enable || idx < 1 || idx > 9
            tasmota.resp_cmnd("Knife game inactive or bad hole")
            return
        end
        self.publish_first()
        self.rotate(idx)
        if self.solution_check()
            self.game_solved()
        end
        self.publish_status()
        tasmota.resp_cmnd("Virtual stab " .. idx)
    end

    def force_first()
        self.publish_first()
        self.publish_status()
        tasmota.resp_cmnd("First usage forced")
    end

    def force_complete()
        self.run_id += 1
        self.enable = true
        self.stable_cnt = 0
        self.last_input = 0
        self.triggered = 0
        self.solved = false

        self.publish_first()

        # Preserve the white base used by normal random initialization.
        for i: 0..23
            self.set_color(i, WHITE)
        end

        for i: 0..2
            self.set_color(RED_SOLUTION[i], RED)
            self.set_color(GREEN_SOLUTION[i], GREEN)
            self.set_color(BLUE_SOLUTION[i], BLUE)
            self.set_color(YELLOW_SOLUTION[i], YELLOW)
        end

        self.strip.show()
        self.game_solved()
        self.publish_status()
        tasmota.resp_cmnd("Knife game force completed")
    end

    def enable_game()
        self.run_id += 1
        self.enable = true
        self.stable_cnt = 0
        self.last_input = 0
        self.triggered = 0
        self.sound_sent = false
        self.solved = false
        self.last_status = ""
        self.publish_status()

        tasmota.resp_cmnd("Game enabled")
    end

    def disable_game()
        self.run_id += 1
        self.enable = false
        self.stable_cnt = 0
        self.last_input = 0
        self.triggered = 0
        self.sound_sent = false
        self.solved = false

        mqtt.publish(
            "cmnd/CANIMALWHEEL/i2sstop",
            ""
        )

        self.strip.clear()
        self.strip.show()

        for i: 0..23
            self.color_state[i] = OFF
        end

        self.last_status = ""
        self.publish_status()

        tasmota.resp_cmnd("Game disabled, reset and leds off")
    end

    def led_off()
        self.disable_game()
    end

    def set_color(index, color)
        self.strip.set_pixel_color(
            index,
            color,
            255
        )

        self.color_state[index] = color
    end

    def color_init()
        for i: 0..5
            self.set_color(
                self.color_map[i],
                RED
            )

            self.set_color(
                self.color_map[i + 6],
                YELLOW
            )

            self.set_color(
                self.color_map[i + 12],
                BLUE
            )

            self.set_color(
                self.color_map[i + 18],
                GREEN
            )
        end

        self.strip.show()
        self.publish_status()

        tasmota.resp_cmnd(
            "Colors initialized"
        )
    end

    def color_init_rnd()
        for i: 0..23
            self.set_color(
                i,
                WHITE
            )
        end

        for i: 0..2
            self.set_color(
                self.rnd[i],
                RED
            )

            self.set_color(
                self.rnd[i + 3],
                YELLOW
            )

            self.set_color(
                self.rnd[i + 6],
                BLUE
            )

            self.set_color(
                self.rnd[i + 9],
                GREEN
            )
        end

        self.strip.show()
        self.publish_status()

        tasmota.resp_cmnd(
            "Colors initialized randomly"
        )
    end

    def rotate(idx)
        var buf = self.strip.pixels_buffer()
        var ps = self.strip.pixel_size()

        var a = LED_MAP[idx][0]
        var b = LED_MAP[idx][1]
        var c = LED_MAP[idx][2]
        var d = LED_MAP[idx][3]

        var ia = a * ps
        var ib = b * ps
        var ic = c * ps
        var id = d * ps

        var tmp = [0,0,0]

        for i: 0..(ps - 1)
            tmp[i] = buf[ia + i]

            buf[ia + i] = buf[ib + i]
            buf[ib + i] = buf[ic + i]
            buf[ic + i] = buf[id + i]
            buf[id + i] = tmp[i]
        end

        var color_tmp = self.color_state[a]

        self.color_state[a] = self.color_state[b]
        self.color_state[b] = self.color_state[c]
        self.color_state[c] = self.color_state[d]
        self.color_state[d] = color_tmp

        self.strip.dirty()
        self.strip.show()

        tasmota.resp_cmnd(
            "Block " ..
            idx ..
            " rotated (reverse)."
        )
    end

    def delayed_rotate(idx, id)
        if !self.enable || id != self.run_id
            return
        end

        self.rotate(idx)
        self.publish_status()
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

    def every_50ms()
        self.publish_status()

        if !self.enable
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

                var rotate_current = current
                var id = self.run_id

                tasmota.set_timer(
                    50,
                    / -> self.delayed_rotate(rotate_current, id)
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

        if self.solution_check()
            self.game_solved()
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
    / -> knife_game_driver.color_init()
)

tasmota.add_cmd(
    "rndinit",
    / -> knife_game_driver.color_init_rnd()
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

tasmota.add_cmd("stab", /cmd, i, idx -> knife_game_driver.stab(number(idx)))
tasmota.add_cmd("forcefirst", / -> knife_game_driver.force_first())
tasmota.add_cmd("forcecomplete", / -> knife_game_driver.force_complete())

print("KnifeGame driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("enable - game enabled")
print("off - game disabled, reset and leds off")
print("disable - game disabled, reset and leds off")
print("init - initialize the colors, no WHITE")
print("rndinit - initialize the colors, with WHITE, random order")
print("rotate <n> - rotates the <n> block")
print("stab <n> - virtual physical stab")
print("forcefirst - force only first-use event")
print("forcecomplete - set solved colors and SOLVED event")
print("--------------------------------------------------------------")
