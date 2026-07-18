import gpio
import mqtt

var MQTT_TOPIC = "CCYLINDER/pos"

var STEP_PIN = 32
var DIR_PIN = 33
var EN_PIN = 25
var HOME_PIN = 22

var LALOCK = 0
var LAUNLOCK = 1

var pos0 = 0
var pos1 = 475
var pos2 = 970
var pos3 = 1390
var pos4 = 1890

var START_MS = 20
var FAST_MS = 7
var HOME_MS = 10
var RAMP_STEPS = 150

var HOME_MAX_STEPS = 5000

var UNLOCK_MS = 3000
var LOCK_MS = 5000

var DIR_INVERT = true

var CYL_LED_PIN = 17
var CYL_LED_COUNT = 33

var CYL_LED_OFF = 0
var CYL_LED_RUN = 1
var CYL_LED_BLINK = 2

class CylinderLedRing
    var strip, led_count
    var mode, color
    var run_pos
    var blink_on
    var tick
    var anim_speed
    var run_leds

    def init()
        self.led_count = CYL_LED_COUNT

        self.strip = Leds(
            self.led_count,
            gpio.pin(gpio.WS2812, CYL_LED_PIN)
        )

        self.mode = CYL_LED_OFF
        self.color = self.rgb(255, 0, 0)

        self.run_pos = 0
        self.blink_on = false
        self.tick = 0

        self.anim_speed = 1
        self.run_leds = 5

        self.clear()
    end

    def rgb(r, g, b)
        return (r << 16) | (g << 8) | b
    end

    def clear()
        self.strip.clear()
        self.strip.show()
    end

    def stop(cmd, idx)
        self.mode = CYL_LED_OFF
        self.clear()

        tasmota.resp_cmnd("Cylinder LED stopped")
    end

    def set_speed(cmd, idx, speed)
        var s = number(speed)

        if s < 1
            s = 1
        end

        self.anim_speed = s
        self.tick = 0

        tasmota.resp_cmnd(
            "Cylinder LED speed set to " ..
            self.anim_speed
        )
    end

    def set_count(cmd, idx, count)
        var c = number(count)

        if c < 1
            c = 1
        end

        if c > self.led_count
            c = self.led_count
        end

        self.run_leds = c

        tasmota.resp_cmnd(
            "Cylinder LED run count set to " ..
            self.run_leds
        )
    end

    def start_run(r, g, b, speed, count)
        self.color = self.rgb(r, g, b)

        if speed < 1
            speed = 1
        end

        if count < 1
            count = 1
        end

        if count > self.led_count
            count = self.led_count
        end

        self.anim_speed = speed
        self.run_leds = count
        self.run_pos = 0
        self.tick = 0
        self.mode = CYL_LED_RUN
    end

    def start_blink(r, g, b, speed)
        self.color = self.rgb(r, g, b)

        if speed < 1
            speed = 1
        end

        self.anim_speed = speed
        self.blink_on = false
        self.tick = 0
        self.mode = CYL_LED_BLINK
    end

    def red_run(cmd, idx)
        self.start_run(
            255,
            0,
            0,
            self.anim_speed,
            self.run_leds
        )

        tasmota.resp_cmnd("Cylinder LED red run")
    end

    def green_run(cmd, idx)
        self.start_run(
            0,
            255,
            0,
            self.anim_speed,
            self.run_leds
        )

        tasmota.resp_cmnd("Cylinder LED green run")
    end

    def red_blink(cmd, idx)
        self.start_blink(
            255,
            0,
            0,
            self.anim_speed
        )

        tasmota.resp_cmnd("Cylinder LED red blink")
    end

    def green_blink(cmd, idx)
        self.start_blink(
            0,
            255,
            0,
            self.anim_speed
        )

        tasmota.resp_cmnd("Cylinder LED green blink")
    end

    def auto_red_move()
        self.start_run(
            255,
            0,
            0,
            2,
            10
        )
    end

    def auto_green_locked()
        self.start_blink(
            0,
            255,
            0,
            5
        )
    end

    def every_50ms()
        if self.mode == CYL_LED_RUN
            self.animate_run()
        elif self.mode == CYL_LED_BLINK
            self.animate_blink()
        end
    end

    def wait_tick()
        self.tick += 1

        if self.tick < self.anim_speed
            return true
        end

        self.tick = 0
        return false
    end

    def animate_run()
        if self.wait_tick()
            return
        end

        self.strip.clear()

        for i: 0..(self.run_leds - 1)
            var led_index =
                self.run_pos + i

            while led_index >= self.led_count
                led_index =
                    led_index - self.led_count
            end

            self.strip.set_pixel_color(
                led_index,
                self.color,
                255
            )
        end

        self.strip.show()

        self.next_run_pos()
    end

    def animate_blink()
        if self.wait_tick()
            return
        end

        self.blink_on = !self.blink_on

        if self.blink_on
            for i: 0..(self.led_count - 1)
                self.strip.set_pixel_color(
                    i,
                    self.color,
                    255
                )
            end
        else
            self.strip.clear()
        end

        self.strip.show()
    end

    def next_run_pos()
        var step = 1

        if self.anim_speed == 1
            step = 5
        elif self.anim_speed == 2
            step = 3
        elif self.anim_speed == 3
            step = 2
        end

        self.run_pos += step

        while self.run_pos >= self.led_count
            self.run_pos -= self.led_count
        end
    end
