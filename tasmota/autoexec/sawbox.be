var SAW = 33

var OUT1 = 0

class SawBox
    var counter, saw_in, strip, led_count, red_color, green_color, count_per_led

    def init()
        self.counter = 0
        self.saw_in = false
        self.led_count = 30
        self.count_per_led = 25
        self.red_color = self.rgb(255, 0, 0)
        self.green_color = self.rgb(0,255, 0)

        self.strip = Leds(self.led_count, gpio.pin(gpio.WS2812, 3))
        self.strip.clear()

        tasmota.add_fast_loop(/-> self.fast_loop())
    end

    def initGame() #for command
        self.counter = 0
        self.saw_in = false
        self.strip.clear()

        tasmota.resp_cmnd("Initialized")
    end

    def fast_loop()
        if !gpio.digital_read(SAW) && !self.saw_in
            self.counter = self.counter + 1 
            self.saw_in = true
        end

        if gpio.digital_read(SAW) && self.saw_in
            self.saw_in = false
        end
    end

    def rgb(r, g, b)
        return (r << 16) | (g << 8) | b
    end

    def every_50ms()
        if self.counter < (self.count_per_led * self.led_count)
            self.strip.set_pixel_color(29-(self.counter/self.count_per_led-1), self.red_color, 255)
            print("Counter " .. self.counter)
        else
            for i: 0..(self.led_count - 1)
                self.strip.set_pixel_color(i, self.green_color, 255)
                tasmota.set_power(OUT1, false)
            end
        end

        self.strip.show()
    end
end

var sawboxdriver = SawBox()
tasmota.add_driver(sawboxdriver)

tasmota.add_cmd("init", /cmd, idx -> sawboxdriver.initGame())

print("SawBox driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("")
print("--------------------------------------------------------------")