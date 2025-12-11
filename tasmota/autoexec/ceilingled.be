#releket configolni kell, switcheket switch_d-re kell configolni

import mqtt

def pwm_switcher(pwm_number, state)
    if pwm_number > 9 || pwm_number < 0 || state < 0 || state > 1
        return
    else
        tasmota.cmd("PWM" .. pwm_number .. " " .. state * 1023)
    end
end

def runing_animation(number_of_rounds)
    for i: 1 .. 9
        pwm_switcher(i,0)   
    end
    
    for i: 1 .. 9
        def t1() 
            pwm_switcher(i,1)
            pwm_switcher(i-1,0) 
        end
        tasmota.set_timer(250*i, t1)
    end
    tasmota.cmd("PWM" .. )
end

tasmota.add_cmd("UpdateScripts", autoload_module.update_scripts)

print ("Ceiling led driver loaded")