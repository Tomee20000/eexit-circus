import mqtt
import gpio

var MQTT_TOPIC = "CCLAWMACHINE"

var MOTOR_FB1 = 23
var MOTOR_FB2 = 22
var MOTOR_LR2 = 21
var MOTOR_LR1 = 19
var MOTOR_CLAW1 = 5
var MOTOR_CLAW2 = 18
var CLAW = 12

var CLAW_MOTOR_RELAY = 17

var JOY_L = 32
var JOY_R = 33
var JOY_F = 35
var JOY_B = 34
var JOY_BUTTON = 25

var ENDSTOP_L = 27
var ENDSTOP_F = 14
var ENDSTOP_CLAW = 26

var COIN = 4

var PWM_MAX = 1023

var DOWN_MS = 4850
var EXTRA_DOWN_MS = 2000
var FULL_DOWN_MS = DOWN_MS + EXTRA_DOWN_MS
var GRAB_WAIT_MS = 1500
var FULLCYCLE_GRAB_WAIT_MS = 3000

var UP_TOTAL_MS = 4850
var UP_START_PWM = 410
var UP_RAMP_MS = 600

var HOMING_START_PWM = 430
var HOMING_MAX_PWM = 870
var HOMING_RAMP_MS = 400

var DROP_OPEN_MS = 1000
var FINAL_UP_MAX_MS = 9000
var RELAY_DELAY_MS = 100

var CLAW_RELAY_ON = gpio.HIGH
var CLAW_RELAY_OFF = gpio.LOW

gpio.set_pwm(MOTOR_LR1, 0, 0)
gpio.set_pwm(MOTOR_LR2, 0, 0)
gpio.set_pwm(MOTOR_FB1, 0, 0)
gpio.set_pwm(MOTOR_FB2, 0, 0)
gpio.set_pwm(MOTOR_CLAW1, 0, 0)
gpio.set_pwm(MOTOR_CLAW2, 0, 0)

gpio.digital_write(CLAW, gpio.LOW)
gpio.digital_write(CLAW_MOTOR_RELAY, CLAW_RELAY_OFF)

