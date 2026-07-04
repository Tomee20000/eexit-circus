import gpio
import mqtt
import json

# =========================================================
# CONFIG
# =========================================================
var LED0 = 3
var LED_COUNT = 6

var LASER = 25
var MOTOR1 = 32
var MOTOR2 = 33
var CONNECTED = 36
var TRIGGER = 39

var STEP = 5
var MAX_CHARGE = STEP * 5

var DECAY_MS = 5000

var FORWARD1_MS = 35
var BACK_MS = 50
var FORWARD2_MS = 35

var SAW_SOUND_TOPIC = "CSAWBOX/SOUND"
var CRY_GAIN = 100
var CRY_RESTART_MS = 29000


# =========================================================
# LASERGUN DRIVER
# =========================================================
class LaserGun

    var enable, charge, last_msg, trigger_lock, decay, infinite
    var shot_phase, phase_start, led_update
    var cry_started, cry_loud, cry_start

    def leds()
        if self.infinite
            return
        end

        tasmota.set_power(LED0, true)

        for i: 1..LED_COUNT - 1
            tasmota.set_power(
                LED0 + i,
                self.charge >= i * STEP
            )
        end
    end

    def leds_all_on()
        for i: 0..LED_COUNT - 1
            tasmota.set_power(LED0 + i, true)
        end
    end

    def leds_off()
        for i: 0..LED_COUNT - 1
            tasmota.set_power(LED0 + i, false)
        end
    end

    def down(update_leds)
        if self.infinite
            return
        end

        if self.charge >= STEP
            self.charge =
                ((self.charge / STEP) - 1) * STEP
        else
            self.charge = 0
        end

        if update_leds
            self.leds()
        else
            self.led_update = true
        end
    end

    def motor_off()
        gpio.digital_write(LASER, 0)
        gpio.digital_write(MOTOR1, 0)
        gpio.digital_write(MOTOR2, 0)
    end

    def motor_forward()
        gpio.digital_write(LASER, 0)
        gpio.digital_write(MOTOR1, 0)
        gpio.digital_write(MOTOR2, 1)
    end

    def motor_back()
        gpio.digital_write(LASER, 1)
        gpio.digital_write(MOTOR1, 1)
        gpio.digital_write(MOTOR2, 0)
    end

    def shoot()
        self.down(false)

        self.shot_phase = 1
        self.phase_start = tasmota.millis()
        self.motor_forward()
    end

    def start_cry()
        self.cry_started = true
        self.cry_start = tasmota.millis()

        tasmota.cmd("i2sgain " .. str(CRY_GAIN))
        tasmota.cmd("i2splay mp3/cry.mp3")
    end

    def cry_on()
        var now = tasmota.millis()

        if !self.cry_started || now - self.cry_start >= CRY_RESTART_MS
            self.start_cry()
        end

        if !self.cry_loud
            self.cry_loud = true
            tasmota.cmd("i2sgain " .. str(CRY_GAIN))
        end
    end

    def cry_quiet()
        if self.cry_loud
            self.cry_loud = false
            tasmota.cmd("i2sgain 0")
        end
    end

    def cry_stop()
        self.cry_started = false
        self.cry_loud = false
        self.cry_start = 0

        tasmota.cmd("i2sstop")
        tasmota.cmd("i2sgain 0")
    end

    def on_mqtt_message(topic, payload)
        if topic == "CLASERGUN/BCOUNTER"
            self.last_msg = tasmota.millis()

            if !self.infinite
                self.charge += number(payload)

                if self.charge > MAX_CHARGE
                    self.charge = MAX_CHARGE
                end

                if self.enable && self.shot_phase == 0
                    self.leds()
                else
                    self.led_update = true
                end
            end

            return
        end

        if topic == SAW_SOUND_TOPIC
            var data = json.load(payload).find("data", nil)

            if data == "LOUD"
                self.cry_on()
            elif data == "QUIET"
                self.cry_quiet()
            elif data == "STOP"
                self.cry_stop()
            end

            return
        end
    end

    def init()
        mqtt.subscribe(
            "CLASERGUN/BCOUNTER",
            /t, idx, data, b -> self.on_mqtt_message(t, data)
        )

        mqtt.subscribe(
            SAW_SOUND_TOPIC,
            /t, idx, data, b -> self.on_mqtt_message(t, data)
        )

        tasmota.add_fast_loop(/ -> self.fast_loop())

        self.enable = true
        self.charge = 0
        self.last_msg = tasmota.millis()
        self.trigger_lock = false
        self.decay = true
        self.infinite = false
        self.shot_phase = 0
        self.phase_start = 0
        self.led_update = false

        self.cry_started = false
        self.cry_loud = false
        self.cry_start = 0

        self.motor_off()
        self.leds()

        tasmota.cmd("i2sgain 0")
    end

    def enable_game()
        self.enable = true
        self.last_msg = tasmota.millis()
        self.trigger_lock = false
        self.shot_phase = 0
        self.phase_start = 0
        self.led_update = false
        self.motor_off()

        if self.infinite
            self.leds_all_on()
        else
            self.leds()
        end

        tasmota.resp_cmnd("Game enabled")
    end

    def disable_game()
        self.enable = false
        self.trigger_lock = false
        self.shot_phase = 0
        self.phase_start = 0
        self.led_update = false
        self.motor_off()
        self.leds_off()

        tasmota.resp_cmnd("Game disabled")
    end

    def decay_on()
        self.decay = true
        self.last_msg = tasmota.millis()
        tasmota.resp_cmnd("Auto decay enabled")
    end

    def decay_off()
        self.decay = false
        tasmota.resp_cmnd("Auto decay disabled")
    end

    def infinite_on()
        self.infinite = true
        self.led_update = false
        self.leds_all_on()
        tasmota.resp_cmnd("Infinite shots enabled")
    end

    def infinite_off()
        self.infinite = false
        self.led_update = false
        self.leds()
        tasmota.resp_cmnd("Infinite shots disabled")
    end

    def every_50ms()
        var now = tasmota.millis()

        if self.cry_loud &&
           self.cry_started &&
           now - self.cry_start >= CRY_RESTART_MS

            self.start_cry()
        end

        if !self.enable
            return
        end

        if self.decay &&
           !self.infinite &&
           self.charge > 0 &&
           now - self.last_msg >= DECAY_MS

            self.down(true)
            self.last_msg = now
        end
    end

    def fast_loop()
        var now = tasmota.millis()

        if self.shot_phase == 1 &&
           now - self.phase_start >= FORWARD1_MS

            self.shot_phase = 2
            self.phase_start = now
            self.motor_back()
        end

        if self.shot_phase == 2 &&
           now - self.phase_start >= BACK_MS

            self.shot_phase = 3
            self.phase_start = now
            self.motor_forward()
        end

        if self.shot_phase == 3 &&
           now - self.phase_start >= FORWARD2_MS

            self.shot_phase = 0
            self.phase_start = 0
            self.motor_off()

            if self.led_update && !self.infinite
                self.led_update = false
                self.leds()
            end
        end

        if !self.enable
            return
        end

        if gpio.digital_read(TRIGGER)
            self.trigger_lock = false
        end

        if !gpio.digital_read(CONNECTED) &&
           !gpio.digital_read(TRIGGER) &&
           !self.trigger_lock &&
           self.shot_phase == 0 &&
           (self.infinite || self.charge >= STEP)

            self.trigger_lock = true
            self.shoot()
        end
    end
end


# =========================================================
# INIT
# =========================================================
var laser_gun_driver = LaserGun()
tasmota.add_driver(laser_gun_driver)


# =========================================================
# COMMANDS
# =========================================================
tasmota.add_cmd("enable", / -> laser_gun_driver.enable_game())
tasmota.add_cmd("disable", / -> laser_gun_driver.disable_game())

tasmota.add_cmd("decayon", / -> laser_gun_driver.decay_on())
tasmota.add_cmd("decayoff", / -> laser_gun_driver.decay_off())

tasmota.add_cmd("infiniteon", / -> laser_gun_driver.infinite_on())
tasmota.add_cmd("infiniteoff", / -> laser_gun_driver.infinite_off())


# =========================================================
# HELP / INFO
# =========================================================
print("LaserGun driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("enable - game enabled")
print("disable - game disabled")
print("decayon - automatic led decrease enabled")
print("decayoff - automatic led decrease disabled")
print("infiniteon - infinite shots enabled")
print("infiniteoff - infinite shots disabled")
print("--------------------------------------------------------------")