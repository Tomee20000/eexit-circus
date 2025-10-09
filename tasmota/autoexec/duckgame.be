#
# duck_game.be — Berry script Tasmota ESP32-n, indítás parancsra (nem “mqtt.on”)
#

# Globális változók
var cycle_count = 0
var going_up = true
var max_cycles = 10

# --- Inicializálás indításkor (betöltéskor) ---
def init()
    # Alapkonfigurációk, mindig beállítjuk indításkor
    send("SetOption80 1")
    send("Shuttermode 5")
    send("PWMfrequency 200")
    send("SetOption15 0")

    send("ShutterPwmRange1 100,500")
    send("ShutterOpenDuration1 1")
    send("ShutterCloseDuration1 1")
    send("ShutterMotorDelay1 0.2")

    # Regisztráljuk eseménykezelőre a belső pozícióváltozás eseményt
    event.on("shutter1#position", on_position_change)

    # Regisztráljuk a custom parancsot: “DUCKSTART”
    # amikor kiadod console-ból: DUCKSTART
    # akkor meghívódik a funkció start_game()
    tasmota.add_cmd("DUCKSTART", start_game)
end

# --- A parancs hatására elindul (nem MQTT callback) ---
def start_game(args)
    # („args” lehet parancs argumentum, itt nem használjuk)
    cycle_count = 0
    going_up = true
    # Indító mozgás
    send("ShutterPosition1 100")
end

# --- Callback: pozícióváltozás történt ---
def on_position_change(pos)
    # pos értéke 0..100 (szám)
    var p = pos
    # Ha felfelé tartunk, és elértük vagy meghaladtuk 100-at
    if going_up and p >= 100
        send("ShutterPosition1 40")
        going_up = false
        cycle_count = cycle_count + 1
    end
    # Ha visszafelé tartunk és elértük vagy alá mentünk 40-es szintet
    if (not going_up) and p <= 40
        if cycle_count < max_cycles
            send("ShutterPosition1 100")
            going_up = true
        end
    end
end

# --- Betöltéskor futtatjuk az initet ---
init()
