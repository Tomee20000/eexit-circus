import math
import mqtt

var SERIAL_RX = 16
var SERIAL_TX = 17
var SERIAL_BAUD = 9600
var SERIAL_MODE = serial.SERIAL_8N1

var WS2812_PIN = 3
var LED_COUNT = 46

var LDR_PINS = [27, 14, 13, 23]
var LDR_ACTIVE_LOW = true
var LDR_USE_PULLUP = false

var DUCK_MOVE_PINS = [32, 33, 25, 26]
var DUCK_MOVE_ACTIVE_HIGH = true

var WATCHDOG_INTERVAL_MS = 50
var MOVE_START_GRACE_MS = 1200
var MOVE_STOP_GRACE_MS = 700
var HOME_START_TIMEOUT_MS = 1500
var HOME_LOW_STABLE_MS = 300

var LDR_REARM_MS = 80
var LDR_LOCK_MS = 250

var ANIM_INTERVAL_MS = 40
var BLINK_INTERVAL_MS = 250
var SHOT_TIME = 5000

var SOLVED_FRAME_MS = 35
var SOLVED_FLASH_TIME_MS = 1000
var SOLVED_SPLASH_TIME_MS = 4500
var SOLVED_FADE_TIME_MS = 4500
var SOLVED_TOTAL_TIME_MS =
    SOLVED_FLASH_TIME_MS +
    SOLVED_SPLASH_TIME_MS +
    SOLVED_FADE_TIME_MS

var WAVE_SPEED = 0.15
var WAVE_LENGTH = 3
var BASE_BRIGHTNESS = 80
var WAVE_AMPLITUDE = 60

var SOLVED_TOPIC = "CDUCKGAME"
var SOLVED_PAYLOAD = '{"data":"SOLVED"}'

var SHOT_TOPIC = "CDUCKGAME"

var duck_game_driver = nil
var wave_driver = nil
var duck_move_watchdog = nil

var serial_port = serial(
    SERIAL_RX,
    SERIAL_TX,
    SERIAL_BAUD,
    SERIAL_MODE
)

var duck_led_map = {
    1: [0,1,2,3,4,5,6,7],
    2: [12,13,14,15,16,17,18,19],
    3: [25,26,27,28,29,30,31,32],
    4: [36,37,38,39,40,41,42,43]
}

def send_duck_cmd(idx, action)
    serial_port.write(
        bytes().fromstring(
            "duck" .. idx .. " " .. action .. "\n"
        )
    )
end

def send_broadcast_cmd(action)
    serial_port.write(
        bytes().fromstring(action .. "\n")
    )
end

def force_status_publish()
    if wave_driver != nil
        wave_driver.last_status = ""
        wave_driver.publish_status()
    end
end

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

