#TODO SwitchMode0 1
#TODO coin érzékelés

var MOTOR_LR1 = 0
var MOTOR_LR2 = 1
var MOTOR_FB1 = 2
var MOTOR_FB2 = 3
var MOTOR_CLAW1 = 4
var MOTOR_CLAW2 = 5
var CLAW = 6

var JOY_L = 21
var JOY_R = 22
var JOY_F = 23
var JOY_B = 25
var JOY_BUTTON = 26

var ENDSTOP_L = 27
var ENDSTOP_F = 32
var ENDSTOP_CLAW = 33

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

tasmota.set_power(MOTOR_LR1, false)
tasmota.set_power(MOTOR_LR2, false)
tasmota.set_power(MOTOR_FB1, false)
tasmota.set_power(MOTOR_FB2, false)
tasmota.set_power(MOTOR_CLAW1, false)
tasmota.set_power(MOTOR_CLAW2, false)
tasmota.set_power(CLAW, false)

def clawmachine_init()
    in_claw_animation = false
    is_full_left = false
    is_full_front = false
    is_coin_inserted = false

    tasmota.set_power(MOTOR_LR1, false)
    tasmota.set_power(MOTOR_LR2, false)
    tasmota.set_power(MOTOR_FB1, false)
    tasmota.set_power(MOTOR_FB2, false)
    tasmota.set_power(MOTOR_CLAW1, false)
    tasmota.set_power(MOTOR_CLAW2, false)
    tasmota.set_power(CLAW, false)

    tasmota.resp_cmnd("Clawmachine init")
end

def clawmachine_enable()
    is_coin_inserted = true
    tasmota.resp_cmnd("Clawmachine enabled")
end

def clawStopAndGrip()
    print("claw stop down")
    motor_claw_state = 0
    tasmota.set_power(MOTOR_CLAW1, false)
    tasmota.set_power(MOTOR_CLAW2, false)

    # claw grips
    print("claw grip")
    tasmota.set_power(CLAW, true)
end

def clawUp()
    print("claw up")
    motor_claw_state = 2
    tasmota.set_power(MOTOR_CLAW1, true)
    tasmota.set_power(MOTOR_CLAW2, false)
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
                tasmota.set_power(MOTOR_LR1, true)
                tasmota.set_power(MOTOR_LR2, false)
            #right
            elif gpio.digital_read(JOY_R)  && motor_lr_state != 2
                print("right")
                motor_lr_state = 2
                tasmota.set_power(MOTOR_LR1, false)
                tasmota.set_power(MOTOR_LR2, true)
            #lrstop
            elif !gpio.digital_read(JOY_L) && !gpio.digital_read(JOY_R) && motor_lr_state != 0
                print("lrstop")
                motor_lr_state = 0
                tasmota.set_power(MOTOR_LR1, false)
                tasmota.set_power(MOTOR_LR2, false)
            #forward
            elif gpio.digital_read(JOY_F) && motor_fb_state != 1 
                print("forward")
                motor_fb_state = 1
                tasmota.set_power(MOTOR_FB1, true)
                tasmota.set_power(MOTOR_FB2, false)
            #backwards
            elif gpio.digital_read(JOY_B) && motor_fb_state != 2
                print("backwards")
                motor_fb_state = 2
                tasmota.set_power(MOTOR_FB1, false)
                tasmota.set_power(MOTOR_FB2, true)
            #fbstop
            elif !gpio.digital_read(JOY_F) && !gpio.digital_read(JOY_B) && motor_fb_state != 0
                print("fbstop")
                motor_fb_state = 0
                tasmota.set_power(MOTOR_FB1, false)
                tasmota.set_power(MOTOR_FB2, false)
            #claw
            elif gpio.digital_read(JOY_BUTTON)
                print("claw animation started")
                in_claw_animation = true

                # motors stop and claw opens if wasn't
                tasmota.set_power(MOTOR_LR1, false)
                tasmota.set_power(MOTOR_LR2, false)
                tasmota.set_power(MOTOR_FB1, false)
                tasmota.set_power(MOTOR_FB2, false)
                tasmota.set_power(CLAW, false)

                # claw goes down
                print("claw down")
                motor_claw_state = 1
                tasmota.set_power(MOTOR_CLAW1, false)
                tasmota.set_power(MOTOR_CLAW2, true)
                
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
            tasmota.set_power(MOTOR_CLAW1, false)
            tasmota.set_power(MOTOR_CLAW2, false)

            #goes over the hole
            print("claw goes to the hole")
            motor_lr_state = 1
            tasmota.set_power(MOTOR_LR1, true)
            tasmota.set_power(MOTOR_LR2, false)

            motor_fb_state = 2
            tasmota.set_power(MOTOR_FB1, false)
            tasmota.set_power(MOTOR_FB2, true)
        end

        #left endstop
        if gpio.digital_read(ENDSTOP_L)
            print("full left")
            is_full_left = true
            motor_lr_state = 0

            # left stop
            tasmota.set_power(MOTOR_LR1, false)
            tasmota.set_power(MOTOR_LR2, false)
        else
            is_full_left = false
        end

        #front endstop
        if gpio.digital_read(ENDSTOP_F)
            print("full front")
            is_full_front = true
            motor_fb_state = 0

            # front stop
            tasmota.set_power(MOTOR_FB1, false)
            tasmota.set_power(MOTOR_FB2, false)
        else
            is_full_front = false
        end

        # claw over dropping hole
        if is_full_left && is_full_front && in_claw_animation

            print("claw over dropping hole")
            # motor stops, claw opens
            tasmota.set_power(MOTOR_LR1, false)
            tasmota.set_power(MOTOR_LR2, false)
            tasmota.set_power(MOTOR_FB1, false)
            tasmota.set_power(MOTOR_FB2, false)
            tasmota.set_power(CLAW, false)

            print("claw animation finished")
            in_claw_animation = false
            is_coin_inserted = false
        end
    end
end
  
d1 = ClawMachineDriver()

tasmota.add_driver(d1)