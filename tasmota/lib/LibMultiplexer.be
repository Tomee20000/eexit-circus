class Multiplexer
    var values, old_values, mapped_values, analog_map, character_map
    var address_pins, common_pin
    var tolerance
    var topic, log_level

    # Distributed iteration globals. 
    var mux_iteration_counter, is_mux_dirty, output_string

    def init()
        self.values  = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
        self.old_values  = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
        self.mapped_values  = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
        self.analog_map = [
            [176, 407, 1],
            [408, 638, 2],
            [639, 870, 3],
            [871, 1102, 4],
            [1103, 1333, 5],
            [1334, 1565, 6],
            [1566, 1796, 7],
            [1797, 2028, 8],
            [2029, 2260, 9],
            [2261, 2491, 10],
            [2492, 2723, 11],
            [2724, 2955, 12],
            [2956, 3186, 13],
            [3187, 3418, 14],
            [3419, 3649, 15],
            [3650, 4092, 0],
            # [3650, 3881, 0],
            # [3882, 4092, 0],
        ]
        self.address_pins = [-1,-1,-1,-1]
        self.tolerance = 0
        self.mux_iteration_counter = 0
        self.is_mux_dirty = false
        self.output_string = ""
    end

    def set_topic(topic)
        self.topic = topic
    end

    def set_character_map (character_map)
        self.character_map = character_map
    end


    def set_common_analog_input_pin(pin_common_adc)
        import string
        var gpio_config = tasmota.cmd("GPIO")
        if (!gpio_config[string.format("GPIO%i",pin_common_adc)].contains("4704"))
            tasmota.cmd(string.format("GPIO%i 4704", pin_common_adc))
        end
    end

    def set_address_pins(a0, a1, a2, a3)
        self.address_pins = [a0, a1, a2, a3]
        for i: 0 .. 3
            gpio.pin_mode(self.address_pins[i], gpio.OUTPUT)
        end
    end

    def set_tolerance(tolerance)
        self.tolerance = tolerance
    end

    def write_out_address (address)
        for i: 0 .. 3
            var bit = (address >> i) & 0x01
            gpio.digital_write(self.address_pins[i], bit)
        end
    end

    def map_raw_value(raw_value)
        for range: self.analog_map
            log(range)
            var from = range[0]
            var to = range[1]
            var value = range[2]
            if (raw_value >= from && raw_value <= to)
                return value
            end
        end
        return -1
    end


    def read()
        import json
        import math
        import string
        # Distributed iteration of 15 letters. Runs every 100ms
        var address = self.mux_iteration_counter
        
        self.write_out_address(address)
        self.values[address] = json.load(tasmota.read_sensors())["ANALOG"]["A1"]
        self.mapped_values[address] = self.map_raw_value(self.values[address])
        
        self.output_string += self.character_map[self.mapped_values[address]]

        if (math.abs(self.values[address] - self.old_values[address]) > self.tolerance)
            self.is_mux_dirty = true
        end
        # end
        if (self.mux_iteration_counter == 14)
            
            var return_values = {
                "is_dirty":self.is_mux_dirty,
                "analog_value": self.values,
                "mapped_values": self.mapped_values,
                "mapped_string": self.output_string
            }
            
            for i: 0 .. 14
                self.old_values[i] = self.values[i]
            end

            log(return_values, 4)
            self.mux_iteration_counter = 0
            self.is_mux_dirty = false
            self.output_string = ""
            return return_values
        end
        self.mux_iteration_counter += 1
        return false
    end

    def every_100ms()
        var mux_data = self.read()
        
        if (mux_data != false)
            import json
            import mqtt
            if (mux_data["is_dirty"])
                mqtt.publish("tele/" + self.topic +"/MUX", json.dump(mux_data))
            end
        end

    end
end
