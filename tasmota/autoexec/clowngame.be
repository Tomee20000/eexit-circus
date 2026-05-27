var NOSE1 = 25
var NOSE2 = 26
var NOSE3 = 27
var NOSE4 = 14
var NOSE5 = 12

var BUTTON1 = 39
var BUTTON2 = 34
var BUTTON3 = 35
var BUTTON4 = 32
var BUTTON5 = 33

var EYE1 = 23
var EYE2 = 22
var EYE3 = 21
var EYE4 = 19
var EYE5 = 18

class Clowngame
    var enable, max_brightness, blink_num

    def init()
        self.enable = false
        self.max_brightness = 256
        self.blink_num = 5

        gpio.set_pwm(EYE1,0)
        gpio.set_pwm(EYE2,0)
        gpio.set_pwm(EYE3,0)
        gpio.set_pwm(EYE4,0)
        gpio.set_pwm(EYE5,0)
    end

    def enable_game()
        self.enable = true
        self.blink(EYE1)
        tasmota.resp_cmnd("Game enabled")
    end

    def disable_game()
        self.enable = false
        tasmota.resp_cmnd("Game disabled")
    end

    def blink(eye)
        self._blink_step(eye, 0)
    end

    def _blink_step(eye, n)
        if n >= (self.blink_num * 2)
            gpio.set_pwm(eye, 0)
            return nil
        end

        gpio.set_pwm(eye, (n % 2 == 0) ? self.max_brightness : 0)

        tasmota.set_timer(250, /-> self._blink_step(eye, n + 1))
    end
end

var clowngamedriver = Clowngame()

tasmota.add_driver(clowngamedriver)


tasmota.add_cmd("enable", / -> clowngamedriver.enable_game())
tasmota.add_cmd("disable", / -> clowngamedriver.disable_game())

print("Clowngame driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("enable - game enabled")
print("disable - game disabled")
print("--------------------------------------------------------------")