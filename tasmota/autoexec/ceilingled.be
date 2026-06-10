import re

var PWM1 = 32
var PWM2 = 33
var PWM3 = 25
var PWM4 = 26
var PWM5 = 27
var PWM6 = 14
var PWM7 = 13
var PWM8 = 23

class CeilingLed
    var n, max_pwm, pin, lvl, tgt, act
    var dim, dim_t, fade_step, dim_step
    var mode, cnt, run_spd, rnd_spd
    var r_led, r_done, r_total
    var fill_led, fill_done, fill_started
    var rnd_end, final_led, new_led, old_led, rng

    def init()
        self.n = 8
        self.max_pwm = 1023

        self.pin = {
            1 : PWM1, 2 : PWM2, 3 : PWM3, 4 : PWM4,
            5 : PWM5, 6 : PWM6, 7 : PWM7, 8 : PWM8
        }

        self.lvl = {}
        self.tgt = {}
        self.act = {}

        for i: 1 .. self.n
            self.lvl[i] = 0
            self.tgt[i] = 0
            self.act[i] = 0
            gpio.set_pwm(self.pin[i], 0)
        end

        self.dim = self.max_pwm
        self.dim_t = self.max_pwm
        self.fade_step = 256
        self.dim_step = 64

        self.mode = 0
        self.cnt = 0
        self.run_spd = 1
        self.rnd_spd = 10

        self.r_led = 0
        self.r_done = 0
        self.r_total = 0

        self.fill_led = 0
        self.fill_done = 0
        self.fill_started = 0

        self.rnd_end = 0
        self.final_led = 0
        self.new_led = 0
        self.old_led = 0
        self.rng = tasmota.millis() % 9973
    end

    def pwm(v)
        return int((v * self.dim) / self.max_pwm)
    end

    def move(v, t, s)
        if v < t
            v = v + s
            if v > t
                v = t
            end
        elif v > t
            v = v - s
            if v < t
                v = t
            end
        end

        return v
    end

    def wrap(i)
        while i < 1
            i = i + self.n
        end

        while i > self.n
            i = i - self.n
        end

        return i
    end

    def set_t(i, on)
        if i < 1 || i > self.n
            return
        end

        if on == 1
            self.tgt[i] = self.max_pwm
        else
            self.tgt[i] = 0
        end
    end

    def set_led(i, on)
        if i < 1 || i > self.n
            return
        end

        self.act[i] = on
        self.set_t(i, on)
    end

    def set_all(on)
        for i: 1 .. self.n
            self.act[i] = on
            self.set_t(i, on)
        end
    end

    def stop0()
        self.mode = 0
        self.cnt = 0
        self.r_led = 0
        self.r_done = 0
        self.r_total = 0
        self.fill_led = 0
        self.fill_done = 0
        self.fill_started = 0
        self.rnd_end = 0
        self.final_led = 0
        self.new_led = 0
        self.old_led = 0
    end

    def stop()
        self.stop0()
        tasmota.resp_cmnd("Animation stopped")
    end

    def all_on()
        self.stop0()
        self.set_all(1)
        tasmota.resp_cmnd("All led on")
    end

    def all_off()
        self.stop0()
        self.set_all(0)
        tasmota.resp_cmnd("All led off")
    end

    def manual(cmd, led, on)
        led = int(led)
        on = int(on)

        if led < 1 || led > self.n || on < 0 || on > 1
            tasmota.resp_cmnd("Bad argument")
            return
        end

        self.stop0()
        self.set_led(led, on)
        tasmota.resp_cmnd("Led " .. led .. " set to " .. on)
    end

    def set_dim(cmd, percent)
        percent = int(percent)

        if percent < 0 || percent > 100
            tasmota.resp_cmnd("Bad dimmer value, use 0..100")
            return
        end

        self.dim_t = int((percent * self.max_pwm) / 100)
        tasmota.resp_cmnd("Ceiling dimmer set to " .. percent .. "%")
    end

    def set_run_speed(cmd, i, speed)
        speed = int(speed)

        if speed < 1
            tasmota.resp_cmnd("Bad argument: " .. speed)
            return
        end

        self.run_spd = speed
        self.cnt = 0
        tasmota.resp_cmnd("Speed set to " .. self.run_spd)
    end

    def set_random_speed(cmd, speed)
        speed = int(speed)

        if speed < 1
            tasmota.resp_cmnd("Bad argument: " .. speed)
            return
        end

        self.rnd_spd = speed
        self.cnt = 0
        tasmota.resp_cmnd("Random speed set to " .. self.rnd_spd)
    end

    def rnd(max)
        if max < 1
            return 1
        end

        self.rng = (self.rng * 73 + 41 + tasmota.millis()) % 9973
        return (self.rng % max) + 1
    end

    def count_on()
        var c = 0

        for i: 1 .. self.n
            if self.act[i] == 1
                c = c + 1
            end
        end

        return c
    end

    def after(i, old, new)
        i = self.wrap(i)

        if i == old
            return false
        end

        if i == new
            return true
        end

        return self.act[i] == 1
    end

    def has3(old, new)
        for i: 1 .. self.n
            if self.after(i, old, new) &&
               self.after(i + 1, old, new) &&
               self.after(i + 2, old, new)
                return true
            end
        end

        return false
    end

    def ready3()
        if self.count_on() != 3
            return false
        end

        for i: 1 .. self.n
            if self.act[i] == 1
                if self.lvl[i] < self.max_pwm
                    return false
                end
            else
                if self.lvl[i] > 0
                    return false
                end
            end
        end

        return true
    end

    def pick_initial3()
        self.set_all(0)

        var guard = 0

        while self.count_on() < 3 && guard < 200
            var led = self.rnd(self.n)

            if self.act[led] == 0
                self.act[led] = 1

                if self.has3(0, 0)
                    self.act[led] = 0
                else
                    self.set_t(led, 1)
                end
            end

            guard = guard + 1
        end

        if self.count_on() < 3
            self.set_all(0)
            self.set_led(1, 1)
            self.set_led(3, 1)
            self.set_led(6, 1)
        end
    end

    def pick_switch()
        var c = 0

        for old: 1 .. self.n
            if self.act[old] == 1
                for new: 1 .. self.n
                    if self.act[new] == 0 && !self.has3(old, new)
                        c = c + 1
                    end
                end
            end
        end

        if c < 1
            return false
        end

        var p = self.rnd(c)

        for old: 1 .. self.n
            if self.act[old] == 1
                for new: 1 .. self.n
                    if self.act[new] == 0 && !self.has3(old, new)
                        p = p - 1

                        if p == 0
                            self.old_led = old
                            self.new_led = new
                            return true
                        end
                    end
                end
            end
        end

        return false
    end

    def pick_not_final()
        var c = 0

        for i: 1 .. self.n
            if self.act[i] == 1 && i != self.final_led
                c = c + 1
            end
        end

        if c < 1
            return 0
        end

        var p = self.rnd(c)

        for i: 1 .. self.n
            if self.act[i] == 1 && i != self.final_led
                p = p - 1

                if p == 0
                    return i
                end
            end
        end

        return 0
    end

    def random_cmd(cmd, idx, payload)
        if idx != 3
            tasmota.resp_cmnd("Use: random3 <seconds> <final_led>")
            return
        end

        var m = re.search("^ *([0-9]+) +([0-9]+) *$", payload)

        if m == nil || size(m) < 3
            tasmota.resp_cmnd("Use: random3 <seconds> <final_led>")
            return
        end

        self.random3(cmd, number(m[1]), number(m[2]))
    end

    def random3(cmd, seconds, final_led)
        seconds = int(seconds)
        final_led = int(final_led)

        if seconds < 1
            tasmota.resp_cmnd("Bad seconds value")
            return
        end

        if final_led < 1 || final_led > self.n
            tasmota.resp_cmnd("Bad final led, use 1.." .. self.n)
            return
        end

        self.stop0()
        self.final_led = final_led
        self.rnd_end = tasmota.millis() + seconds * 1000
        self.pick_initial3()
        self.mode = 2

        tasmota.resp_cmnd("Random3 started for " .. seconds .. " sec, final led: " .. final_led)
    end

    def run_start(cmd, rounds)
        rounds = int(rounds)

        if rounds < 1
            tasmota.resp_cmnd("Bad rounds value")
            return
        end

        self.stop0()
        self.set_all(0)
        self.r_total = rounds
        self.r_done = 0
        self.r_led = 0
        self.mode = 1

        tasmota.resp_cmnd("Number of rounds set to " .. self.r_total)
    end

    def run_step()
        if self.r_done >= self.r_total
            self.mode = 0
            self.r_led = 0
            self.set_all(0)
            return
        end

        if self.r_led == 0
            self.r_led = 1
            self.set_all(0)
            self.set_t(self.r_led, 1)

        elif self.r_led < self.n
            self.set_t(self.r_led, 0)
            self.r_led = self.r_led + 1
            self.set_t(self.r_led, 1)

        else
            self.set_t(self.r_led, 0)
            self.r_done = self.r_done + 1

            if self.r_done < self.r_total
                self.r_led = 1
                self.set_t(self.r_led, 1)
            else
                self.r_led = 0
                self.mode = 0
            end
        end
    end

    def fill_start(cmd, start_led)
        start_led = int(start_led)

        if start_led < 1 || start_led > self.n
            tasmota.resp_cmnd("Bad start led, use 1.." .. self.n)
            return
        end

        self.stop0()
        self.set_all(0)
        self.fill_led = start_led
        self.fill_done = 0
        self.fill_started = 0
        self.mode = 4

        tasmota.resp_cmnd("Fill started from led " .. start_led)
    end

    def previous_led(i)
        i = i - 1

        if i < 1
            i = self.n
        end

        return i
    end

    def fill_step()
        if self.fill_done >= self.n - 1
            self.mode = 0
            self.fill_led = 0
            return
        end

        self.fill_done = self.fill_done + 1
        self.fill_led = self.previous_led(self.fill_led)
        self.set_led(self.fill_led, 1)
    end

    def finish_step()
        if self.act[self.final_led] != 1
            self.set_led(self.final_led, 1)
            self.mode = 7
            return
        end

        if self.lvl[self.final_led] < self.max_pwm
            return
        end

        var led = self.pick_not_final()

        if led != 0
            self.old_led = led
            self.set_led(led, 0)
            self.mode = 8
            return
        end

        for i: 1 .. self.n
            if i == self.final_led
                self.set_led(i, 1)
            else
                self.set_led(i, 0)
            end
        end

        self.mode = 0
    end

    def fade()
        var old_dim = self.dim
        self.dim = self.move(self.dim, self.dim_t, self.dim_step)

        for i: 1 .. self.n
            var old = self.lvl[i]
            self.lvl[i] = self.move(self.lvl[i], self.tgt[i], self.fade_step)

            if old != self.lvl[i] || old_dim != self.dim
                gpio.set_pwm(self.pin[i], self.pwm(self.lvl[i]))
            end
        end
    end

    def animate()
        if self.mode == 0
            return
        end

        if self.mode == 1
            if self.r_led != 0 && self.lvl[self.r_led] < self.max_pwm
                return
            end

            self.cnt = self.cnt + 1

            if self.cnt >= self.run_spd
                self.cnt = 0
                self.run_step()
            end

        elif self.mode == 2
            if tasmota.millis() >= self.rnd_end
                self.mode = 6
                self.cnt = 0
                return
            end

            if !self.ready3()
                return
            end

            self.cnt = self.cnt + 1

            if self.cnt >= self.rnd_spd
                self.cnt = 0

                if self.pick_switch()
                    self.set_led(self.new_led, 1)
                    self.mode = 3
                end
            end

        elif self.mode == 3
            if self.lvl[self.new_led] >= self.max_pwm
                self.set_led(self.old_led, 0)
                self.mode = 5
            end

        elif self.mode == 4
            if self.fill_started == 0
                for i: 1 .. self.n
                    if self.lvl[i] > 0
                        return
                    end
                end

                self.set_led(self.fill_led, 1)
                self.fill_started = 1
                self.cnt = 0
                return
            end

            if self.fill_led == 0 || self.lvl[self.fill_led] < self.max_pwm
                return
            end

            self.cnt = self.cnt + 1

            if self.cnt >= self.run_spd
                self.cnt = 0
                self.fill_step()
            end

        elif self.mode == 5
            if self.lvl[self.old_led] <= 0
                self.new_led = 0
                self.old_led = 0
                self.mode = 2
                self.cnt = 0
            end

        elif self.mode == 6
            self.finish_step()

        elif self.mode == 7
            if self.lvl[self.final_led] >= self.max_pwm
                self.mode = 6
            end

        elif self.mode == 8
            if self.lvl[self.old_led] <= 0
                self.old_led = 0
                self.mode = 6
            end
        end
    end

    def status(cmd)
        var msg = "mode=" .. self.mode
        msg = msg .. ", dim=" .. int((self.dim_t * 100) / self.max_pwm) .. "%"
        tasmota.resp_cmnd(msg)
    end

    def every_50ms()
        self.animate()
        self.fade()
    end
