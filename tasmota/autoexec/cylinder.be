import math

var IN1 = 14
var IN2 = 13
var IN3 = 23
var IN4 = 21

var LAOUT = 26
var LAIN = 27

var homing_steps = 500
var speed = 1000

#absolute positions
var pos1 = 1000
var pos2 = 2000
var pos3 = 3000
var pos4 = 4000

class CylinderDriver
    var actual_position

    def init()
        self.actual_position = 0
    end

    def loop()
        
    end

    def lock(cmd,idx)
        gpio.digital_write(LAIN, gpio.LOW)
        gpio.digital_write(LAOUT, gpio.HIGH)

        tasmota.set_timer(5000, / ->
            gpio.digital_write(LAOUT, gpio.LOW)
        )
        tasmota.resp_cmnd("Cylinder locked")
    end

    def unlock(cmd,idx) #blokkolni kell hogy teljes nyitásig ne mozogjon el
        gpio.digital_write(LAOUT, gpio.LOW)
        gpio.digital_write(LAIN, gpio.HIGH)
        tasmota.delay(5000) 
        gpio.digital_write(LAIN, gpio.LOW)
        tasmota.resp_cmnd("Cylinder unlocked")
    end

    def home(cmd, idx)
        if !gpio.digital_read(IN4)
            self.unlock()

            while !gpio.digital_read(IN4)
                tasmota.cmd("motormove " .. homing_steps);
                tasmota.delay((speed / homing_steps ) + 20)
            end

            self.actual_position = 0   
        end

        self.lock()
        tasmota.resp_cmnd("Homing done")
    end

    def set_pos(cmd, i, position)
        if position == 1
            self.unlock()
            tasmota.cmd("motorMove " .. pos1 - self.actual_position);
            tasmota.set_timer(math.abs(number(pos1 - self.actual_position)), / ->
                self.lock()
            )   
            self.actual_position = pos1
        elif position == 2
            self.unlock()
            tasmota.cmd("motorMove " .. pos2 - self.actual_position);
            tasmota.set_timer(math.abs(pos2 - self.actual_position), / ->
                self.lock()
            )
            self.actual_position = pos2

        elif position == 3
            self.unlock()
            tasmota.cmd("motorMove " .. pos3 - self.actual_position);
            tasmota.set_timer(math.abs(pos3 - self.actual_position), / ->
                self.lock()
            )
            self.actual_position = pos3

        elif position == 4
            self.unlock()
            tasmota.cmd("motorMove " .. pos4 - self.actual_position);
            tasmota.set_timer(math.abs(pos4 - self.actual_position), / ->
                self.lock()
            )
            self.actual_position = pos4
        else
            tasmota.resp_cmnd("Bad argument:" .. position)
            return
        end

        tasmota.resp_cmnd("Cylinder set to pos" .. position .. ", actual position:" .. self.actual_position)
    end
end
  
var cylinderdriver = CylinderDriver()

tasmota.add_driver(cylinderdriver)

tasmota.add_cmd("lock", /cmd, idx-> cylinderdriver.lock(cmd, idx))
tasmota.add_cmd("unlock", /cmd, idx-> cylinderdriver.unlock(cmd, idx))
tasmota.add_cmd("home", /cmd, idx-> cylinderdriver.home(cmd, idx))
tasmota.add_cmd("pos", /cmd, i, position -> cylinderdriver.set_pos(cmd, i, number(position)))

tasmota.cmd("MotorRPM " .. speed);

print("Cylinder driver loaded")
print("Commands:")
print("lock - locks the cylinder in place")
print("unlock - unlocks the cylinder")
print("home - start homing")
print("pos <n> - goes to the given position")