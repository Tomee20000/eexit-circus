import math
import mqtt

# =========================================================
# CONFIG
# =========================================================
var SERIAL_RX = 16
var SERIAL_TX = 17
var SERIAL_BAUD = 9600
var SERIAL_MODE = serial.SERIAL_8E1

var WS2812_PIN = 3
var LED_COUNT = 46

var LDR_PINS = [27, 14, 13, 23]
var LDR_ACTIVE_LOW = true
var LDR_USE_PULLUP = false

var LDR_REARM_MS = 80
var LDR_LOCK_MS = 250

var ANIM_INTERVAL_MS = 40
var BLINK_INTERVAL_MS = 250
var SHOT_TIME = 5000

var WAVE_SPEED = 0.15
var WAVE_LENGTH = 3
var BASE_BRIGHTNESS = 80
var WAVE_AMPLITUDE = 60

var SOLVED_TOPIC = "CDUCKGAME"
var SOLVED_PAYLOAD = '{"data":"SOLVED"}'

var SHOT_TOPIC = "CDUCKGAME"

# =========================================================
# SERIAL
# =========================================================
var serial_port = serial(
    SERIAL_RX,
    SERIAL_TX,
    SERIAL_BAUD,
    SERIAL_MODE
)

# =========================================================
# LED MAP
# =========================================================
var duck_led_map = {
    1: [0,1,2,3,4,5,6,7],
    2: [12,13,14,15,16,17,18,19],
    3: [25,26,27,28,29,30,31,32],
    4: [36,37,38,39,40,41,42,43]
}

# =========================================================
# GENERIC DUCK COMMAND
# =========================================================
def duck_command(cmd, idx, payload, payload_json)
    payload += "\n"
    serial_port.write(bytes().fromstring(payload))
    tasmota.resp_cmnd_done()
end

tasmota.add_cmd(
    "duck",
    /cmd, idx, payload, payload_json ->
        duck_command(cmd, idx, payload, payload_json)
)

# =========================================================
# DUCK GAME DRIVER
# =========================================================
class DuckGameDriver

    def home(cmd, idx)
        serial_port.write(
            bytes().fromstring("duck" .. idx .. " home\n")
        )
        tasmota.resp_cmnd("duck" .. idx .. " homing")
    end

    def home_all(cmd, idx)
        serial_port.write(
            bytes().fromstring("homeall\n")
        )
        tasmota.resp_cmnd("homing all")
    end

    def move(cmd, idx)
        serial_port.write(
            bytes().fromstring("duck" .. idx .. " move\n")
        )
        tasmota.resp_cmnd("duck" .. idx .. " moving")
    end

    def move_all(cmd, idx)
        serial_port.write(
            bytes().fromstring("moveall\n")
        )
        tasmota.cmd("ledinit")
        tasmota.cmd("enable")
        tasmota.resp_cmnd("moving all")
    end

    def stop(cmd, idx)
        serial_port.write(
            bytes().fromstring("duck" .. idx .. " stop\n")
        )
        tasmota.resp_cmnd("duck" .. idx .. " stopped")
    end

    def stop_all(cmd, idx)
        serial_port.write(
            bytes().fromstring("stopall\n")
        )
        tasmota.resp_cmnd("all stopped")
    end

    def restart(cmd, idx)
        serial_port.write(
            bytes().fromstring("duck" .. idx .. " restart\n")
        )
        tasmota.resp_cmnd("duck" .. idx .. " restarting")
    end

    def set_speed(cmd, idx, speed)
        if speed == "" ||
           number(speed) > 10 ||
           number(speed) < 1
            return
        end

        serial_port.write(
            bytes().fromstring(
                "duck" .. idx .. " speed " .. speed .. "\n"
            )
        )

        tasmota.resp_cmnd(
            "duck" .. idx .. " speed set to " .. speed
        )
    end
end