class DuckMoveWatchdog

    var wanted, has_moved
    var homing, recovering, pending_move
    var home_confirmed
    var moveall_pending
    var move_cmd_ms, low_since
    var home_cmd_ms, home_seen_high, home_low_since
    var next_check_ms

    def init()
        self.wanted = [false, false, false, false]
        self.has_moved = [false, false, false, false]

        self.homing = [false, false, false, false]
        self.recovering = [false, false, false, false]
        self.pending_move = [false, false, false, false]

        self.home_confirmed = [false, false, false, false]
        self.moveall_pending = false

        self.move_cmd_ms = [0, 0, 0, 0]
        self.low_since = [0, 0, 0, 0]

        self.home_cmd_ms = [0, 0, 0, 0]
        self.home_seen_high = [false, false, false, false]
        self.home_low_since = [0, 0, 0, 0]

        self.next_check_ms = 0

        for i: 0..3
            gpio.pin_mode(DUCK_MOVE_PINS[i], gpio.INPUT)
        end

        tasmota.add_fast_loop(/ -> self.loop())
    end

    def write_duck(idx, cmd)
        send_duck_cmd(idx, cmd)
    end

    def read_move(i)
        var moving = gpio.digital_read(DUCK_MOVE_PINS[i])

        if !DUCK_MOVE_ACTIVE_HIGH
            moving = !moving
        end

        return moving
    end

    def is_down(idx)
        if wave_driver == nil
            return false
        end

        return wave_driver.duck_is_down(idx)
    end

    def all_home_confirmed()
        for i: 0..3
            if !self.home_confirmed[i]
                return false
            end
        end

        return true
    end

    def reset_motion_state(i)
        self.wanted[i] = false
        self.has_moved[i] = false

        self.homing[i] = false
        self.recovering[i] = false
        self.pending_move[i] = false

        self.move_cmd_ms[i] = 0
        self.low_since[i] = 0

        self.home_cmd_ms[i] = 0
        self.home_seen_high[i] = false
        self.home_low_since[i] = 0
    end

    def begin_home(idx, move_after_home, recovery_mode)
        if idx < 1 || idx > 4
            return
        end

        var i = idx - 1
        var now = tasmota.millis()

        self.wanted[i] = false
        self.has_moved[i] = false

        self.homing[i] = true
        self.recovering[i] = recovery_mode
        self.pending_move[i] = move_after_home

        self.home_confirmed[i] = false

        self.move_cmd_ms[i] = 0
        self.low_since[i] = 0

        self.home_cmd_ms[i] = now
        self.home_seen_high[i] = false
        self.home_low_since[i] = 0
    end

    def request_home(idx, move_after_home)
        if idx < 1 || idx > 4
            return
        end

        if self.is_down(idx)
            self.stop_duck(idx)
            return
        end

        self.begin_home(idx, move_after_home, false)
        self.write_duck(idx, "home")

        print("Duck" .. idx .. " homing requested")
        force_status_publish()
    end

    def request_home_all()
        self.moveall_pending = false

        for idx: 1..4
            if !self.is_down(idx)
                self.begin_home(idx, false, false)
            end
        end

        send_broadcast_cmd("homeall")

        print("All ducks homing requested")
        force_status_publish()
    end

    def prepare_home_all_for_moveall()
        self.moveall_pending = true

        for idx: 1..4
            if !self.is_down(idx)
                self.begin_home(idx, false, false)
            end
        end

        send_broadcast_cmd("homeall")

        print("Moveall waiting for all ducks to home")
        force_status_publish()
    end

    def send_single_move(idx)
        if idx < 1 || idx > 4
            return false
        end

        if self.is_down(idx)
            self.stop_duck(idx)
            return false
        end

        var i = idx - 1
        var now = tasmota.millis()

        if !self.home_confirmed[i]
            print("Duck" .. idx .. " move rejected, not home")
            force_status_publish()
            return false
        end

        self.write_duck(idx, "move")

        self.wanted[i] = true
        self.has_moved[i] = false

        self.homing[i] = false
        self.recovering[i] = false
        self.pending_move[i] = false

        self.home_confirmed[i] = false

        self.move_cmd_ms[i] = now
        self.low_since[i] = 0

        self.home_cmd_ms[i] = 0
        self.home_seen_high[i] = false
        self.home_low_since[i] = 0

        print("Duck" .. idx .. " moving from confirmed home")
        force_status_publish()

        return true
    end

    def dispatch_moveall()
        var now = tasmota.millis()

        self.moveall_pending = false

        send_broadcast_cmd("moveall")

        for i: 0..3
            self.wanted[i] = true
            self.has_moved[i] = false

            self.homing[i] = false
            self.recovering[i] = false
            self.pending_move[i] = false

            self.home_confirmed[i] = false

            self.move_cmd_ms[i] = now
            self.low_since[i] = 0

            self.home_cmd_ms[i] = 0
            self.home_seen_high[i] = false
            self.home_low_since[i] = 0
        end

        if wave_driver != nil && !wave_driver.enabled
            wave_driver.enable_game()
        end

        print("Moveall broadcast sent")
        force_status_publish()
    end

    def request_move(idx)
        return self.send_single_move(idx)
    end

    def request_move_all()
        if self.all_home_confirmed()
            self.dispatch_moveall()
        else
            self.prepare_home_all_for_moveall()
        end
    end

    def stop_duck(idx)
        if idx < 1 || idx > 4
            return
        end

        var i = idx - 1

        self.reset_motion_state(i)
        self.home_confirmed[i] = false

        force_status_publish()
    end

    def stop_all()
        self.moveall_pending = false

        for i: 0..3
            self.reset_motion_state(i)
            self.home_confirmed[i] = false
        end

        force_status_publish()
    end

    def start_recovery(idx)
        if idx < 1 || idx > 4
            return
        end

        if self.is_down(idx)
            self.stop_duck(idx)
            return
        end

        self.begin_home(idx, true, true)
        self.write_duck(idx, "home")

        print("Duck" .. idx .. " stopped outside cycle, recovery homing")
        force_status_publish()
    end

    def finish_home(idx)
        if idx < 1 || idx > 4
            return
        end

        var i = idx - 1
        var should_move = self.pending_move[i]

        self.homing[i] = false
        self.recovering[i] = false
        self.pending_move[i] = false

        self.wanted[i] = false
        self.has_moved[i] = false

        self.home_confirmed[i] = true

        self.move_cmd_ms[i] = 0
        self.low_since[i] = 0

        self.home_cmd_ms[i] = 0
        self.home_seen_high[i] = false
        self.home_low_since[i] = 0

        print("Duck" .. idx .. " home confirmed")
        force_status_publish()

        if should_move
            self.send_single_move(idx)
        end

        if self.moveall_pending && self.all_home_confirmed()
            self.dispatch_moveall()
        end
    end

    def handle_home(i, idx, moving, now)
        if moving
            self.home_seen_high[i] = true
            self.home_low_since[i] = 0
            return
        end

        if !self.home_seen_high[i]
            if now - self.home_cmd_ms[i] >= HOME_START_TIMEOUT_MS
                self.finish_home(idx)
            end

            return
        end

        if self.home_low_since[i] == 0
            self.home_low_since[i] = now
        end

        if now - self.home_low_since[i] >= HOME_LOW_STABLE_MS
            self.finish_home(idx)
        end
    end

    def loop()
        var now = tasmota.millis()

        if now < self.next_check_ms
            return
        end

        self.next_check_ms = now + WATCHDOG_INTERVAL_MS

        for i: 0..3
            var idx = i + 1
            var moving = self.read_move(i)

            if self.is_down(idx)
                self.reset_motion_state(i)
                continue
            end

            if self.homing[i]
                self.handle_home(i, idx, moving, now)
                continue
            end

            if !self.wanted[i]
                continue
            end

            if moving
                self.has_moved[i] = true
                self.low_since[i] = 0
                continue
            end

            if now - self.move_cmd_ms[i] < MOVE_START_GRACE_MS
                self.low_since[i] = 0
                continue
            end

            if self.low_since[i] == 0
                self.low_since[i] = now
            end

            if now - self.low_since[i] < MOVE_STOP_GRACE_MS
                continue
            end

            self.start_recovery(idx)
        end
    end
