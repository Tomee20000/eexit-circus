var PWM1 = 32
var PWM2 = 33
var PWM3 = 25
var PWM4 = 26
var PWM5 = 27
var PWM6 = 14
var PWM7 = 13
var PWM8 = 23
var LED_MAP = {1 : [PWM1, 0],2 : [PWM2, 0],3 : [PWM3, 0],4 : [PWM4, 0],5 : [PWM5, 0],6 : [PWM6, 0],7 : [PWM7, 0],8 : [PWM8, 0]}

def pwm_dimmer(cmd, pwm_number, state)
    if pwm_number > LED_MAP.size() || pwm_number < 1 || state < 0 || state > 1 || state == LED_MAP[pwm_number][1]
        return
    else
        if state == 1
            for i: 1 .. 16
                gpio.set_pwm(LED_MAP[pwm_number][0], i * 64 - 1)
                tasmota.delay(10)
            end
            tasmota.resp_cmnd("Led " .. pwm_number .. " turned on")
        else
            for i: 1 .. 16
                gpio.set_pwm(LED_MAP[pwm_number][0], 1024 - i * 64)
                tasmota.delay(10)
            end
            tasmota.resp_cmnd("Led " .. pwm_number .. " turned off")
        end
        LED_MAP[pwm_number][1] = state
    end
end

class CeilingLed
    var round_enabled, round_on_led, maxled, time_counter, number_of_rounds, round_count, speed, speed_counter
    def init()
        self.speed = 1
        self.speed_counter = 1
        self.round_enabled = false
        self.round_on_led = 0
        self.maxled = 8
        self.time_counter = 0
        self.number_of_rounds = 0
        self.round_count = 0
        for i: 1 .. LED_MAP.size()
            gpio.set_pwm(LED_MAP[i][0], LED_MAP[i][1])
        end
    end

    def set_speed(cmd, i, speed)
        if speed < 1
            tasmota.resp_cmnd("Bad argument: " .. speed)
            return
        end

        self.speed = speed
        self.speed_counter = self.speed_counter % speed + 1 
        tasmota.resp_cmnd("Speed set to " .. self.speed)
    end

    def all_on_dim()
        for i: 1 .. LED_MAP.size()
            pwm_dimmer('', i, 1)
        end
        tasmota.resp_cmnd("All led on")
    end

    def all_off_dim()
        for i: 1 .. LED_MAP.size()
            pwm_dimmer('', i, 0)
        end
        tasmota.resp_cmnd("All led off")
    end

    def all_running(cmd, i, rounds)
        for j: 1 .. rounds
            self.all_on_dim()
            self.all_off_dim()
        end

        tasmota.resp_cmnd("All running, rounds: " .. rounds)
    end

    def running_led_switch(cmd, mode, rounds)
        if mode == 1
            self.number_of_rounds = rounds
            self.round_enabled = true

            tasmota.resp_cmnd("Number of rounds set to " .. self.number_of_rounds)

        elif mode == 0
            self.number_of_rounds = 0
            self.round_enabled = false
            self.round_count = 0
            self.round_on_led = 0

            for i: 1 .. LED_MAP.size()
                gpio.set_pwm(LED_MAP[i][0], LED_MAP[i][1])
            end

            tasmota.resp_cmnd("Led off")
        end
    end

    def every_100ms()
        if self.speed_counter == self.speed
            if self.round_enabled && self.round_count != self.number_of_rounds
                if self.round_on_led == 0
                    pwm_dimmer('', 1, 1)
                    self.round_on_led = 1
                elif self.round_on_led < self.maxled
                    pwm_dimmer('', self.round_on_led + 1, 1)
                    pwm_dimmer('', self.round_on_led, 0)
                    self.round_on_led = self.round_on_led + 1
                elif self.round_on_led == self.maxled && self.round_count + 1 < self.number_of_rounds
                    self.round_count = self.round_count + 1
                    pwm_dimmer('', 1, 1)
                    pwm_dimmer('', self.round_on_led, 0)
                    self.round_on_led = 1
                elif self.round_on_led == self.maxled && self.round_count + 1 == self.number_of_rounds
                    self.round_count = self.round_count + 1
                    pwm_dimmer('', self.round_on_led, 0)
                    self.round_on_led = 0
                end
            end
            self.speed_counter = 1
        else
            self.speed_counter = self.speed_counter + 1
        end
    end
end

var ceiling_led_driver = CeilingLed()

tasmota.add_driver(ceiling_led_driver)

tasmota.add_cmd("pwmdimmer", /cmd, pwm_number, state -> pwm_dimmer(cmd, number(pwm_number), number(state)))
tasmota.add_cmd("runningled", /cmd, mode, rounds -> ceiling_led_driver.running_led_switch(cmd, number(mode), number(rounds)))
tasmota.add_cmd("runningspeed", /cmd, i, speed -> ceiling_led_driver.set_speed(cmd, i, number(speed)))
tasmota.add_cmd("allon", / -> ceiling_led_driver.all_on_dim())
tasmota.add_cmd("alloff", / -> ceiling_led_driver.all_off_dim())
tasmota.add_cmd("allrunning", /cmd, i, rounds -> ceiling_led_driver.all_running(cmd, i, number(rounds)))

ceiling_led_driver.all_off_dim()

print("CeilingLed driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("pwmdimmer<n> <state> - set selected LED, state: 1-on 0-off")
print("runningled<mode> <rounds> - running LED mode, mode: 1-on 0-off")
print("runningspeed <speed> - speed of runningled")
print("allon - turn on all LEDs")
print("alloff - turn off all LEDs")
print("allrunning <rounds> - turn all LEDs on and off for the selected rounds")
print("--------------------------------------------------------------")