# =========================================================
# WAVE / LDR DRIVER
# =========================================================
class WaveDriver

    var time, strip
    var enabled, blink_state
    var duck_anim, duck_red
    var next_anim_ms, next_blink_ms
    var ldr_latched, ldr_off_since, ldr_lock_until
    var ldr_debug
    var solved

    def init()
        self.time = 0
        self.enabled = false
        self.blink_state = false
        self.next_anim_ms = 0
        self.next_blink_ms = 0
        self.solved = false

        self.duck_anim = [
            false,
            false,
            false,
            false
        ]

        self.duck_red = [
            false,
            false,
            false,
            false
        ]

        self.ldr_latched = [
            false,
            false,
            false,
            false
        ]

        self.ldr_off_since = [0, 0, 0, 0]
        self.ldr_lock_until = [0, 0, 0, 0]

        self.ldr_debug = [
            false,
            false,
            false,
            false
        ]

        for i: 0..3
            if LDR_USE_PULLUP
                gpio.pin_mode(
                    LDR_PINS[i],
                    gpio.INPUT_PULLUP
                )
            else
                gpio.pin_mode(
                    LDR_PINS[i],
                    gpio.INPUT
                )
            end
        end

        self.strip = Leds(
            LED_COUNT,
            gpio.pin(gpio.WS2812, WS2812_PIN)
        )

        self.strip.clear()
        self.strip.show()

        tasmota.add_fast_loop(
            / -> self.ldr_loop()
        )

        tasmota.add_fast_loop(
            / -> self.anim_loop()
        )
    end

    def read_ldr_pin(i)
        var hit = gpio.digital_read(LDR_PINS[i])

        if LDR_ACTIVE_LOW
            hit = !hit
        end

        return hit
    end

    def ldr_loop()
        var now = tasmota.millis()

        for i: 0..3
            var hit = self.read_ldr_pin(i)
            self.ldr_debug[i] = hit

            if hit
                self.ldr_off_since[i] = 0

                if !self.ldr_latched[i] &&
                   now >= self.ldr_lock_until[i]

                    self.ldr_latched[i] = true
                    self.ldr_lock_until[i] =
                        now + LDR_LOCK_MS

                    self.shoot_fast(i + 1)
                end
            else
                if self.ldr_off_since[i] == 0
                    self.ldr_off_since[i] = now
                end

                if self.ldr_latched[i] &&
                   now - self.ldr_off_since[i] >=
                   LDR_REARM_MS

                    self.ldr_latched[i] = false
                end
            end
        end
    end

    def anim_loop()
        if !self.enabled
            return
        end

        var now = tasmota.millis()

        if now < self.next_anim_ms
            return
        end

        self.next_anim_ms =
            now + ANIM_INTERVAL_MS

        self.ldr_loop()
        self.sea_wave()
        self.ldr_loop()
    end

    def rgb(r, g, b)
        return (r << 16) | (g << 8) | b
    end

    def set_duck_pixels(duck_id, color, brightness)
        for i: 0..(
            duck_led_map[duck_id].size() - 1
        )
            self.strip.set_pixel_color(
                duck_led_map[duck_id][i],
                color,
                brightness
            )
        end
    end

    def sea_wave()
        var now = tasmota.millis()
        var red_color = self.rgb(255, 0, 0)

        for i: 0..(LED_COUNT - 1)
            var wave = math.sin(
                (i / WAVE_LENGTH) + self.time
            )

            var level = (wave + 1) / 2

            var brightness =
                BASE_BRIGHTNESS +
                (level * WAVE_AMPLITUDE)

            if brightness > 255
                brightness = 255
            end

            self.strip.set_pixel_color(
                i,
                self.rgb(
                    0,
                    0,
                    int(brightness)
                ),
                255
            )
        end

        for duck_id: 1..4
            if self.duck_red[duck_id - 1]
                self.set_duck_pixels(
                    duck_id,
                    red_color,
                    255
                )
            end

            if self.duck_anim[duck_id - 1]
                if self.blink_state
                    self.set_duck_pixels(
                        duck_id,
                        red_color,
                        255
                    )
                else
                    self.set_duck_pixels(
                        duck_id,
                        red_color,
                        0
                    )
                end
            end
        end

        if now >= self.next_blink_ms
            self.next_blink_ms =
                now + BLINK_INTERVAL_MS

            self.blink_state =
                !self.blink_state
        end

        self.strip.show()
        self.time += WAVE_SPEED
    end

    def enable_game()
        self.enabled = true
        self.next_anim_ms = 0
        self.next_blink_ms = 0

        tasmota.resp_cmnd("Led enabled")
    end

    def disable_game()
        self.enabled = false

        self.duck_anim = [
            false,
            false,
            false,
            false
        ]

        self.duck_red = [
            false,
            false,
            false,
            false
        ]

        self.solved = false

        self.strip.clear()
        self.strip.show()

        tasmota.resp_cmnd("Led disabled")
    end

    def check_solved()
        if self.solved
            return
        end

        if self.duck_red[0] &&
           self.duck_red[1] &&
           self.duck_red[2] &&
           self.duck_red[3]

            self.solved = true

            mqtt.publish(
                SOLVED_TOPIC,
                SOLVED_PAYLOAD,
                false
            )

            print("DuckGame solved")
            print(
                "MQTT: " ..
                SOLVED_TOPIC ..
                " = " ..
                SOLVED_PAYLOAD
            )
        end
    end

    def finish_shot(idx)
        self.duck_anim[idx - 1] = false
        self.duck_red[idx - 1] = true

        self.check_solved()
    end

    def shoot_fast(idx)
        if idx < 1 || idx > 4
            return
        end

        if self.duck_anim[idx - 1] ||
           self.duck_red[idx - 1]
            return
        end

        self.duck_anim[idx - 1] = true
        self.blink_state = true

        mqtt.publish(
            SHOT_TOPIC,
            '{"data":"DUCK' .. idx .. 'SHOT"}',
            false
        )

        self.next_blink_ms =
            tasmota.millis() +
            BLINK_INTERVAL_MS

        tasmota.set_timer(
            SHOT_TIME,
            def()
                self.finish_shot(idx)
            end
        )
    end

    def shoot(cmd, idx)
        self.shoot_fast(idx)

        tasmota.resp_cmnd(
            "Duck" .. idx .. " shot down"
        )
    end

    def led_reset()
        self.duck_anim = [
            false,
            false,
            false,
            false
        ]

        self.duck_red = [
            false,
            false,
            false,
            false
        ]

        self.solved = false
        self.blink_state = false
        self.next_blink_ms = 0

        if self.enabled
            self.sea_wave()
        else
            self.strip.clear()
            self.strip.show()
        end

        tasmota.resp_cmnd("Led reset")
    end

    def led_init()
        self.enabled = false
        self.solved = false
        self.blink_state = false
        self.next_anim_ms = 0
        self.next_blink_ms = 0

        self.duck_anim = [
            false,
            false,
            false,
            false
        ]

        self.duck_red = [
            false,
            false,
            false,
            false
        ]

        self.ldr_latched = [
            false,
            false,
            false,
            false
        ]

        self.ldr_off_since = [0, 0, 0, 0]
        self.ldr_lock_until = [0, 0, 0, 0]

        self.ldr_debug = [
            false,
            false,
            false,
            false
        ]

        self.strip.clear()
        self.strip.show()

        tasmota.resp_cmnd("Led init")
    end

    def ldr_status(cmd)
        var msg = "LDR=["

        for i: 0..3
            if self.ldr_debug[i]
                msg = msg .. "1"
            else
                msg = msg .. "0"
            end

            if i < 3
                msg = msg .. ","
            end
        end

        msg = msg .. "]"

        tasmota.resp_cmnd(msg)
    end