end

class DuckGameDriver

    def home(cmd, idx)
        if duck_move_watchdog != nil
            duck_move_watchdog.request_home(idx, false)
        else
            send_duck_cmd(idx, "home")
        end

        force_status_publish()
        tasmota.resp_cmnd("duck" .. idx .. " homing")
    end

    def home_all(cmd, idx)
        if duck_move_watchdog != nil
            duck_move_watchdog.request_home_all()
        else
            send_broadcast_cmd("homeall")
        end

        force_status_publish()
        tasmota.resp_cmnd("homing all")
    end

    def move(cmd, idx)
        var ok = false

        if duck_move_watchdog != nil
            ok = duck_move_watchdog.request_move(idx)
        else
            send_duck_cmd(idx, "move")
            ok = true
        end

        force_status_publish()

        if ok
            tasmota.resp_cmnd("duck" .. idx .. " moving")
        else
            tasmota.resp_cmnd("duck" .. idx .. " move rejected, not home")
        end
    end

    def move_all(cmd, idx)
        if wave_driver != nil
            wave_driver.led_init()
        end

        if duck_move_watchdog != nil
            duck_move_watchdog.request_move_all()
        else
            send_broadcast_cmd("moveall")
        end

        force_status_publish()
        tasmota.resp_cmnd("safe moveall requested")
    end

    def stop(cmd, idx)
        if duck_move_watchdog != nil
            duck_move_watchdog.stop_duck(idx)
        end

        send_duck_cmd(idx, "stop")

        force_status_publish()
        tasmota.resp_cmnd("duck" .. idx .. " stopped")
    end

    def stop_all(cmd, idx)
        if duck_move_watchdog != nil
            duck_move_watchdog.stop_all()
        end

        send_broadcast_cmd("stopall")

        force_status_publish()
        tasmota.resp_cmnd("all stopped")
    end

    def restart(cmd, idx)
        if duck_move_watchdog != nil
            duck_move_watchdog.stop_duck(idx)
        end

        send_duck_cmd(idx, "restart")
        force_status_publish()
        tasmota.resp_cmnd("duck" .. idx .. " restarting")
    end

    def set_speed(cmd, idx, speed)
        if speed == "" ||
           number(speed) > 10 ||
           number(speed) < 1
            return
        end

        send_duck_cmd(idx, "speed " .. speed)

        tasmota.resp_cmnd(
            "duck" .. idx .. " speed set to " .. speed
        )
    end
