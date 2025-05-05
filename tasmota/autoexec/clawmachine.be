#TODO SwitchMode0 1
#TODO coin érzékelés

var in_claw_animation = false
var is_full_left = false
var is_full_front = false
var is_coin_inserted = false

function on_switch_event(event) {
    # left
    if (event.idx == 1 && !in_claw_animation && is_coin_inserted) { 
        if (event.state == 1) {
            tasmota.set_power(0, true)
            tasmota.set_power(1, false)
        } 

        #stop
        else {
            tasmota.set_power(0, false)
            tasmota.set_power(1, false)
        }
    }

    # right
    else if (event.idx == 2 && !in_claw_animation && is_coin_inserted) {
        if (event.state == 1) {
            tasmota.set_power(0, false)
            tasmota.set_power(1, true)
        } 

        #stop
        else {
            tasmota.set_power(0, false)
            tasmota.set_power(1, false)
        }
    }

    # forward
    else if (event.idx == 3 && !in_claw_animation && is_coin_inserted) {
        if (event.state == 1) {
            tasmota.set_power(2, true)
            tasmota.set_power(3, false)
        } 

        #stop
        else {
            tasmota.set_power(2, false)
            tasmota.set_power(3, false)
        }
    }

    # backwards
    else if (event.idx == 4 && !in_claw_animation && is_coin_inserted) {
        if (event.state == 1) {
            tasmota.set_power(2, false)
            tasmota.set_power(3, true)
        } 

        #stop
        else {
            tasmota.set_power(2, false)
            tasmota.set_power(3, false)
        }
    }

    # claw
    else if (event.idx == 5 && !in_claw_animation && is_coin_inserted) {
        if (event.state == 1) {
            in_claw_animation = true

            # motors stop and claw opens if wasn't
            tasmota.set_power(0, false)
            tasmota.set_power(1, false)
            tasmota.set_power(2, false)
            tasmota.set_power(3, false)
            tasmota.set_power(6, false)

            # claw goes down
            tasmota.set_power(4, false)
            tasmota.set_power(5, true)
            
            # after 3 sec claw stops
            tasmota.set_timer(3000, 
                tasmota.set_power(4, false)
                tasmota.set_power(5, false)

                # claw grips
                tasmota.set_power(6, true)
            )

            # claw goes up
            tasmota.set_timer(2000, 
                tasmota.set_power(4, true)
                tasmota.set_power(5, false)
            )
        }
    }

    # claw endstop
    else if (event.idx == 5) { 
        if (event.state == 1) {
            #claw stops
            tasmota.set_power(4, false)
            tasmota.set_power(5, false)

            #goes over the hole
            tasmota.set_power(0, true)
            tasmota.set_power(1, false)
            tasmota.set_power(2, false)
            tasmota.set_power(3, true)
        }
    }

    # left endstop
    else if (event.idx == 6) { 
        if (event.state == 1) {
            is_full_left = true

            # left stop
            tasmota.set_power(0, false)
            tasmota.set_power(1, false)
        }
        else{
            is_full_left = false
        }
    }

    # front endstop
    else if (event.idx == 7) { 
        if (event.state == 1) {
            is_full_front = true
            
            # backwards stop
            tasmota.set_power(2, false)
            tasmota.set_power(3, false)
        }
        else{
            is_full_front = false
        }
    }

    # claw over dropping hole
    if(is_full_front && is_full_left && in_claw_animation  && is_coin_inserted){

        # motor stops, claw opens
        tasmota.set_power(0, false)
        tasmota.set_power(1, false)
        tasmota.set_power(2, false)
        tasmota.set_power(3, false)
        tasmota.set_power(6, false)

        tasmota.set_timer(2000, 
            in_claw_animation = false
            && is_coin_inserted = false
        )
    }
}

event.sub("switch", on_switch_event)