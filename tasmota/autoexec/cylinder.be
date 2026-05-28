import gpio

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

var START_MS = 25
var FAST_MS = 10
var HOME_MS = 15
var RAMP_STEPS = 300
var BACKOFF_STEPS = 100

var DIR_INVERT = true
var DIR_CHANGE_EXTRA_STEPS = 0

class CylinderDriver
    var actual_position, target_position, start_position, final_position
    var moving, homing_state, backoff_left
    var last_ms, loop_running, loop_cb
    var lock_after_move, last_move_dir

    def init()
        self.actual_position = 0
        self.target_position = 0
        self.start_position = 0
        self.final_position = 0
        self.moving = false
        self.homing_state = 0
        self.backoff_left = 0
        self.loop_running = false
        self.lock_after_move = false
        self.last_move_dir = 0
        self.loop_cb = / -> self._loop()

        gpio.pin_mode(STEP_PIN, gpio.OUTPUT)
        gpio.pin_mode(DIR_PIN, gpio.OUTPUT)
        gpio.pin_mode(EN_PIN, gpio.OUTPUT)
        gpio.pin_mode(HOME_PIN, gpio.INPUT_PULLUP)

        gpio.digital_write(STEP_PIN, gpio.LOW)
        gpio.digital_write(EN_PIN, gpio.HIGH)
    end

    def lock(cmd, idx)
        tasmota.set_power(LAUNLOCK, false)
        tasmota.set_power(LALOCK, true)
        tasmota.set_timer(5000, / -> tasmota.set_power(LALOCK, false))
        tasmota.resp_cmnd("Cylinder locked")
    end

    def unlock(cmd, idx)
        tasmota.set_power(LALOCK, false)
        tasmota.set_power(LAUNLOCK, true)
        tasmota.delay(5000)
        tasmota.set_power(LAUNLOCK, false)
        tasmota.resp_cmnd("Cylinder unlocked")
    end

    def home(cmd, idx)
        if self.moving || self.homing_state != 0
            tasmota.resp_cmnd("Busy")
            return
        end

        self.unlock(nil, nil)
        self._enable()
        self.homing_state = 1
        self.backoff_left = 0
        self.last_ms = tasmota.millis()
        self._start_loop()
        tasmota.resp_cmnd("Homing started")
    end

    def set_pos(cmd, i, position)
        if self.moving || self.homing_state != 0
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
            tasmota.resp_cmnd("Bad argument: " .. position)
            return
        end

        self.unlock(nil, nil)
        self._move_to(p, true)
        tasmota.resp_cmnd("Cylinder moving to pos" .. position .. ", from " .. self.actual_position .. " to " .. p)
    end

    def move_steps(cmd, i, steps)
        if self.moving || self.homing_state != 0
            tasmota.resp_cmnd("Busy")
            return
        end

        if steps == 0
            tasmota.resp_cmnd("No move")
            return
        end

        var target = self.actual_position + steps

        self._move_to(target, false)
        tasmota.resp_cmnd("Moving " .. steps .. " steps only, from " .. self.actual_position .. " to " .. target)
    end

    def _move_to(p, do_lock)
        if p == self.actual_position
            if do_lock
                self.lock(nil, nil)
            end
            return
        end

        var dir = 1
        var move_target = p

        if p < self.actual_position
            dir = -1
        end

        if self.last_move_dir != 0 && self.last_move_dir != dir
            move_target = p + (dir * DIR_CHANGE_EXTRA_STEPS)
        end

        self._enable()
        self.start_position = self.actual_position
        self.target_position = move_target
        self.final_position = p
        self.lock_after_move = do_lock
        self.last_move_dir = dir
        self.moving = true
        self.last_ms = tasmota.millis()
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
        var diff = self.target_position - self.actual_position

        if diff == 0
            self._move_done()
            return
        end

        if diff > 0
            self._step(1)
        else
            self._step(-1)
        end

        if self.actual_position == self.target_position
            self._move_done()
        end
    end

    def _move_done()
        self.moving = false
        self.actual_position = self.final_position
        self.target_position = self.actual_position
        self.start_position = self.actual_position
        self._stop_loop()

        if self.lock_after_move
            tasmota.set_timer(1000, / -> self.lock(nil, nil))
        end

        tasmota.resp_cmnd("Move done, actual position: " .. self.actual_position)
    end

    def _home_step()
        if self.homing_state == 1
            if !self._home_active()
                self._step(1)
            else
                self.homing_state = 2
                self.backoff_left = BACKOFF_STEPS
            end

        elif self.homing_state == 2
            if self.backoff_left > 0
                self._step(-1)
                self.backoff_left -= 1
            else
                self.homing_state = 3
            end

        elif self.homing_state == 3

            if !self._home_active()
                self._step(1)
            else
                self._step(1)
                self.actual_position = 0
                self.target_position = 0
                self.start_position = 0
                self.final_position = 0
                self.last_move_dir = 0
                self.homing_state = 0
                self._stop_loop()
                tasmota.set_timer(1250, / -> self.lock(nil, nil))
                tasmota.resp_cmnd("Homing done")
            end
        end
    end

    def _step(dir)
        self._set_dir(dir)

        tasmota.delay(1)
        gpio.digital_write(STEP_PIN, gpio.HIGH)
        tasmota.delay(1)
        gpio.digital_write(STEP_PIN, gpio.LOW)

        self.actual_position += dir
    end

    def _set_dir(dir)
        var level = gpio.LOW

        if dir > 0
            if DIR_INVERT
                level = gpio.LOW
            else
                level = gpio.HIGH
            end
        else
            if DIR_INVERT
                level = gpio.HIGH
            else
                level = gpio.LOW
            end
        end

        gpio.digital_write(DIR_PIN, level)
    end

    def _ramp_ms()
        var done = self._abs(self.actual_position - self.start_position)
        var left = self._abs(self.target_position - self.actual_position)
        var zone = done
        var fast = FAST_MS

        if self.target_position < self.start_position
            fast = FAST_MS + 5
        end

        if left < zone
            zone = left
        end

        if zone >= RAMP_STEPS
            return fast
        end

        return START_MS - int(((START_MS - fast) * zone) / RAMP_STEPS)
    end

    def _home_active()
        return gpio.digital_read(HOME_PIN)
    end

    def _enable()
        gpio.digital_write(EN_PIN, gpio.LOW)
    end

    def _start_loop()
        if !self.loop_running
            self.loop_running = true
            tasmota.add_fast_loop(self.loop_cb)
        end
    end

    def _stop_loop()
        if self.loop_running
            self.loop_running = false
            tasmota.remove_fast_loop(self.loop_cb)
        end
    end

    def _abs(v)
        if v < 0
            return -v
        end
        return v
    end
end

var cylinder_driver = CylinderDriver()

tasmota.add_driver(cylinder_driver)

tasmota.add_cmd("lock", /cmd, idx -> cylinder_driver.lock(cmd, idx))
tasmota.add_cmd("unlock", /cmd, idx -> cylinder_driver.unlock(cmd, idx))
tasmota.add_cmd("home", /cmd, idx -> cylinder_driver.home(cmd, idx))
tasmota.add_cmd("pos", /cmd, i, position -> cylinder_driver.set_pos(cmd, i, number(position)))
tasmota.add_cmd("movestep", /cmd, i, steps -> cylinder_driver.move_steps(cmd, i, number(steps)))

print("Cylinder driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("lock - lock cylinder")
print("unlock - unlock cylinder")
print("home - start homing")
print("pos <0-4> - move cylinder to saved position")
print("movestep <steps> - move cylinder by relative steps")
print("--------------------------------------------------------------")