end

class WaveDriver

    var time, strip
    var enabled, blink_state
    var duck_anim, duck_red
    var next_anim_ms, next_blink_ms
    var ldr_latched, ldr_off_since, ldr_lock_until
    var ldr_debug
    var solved
    var solved_anim
    var solved_anim_start_ms
    var next_solved_ms
    var last_status
    var reset_id

    def init()
        self.time = 0
        self.enabled = false
        self.blink_state = false
        self.next_anim_ms = 0
        self.next_blink_ms = 0
        self.solved = false
        self.solved_anim = false
        self.solved_anim_start_ms = 0
        self.next_solved_ms = 0
        self.last_status = ""
        self.reset_id = 0

        self.duck_anim = [false, false, false, false]
        self.duck_red = [false, false, false, false]

        self.ldr_latched = [false, false, false, false]
        self.ldr_off_since = [0, 0, 0, 0]
        self.ldr_lock_until = [0, 0, 0, 0]
        self.ldr_debug = [false, false, false, false]

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

    def duck_state(i)
        if self.duck_anim[i]
            return "shot_animation"
        elif self.duck_red[i]
            return "shot"
        elif duck_move_watchdog != nil && duck_move_watchdog.recovering[i]
            return "recovering"
        elif duck_move_watchdog != nil && duck_move_watchdog.homing[i]
            return "homing"
        elif duck_move_watchdog != nil && duck_move_watchdog.wanted[i]
            return "moving"
        elif duck_move_watchdog != nil && duck_move_watchdog.home_confirmed[i]
            return "home"
        elif duck_move_watchdog != nil && duck_move_watchdog.moveall_pending
            return "waiting_for_moveall"
        end

        return "unknown"
    end

    def effect_state()
        if self.solved_anim
            return "solved_fadeout"
        elif self.solved
            return "solved"
        elif self.enabled
            return "running"
        end

        return "off"
    end

    def publish_status()
        var count = 0

        for i: 0..3
            if self.duck_red[i]
                count = count + 1
            end
        end

        var text = str(count) .. " / 4 kacsa lelőve"

        if self.solved_anim
            text = "Megoldva - fény animáció"
        elif self.solved
            text = "Megoldva - 4 / 4 kacsa lelőve"
        elif !self.enabled
            text = "Inaktív - " .. text
        end

        var moveall_waiting = "false"

        if duck_move_watchdog != nil && duck_move_watchdog.moveall_pending
            moveall_waiting = "true"
        end

        var msg = '{"text":"' .. text .. '","shot_count":' .. count .. ',"total":4,"enabled":' .. (self.enabled ? "true" : "false") .. ',"solved":' .. (self.solved ? "true" : "false") .. ',"effect":"' .. self.effect_state() .. '","moveall_waiting":' .. moveall_waiting .. ',"ducks":['

        for i: 0..3
            if i > 0
                msg = msg .. ","
            end

            msg = msg .. '"' .. self.duck_state(i) .. '"'
        end

        msg = msg .. "]}"

        if msg == self.last_status
            return
        end

        self.last_status = msg
        mqtt.publish("CDUCKGAME/STATUS", msg, true)
    end

    def force_complete()
        self.reset_id = self.reset_id + 1

        if duck_move_watchdog != nil
            duck_move_watchdog.stop_all()
        end

        send_broadcast_cmd("stopall")

        self.enabled = true

        for i: 0..3
            self.duck_anim[i] = false
            self.duck_red[i] = true
        end

        self.solved = false
        self.publish_status()
        self.check_solved()
        tasmota.resp_cmnd("Duck game force completed")
    end

    def duck_is_down(idx)
        if idx < 1 || idx > 4
            return true
        end

        return self.duck_anim[idx - 1] ||
               self.duck_red[idx - 1]
    end

    def read_ldr_pin(i)
        var hit = gpio.digital_read(LDR_PINS[i])

        if LDR_ACTIVE_LOW
            hit = !hit
        end

        return hit
    end

    def ldr_loop()
        if !self.enabled || self.solved_anim
            return
        end

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
        self.publish_status()

        if self.solved_anim
            self.solved_anim_loop()
            return
        end

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

    def set_all_pixels(color, brightness)
        for i: 0..(LED_COUNT - 1)
            self.strip.set_pixel_color(
                i,
                color,
                brightness
            )
        end

        self.strip.show()
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

    def start_solved_animation()
        self.solved_anim = true
        self.solved_anim_start_ms = tasmota.millis()
        self.next_solved_ms = 0
        self.enabled = true
        self.blink_state = false
        self.time = 0

        self.last_status = ""
        self.publish_status()
    end

    def solved_flash_frame(elapsed)
        var white = self.rgb(255, 255, 255)
        var cycle = int(elapsed / 125)

        if cycle % 2 == 0
            self.set_all_pixels(white, 255)
        else
            self.set_all_pixels(white, 0)
        end
    end

    def solved_splash_frame(elapsed)
        var phase = int(elapsed / SOLVED_FRAME_MS)
        var white = self.rgb(255, 255, 255)

        for i: 0..(LED_COUNT - 1)
            var wave = math.sin(
                (i / 2.2) + (phase * 0.35)
            )

            var level = (wave + 1) / 2
            var brightness = 35 + (level * 180)

            var sparkle = (i * 17 + phase * 11) % 29

            if sparkle == 0 || sparkle == 1
                brightness = 255
            end

            if brightness > 255
                brightness = 255
            end

            self.strip.set_pixel_color(
                i,
                white,
                int(brightness)
            )
        end

        self.strip.show()
    end

    def solved_fade_frame(elapsed)
        var white = self.rgb(255, 255, 255)
        var remaining = SOLVED_FADE_TIME_MS - elapsed

        if remaining < 0
            remaining = 0
        end

        var base = int((remaining * 255) / SOLVED_FADE_TIME_MS)
        var phase = int(elapsed / SOLVED_FRAME_MS)

        for i: 0..(LED_COUNT - 1)
            var wave = math.sin(
                (i / 3.0) + (phase * 0.12)
            )

            var level = (wave + 1) / 2
            var brightness = int(base * (0.35 + level * 0.65))

            if brightness < 0
                brightness = 0
            end

            self.strip.set_pixel_color(
                i,
                white,
                brightness
            )
        end

        self.strip.show()
    end

    def solved_anim_loop()
        var now = tasmota.millis()

        if now < self.next_solved_ms
            return
        end

        self.next_solved_ms = now + SOLVED_FRAME_MS

        var elapsed = now - self.solved_anim_start_ms

        if elapsed >= SOLVED_TOTAL_TIME_MS
            self.solved_anim = false
            self.enabled = false
            self.strip.clear()
            self.strip.show()

            self.last_status = ""
            self.publish_status()
            return
        end

        if elapsed < SOLVED_FLASH_TIME_MS
            self.solved_flash_frame(elapsed)
        elif elapsed < SOLVED_FLASH_TIME_MS + SOLVED_SPLASH_TIME_MS
            self.solved_splash_frame(
                elapsed - SOLVED_FLASH_TIME_MS
            )
        else
            self.solved_fade_frame(
                elapsed -
                SOLVED_FLASH_TIME_MS -
                SOLVED_SPLASH_TIME_MS
            )
        end
    end

    def enable_game()
        self.reset_id = self.reset_id + 1
        self.enabled = true
        self.solved = false
        self.solved_anim = false
        self.solved_anim_start_ms = 0
        self.next_solved_ms = 0
        self.next_anim_ms = 0
        self.next_blink_ms = 0
        self.last_status = ""
        self.publish_status()

        tasmota.resp_cmnd("Duck game enabled")
    end

    def disable_game()
        self.reset_id = self.reset_id + 1
        self.enabled = false
        self.solved_anim = false
        self.solved_anim_start_ms = 0
        self.next_solved_ms = 0
        self.time = 0
        self.blink_state = false
        self.next_anim_ms = 0
        self.next_blink_ms = 0
        self.solved = false

        self.duck_anim = [false, false, false, false]
        self.duck_red = [false, false, false, false]
        self.ldr_latched = [false, false, false, false]
        self.ldr_off_since = [0, 0, 0, 0]
        self.ldr_lock_until = [0, 0, 0, 0]
        self.ldr_debug = [false, false, false, false]

        if duck_move_watchdog != nil
            duck_move_watchdog.stop_all()
        end

        send_broadcast_cmd("stopall")

        if duck_move_watchdog != nil
            duck_move_watchdog.request_home_all()
        else
            send_broadcast_cmd("homeall")
        end

        self.strip.clear()
        self.strip.show()

        self.last_status = ""
        self.publish_status()
        tasmota.resp_cmnd("Duck game disabled, reset and homing")
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

            self.start_solved_animation()
        end
    end

    def finish_shot(idx, id)
        if id != self.reset_id || !self.enabled
            return
        end

        self.duck_anim[idx - 1] = false
        self.duck_red[idx - 1] = true

        self.check_solved()
        self.last_status = ""
        self.publish_status()
    end

    def shoot_fast(idx)
        if !self.enabled
            return
        end

        if idx < 1 || idx > 4
            return
        end

        if self.duck_anim[idx - 1] ||
           self.duck_red[idx - 1]
            return
        end

        send_duck_cmd(idx, "shot")

        if duck_move_watchdog != nil
            duck_move_watchdog.stop_duck(idx)
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

        var id = self.reset_id

        tasmota.set_timer(
            SHOT_TIME,
            def()
                self.finish_shot(idx, id)
            end
        )

        self.last_status = ""
        self.publish_status()
    end

    def shoot(cmd, idx)
        self.shoot_fast(idx)

        tasmota.resp_cmnd(
            "Duck" .. idx .. " shot down"
        )
    end

    def led_reset()
        self.reset_id = self.reset_id + 1

        self.solved_anim = false
        self.solved_anim_start_ms = 0
        self.next_solved_ms = 0

        self.duck_anim = [false, false, false, false]
        self.duck_red = [false, false, false, false]

        self.solved = false
        self.blink_state = false
        self.next_blink_ms = 0

        if self.enabled
            self.sea_wave()
        else
            self.strip.clear()
            self.strip.show()
        end

        self.last_status = ""
        self.publish_status()
        tasmota.resp_cmnd("Led reset")
    end

    def led_init()
        self.reset_id = self.reset_id + 1
        self.enabled = false
        self.solved = false
        self.solved_anim = false
        self.solved_anim_start_ms = 0
        self.next_solved_ms = 0
        self.blink_state = false
        self.next_anim_ms = 0
        self.next_blink_ms = 0

        self.duck_anim = [false, false, false, false]
        self.duck_red = [false, false, false, false]

        self.ldr_latched = [false, false, false, false]
        self.ldr_off_since = [0, 0, 0, 0]
        self.ldr_lock_until = [0, 0, 0, 0]
        self.ldr_debug = [false, false, false, false]

        self.strip.clear()
        self.strip.show()

        self.last_status = ""
        self.publish_status()
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