end

var ceiling_led_driver = CeilingLed()

tasmota.add_driver(ceiling_led_driver)

tasmota.add_cmd("pwmdimmer", /cmd, pwm_number, state -> ceiling_led_driver.manual(cmd, number(pwm_number), number(state)))
tasmota.add_cmd("runningled", /cmd, i, rounds -> ceiling_led_driver.run_start(cmd, number(rounds)))
tasmota.add_cmd("fillled", /cmd, i, start_led -> ceiling_led_driver.fill_start(cmd, number(start_led)))
tasmota.add_cmd("runningspeed", /cmd, i, speed -> ceiling_led_driver.set_run_speed(cmd, i, number(speed)))
tasmota.add_cmd("allon", / -> ceiling_led_driver.all_on())
tasmota.add_cmd("alloff", / -> ceiling_led_driver.all_off())
tasmota.add_cmd("ceildim", /cmd, i, percent -> ceiling_led_driver.set_dim(cmd, number(percent)))
tasmota.add_cmd("random", /cmd, idx, payload -> ceiling_led_driver.random_cmd(cmd, idx, payload))
tasmota.add_cmd("randomspeed", /cmd, i, speed -> ceiling_led_driver.set_random_speed(cmd, number(speed)))
tasmota.add_cmd("ceilstop", /cmd -> ceiling_led_driver.stop())
tasmota.add_cmd("ceilstatus", /cmd -> ceiling_led_driver.status(cmd))

ceiling_led_driver.all_off()

print("CeilingLed driver loaded - FILL REVERSE V2")
print("--------------------------------------------------------------")
print("Commands:")
print("pwmdimmer<n> <state> - set selected LED, state: 1-on 0-off")
print("runningled <rounds> - run selected number of rounds")
print("fillled <start_led> - order: start, start-1 ... 1, 8 ...")
print("runningspeed <speed> - speed of runningled and fillled")
print("allon - turn on all LEDs")
print("alloff - turn off all LEDs")
print("ceildim <0..100> - global dimmer")
print("random <seconds> <final_led> - random 3 LED animation, final_led remains on")
print("randomspeed <speed> - speed of random3")
print("ceilstop - stop current animation")
print("ceilstatus - show current state")
print("--------------------------------------------------------------")
