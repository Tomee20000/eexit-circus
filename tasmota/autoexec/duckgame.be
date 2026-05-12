import math

# =========================================================
# SERIAL
# =========================================================
var serial_port = serial(16, 17, 9600, serial.SERIAL_8E1)

# =========================================================
# LED MAP
# =========================================================
var duck_led_map = {
    1: [0,1,2,3,4,5,6,7],
    2: [12,13,14,15,16,17,18,19],
    3: [25,26,27,28,29,30,31,32],
    4: [36,37,38,39,40,41,42,43]
}

var LDR1 = 27
var LDR2 = 14
var LDR3 = 13
var LDR4 = 23

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

    var time, speed, wavelength
    var base_brightness, amplitude
    var strip, led_count

    var enabled
    var duck_anim_1, duck_anim_2, duck_anim_3, duck_anim_4

    var blink_state
    var loop_counter

    def fast_loop()
        if self.enabled
            self.sea_wave()
            self.loop_counter += 1
        end

        if self.loop_counter == 10
            self.loop_counter = 0
        end

        if !gpio.digital_read(LDR1)
            self.shoot(0,1)
        end

        if !gpio.digital_read(LDR2)
            self.shoot(0,2)
        end

        if !gpio.digital_read(LDR3)
            self.shoot(0,3)
        end

        if !gpio.digital_read(LDR4)
            self.shoot(0,4)
        end
    end

    def init()
        self.time = 0
        self.speed = 0.15
        self.wavelength = 3

        self.base_brightness = 120
        self.amplitude = 20

        self.led_count = 46

        self.enabled = false

        self.duck_anim_1 = false
        self.duck_anim_2 = false
        self.duck_anim_3 = false
        self.duck_anim_4 = false

        self.blink_state = false
        self.loop_counter = 0

        self.strip = Leds(self.led_count, gpio.pin(gpio.WS2812, 3))
        self.strip.clear()

        tasmota.add_fast_loop(/-> self.fast_loop())

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

        for i: 0..(self.led_count - 1)
            var wave = math.sin((i / self.wavelength) + self.time)
            var level = (wave + 1) / 2
            var brightness = self.base_brightness + (level * self.amplitude)

            if brightness > 255
                brightness = 255
            end

            var color = self.rgb(0, 0, int(brightness))
            self.strip.set_pixel_color(i, color, 255)
        end

        for i: 0..(duck_led_map[1].size()-1)
            if self.duck_anim_1
                self.set_duck_pixel(1, i, red_color)
            end
            if self.duck_anim_2
                self.set_duck_pixel(2, i, red_color)
            end
            if self.duck_anim_3
                self.set_duck_pixel(3, i, red_color)
            end
            if self.duck_anim_4
                self.set_duck_pixel(4, i, red_color)
            end
        end

        if self.loop_counter % 10 == 0
            self.blink_state = !self.blink_state
        end

        self.strip.show()
        self.time += self.speed
    end

    def enable_game()
        self.enabled = true
        tasmota.resp_cmnd("Led enabled")
    end

    def disable_game()
        self.enabled = false
        self.strip.clear()
        tasmota.resp_cmnd("Led disabled")
    end

    def shoot(cmd, idx)
        if idx == 1
            self.duck_anim_1 = true
            tasmota.set_timer(5000, def() self.duck_anim_1 = false end)
        elif idx == 2
            self.duck_anim_2 = true
            tasmota.set_timer(5000, def() self.duck_anim_2 = false end)
        elif idx == 3
            self.duck_anim_3 = true
            tasmota.set_timer(5000, def() self.duck_anim_3 = false end)
        elif idx == 4
            self.duck_anim_4 = true
            tasmota.set_timer(5000, def() self.duck_anim_4 = false end)
        end

        self.blink_state = true
        self.loop_counter = 0

        tasmota.resp_cmnd("Duck" .. idx .. " shot down")
    end

    def led_init()
        self.duck_anim_1 = false
        self.duck_anim_2 = false
        self.duck_anim_3 = false
        self.duck_anim_4 = false

        self.enabled = false
        self.strip.clear()

        self.blink_state = false

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
print("speed<n> <value> - set movement speed of duck (1–10)")
print("--------------------------------------------------------------")

print("Wave driver loaded")
print("--------------------------------------------------------------")
print("enable - enable LED animation system")
print("disable - disable LED and turn off all LEDs")
print("ledinit - reset LED state and internal flags")
print("duckshoot<n> - start red blinking animation behind duck<n> for 5 seconds")
print("--------------------------------------------------------------")