end

# =========================================================
# INIT
# =========================================================
var duck_game_driver = DuckGameDriver()
var wave_driver = WaveDriver()

tasmota.add_driver(duck_game_driver)
tasmota.add_driver(wave_driver)

# =========================================================
# COMMANDS
# =========================================================
tasmota.add_cmd(
    "enable",
    /cmd, idx -> wave_driver.enable_game()
)

tasmota.add_cmd(
    "disable",
    /cmd, idx -> wave_driver.disable_game()
)

tasmota.add_cmd(
    "duckshoot",
    /cmd, idx -> wave_driver.shoot(cmd, idx)
)

tasmota.add_cmd(
    "ledinit",
    /cmd, idx -> wave_driver.led_init()
)

tasmota.add_cmd(
    "ledreset",
    /cmd, idx -> wave_driver.led_reset()
)

tasmota.add_cmd(
    "ldrstatus",
    /cmd -> wave_driver.ldr_status(cmd)
)

tasmota.add_cmd(
    "home",
    /cmd, idx -> duck_game_driver.home(cmd, idx)
)

tasmota.add_cmd(
    "homeall",
    /cmd, idx -> duck_game_driver.home_all(cmd, idx)
)

tasmota.add_cmd(
    "move",
    /cmd, idx -> duck_game_driver.move(cmd, idx)
)

tasmota.add_cmd(
    "moveall",
    /cmd, idx -> duck_game_driver.move_all(cmd, idx)
)

tasmota.add_cmd(
    "stop",
    /cmd, idx -> duck_game_driver.stop(cmd, idx)
)

tasmota.add_cmd(
    "stopall",
    /cmd, idx -> duck_game_driver.stop_all(cmd, idx)
)

tasmota.add_cmd(
    "duckrestart",
    /cmd, idx -> duck_game_driver.restart(cmd, idx)
)

tasmota.add_cmd(
    "speed",
    /cmd, idx, speed ->
        duck_game_driver.set_speed(
            cmd,
            idx,
            speed
        )
)

# =========================================================
# HELP / INFO
# =========================================================
print("DuckGame driver loaded")
print("--------------------------------------------------------------")
print("Command example: home1 - duck1 start homing")
print("home<n> - start homing for the selected duck")
print("homeall - start homing for all ducks")
print("move<n> - start moving the selected duck up and down")
print("moveall - start moving all ducks up and down")
print("stop<n> - stop movement of the selected duck")
print("stopall - stop movement of all ducks")
print("duckrestart - restart the ESP32-C3 SuperMini")
print("speed<n> <value> - set movement speed of duck 1-10")
print("--------------------------------------------------------------")

print("Wave driver loaded")
print("--------------------------------------------------------------")
print("enable - enable LED animation system")
print("disable - disable LED and turn off all LEDs")
print("ledinit - reset LED state and internal flags")
print("ledreset - clear shot/red LED states")
print("duckshoot<n> - start red blinking animation behind duck<n> for 5 seconds")
print("ldrstatus - show current LDR raw hit states")
print("--------------------------------------------------------------")

tasmota.cmd("homeall")
tasmota.cmd("homeall")