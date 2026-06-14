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

var DIR_INVERT = true

class CylinderDriver
    var actual_position
    var target_position
    var start_position
    var final_position

    var moving
    var homing_state
    var homing_steps

    var last_ms
    var loop_running
    var loop_cb

    var lock_after_move
    var pending_position

    var after_home_target
    var after_home_position

    def init()
        self.actual_position = 0
        self.target_position = 0
        self.start_position = 0
        self.final_position = 0

        self.moving = false
        self.homing_state = 0
        self.homing_steps = 0

        self.loop_running = false
        self.lock_after_move = false
        self.pending_position = -1

        self.after_home_target = 0
        self.after_home_position = 0

        self.loop_cb = / -> self._loop()

        gpio.pin_mode(STEP_PIN, gpio.OUTPUT)
        gpio.pin_mode(DIR_PIN, gpio.OUTPUT)
        gpio.pin_mode(EN_PIN, gpio.OUTPUT)
        gpio.pin_mode(HOME_PIN, gpio.INPUT_PULLUP)

        gpio.digital_write(STEP_PIN, gpio.LOW)
        gpio.digital_write(EN_PIN, gpio.HIGH)
    end

    def publish_position(position)
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
    end

    def lock(cmd, idx)
        tasmota.set_power(LAUNLOCK, false)
        tasmota.set_power(LALOCK, true)

        tasmota.set_timer(
            3000,
            / -> tasmota.set_power(
                LALOCK,
                false
            )
        )

        tasmota.resp_cmnd("Cylinder locked")
    end

    def lock_and_publish(position)
        tasmota.set_power(LAUNLOCK, false)
        tasmota.set_power(LALOCK, true)

        print(
            "Cylinder locking before publishing pos" ..
            position
        )

        tasmota.set_timer(
            3000,
            / -> self._lock_done_publish(position)
        )
    end

    def _lock_done_publish(position)
        tasmota.set_power(LALOCK, false)

        self.publish_position(position)

        print(
            "Cylinder locked, position published: " ..
            position
        )
    end

    def unlock(cmd, idx)
        tasmota.set_power(LALOCK, false)
        tasmota.set_power(LAUNLOCK, true)

        tasmota.delay(3000)

        tasmota.set_power(LAUNLOCK, false)

        tasmota.resp_cmnd("Cylinder unlocked")
    end

    def home(cmd, idx)
        if self.moving ||
           self.homing_state != 0

            tasmota.resp_cmnd("Busy")
            return
        end

        self.pending_position = 0

        self.unlock(nil, nil)

        self._start_home_to(
            pos0,
            0
        )

        tasmota.resp_cmnd("Homing started")
    end

    def set_pos(cmd, i, position)
        if self.moving ||
           self.homing_state != 0

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

        self.unlock(nil, nil)

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
           self.homing_state != 0

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
            end

            return
        end

        self._enable()

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
                / -> self.lock_and_publish(0)
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

print("Cylinder driver loaded")
print("Only positive motor movement enabled")
print("MQTT topic: CCYLINDER/pos")
print("Position is published after locking")
print("------------------------------------------------")
print("Commands:")
print("lock")
print("unlock")
print("home")
print("pos <0-4>")
print("movestep <positive steps>")
print("------------------------------------------------")