duck_game_driver = DuckGameDriver()
wave_driver = WaveDriver()
duck_move_watchdog = DuckMoveWatchdog()

tasmota.add_driver(duck_game_driver)
tasmota.add_driver(wave_driver)

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

tasmota.add_cmd("forcecomplete", / -> wave_driver.force_complete())

print("DuckGame driver loaded")
print("forcecomplete - mark all ducks shot and publish SOLVED")
print("--------------------------------------------------------------")
print("Command example: home1 - duck1 start homing")
print("home<n> - start homing for the selected duck")
print("homeall - start homing for all ducks")
print("move<n> - move only if duck is confirmed home")
print("moveall - home all first if needed, then send broadcast moveall")
print("stop<n> - stop movement of the selected duck")
print("stopall - stop movement of all ducks")
print("duckrestart - restart the ESP32-C3 SuperMini")
print("speed<n> <value> - set movement speed of duck 1-10")
print("--------------------------------------------------------------")

print("Wave driver loaded")
print("--------------------------------------------------------------")
print("enable - enable LED animation system")
print("disable - clear game, stop timers and home all ducks")
print("ledinit - reset LED state and internal flags")
print("ledreset - clear shot/red LED states")
print("duckshoot<n> - manual shot command for duck<n>")
print("ldrstatus - show current LDR raw hit states")
print("solved effect - white splash, then slow fade to off")
print("--------------------------------------------------------------")

print("Duck move watchdog loaded")
print("Duck move pins: duck1=32 duck2=33 duck3=25 duck4=26")
print("HIGH=moving LOW=stopped")
print("Single move is rejected if duck is not confirmed home")
print("Moveall keeps original C++ delayed start")
print("--------------------------------------------------------------")

tasmota.cmd("homeall")
tasmota.cmd("homeall")