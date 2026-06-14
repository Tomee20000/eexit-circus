import math
import mqtt

var RED = 0xFF0000
var GREEN = 0x013C10
var BLUE = 0x0000FF
var YELLOW = 0xFFFF00
var WHITE = 0xFFFFFF

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

var LED_SOLUTION = {
    RED : [0,1,2],
    GREEN : [22,20,18],
    BLUE : [3,16,17],
    YELLOW : [9,10,23]
}

class KnifeGame
    var strip, color_map, rnd
    var hole1, hole2, hole3, hole4, hole5
    var hole6, hole7, hole8, hole9
    var enable, stable_cnt, last_input, triggered

    def init()
        self.strip = Leds(
            24,
            gpio.pin(gpio.WS2812, 3)
        )

        self.strip.set_gamma(false)

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

        self.hole1 = false
        self.hole2 = false
        self.hole3 = false
        self.hole4 = false
        self.hole5 = false
        self.hole6 = false
        self.hole7 = false
        self.hole8 = false
        self.hole9 = false

        self.enable = false
        self.stable_cnt = 0
        self.last_input = 0
        self.triggered = 0

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

    def enable_game()
        self.enable = true
        self.stable_cnt = 0
        self.last_input = 0
        self.triggered = 0

        tasmota.resp_cmnd("Game enabled")
    end

    def led_off()
        self.strip.clear()
        self.strip.show()

        tasmota.resp_cmnd("Led off")
    end

    def color_init()
        for i: 0..5
            self.strip.set_pixel_color(
                self.color_map[i],
                RED,
                255
            )

            self.strip.set_pixel_color(
                self.color_map[i + 6],
                YELLOW,
                255
            )

            self.strip.set_pixel_color(
                self.color_map[i + 12],
                BLUE,
                255
            )

            self.strip.set_pixel_color(
                self.color_map[i + 18],
                GREEN,
                255
            )
        end

        self.strip.show()

        tasmota.resp_cmnd(
            "Colors initialized"
        )
    end

    def color_init_rnd()
        for i: 0..self.strip.pixel_count()-1
            self.strip.set_pixel_color(
                i,
                WHITE,
                255
            )
        end

        for i: 0..2
            self.strip.set_pixel_color(
                self.rnd[i],
                RED,
                255
            )

            self.strip.set_pixel_color(
                self.rnd[i + 3],
                YELLOW,
                255
            )

            self.strip.set_pixel_color(
                self.rnd[i + 6],
                BLUE,
                255
            )

            self.strip.set_pixel_color(
                self.rnd[i + 9],
                GREEN,
                255
            )
        end

        self.strip.show()

        tasmota.resp_cmnd(
            "Colors initialized randomly"
        )
    end

    def rotate(idx)
        var buf = self.strip.pixels_buffer()
        var ps = self.strip.pixel_size()

        var ia = LED_MAP[idx][0] * ps
        var ib = LED_MAP[idx][1] * ps
        var ic = LED_MAP[idx][2] * ps
        var id = LED_MAP[idx][3] * ps

        var tmp = [0,0,0]

        for i: 0..(ps-1)
            tmp[i] = buf[ia + i]

            buf[ia + i] = buf[ib + i]
            buf[ib + i] = buf[ic + i]
            buf[ic + i] = buf[id + i]
            buf[id + i] = tmp[i]
        end

        self.strip.dirty()
        self.strip.show()

        tasmota.resp_cmnd(
            "Block " ..
            idx ..
            " rotated (reverse)."
        )
    end

    def solution_check()
        for i: 0..2
            if self.strip.get_pixel_color(
                LED_SOLUTION[RED][i]
            ) != RED
                return false
            end

            if self.strip.get_pixel_color(
                LED_SOLUTION[GREEN][i]
            ) != GREEN
                return false
            end

            if self.strip.get_pixel_color(
                LED_SOLUTION[BLUE][i]
            ) != BLUE
                return false
            end

            if self.strip.get_pixel_color(
                LED_SOLUTION[YELLOW][i]
            ) != YELLOW
                return false
            end
        end

        return true
    end

    def game_solved()
        self.enable = false

        mqtt.publish(
            "CKNIFEGAME",
            '{"data":"SOLVED"}'
        )

        print("Game solved")
        print(
            'MQTT: CKNIFEGAME = {"data":"SOLVED"}'
        )
    end

    def every_50ms()
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
                self.rotate(current)
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
    "rotate",
    /cmd, i, idx ->
        knife_game_driver.rotate(number(idx))
)

print("KnifeGame driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("enable - game enabled")
print("off - led off")
print("init - initialize the colors, no WHITE")
print("rndinit - initialize the colors, with WHITE, random order")
print("rotate <n> - rotates the <n> block")
print("--------------------------------------------------------------")