class ClawMachine
    var motor_lr_state, motor_fb_state, motor_claw_state
    var in_claw_animation, is_coin_inserted
    var phase, anim_id
    var claw_ramp_start, homing_ramp_start
    var last_status
    var coin_ready

    def pwm_pair(pin1, pin2, v1, v2)
        if v1 < 0
            v1 = 0
        end

        if v2 < 0
            v2 = 0
        end

        if v1 > PWM_MAX
            v1 = PWM_MAX
        end

        if v2 > PWM_MAX
            v2 = PWM_MAX
        end

        if v1 + v2 > PWM_MAX
            if v1 > v2
                v1 = PWM_MAX
                v2 = 0
            else
                v1 = 0
                v2 = PWM_MAX
            end
        end

        gpio.set_pwm(pin1, v1, 0)
        gpio.set_pwm(pin2, v2, v1)
    end

    def motor_lr(dir, duty)
        if dir == 1
            self.pwm_pair(MOTOR_LR1, MOTOR_LR2, duty, 0)
        elif dir == 2
            self.pwm_pair(MOTOR_LR1, MOTOR_LR2, 0, duty)
        else
            self.pwm_pair(MOTOR_LR1, MOTOR_LR2, 0, 0)
        end
    end

    def motor_fb(dir, duty)
        if dir == 1
            self.pwm_pair(MOTOR_FB1, MOTOR_FB2, duty, 0)
        elif dir == 2
            self.pwm_pair(MOTOR_FB1, MOTOR_FB2, 0, duty)
        else
            self.pwm_pair(MOTOR_FB1, MOTOR_FB2, 0, 0)
        end
    end

    def motor_claw(dir, duty)
        if dir == 1
            self.pwm_pair(MOTOR_CLAW1, MOTOR_CLAW2, 0, duty)
        elif dir == 2
            self.pwm_pair(MOTOR_CLAW1, MOTOR_CLAW2, duty, 0)
        else
            self.pwm_pair(MOTOR_CLAW1, MOTOR_CLAW2, 0, 0)
        end
    end

    def claw_relay_on()
        gpio.digital_write(CLAW_MOTOR_RELAY, CLAW_RELAY_ON)
    end

    def claw_relay_off()
        gpio.digital_write(CLAW_MOTOR_RELAY, CLAW_RELAY_OFF)
    end

    def ramp_value(start_pwm, max_pwm, ramp_ms, start_time)
        var elapsed = tasmota.millis() - start_time

        if elapsed >= ramp_ms
            return max_pwm
        end

        return start_pwm + ((max_pwm - start_pwm) * elapsed) / ramp_ms
    end

    def valid_anim(id)
        if !self.in_claw_animation
            return false
        end

        if id != self.anim_id
            return false
        end

        return true
    end

    def status_text()
        if self.phase == 1
            return "Karomciklus indul"
        elif self.phase == 2
            return "Karom leengedése"
        elif self.phase == 3
            return "Markolás"
        elif self.phase == 4
            return "Karom felhúzása"
        elif self.phase == 5
            return "X/Y tengelyek alaphelyzetbe állítása"
        elif self.phase == 6
            return "Labda elengedése"
        elif self.phase == 7 || self.phase == 8
            return "Végső karomfelhúzás"
        elif self.phase == 9 || self.phase == 10
            return "Letiltás és alaphelyzetbe állítás"
        elif self.phase == 11
            return "Kézi leengedés"
        elif self.phase == 12
            return "Kézi felhúzás"
        elif self.phase == 20
            return "Teljes ciklus: karom alaphelyzet"
        elif self.phase == 21
            return "Teljes ciklus: X/Y alaphelyzet"
        elif self.phase == 22
            return "Teljes ciklus: leengedés"
        elif self.phase == 23
            return "Teljes ciklus: várakozás"
        elif self.phase == 24
            return "Teljes ciklus: felhúzás"
        end

        if self.motor_lr_state != 0 || self.motor_fb_state != 0
            return "Játékos vezérlés"
        end

        if self.is_coin_inserted
            return "Játékra kész"
        end

        return "Inaktív"
    end

    def publish_status()
        var text = self.status_text()
        var msg = '{"text":"' .. text .. '","phase":' .. self.phase .. ',"enabled":' .. (self.is_coin_inserted ? "true" : "false") .. '}'
        if msg == self.last_status
            return
        end
        self.last_status = msg
        mqtt.publish("CCLAWMACHINE/STATUS", msg, true)
    end

    def all_motors_stop()
        self.motor_lr(0, 0)
        self.motor_fb(0, 0)
        self.motor_claw(0, 0)

        self.motor_lr_state = 0
        self.motor_fb_state = 0
        self.motor_claw_state = 0
    end

    def fast_loop()
        if gpio.digital_read(COIN)
            self.coin_ready = true
        end

        if !gpio.digital_read(COIN) &&
           self.coin_ready &&
           !self.is_coin_inserted &&
           !self.in_claw_animation

            self.coin_ready = false
            self.enable_game()

            var payload = '{"data":"ENABLED"}'

            mqtt.publish(
                MQTT_TOPIC,
                payload
            )
        end
    end

    def init()
        self.motor_lr_state = 0
        self.motor_fb_state = 0
        self.motor_claw_state = 0
        self.in_claw_animation = false
        self.is_coin_inserted = false
        self.phase = 0
        self.anim_id = 0
        self.claw_ramp_start = 0
        self.homing_ramp_start = 0
        self.last_status = ""
        self.coin_ready = gpio.digital_read(COIN)

        self.all_motors_stop()
        self.claw_relay_off()
        gpio.digital_write(CLAW, gpio.LOW)

        tasmota.add_fast_loop(/ -> self.fast_loop())
    end

    def enable_game()
        self.is_coin_inserted = true
        self.last_status = ""
        self.publish_status()
        tasmota.resp_cmnd("Game enabled")
    end

    def disable_game()
        self.is_coin_inserted = false
        self.coin_ready = false
        self.start_disable_homing()
        self.last_status = ""
        self.publish_status()
        tasmota.resp_cmnd("Game disabled, reset homing started")
    end

    def start_claw_animation()
        print("claw animation started")

        self.anim_id = self.anim_id + 1
        var id = self.anim_id

        self.in_claw_animation = true
        self.phase = 1

        self.all_motors_stop()

        gpio.digital_write(CLAW, gpio.LOW)

        self.claw_relay_on()

        tasmota.set_timer(RELAY_DELAY_MS, / -> self.start_claw_down(id))
    end

    def start_claw_down(id)
        if !self.valid_anim(id) || self.phase != 1
            return
        end

        print("claw down")

        self.phase = 2
        self.motor_claw_state = 1
        self.motor_claw(1, PWM_MAX)

        tasmota.set_timer(DOWN_MS, / -> self.claw_stop_grab(id))
        tasmota.set_timer(DOWN_MS + GRAB_WAIT_MS, / -> self.claw_up_soft(id))
    end

    def claw_stop_grab(id)
        if !self.valid_anim(id) || self.phase != 2
            return
        end

        print("claw grab")

        self.phase = 3
        self.motor_claw_state = 0
        self.motor_claw(0, 0)
        gpio.digital_write(CLAW, gpio.HIGH)
    end

    def claw_up_soft(id)
        if !self.valid_anim(id) || self.phase != 3
            return
        end

        print("claw up soft")

        if gpio.digital_read(ENDSTOP_CLAW)
            self.claw_home(id)
            return
        end

        self.phase = 4
        self.motor_claw_state = 2
        self.claw_ramp_start = tasmota.millis()

        self.motor_claw(2, UP_START_PWM)

        tasmota.set_timer(UP_TOTAL_MS, / -> self.claw_home(id))
    end

    def claw_home(id)
        if !self.valid_anim(id) || self.phase != 4
            return
        end

        print("claw homing")

        self.motor_claw_state = 0
        self.motor_claw(0, 0)
        self.claw_relay_off()

        self.phase = 5
        self.homing_ramp_start = tasmota.millis()

        if gpio.digital_read(ENDSTOP_L)
            self.motor_lr_state = 0
            self.motor_lr(0, 0)
        else
            self.motor_lr_state = 1
            self.motor_lr(1, HOMING_START_PWM)
        end

        if gpio.digital_read(ENDSTOP_F)
            self.motor_fb_state = 0
            self.motor_fb(0, 0)
        else
            self.motor_fb_state = 2
            self.motor_fb(2, HOMING_START_PWM)
        end
    end

    def drop_ball()
        if !self.in_claw_animation || self.phase != 5
            return
        end

        print("claw over dropping hole")

        self.phase = 6

        self.motor_lr_state = 0
        self.motor_fb_state = 0

        self.motor_lr(0, 0)
        self.motor_fb(0, 0)

        gpio.digital_write(CLAW, gpio.LOW)

        var id = self.anim_id

        tasmota.set_timer(DROP_OPEN_MS, / -> self.final_claw_relay_on(id))
    end

    def final_claw_relay_on(id)
        if !self.valid_anim(id) || self.phase != 6
            return
        end

        print("final claw relay on")

        self.phase = 7
        self.claw_relay_on()

        tasmota.set_timer(RELAY_DELAY_MS, / -> self.final_claw_up(id))
    end

    def final_claw_up(id)
        if !self.valid_anim(id) || self.phase != 7
            return
        end

        print("final claw up full speed")

        if gpio.digital_read(ENDSTOP_CLAW)
            self.finish_animation(id)
            return
        end

        self.phase = 8
        self.motor_claw_state = 2

        self.motor_claw(2, PWM_MAX)

        tasmota.set_timer(FINAL_UP_MAX_MS, / -> self.finish_animation(id))
    end

    def finish_animation(id)
        if !self.valid_anim(id)
            return
        end

        print("claw animation finished")

        self.all_motors_stop()
        self.claw_relay_off()
        gpio.digital_write(CLAW, gpio.LOW)

        self.phase = 0
        self.in_claw_animation = false
    end

    def start_disable_homing()
        print("disable homing")

        self.anim_id = self.anim_id + 1
        var id = self.anim_id

        self.in_claw_animation = true
        self.phase = 9
        self.claw_ramp_start = 0
        self.homing_ramp_start = 0

        self.all_motors_stop()
        gpio.digital_write(CLAW, gpio.LOW)

        if gpio.digital_read(ENDSTOP_CLAW)
            self.claw_relay_off()
            self.start_xy_homing_only()
            return
        end

        self.claw_relay_on()

        self.motor_claw_state = 2
        self.claw_ramp_start = tasmota.millis()
        self.motor_claw(2, UP_START_PWM)

        tasmota.set_timer(FINAL_UP_MAX_MS, / -> self.disable_claw_homing_timeout(id))
    end

    def disable_claw_homing_timeout(id)
        if !self.valid_anim(id) || self.phase != 9
            return
        end

        print("disable claw homing timeout")

        self.motor_claw_state = 0
        self.motor_claw(0, 0)
        self.claw_relay_off()

        self.start_xy_homing_only()
    end

    def start_xy_homing_only()
        print("xy homing only")

        self.phase = 10
        self.homing_ramp_start = tasmota.millis()

        if gpio.digital_read(ENDSTOP_L)
            self.motor_lr_state = 0
            self.motor_lr(0, 0)
        else
            self.motor_lr_state = 1
            self.motor_lr(1, HOMING_START_PWM)
        end

        if gpio.digital_read(ENDSTOP_F)
            self.motor_fb_state = 0
            self.motor_fb(0, 0)
        else
            self.motor_fb_state = 2
            self.motor_fb(2, HOMING_START_PWM)
        end

        if self.motor_lr_state == 0 && self.motor_fb_state == 0
            self.finish_homing_only()
        end
    end

    def finish_homing_only()
        print("homing finished")

        self.all_motors_stop()
        self.claw_relay_off()
        gpio.digital_write(CLAW, gpio.LOW)

        self.phase = 0
        self.in_claw_animation = false
        self.claw_ramp_start = 0
        self.homing_ramp_start = 0
        self.last_status = ""
        self.publish_status()
    end

    def claw_down_cmd()
        print("command claw down")

        self.anim_id = self.anim_id + 1
        var id = self.anim_id

        self.in_claw_animation = true
        self.phase = 11

        self.all_motors_stop()
        gpio.digital_write(CLAW, gpio.LOW)
        self.claw_relay_on()

        tasmota.set_timer(RELAY_DELAY_MS, / -> self.claw_down_cmd_start(id))
    end

    def claw_down_cmd_start(id)
        if !self.valid_anim(id) || self.phase != 11
            return
        end

        self.motor_claw_state = 1
        self.motor_claw(1, PWM_MAX)

        tasmota.set_timer(FULL_DOWN_MS, / -> self.finish_manual_claw(id))
    end

    def claw_up_cmd()
        print("command claw up")

        self.anim_id = self.anim_id + 1
        var id = self.anim_id

        self.in_claw_animation = true
        self.phase = 12

        self.all_motors_stop()
        gpio.digital_write(CLAW, gpio.LOW)

        if gpio.digital_read(ENDSTOP_CLAW)
            self.finish_manual_claw(id)
            return
        end

        self.claw_relay_on()

        tasmota.set_timer(RELAY_DELAY_MS, / -> self.claw_up_cmd_start(id))
    end

    def claw_up_cmd_start(id)
        if !self.valid_anim(id) || self.phase != 12
            return
        end

        if gpio.digital_read(ENDSTOP_CLAW)
            self.finish_manual_claw(id)
            return
        end

        self.motor_claw_state = 2
        self.motor_claw(2, PWM_MAX)

        tasmota.set_timer(FINAL_UP_MAX_MS, / -> self.finish_manual_claw(id))
    end

    def finish_manual_claw(id)
        if !self.valid_anim(id)
            return
        end

        print("manual claw finished")

        self.all_motors_stop()
        self.claw_relay_off()
        gpio.digital_write(CLAW, gpio.LOW)

        self.phase = 0
        self.in_claw_animation = false
    end

    def fullcycle_cmd()
        print("fullcycle started")

        self.anim_id = self.anim_id + 1
        var id = self.anim_id

        self.in_claw_animation = true
        self.phase = 20

        self.all_motors_stop()
        gpio.digital_write(CLAW, gpio.LOW)

        if gpio.digital_read(ENDSTOP_CLAW)
            self.claw_relay_off()
            self.fullcycle_xy_homing()
            return
        end

        self.claw_relay_on()

        tasmota.set_timer(RELAY_DELAY_MS, / -> self.fullcycle_claw_home_start(id))
    end

    def fullcycle_claw_home_start(id)
        if !self.valid_anim(id) || self.phase != 20
            return
        end

        if gpio.digital_read(ENDSTOP_CLAW)
            self.motor_claw_state = 0
            self.motor_claw(0, 0)
            self.claw_relay_off()
            self.fullcycle_xy_homing()
            return
        end

        self.motor_claw_state = 2
        self.motor_claw(2, PWM_MAX)

        tasmota.set_timer(FINAL_UP_MAX_MS, / -> self.fullcycle_claw_home_timeout(id))
    end

    def fullcycle_claw_home_timeout(id)
        if !self.valid_anim(id) || self.phase != 20
            return
        end

        self.motor_claw_state = 0
        self.motor_claw(0, 0)
        self.claw_relay_off()

        self.fullcycle_xy_homing()
    end

    def fullcycle_xy_homing()
        print("fullcycle xy homing")

        self.phase = 21
        self.homing_ramp_start = tasmota.millis()

        if gpio.digital_read(ENDSTOP_L)
            self.motor_lr_state = 0
            self.motor_lr(0, 0)
        else
            self.motor_lr_state = 1
            self.motor_lr(1, HOMING_START_PWM)
        end

        if gpio.digital_read(ENDSTOP_F)
            self.motor_fb_state = 0
            self.motor_fb(0, 0)
        else
            self.motor_fb_state = 2
            self.motor_fb(2, HOMING_START_PWM)
        end

        if self.motor_lr_state == 0 && self.motor_fb_state == 0
            self.fullcycle_down()
        end
    end

    def fullcycle_down()
        print("fullcycle down")

        var id = self.anim_id

        self.phase = 22

        self.motor_lr_state = 0
        self.motor_fb_state = 0

        self.motor_lr(0, 0)
        self.motor_fb(0, 0)

        gpio.digital_write(CLAW, gpio.LOW)
        self.claw_relay_on()

        tasmota.set_timer(RELAY_DELAY_MS, / -> self.fullcycle_down_start(id))
    end

    def fullcycle_down_start(id)
        if !self.valid_anim(id) || self.phase != 22
            return
        end

        self.motor_claw_state = 1
        self.motor_claw(1, PWM_MAX)

        tasmota.set_timer(FULL_DOWN_MS, / -> self.fullcycle_grab(id))
    end

    def fullcycle_grab(id)
        if !self.valid_anim(id) || self.phase != 22
            return
        end

        print("fullcycle grab")

        self.phase = 23
        self.motor_claw_state = 0
        self.motor_claw(0, 0)
        gpio.digital_write(CLAW, gpio.LOW)

        tasmota.set_timer(FULLCYCLE_GRAB_WAIT_MS, / -> self.fullcycle_up(id))
    end

    def fullcycle_up(id)
        if !self.valid_anim(id) || self.phase != 23
            return
        end

        print("fullcycle up")

        if gpio.digital_read(ENDSTOP_CLAW)
            self.finish_fullcycle(id)
            return
        end

        self.phase = 24
        self.motor_claw_state = 2
        self.motor_claw(2, PWM_MAX)

        tasmota.set_timer(FINAL_UP_MAX_MS, / -> self.finish_fullcycle(id))
    end

    def finish_fullcycle(id)
        if !self.valid_anim(id)
            return
        end

        print("fullcycle finished")

        self.all_motors_stop()
        self.claw_relay_off()
        gpio.digital_write(CLAW, gpio.LOW)

        self.phase = 0
        self.in_claw_animation = false
    end

    def update_claw_ramp()
        if self.phase == 4
            if gpio.digital_read(ENDSTOP_CLAW)
                self.motor_claw_state = 0
                self.motor_claw(0, 0)
                self.claw_home(self.anim_id)
                return
            end

            var duty = self.ramp_value(
                UP_START_PWM,
                PWM_MAX,
                UP_RAMP_MS,
                self.claw_ramp_start
            )

            self.motor_claw(2, duty)

        elif self.phase == 8
            if gpio.digital_read(ENDSTOP_CLAW)
                self.motor_claw_state = 0
                self.motor_claw(0, 0)
                self.finish_animation(self.anim_id)
                return
            end

            self.motor_claw(2, PWM_MAX)

        elif self.phase == 9
            if gpio.digital_read(ENDSTOP_CLAW)
                self.motor_claw_state = 0
                self.motor_claw(0, 0)
                self.claw_relay_off()
                self.start_xy_homing_only()
                return
            end

            var duty2 = self.ramp_value(
                UP_START_PWM,
                PWM_MAX,
                UP_RAMP_MS,
                self.claw_ramp_start
            )

            self.motor_claw(2, duty2)

        elif self.phase == 12
            if gpio.digital_read(ENDSTOP_CLAW)
                self.finish_manual_claw(self.anim_id)
                return
            end

            self.motor_claw(2, PWM_MAX)

        elif self.phase == 20
            if gpio.digital_read(ENDSTOP_CLAW)
                self.motor_claw_state = 0
                self.motor_claw(0, 0)
                self.claw_relay_off()
                self.fullcycle_xy_homing()
                return
            end

            if self.motor_claw_state == 2
                self.motor_claw(2, PWM_MAX)
            end

        elif self.phase == 24
            if gpio.digital_read(ENDSTOP_CLAW)
                self.finish_fullcycle(self.anim_id)
                return
            end

            self.motor_claw(2, PWM_MAX)
        end
    end

    def update_homing_ramp()
        if self.phase != 5 && self.phase != 10 && self.phase != 21
            return
        end

        var duty = self.ramp_value(
            HOMING_START_PWM,
            HOMING_MAX_PWM,
            HOMING_RAMP_MS,
            self.homing_ramp_start
        )

        if self.motor_lr_state == 1
            if gpio.digital_read(ENDSTOP_L)
                self.motor_lr_state = 0
                self.motor_lr(0, 0)
            else
                self.motor_lr(1, duty)
            end
        end

        if self.motor_fb_state == 2
            if gpio.digital_read(ENDSTOP_F)
                self.motor_fb_state = 0
                self.motor_fb(0, 0)
            else
                self.motor_fb(2, duty)
            end
        end
    end

    def idle_claw_safe()
        if !self.in_claw_animation
            self.motor_claw_state = 0
            self.motor_claw(0, 0)
            self.claw_relay_off()
        end
    end

    def every_50ms()
        self.update_claw_ramp()
        self.update_homing_ramp()

        self.idle_claw_safe()

        if !self.in_claw_animation && self.is_coin_inserted
            if !gpio.digital_read(JOY_L) && !gpio.digital_read(ENDSTOP_L) && self.motor_lr_state != 1
                print("left")
                self.motor_lr_state = 1
                self.motor_lr(1, PWM_MAX)

            elif !gpio.digital_read(JOY_R) && self.motor_lr_state != 2
                print("right")
                self.motor_lr_state = 2
                self.motor_lr(2, PWM_MAX)

            elif gpio.digital_read(JOY_L) && gpio.digital_read(JOY_R) && self.motor_lr_state != 0
                print("lrstop")
                self.motor_lr_state = 0
                self.motor_lr(0, 0)

            elif !gpio.digital_read(JOY_F) && self.motor_fb_state != 1
                print("forward")
                self.motor_fb_state = 1
                self.motor_fb(1, PWM_MAX)

            elif !gpio.digital_read(JOY_B) && !gpio.digital_read(ENDSTOP_F) && self.motor_fb_state != 2
                print("backwards")
                self.motor_fb_state = 2
                self.motor_fb(2, PWM_MAX)

            elif gpio.digital_read(JOY_F) && gpio.digital_read(JOY_B) && self.motor_fb_state != 0
                print("fbstop")
                self.motor_fb_state = 0
                self.motor_fb(0, 0)

            elif !gpio.digital_read(JOY_BUTTON) && (!gpio.digital_read(ENDSTOP_L) || !gpio.digital_read(ENDSTOP_F))
                self.start_claw_animation()
            end
        end

        if gpio.digital_read(ENDSTOP_L) && self.motor_lr_state == 1
            print("full left")
            self.motor_lr_state = 0
            self.motor_lr(0, 0)
        end

        if gpio.digital_read(ENDSTOP_F) && self.motor_fb_state == 2
            print("full front")
            self.motor_fb_state = 0
            self.motor_fb(0, 0)
        end

        if gpio.digital_read(ENDSTOP_CLAW) && self.motor_claw_state == 2
            print("claw top")
            self.motor_claw_state = 0
            self.motor_claw(0, 0)
        end

        if self.phase == 5 && self.motor_lr_state == 0 && self.motor_fb_state == 0
            self.drop_ball()
        end

        if self.phase == 10 && self.motor_lr_state == 0 && self.motor_fb_state == 0
            self.finish_homing_only()
        end

        if self.phase == 21 && self.motor_lr_state == 0 && self.motor_fb_state == 0
            self.fullcycle_down()
        end

        self.publish_status()
    end
end

var claw_machine_driver = ClawMachine()

tasmota.add_driver(claw_machine_driver)

tasmota.add_cmd("enable", / -> claw_machine_driver.enable_game())
tasmota.add_cmd("disable", / -> claw_machine_driver.disable_game())
tasmota.add_cmd("clawdown", / -> claw_machine_driver.claw_down_cmd())
tasmota.add_cmd("clawup", / -> claw_machine_driver.claw_up_cmd())
tasmota.add_cmd("fullcycle", / -> claw_machine_driver.fullcycle_cmd())

print("ClawMachine driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("enable - game enabled")
print("disable - disable, open claw and home every axis")
print("clawdown - claw down full speed")
print("clawup - claw up full speed")
print("fullcycle - homing, down, full up")
print("--------------------------------------------------------------")
