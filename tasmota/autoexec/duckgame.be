#
# duck_game.be — Berry script Tasmota ESP32-n
#

# Globális változók
var cycle_count = 0
var going_up = true
var max_cycles = 10

# --- Inicializálás indításkor ---
def init()
    # Alapkonfigurációk
    send("SetOption80 1")
    send("Shuttermode 5")
    send("PWMfrequency 200")
    send("SetOption15 0")

    send("ShutterPwmRange1 100,500")
    send("ShutterOpenDuration1 1")
    send("ShutterCloseDuration1 1")
    send("ShutterMotorDelay1 0.2")

    # Regisztráljuk, hogy reagáljunk a belső redőny eseményekre
    # „shutter#position” esemény: minden pozícióváltozásnál fut
    event.on("shutter1#position", on_position_change)
    # (lehet használni shutter1#moved is, hogy a mozgás végén reagálj)
    event.on("shutter1#moved", on_movement_end)
end

# --- Callback: pozícióváltozás történt ---
def on_position_change(pos)
    # pos értéke szám (0..100)
    var p = pos
    # Ha most felfelé megyünk és elértük vagy meghaladtuk 100-at
    if going_up and p >= 100
        # Azonnal parancs visszafelé
        send("ShutterPosition1 40")
        going_up = false
        cycle_count = cycle_count + 1
    end
    # Ha visszafelé megyünk és elértük vagy alá mentünk 40-es szintet
    if (not going_up) and p <= 40
        if cycle_count < max_cycles
            send("ShutterPosition1 100")
            going_up = true
        end
    end
end

# --- Callback: mozgás befejeződött (elmozdulás vége) ---
def on_movement_end()
    # Lehet használni ha akarsz valamit a mozgás végén, de nem kötelező
    # (Pl. kikapcsolod a PWM-et, ha nem akarod, hogy “tartsa”)
    # Itt nincs szükség feltétlenül semmire
    nil
end

# --- MQTT üzenet kezelése (csak a START parancs) ---
def on_mqtt(topic, payload)
    # Feltételezzük, hogy a START üzenet topicja pl. „cmnd/tasmota_A503DC/START” vagy amit beállítottál
    if payload == "START"
        # indítsuk el az első mozgást
        send("ShutterPosition1 100")
        going_up = true
        cycle_count = 0
    end
end

# Esemény regisztráció indításkor
mqtt.on("cmnd/tasmota_A503DC/START", on_mqtt)

# Amikor a script elindul, hívjuk meg az initet
init()