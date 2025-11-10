#TODO SwitchMode0 1
#TODO coin érzékelés

var MOTOR_LR1 = 23
var MOTOR_LR2 = 22
var MOTOR_FB1 = 21
var MOTOR_FB2 = 19
var MOTOR_CLAW1 = 5
var MOTOR_CLAW2 = 2
var CLAW = 12

var JOY_L = 34
var JOY_R = 35
var JOY_F = 32
var JOY_B = 33
var JOY_BUTTON = 25

var ENDSTOP_L = 26
var ENDSTOP_F = 27
var ENDSTOP_CLAW = 14 

var in_claw_animation = false
var is_full_left = false
var is_full_front = false
var is_coin_inserted = false

#- state
    0 - stop
    1 - left/forward/down
    2 - right/backwards/up
-#

var motor_lr_state = 0
var motor_fb_state = 0
var motor_claw_state = 0

gpio.digital_write(MOTOR_LR1, false)
gpio.digital_write(MOTOR_LR2, false)
gpio.digital_write(MOTOR_FB1, false)
gpio.digital_write(MOTOR_FB2, false)
gpio.digital_write(MOTOR_CLAW1, false)
gpio.digital_write(MOTOR_CLAW2, false)
gpio.digital_write(CLAW, false)

def clawmachine_init()
    in_claw_animation = false
    is_full_left = false
    is_full_front = false
    is_coin_inserted = false

    gpio.digital_write(MOTOR_LR1, false)
    gpio.digital_write(MOTOR_LR2, false)
    gpio.digital_write(MOTOR_FB1, false)
    gpio.digital_write(MOTOR_FB2, false)
    gpio.digital_write(MOTOR_CLAW1, false)
    gpio.digital_write(MOTOR_CLAW2, false)
    gpio.digital_write(CLAW, false)

    tasmota.resp_cmnd("Clawmachine init")
end

def clawmachine_enable()
    is_coin_inserted = true
    tasmota.resp_cmnd("Clawmachine enabled")
end

def clawStopAndGrip()
    print("claw stop down")
    motor_claw_state = 0
    gpio.digital_write(MOTOR_CLAW1, false)
    gpio.digital_write(MOTOR_CLAW2, false)

    # claw grips
    print("claw grip")
    gpio.digital_write(CLAW, true)
end

def clawUp()
    print("claw up")
    motor_claw_state = 2
    gpio.digital_write(MOTOR_CLAW1, true)
    gpio.digital_write(MOTOR_CLAW2, false)
end

tasmota.add_cmd("ClawMachineInit", clawmachine_init)
tasmota.add_cmd("ClawMachineEnable", clawmachine_enable)

class ClawMachineDriver
    def every_100ms()
      # not in claw animation and coin was inserted
        if !in_claw_animation && is_coin_inserted
            #left
            if gpio.digital_read(JOY_L) && motor_lr_state != 1 
                print("left")
                motor_lr_state = 1
                gpio.digital_write(MOTOR_LR1, true)
                gpio.digital_write(MOTOR_LR2, false)
            #right
            elif gpio.digital_read(JOY_R)  && motor_lr_state != 2
                print("right")
                motor_lr_state = 2
                gpio.digital_write(MOTOR_LR1, false)
                gpio.digital_write(MOTOR_LR2, true)
            #lrstop
            elif !gpio.digital_read(JOY_L) && !gpio.digital_read(JOY_R) && motor_lr_state != 0
                print("lrstop")
                motor_lr_state = 0
                gpio.digital_write(MOTOR_LR1, false)
                gpio.digital_write(MOTOR_LR2, false)
            #forward
            elif gpio.digital_read(JOY_F) && motor_fb_state != 1 
                print("forward")
                motor_fb_state = 1
                gpio.digital_write(MOTOR_FB1, true)
                gpio.digital_write(MOTOR_FB2, false)
            #backwards
            elif gpio.digital_read(JOY_B) && motor_fb_state != 2
                print("backwards")
                motor_fb_state = 2
                gpio.digital_write(MOTOR_FB1, false)
                gpio.digital_write(MOTOR_FB2, true)
            #fbstop
            elif !gpio.digital_read(JOY_F) && !gpio.digital_read(JOY_B) && motor_fb_state != 0
                print("fbstop")
                motor_fb_state = 0
                gpio.digital_write(MOTOR_FB1, false)
                gpio.digital_write(MOTOR_FB2, false)
            #claw
            elif gpio.digital_read(JOY_BUTTON)
                print("claw animation started")
                in_claw_animation = true

                # motors stop and claw opens if wasn't
                gpio.digital_write(MOTOR_LR1, false)
                gpio.digital_write(MOTOR_LR2, false)
                gpio.digital_write(MOTOR_FB1, false)
                gpio.digital_write(MOTOR_FB2, false)
                gpio.digital_write(CLAW, false)

                # claw goes down
                print("claw down")
                motor_claw_state = 1
                gpio.digital_write(MOTOR_CLAW1, false)
                gpio.digital_write(MOTOR_CLAW2, true)
                
                # after 3 sec claw stops
                tasmota.set_timer(3000,clawStopAndGrip)

                # claw goes up
                tasmota.set_timer(5000,clawUp)
            end
        end

        #claw is up
        if gpio.digital_read(ENDSTOP_CLAW) && motor_claw_state == 2 && in_claw_animation
            print("claw stop up")
            
            #claw stops
            motor_claw_state = 0
            gpio.digital_write(MOTOR_CLAW1, false)
            gpio.digital_write(MOTOR_CLAW2, false)

            #goes over the hole
            print("claw goes to the hole")
            motor_lr_state = 1
            gpio.digital_write(MOTOR_LR1, true)
            gpio.digital_write(MOTOR_LR2, false)

            motor_fb_state = 2
            gpio.digital_write(MOTOR_FB1, false)
            gpio.digital_write(MOTOR_FB2, true)
        end

        #left endstop
        if gpio.digital_read(ENDSTOP_L) && is_full_left && motor_lr_state == 1
            print("full left")
            is_full_left = true
            motor_lr_state = 0

            # left stop
            gpio.digital_write(MOTOR_LR1, false)
            gpio.digital_write(MOTOR_LR2, false)
        else
            is_full_left = false
        end

        #front endstop
        if gpio.digital_read(ENDSTOP_F) && is_full_front && motor_fb_state == 1
            print("full front")
            is_full_front = true
            motor_fb_state = 0

            # front stop
            gpio.digital_write(MOTOR_FB1, false)
            gpio.digital_write(MOTOR_FB2, false)
        else
            is_full_front = false
        end

        # claw over dropping hole
        if is_full_left && is_full_front && in_claw_animation

            print("claw over dropping hole")
            # motor stops, claw opens
            gpio.digital_write(MOTOR_LR1, false)
            gpio.digital_write(MOTOR_LR2, false)
            gpio.digital_write(MOTOR_FB1, false)
            gpio.digital_write(MOTOR_FB2, false)
            gpio.digital_write(CLAW, false)

            print("claw animation finished")
            in_claw_animation = false
            is_coin_inserted = false
        end
    end
end
  
d1 = ClawMachineDriver()

tasmota.add_driver(d1)