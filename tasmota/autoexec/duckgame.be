import math

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

var ANIM_SKIP = 5
var SHOT_TIME = 5000

var WAVE_SPEED = 0.15
var WAVE_LENGTH = 3
var BASE_BRIGHTNESS = 120
var WAVE_AMPLITUDE = 20

# =========================================================
# SERIAL
# =========================================================
var serial_port = serial(SERIAL_RX, SERIAL_TX, SERIAL_BAUD, SERIAL_MODE)

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

tasmota.add_cmd("duck", /cmd, idx, payload, payload_json -> duck_command(cmd, idx, payload, payload_json))


# =========================================================
# DUCK GAME DRIVER
# =========================================================
class DuckGameDriver

    def home(cmd, idx)
        serial_port.write(bytes().fromstring("duck" .. idx .. " home\n"))
        tasmota.resp_cmnd("duck" .. idx .. " homing")
    end

    def home_all(cmd, idx)
        serial_port.write(bytes().fromstring("homeall\n"))
        tasmota.resp_cmnd("homing all")
    end

    def move(cmd, idx)
        serial_port.write(bytes().fromstring("duck" .. idx .. " move\n"))
        tasmota.resp_cmnd("duck" .. idx .. " moving")
    end

    def move_all(cmd, idx)
        serial_port.write(bytes().fromstring("moveall\n"))
        tasmota.cmd("ledinit")
        tasmota.cmd("enable")
        tasmota.resp_cmnd("moving all")
    end

    def stop(cmd, idx)
        serial_port.write(bytes().fromstring("duck" .. idx .. " stop\n"))
        tasmota.resp_cmnd("duck" .. idx .. " stopped")
    end

    def stop_all(cmd, idx)
        serial_port.write(bytes().fromstring("stopall\n"))
        tasmota.resp_cmnd("all stopped")
    end

    def restart(cmd, idx)
        serial_port.write(bytes().fromstring("duck" .. idx .. " restart\n"))
        tasmota.resp_cmnd("duck" .. idx .. " restarting")
    end

    def set_speed(cmd, idx, speed)
        if speed == "" || number(speed) > 10 || number(speed) < 1
            return
        end

        serial_port.write(bytes().fromstring("duck" .. idx .. " speed " .. speed .. "\n"))
        tasmota.resp_cmnd("duck" .. idx .. " speed set to " .. speed)
    end
end


# =========================================================
# WAVE DRIVER
# =========================================================
class WaveDriver

    var time, strip
    var enabled, blink_state
    var loop_counter, anim_counter
    var duck_anim
    var ldr_last

    def init()
        self.time = 0
        self.enabled = false
        self.blink_state = false
        self.loop_counter = 0
        self.anim_counter = 0

        self.duck_anim = [false, false, false, false]
        self.ldr_last = [false, false, false, false]

        self.strip = Leds(LED_COUNT, gpio.pin(gpio.WS2812, WS2812_PIN))
        self.strip.clear()
        self.strip.show()

        tasmota.add_fast_loop(/-> self.fast_loop())
    end

    def fast_loop()
        self.read_ldr()

        if self.enabled
            self.anim_counter += 1

            if self.anim_counter >= ANIM_SKIP
                self.anim_counter = 0
                self.sea_wave()
                self.loop_counter += 1

                if self.loop_counter >= 10
                    self.loop_counter = 0
                end
            end
        end
    end

    def read_ldr()
        for i: 0..3
            var hit = gpio.digital_read(LDR_PINS[i])

            if LDR_ACTIVE_LOW
                hit = !hit
            end

            if hit && !self.ldr_last[i]
                self.shoot_fast(i + 1)
            end

            self.ldr_last[i] = hit
        end
    end

    def rgb(r, g, b)
        return (r << 16) | (g << 8) | b
    end

    def set_duck_pixel(duck_id, index, color)
        if self.blink_state
            self.strip.set_pixel_color(duck_led_map[duck_id][index], color, 255)
        else
            self.strip.set_pixel_color(duck_led_map[duck_id][index], color, 0)
        end
    end

    def sea_wave()
        var red_color = self.rgb(255, 0, 0)

        for i: 0..(LED_COUNT - 1)
            var wave = math.sin((i / WAVE_LENGTH) + self.time)
            var level = (wave + 1) / 2
            var brightness = BASE_BRIGHTNESS + (level * WAVE_AMPLITUDE)

            if brightness > 255
                brightness = 255
            end

            self.strip.set_pixel_color(i, self.rgb(0, 0, int(brightness)), 255)
        end

        for duck_id: 1..4
            if self.duck_anim[duck_id - 1]
                for i: 0..(duck_led_map[duck_id].size() - 1)
                    self.set_duck_pixel(duck_id, i, red_color)
                end
            end
        end

        if self.loop_counter % 10 == 0
            self.blink_state = !self.blink_state
        end

        self.strip.show()
        self.time += WAVE_SPEED
    end

    def enable_game()
        self.enabled = true
        tasmota.resp_cmnd("Led enabled")
    end

    def disable_game()
        self.enabled = false
        self.duck_anim = [false, false, false, false]
        self.strip.clear()
        self.strip.show()
        tasmota.resp_cmnd("Led disabled")
    end

    def shoot_fast(idx)
        if self.duck_anim[idx - 1]
            return
        end

        self.duck_anim[idx - 1] = true
        self.blink_state = true
        self.loop_counter = 0

        tasmota.set_timer(SHOT_TIME, def() self.duck_anim[idx - 1] = false end)
    end

    def shoot(cmd, idx)
        self.shoot_fast(idx)
        tasmota.resp_cmnd("Duck" .. idx .. " shot down")
    end

    def led_init()
        self.enabled = false
        self.blink_state = false
        self.loop_counter = 0
        self.anim_counter = 0
        self.duck_anim = [false, false, false, false]
        self.ldr_last = [false, false, false, false]
        self.strip.clear()
        self.strip.show()
        tasmota.resp_cmnd("Led init")
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
tasmota.add_cmd("enable", /cmd, idx -> wave_driver.enable_game())
tasmota.add_cmd("disable", /cmd, idx -> wave_driver.disable_game())
tasmota.add_cmd("duckshoot", /cmd, idx -> wave_driver.shoot(cmd, idx))
tasmota.add_cmd("ledinit", /cmd, idx -> wave_driver.led_init())

tasmota.add_cmd("home", /cmd, idx -> duck_game_driver.home(cmd, idx))
tasmota.add_cmd("homeall", /cmd, idx -> duck_game_driver.home_all(cmd, idx))
tasmota.add_cmd("move", /cmd, idx -> duck_game_driver.move(cmd, idx))
tasmota.add_cmd("moveall", /cmd, idx -> duck_game_driver.move_all(cmd, idx))
tasmota.add_cmd("stop", /cmd, idx -> duck_game_driver.stop(cmd, idx))
tasmota.add_cmd("stopall", /cmd, idx -> duck_game_driver.stop_all(cmd, idx))
tasmota.add_cmd("duckrestart", /cmd, idx -> duck_game_driver.restart(cmd, idx))
tasmota.add_cmd("speed", /cmd, idx, speed -> duck_game_driver.set_speed(cmd, idx, speed))


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
print("duckshoot<n> - start red blinking animation behind duck<n> for 5 seconds")
print("--------------------------------------------------------------")

tasmota.cmd("homeall")
tasmota.cmd("homeall")