end

var cylinder_led_ring = CylinderLedRing()

tasmota.add_driver(cylinder_led_ring)

class CylinderDriver
    var actual_position
    var target_position
    var start_position
    var final_position

    var moving
    var homing_state
    var homing_steps
    var unlocking

    var last_ms
    var loop_running
    var loop_cb

    var lock_after_move
    var pending_position

    var after_home_target
    var after_home_position

    var named_position
    var disable_requested
    var last_status

    def init()
        self.actual_position = 0
        self.target_position = 0
        self.start_position = 0
        self.final_position = 0

        self.moving = false
        self.homing_state = 0
        self.homing_steps = 0
        self.unlocking = false

        self.loop_running = false
        self.lock_after_move = false
        self.pending_position = -1

        self.after_home_target = 0
        self.after_home_position = 0

        self.named_position = 0
        self.disable_requested = false
        self.last_status = ""

        self.loop_cb = / -> self._loop()

        gpio.pin_mode(STEP_PIN, gpio.OUTPUT)
        gpio.pin_mode(DIR_PIN, gpio.OUTPUT)
        gpio.pin_mode(EN_PIN, gpio.OUTPUT)
        gpio.pin_mode(HOME_PIN, gpio.INPUT_PULLUP)

        gpio.digital_write(STEP_PIN, gpio.LOW)
        self._disable()
        self.publish_position(0)
        self.publish_status()
    end

    def build_status()
        var phase = "idle"

        if self.disable_requested
            phase = "reset_pending"
        elif self.unlocking
            phase = "unlocking"
        elif self.homing_state != 0
            phase = "homing"
        elif self.moving
            phase = "moving"
        end

        return '{"phase":"' .. phase .. '","position":' .. self.named_position .. ',"steps":' .. self.actual_position .. ',"moving":' .. (self.moving ? "true" : "false") .. ',"homing":' .. (self.homing_state != 0 ? "true" : "false") .. ',"unlocking":' .. (self.unlocking ? "true" : "false") .. ',"reset_pending":' .. (self.disable_requested ? "true" : "false") .. '}'
    end

    def publish_status()
        var msg = self.build_status()

        if msg == self.last_status
            return
        end

        self.last_status = msg
        mqtt.publish("CCYLINDER/STATUS", msg, true)
    end

    def publish_position(position)
        self.named_position = position

        if !mqtt.connected()
            print(
                "MQTT not connected, position: " ..
                position
            )
            return
        end

        var payload =
            "{\"data\":\"" ..
            str(position) ..
            "\"}"

        mqtt.publish(
            MQTT_TOPIC,
            payload,
            true
        )

        print(
            "MQTT: " ..
            MQTT_TOPIC ..
            " = " ..
            payload
        )

        self.last_status = ""
        self.publish_status()
    end

    def process_disable()
        if !self.disable_requested
            return
        end

        if self.moving || self.homing_state != 0 || self.unlocking
            return
        end

        self.disable_requested = false
        self.last_status = ""
        self.publish_status()
        self.home(nil, nil)
    end

    def disable_game()
        self.disable_requested = true
        cylinder_led_ring.stop(nil, nil)

        self.process_disable()
        self.last_status = ""
        self.publish_status()
        tasmota.resp_cmnd("Cylinder reset requested")
    end

    def every_50ms()
        self.process_disable()
        self.publish_status()
    end

    def lock(cmd, idx)
        self._enable()

        tasmota.set_power(LAUNLOCK, false)
        tasmota.set_power(LALOCK, true)

        tasmota.set_timer(
            LOCK_MS,
            / -> self._lock_done()
        )

        tasmota.resp_cmnd("Cylinder locking")
    end

    def _lock_done()
        tasmota.set_power(LALOCK, false)
        self._disable()

        cylinder_led_ring.auto_green_locked()

        tasmota.resp_cmnd("Cylinder locked")
    end

    def lock_and_publish(position)
        self._enable()

        tasmota.set_power(LAUNLOCK, false)
        tasmota.set_power(LALOCK, true)

        print(
            "Cylinder locking before publishing pos" ..
            position
        )

        tasmota.set_timer(
            LOCK_MS,
            / -> self._lock_done_publish(
                position,
                true
            )
        )
    end

    def lock_and_publish_no_led(position)
        self._enable()

        tasmota.set_power(LAUNLOCK, false)
        tasmota.set_power(LALOCK, true)

        print(
            "Cylinder locking without LED before publishing pos" ..
            position
        )

        tasmota.set_timer(
            LOCK_MS,
            / -> self._lock_done_publish(
                position,
                false
            )
        )
    end

    def _lock_done_publish(position, start_led)
        tasmota.set_power(LALOCK, false)
        self._disable()

        self.publish_position(position)

        if start_led
            cylinder_led_ring.auto_green_locked()
        end

        print(
            "Cylinder locked, position published: " ..
            position
        )
    end

    def unlock(cmd, idx)
        if self.moving ||
           self.homing_state != 0 ||
           self.unlocking

            tasmota.resp_cmnd("Busy")
            return
        end

        self._unlock_async(nil)
    end

    def _unlock_async(done_cb)
        self.unlocking = true

        self._disable()

        tasmota.set_power(LALOCK, false)
        tasmota.set_power(LAUNLOCK, true)

        tasmota.set_timer(
            UNLOCK_MS,
            / -> self._unlock_done(done_cb)
        )

        tasmota.resp_cmnd("Cylinder unlocking")
    end

    def _unlock_done(done_cb)
        tasmota.set_power(LAUNLOCK, false)
        self._disable()

        self.unlocking = false

        if done_cb != nil
            done_cb()
        else
            tasmota.resp_cmnd("Cylinder unlocked")
        end
    end

    def home(cmd, idx)
        if self.moving ||
           self.homing_state != 0 ||
           self.unlocking

            tasmota.resp_cmnd("Busy")
            return
        end

        self.pending_position = 0

        self._unlock_async(
            / -> self._start_home_after_unlock()
        )

        tasmota.resp_cmnd("Unlocking before homing")
    end

    def _start_home_after_unlock()
        self._start_home_to(
            pos0,
            0
        )

        tasmota.resp_cmnd("Homing started")
    end

    def set_pos(cmd, i, position)
        if self.moving ||
           self.homing_state != 0 ||
           self.unlocking

            tasmota.resp_cmnd("Busy")
            return
        end

        var p = nil

        if position == 0
            p = pos0
        elif position == 1
            p = pos1
        elif position == 2
            p = pos2
        elif position == 3
            p = pos3
        elif position == 4
            p = pos4
        else
            tasmota.resp_cmnd(
                "Bad argument: " ..
                position
            )
            return
        end

        self.pending_position = position

        self._unlock_async(
            / -> self._set_pos_after_unlock(
                p,
                position
            )
        )

        tasmota.resp_cmnd(
            "Unlocking before move to pos" ..
            position
        )
    end

    def _set_pos_after_unlock(p, position)
        if p < self.actual_position
            self._start_home_to(
                p,
                position
            )

            tasmota.resp_cmnd(
                "Cylinder moving through home to pos" ..
                position
            )
        else
            self._move_to(
                p,
                true
            )

            tasmota.resp_cmnd(
                "Cylinder moving to pos" ..
                position ..
                ", from " ..
                self.actual_position ..
                " to " ..
                p
            )
        end
    end

    def move_steps(cmd, i, steps)
        if self.moving ||
           self.homing_state != 0 ||
           self.unlocking

            tasmota.resp_cmnd("Busy")
            return
        end

        if steps <= 0
            tasmota.resp_cmnd(
                "Only positive steps allowed"
            )
            return
        end

        self.pending_position = -1

        var target =
            self.actual_position +
            steps

        self._move_to(
            target,
            false
        )

        tasmota.resp_cmnd(
            "Moving " ..
            steps ..
            " positive steps, from " ..
            self.actual_position ..
            " to " ..
            target
        )
    end

    def _start_home_to(target, position)
        self.moving = false
        self.homing_state = 1
        self.homing_steps = 0

        self.after_home_target = target
        self.after_home_position = position

        self._enable()

        self.last_ms = tasmota.millis()

        self._start_loop()
    end

    def _move_to(p, do_lock)
        if p < self.actual_position
            tasmota.resp_cmnd(
                "Negative movement blocked"
            )
            return
        end

        if p == self.actual_position
            if do_lock
                if self.pending_position >= 0
                    var position =
                        self.pending_position

                    self.pending_position = -1

                    tasmota.set_timer(
                        1000,
                        / -> self.lock_and_publish(
                            position
                        )
                    )
                else
                    tasmota.set_timer(
                        1000,
                        / -> self.lock(nil, nil)
                    )
                end
            elif self.pending_position >= 0
                self.publish_position(
                    self.pending_position
                )

                self.pending_position = -1
                self._disable()
            else
                self._disable()
            end

            return
        end

        self._enable()

        cylinder_led_ring.auto_red_move()

        self.start_position =
            self.actual_position

        self.target_position = p
        self.final_position = p

        self.lock_after_move = do_lock
        self.moving = true

        self.last_ms =
            tasmota.millis()

        self._start_loop()
    end

    def _loop()
        var now = tasmota.millis()

        if self.moving
            var ms = self._ramp_ms()

            if now - self.last_ms >= ms
                self._move_step()
                self.last_ms = now
            end

        elif self.homing_state != 0
            if now - self.last_ms >= HOME_MS
                self._home_step()
                self.last_ms = now
            end

        else
            self._stop_loop()
        end
    end

    def _move_step()
        var diff =
            self.target_position -
            self.actual_position

        if diff <= 0
            self._move_done()
            return
        end

        self._step_positive()

        if self.actual_position >=
           self.target_position

            self._move_done()
        end
    end

    def _move_done()
        self.moving = false

        self.actual_position =
            self.final_position

        self.target_position =
            self.actual_position

        self.start_position =
            self.actual_position

        self._stop_loop()

        if self.lock_after_move
            if self.pending_position >= 0
                var position =
                    self.pending_position

                self.pending_position = -1

                tasmota.set_timer(
                    1000,
                    / -> self.lock_and_publish(
                        position
                    )
                )
            else
                tasmota.set_timer(
                    1000,
                    / -> self.lock(nil, nil)
                )
            end
        elif self.pending_position >= 0
            self.publish_position(
                self.pending_position
            )

            self.pending_position = -1
            self._disable()
        else
            self._disable()
        end

        tasmota.resp_cmnd(
            "Move done, actual position: " ..
            self.actual_position
        )
    end

    def _home_step()
        if self._home_active()
            self._home_found()
            return
        end

        if self.homing_steps >=
           HOME_MAX_STEPS

            self._home_error()
            return
        end

        self._step_positive()
        self.homing_steps += 1
    end

    def _home_found()
        self.actual_position = 0
        self.target_position = 0
        self.start_position = 0
        self.final_position = 0

        self.homing_state = 0
        self.homing_steps = 0

        var target =
            self.after_home_target

        var position =
            self.after_home_position

        print(
            "Home found, next position: " ..
            position
        )

        if target > 0
            self.pending_position = position

            self._move_to(
                target,
                true
            )

            tasmota.resp_cmnd(
                "Home found, moving to pos" ..
                position
            )
        else
            self.pending_position = -1

            self._stop_loop()

            tasmota.set_timer(
                1250,
                / -> self.lock_and_publish_no_led(0)
            )

            tasmota.resp_cmnd(
                "Homing done, locking before publish"
            )
        end
    end

    def _home_error()
        self.moving = false
        self.homing_state = 0
        self.homing_steps = 0
        self.pending_position = -1

        self._stop_loop()
        self._disable()

        tasmota.resp_cmnd(
            "Home error: sensor not found"
        )

        print(
            "ERROR: Home sensor not found after " ..
            HOME_MAX_STEPS ..
            " steps"
        )
    end

    def _step_positive()
        self._set_positive_dir()

        tasmota.delay(1)

        gpio.digital_write(
            STEP_PIN,
            gpio.HIGH
        )

        tasmota.delay(1)

        gpio.digital_write(
            STEP_PIN,
            gpio.LOW
        )

        self.actual_position += 1
    end

    def _set_positive_dir()
        if DIR_INVERT
            gpio.digital_write(
                DIR_PIN,
                gpio.LOW
            )
        else
            gpio.digital_write(
                DIR_PIN,
                gpio.HIGH
            )
        end
    end

    def _ramp_ms()
        var done = self._abs(
            self.actual_position -
            self.start_position
        )

        var left = self._abs(
            self.target_position -
            self.actual_position
        )

        var zone = done

        if left < zone
            zone = left
        end

        if zone >= RAMP_STEPS
            return FAST_MS
        end

        return START_MS -
            int(
                (
                    (START_MS - FAST_MS) *
                    zone
                ) / RAMP_STEPS
            )
    end

    def _home_active()
        return gpio.digital_read(
            HOME_PIN
        )
    end

    def _enable()
        gpio.digital_write(
            EN_PIN,
            gpio.LOW
        )
    end

    def _disable()
        gpio.digital_write(
            EN_PIN,
            gpio.HIGH
        )
    end

    def _start_loop()
        if !self.loop_running
            self.loop_running = true

            tasmota.add_fast_loop(
                self.loop_cb
            )
        end
    end

    def _stop_loop()
        if self.loop_running
            self.loop_running = false

            tasmota.remove_fast_loop(
                self.loop_cb
            )
        end
    end

    def _abs(v)
        if v < 0
            return -v
        end

        return v
    end
