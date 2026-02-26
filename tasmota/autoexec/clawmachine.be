#TODO SwitchMode0 1
#TODO coin érzékelés

var MOTOR_FB1 = 23
var MOTOR_FB2 = 22
var MOTOR_LR2 = 21
var MOTOR_LR1 = 19
var MOTOR_CLAW1 = 5
var MOTOR_CLAW2 = 2
var CLAW = 12

var JOY_L = 32 #left
var JOY_R = 33 #right
var JOY_F = 35 #forward
var JOY_B = 34 #backward
var JOY_BUTTON = 25 #claw

var ENDSTOP_L = 27 #left endstop
var ENDSTOP_F = 14 #front endstop
var ENDSTOP_CLAW = 26 #claw endstop

gpio.digital_write(MOTOR_LR1, gpio.LOW)
gpio.digital_write(MOTOR_LR2, gpio.LOW)
gpio.digital_write(MOTOR_FB1, gpio.LOW)
gpio.digital_write(MOTOR_FB2, gpio.LOW)
gpio.digital_write(MOTOR_CLAW1, gpio.LOW)
gpio.digital_write(MOTOR_CLAW2, gpio.LOW)
gpio.digital_write(CLAW, gpio.LOW)

class ClawMachineDriver
    var motor_lr_state, motor_fb_state, motor_claw_state, in_claw_animation, is_full_left, is_full_front, is_coin_inserted
    #- state
        0 - stop
        1 - left/forward/down
        2 - right/backwards/up
    -# 

    def init()
        self.motor_lr_state = 0
        self.motor_fb_state = 0
        self.motor_claw_state = 0
        self.in_claw_animation = false
        self.is_full_left = false
        self.is_full_front = false
        self.is_coin_inserted = false
    end

    def clawStopAndGrip()
        gpio.digital_write(MOTOR_CLAW1, gpio.LOW)
        gpio.digital_write(MOTOR_CLAW2, gpio.LOW)
        gpio.digital_write(CLAW, gpio.HIGH)
    end

    def clawUp()
        gpio.digital_write(MOTOR_CLAW1, gpio.HIGH)
        gpio.digital_write(MOTOR_CLAW2, gpio.LOW)
    end

    def every_100ms()
        # not in claw animation and coin was inserted
        if !self.in_claw_animation && self.is_coin_inserted
            #left
            if gpio.digital_read(JOY_L) && self.motor_lr_state != 1 
                print("left")
                self.motor_lr_state = 1
                gpio.digital_write(MOTOR_LR1, gpio.HIGH)
                gpio.digital_write(MOTOR_LR2, gpio.LOW)
            #right
            elif gpio.digital_read(JOY_R)  && self.motor_lr_state != 2
                print("right")
                self.motor_lr_state = 2
                gpio.digital_write(MOTOR_LR1, gpio.LOW)
                gpio.digital_write(MOTOR_LR2, gpio.HIGH)
            #lrstop
            elif !gpio.digital_read(JOY_L) && !gpio.digital_read(JOY_R) && self.motor_lr_state != 0
                print("lrstop")
                self.motor_lr_state = 0
                gpio.digital_write(MOTOR_LR1, gpio.LOW)
                gpio.digital_write(MOTOR_LR2, gpio.LOW)
            #forward
            elif gpio.digital_read(JOY_F) && self.motor_fb_state != 1 
                print("forward")
                self.motor_fb_state = 1
                gpio.digital_write(MOTOR_FB1, gpio.HIGH)
                gpio.digital_write(MOTOR_FB2, gpio.LOW)
            #backwards
            elif gpio.digital_read(JOY_B) && self.motor_fb_state != 2
                print("backwards")
                self.motor_fb_state = 2
                gpio.digital_write(MOTOR_FB1, gpio.LOW)
                gpio.digital_write(MOTOR_FB2, gpio.HIGH)
            #fbstop
            elif !gpio.digital_read(JOY_F) && !gpio.digital_read(JOY_B) && self.motor_fb_state != 0
                print("fbstop")
                self.motor_fb_state = 0
                gpio.digital_write(MOTOR_FB1, gpio.LOW)
                gpio.digital_write(MOTOR_FB2, gpio.LOW)
            #claw
            elif gpio.digital_read(JOY_BUTTON) && !self.in_claw_animation
                print("claw animation started")
                self.in_claw_animation = true

                # motors stop and claw opens if it wasn't
                gpio.digital_write(MOTOR_LR1, gpio.LOW)
                gpio.digital_write(MOTOR_LR2, gpio.LOW)
                gpio.digital_write(MOTOR_FB1, gpio.LOW)
                gpio.digital_write(MOTOR_FB2, gpio.LOW)
                gpio.digital_write(CLAW, gpio.LOW)

                # claw goes down
                print("claw down")
                self.motor_claw_state = 1
                gpio.digital_write(MOTOR_CLAW1, gpio.LOW)
                gpio.digital_write(MOTOR_CLAW2, gpio.HIGH)
                
                # after 3 sec claw stops, grabs
                tasmota.set_timer(3000,self.clawStopAndGrip)

                # claw goes up
                tasmota.set_timer(5000,self.clawUp)
            end
        end

        #claw is up
        if gpio.digital_read(ENDSTOP_CLAW) && self.motor_claw_state == 2 && self.in_claw_animation
            print("claw stop up")
            
            #claw stops
            self.motor_claw_state = 0
            gpio.digital_write(MOTOR_CLAW1, gpio.LOW)
            gpio.digital_write(MOTOR_CLAW2, gpio.LOW)

            #goes over the hole
            print("claw goes to the hole")
            self.motor_lr_state = 1
            gpio.digital_write(MOTOR_LR1, gpio.HIGH)
            gpio.digital_write(MOTOR_LR2, gpio.LOW)

            self.motor_fb_state = 2
            gpio.digital_write(MOTOR_FB1, gpio.LOW)
            gpio.digital_write(MOTOR_FB2, gpio.HIGH)
        end

        #left endstop
        if gpio.digital_read(ENDSTOP_L) && self.motor_lr_state == 1
            print("full left")
            self.motor_lr_state = 0

            # left stop
            gpio.digital_write(MOTOR_LR1, gpio.LOW)
            gpio.digital_write(MOTOR_LR2, gpio.LOW)
        end

        #front endstop
        if gpio.digital_read(ENDSTOP_F) && self.motor_fb_state == 1
            print("full front")
            self.motor_fb_state = 0

            # front stop
            gpio.digital_write(MOTOR_FB1, gpio.LOW)
            gpio.digital_write(MOTOR_FB2, gpio.LOW)
        end

        # claw over dropping hole
        if gpio.digital_read(ENDSTOP_F) && gpio.digital_read(ENDSTOP_L) && self.in_claw_animation

            print("claw over dropping hole")
            # motor stops, claw opens
            gpio.digital_write(MOTOR_LR1, gpio.LOW)
            gpio.digital_write(MOTOR_LR2, gpio.LOW)
            gpio.digital_write(MOTOR_FB1, gpio.LOW)
            gpio.digital_write(MOTOR_FB2, gpio.LOW)
            gpio.digital_write(CLAW, gpio.LOW)

            print("claw animation finished")
            self.in_claw_animation = false
            self.is_coin_inserted = false
        end
    end
end
  
d1 = ClawMachineDriver()

tasmota.add_driver(d1)

