#TODO SwitchMode0 1
#TODO coin érzékelés

var MOTOR_LR1 = 0
var MOTOR_LR2 = 1
var MOTOR_FB1 = 2
var MOTOR_FB2 = 3
var MOTOR_CLAW1 = 4
var MOTOR_CLAW2 = 5
var CLAW = 6

var JOY_L = 1
var JOY_R = 2
var JOY_F = 3
var JOY_B = 4
var JOY_BUTTON = 5

var ENDSTOP_L = 6
var ENDSTOP_F = 7
var ENDSTOP_CLAW = 8

var in_claw_animation = false
var is_full_left = false
var is_full_front = false
var is_coin_inserted = false

function on_switch_event(event) {
    # left
    if (event.idx == JOY_L && !in_claw_animation && is_coin_inserted) { 
        if (event.state == 1) {
            tasmota.set_power(MOTOR_LR1, true)
            tasmota.set_power(MOTOR_LR2, false)
        } 

        #stop
        else {
            tasmota.set_power(MOTOR_LR1, false)
            tasmota.set_power(MOTOR_LR2, false)
        }
    }

    # right
    else if (event.idx == JOY_R && !in_claw_animation && is_coin_inserted) {
        if (event.state == 1) {
            tasmota.set_power(MOTOR_LR1, false)
            tasmota.set_power(MOTOR_LR2, true)
        } 

        #stop
        else {
            tasmota.set_power(MOTOR_LR1, false)
            tasmota.set_power(MOTOR_LR2, false)
        }
    }

    # forward
    else if (event.idx == JOY_F && !in_claw_animation && is_coin_inserted) {
        if (event.state == 1) {
            tasmota.set_power(MOTOR_FB1, true)
            tasmota.set_power(MOTOR_FB2, false)
        } 

        #stop
        else {
            tasmota.set_power(MOTOR_FB1, false)
            tasmota.set_power(MOTOR_FB2, false)
        }
    }

    # backwards
    else if (event.idx == JOY_B && !in_claw_animation && is_coin_inserted) {
        if (event.state == 1) {
            tasmota.set_power(MOTOR_FB1, false)
            tasmota.set_power(MOTOR_FB2, true)
        } 

        #stop
        else {
            tasmota.set_power(MOTOR_FB1, false)
            tasmota.set_power(MOTOR_FB2, false)
        }
    }

    # claw
    else if (event.idx == JOY_BUTTON && !in_claw_animation && is_coin_inserted) {
        if (event.state == 1) {
            in_claw_animation = true

            # motors stop and claw opens if wasn't
            tasmota.set_power(MOTOR_LR1, false)
            tasmota.set_power(MOTOR_LR2, false)
            tasmota.set_power(MOTOR_FB1, false)
            tasmota.set_power(MOTOR_FB2, false)
            tasmota.set_power(CLAW, false)

            # claw goes down
            tasmota.set_power(MOTOR_CLAW1, false)
            tasmota.set_power(MOTOR_CLAW2, true)
            
            # after 3 sec claw stops
            tasmota.set_timer(3000, 
                tasmota.set_power(MOTOR_CLAW1, false)
                tasmota.set_power(MOTOR_CLAW2, false)

                # claw grips
                tasmota.set_power(CLAW, true)
            )

            # claw goes up
            tasmota.set_timer(2000, 
                tasmota.set_power(MOTOR_CLAW1, true)
                tasmota.set_power(MOTOR_CLAW2, false)
            )
        }
    }

    # claw endstop
    else if (event.idx == ENDSTOP_CLAW) { 
        if (event.state == 1) {
            #claw stops
            tasmota.set_power(MOTOR_CLAW1, false)
            tasmota.set_power(MOTOR_CLAW2, false)

            #goes over the hole
            tasmota.set_power(MOTOR_LR1, true)
            tasmota.set_power(MOTOR_LR2, false)
            tasmota.set_power(MOTOR_FB1, false)
            tasmota.set_power(MOTOR_FB2, true)
        }
    }

    # left endstop
    else if (event.idx == ENDSTOP_L) { 
        if (event.state == 1) {
            is_full_left = true

            # left stop
            tasmota.set_power(MOTOR_LR1, false)
            tasmota.set_power(MOTOR_LR2, false)
        }
        else{
            is_full_left = false
        }
    }

    # front endstop
    else if (event.idx == ENDSTOP_F) { 
        if (event.state == 1) {
            is_full_front = true
            
            # backwards stop
            tasmota.set_power(MOTOR_FB1, false)
            tasmota.set_power(MOTOR_FB2, false)
        }
        else{
            is_full_front = false
        }
    }

    # claw over dropping hole
    if(is_full_front && is_full_left && in_claw_animation && is_coin_inserted){

        # motor stops, claw opens
        tasmota.set_power(MOTOR_LR1, false)
        tasmota.set_power(MOTOR_LR2, false)
        tasmota.set_power(MOTOR_FB1, false)
        tasmota.set_power(MOTOR_FB2, false)
        tasmota.set_power(CLAW, false)

        tasmota.set_timer(2000, 
            in_claw_animation = false
            && is_coin_inserted = false
        )
    }
}

event.sub("switch", on_switch_event)