end

var cylinder_driver =
    CylinderDriver()

tasmota.add_driver(
    cylinder_driver
)

tasmota.add_cmd(
    "disable",
    / -> cylinder_driver.disable_game()
)

tasmota.add_cmd(
    "lock",
    /cmd, idx ->
        cylinder_driver.lock(
            cmd,
            idx
        )
)

tasmota.add_cmd(
    "unlock",
    /cmd, idx ->
        cylinder_driver.unlock(
            cmd,
            idx
        )
)

tasmota.add_cmd(
    "home",
    /cmd, idx ->
        cylinder_driver.home(
            cmd,
            idx
        )
)

tasmota.add_cmd(
    "pos",
    /cmd, i, position ->
        cylinder_driver.set_pos(
            cmd,
            i,
            number(position)
        )
)

tasmota.add_cmd(
    "movestep",
    /cmd, i, steps ->
        cylinder_driver.move_steps(
            cmd,
            i,
            number(steps)
        )
)

tasmota.add_cmd(
    "redrun",
    /cmd, idx -> cylinder_led_ring.red_run(cmd, idx)
)

tasmota.add_cmd(
    "greenrun",
    /cmd, idx -> cylinder_led_ring.green_run(cmd, idx)
)

tasmota.add_cmd(
    "redblink",
    /cmd, idx -> cylinder_led_ring.red_blink(cmd, idx)
)

tasmota.add_cmd(
    "greenblink",
    /cmd, idx -> cylinder_led_ring.green_blink(cmd, idx)
)

tasmota.add_cmd(
    "ledspeed",
    /cmd, idx, speed -> cylinder_led_ring.set_speed(cmd, idx, speed)
)

tasmota.add_cmd(
    "ledcount",
    /cmd, idx, count -> cylinder_led_ring.set_count(cmd, idx, count)
)

tasmota.add_cmd(
    "ledstop",
    /cmd, idx -> cylinder_led_ring.stop(cmd, idx)
)

print("Cylinder LED ring driver loaded")
print("------------------------------------------------")
print("LED commands:")
print("redrun")
print("greenrun")
print("redblink")
print("greenblink")
print("ledspeed <1+>")
print("ledcount <1-33>")
print("ledstop")
print("------------------------------------------------")

print("Cylinder driver loaded")
print("------------------------------------------------")
print("Commands:")
print("disable - finish current motion, then home and lock")
print("lock")
print("unlock")
print("home")
print("pos <0-4>")
print("movestep <positive steps>")
print("------------------------------------------------")