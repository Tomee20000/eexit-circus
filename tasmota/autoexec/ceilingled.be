var pwm1 = 32
var pwm2 = 33
var pwm3 = 25
var pwm4 = 26
var pwm5 = 27
var pwm6 = 14
var pwm7 = 13
var pwm8 = 23
#var pwm9 = 22

var led_map = {1 : [pwm1,0],2 : [pwm2,0],3 : [pwm3,0],4 : [pwm4,0],5 : [pwm5,0],6 : [pwm6,0],7 : [pwm7,0],8 : [pwm8,0]}

def pwm_dimmer(cmd, pwm_number, state)
    if pwm_number > led_map.size() || pwm_number < 1 || state < 0 || state > 1 || state == led_map[pwm_number][1]
        return
    else
        if state == 1
            for i: 1 .. 16
                gpio.set_pwm(led_map[number(pwm_number)][0],i * 64 - 1)
                tasmota.delay(10)
            end
            tasmota.resp_cmnd("Led " .. pwm_number .. " turned on")
        else
            for i: 1 .. 16
                gpio.set_pwm(led_map[pwm_number][0],1024 - i * 64)
                tasmota.delay(10)
            end
            tasmota.resp_cmnd("Led " .. pwm_number .. " turned off")
        end
        led_map[pwm_number][1] = state
    end
end

class CeilingLed
    var round_enabled, round_on_led, maxled, time_counter, number_of_rounds, round_count, speed, speedcounter
    def init()
        self.speed = 1
        self.speedcounter = 1
        self.round_enabled = false
        self.round_on_led = 0
        self.maxled = 8
        self.time_counter = 0
        self.number_of_rounds = 0
        self.round_count = 0
        for i: 1 .. led_map.size()
            gpio.set_pwm(led_map[i][0],led_map[i][1])
        end
    end

    def set_speed(cmd, i, speed)
        self.speed = speed
        self.speedcounter = self.speedcounter % speed + 1 
        tasmota.resp_cmnd("Speed set to " .. self.speed)
    end

    def all_on_dim()
        for i: 1 .. led_map.size()
            pwm_dimmer('',i,1)
        end
        tasmota.resp_cmnd("All led on")
    end

    def all_off_dim()
        for i: 1 .. led_map.size()
            pwm_dimmer('',i,0)
        end
        tasmota.resp_cmnd("All led off")
    end

    def all_running(cmd,i,rounds)
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

            for i: 1 .. led_map.size()
                gpio.set_pwm(led_map[i][0],led_map[i][1])
            end

            tasmota.resp_cmnd("Led off")
        end
    end

    def every_100ms()
        if self.speedcounter == self.speed
            if self.round_enabled && self.round_count != self.number_of_rounds
                if self.round_on_led == 0
                    pwm_dimmer('',1,1)
                    self.round_on_led = 1
                elif self.round_on_led < self.maxled
                    pwm_dimmer('',self.round_on_led + 1,1)
                    pwm_dimmer('',self.round_on_led,0)
                    self.round_on_led = self.round_on_led + 1
                elif self.round_on_led == self.maxled && self.round_count + 1 < self.number_of_rounds
                    self.round_count = self.round_count + 1
                    pwm_dimmer('',1,1)
                    pwm_dimmer('',self.round_on_led,0)
                    self.round_on_led = 1
                elif self.round_on_led == self.maxled && self.round_count + 1 == self.number_of_rounds
                    self.round_count = self.round_count + 1
                    pwm_dimmer('',self.round_on_led,0)
                    self.round_on_led = 0
                end
            end
            self.speedcounter = 1
        else
            self.speedcounter = self.speedcounter + 1
        end
    end
end

var leddriver = CeilingLed()

tasmota.add_driver(leddriver)

tasmota.add_cmd("pwmdimmer", /cmd, pwm_number, state -> pwm_dimmer(cmd, number(pwm_number), number(state)))
tasmota.add_cmd("runningled", /cmd, mode, rounds -> leddriver.running_led_switch(cmd, number(mode), number(rounds)))
tasmota.add_cmd("runningspeed", /cmd, i, speed -> leddriver.set_speed(cmd, i, number(speed)))
tasmota.add_cmd("allon", / -> leddriver.all_on_dim())
tasmota.add_cmd("alloff", / -> leddriver.all_off_dim())
tasmota.add_cmd("allrunning", /cmd, i, rounds -> leddriver.all_running(cmd,i,number(rounds)))

leddriver.all_on_dim()

print ("Ceiling led driver loaded")