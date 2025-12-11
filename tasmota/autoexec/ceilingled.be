#releket configolni kell, switcheket switch_d-re kell configolni

import mqtt

def pwm_switcher(pwm_number, state)
    if pwm_number > 9 || pwm_number < 0 || state < 0 || state > 1
        return
    else
        tasmota.cmd("PWM" .. pwm_number .. " " .. state * 1023)
    end
end

def runing_animation(cmd, idx, payload, payload_json)
    for i: 1 .. 9
        pwm_switcher(i,0)   
    end

    for i: 1 .. payload
        for i: 1 .. 9
        def t1() 
            pwm_switcher(i,1)
            pwm_switcher(i-1,0) 
        end
        tasmota.set_timer(250*i, t1)
    end
    end

end

tasmota.add_cmd('runinganimation', /cmd, idx, payload, payload_json->runing_animation(cmd, idx, payload, payload_json))

print ("Ceiling led driver loaded")