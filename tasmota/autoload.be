var autoload = module("autoload")

autoload.inited = false

autoload.folders = [
    "/lib",
    "/autoexec",
]

autoload.base_files = [
    "/autoexec.be",
    "/preinit.be",
    "/autoload.be",
]

autoload.autoload_files_for_topic = {
    "CCLAWMACHINE1":"/autoexec/clawmachine.be",
    "CCASHREGISTER":"/autoexec/cashregister.be",
    "CDUCKGAME":"/autoexec/duckgame.be",
    "CCEILINGLED":"/autoexec/ceilingled.be",
    "CSIGN":"/autoexec/sign.be",
    "CANIMALWHEEL":"/autoexec/animalwheel.be",
    "CCYLINDER":"/autoexec/cylinder.be",
    "CKNIFEGAME":"/autoexec/knifegame.be",
    "CELEPHANT":"/autoexec/elephant.be",
    "CHANDGAME1":"/autoexec/handgame1.be",
    "CHANDGAME2":"/autoexec/handgame.be",
    "CHANDGAME3":"/autoexec/handgame.be",
    "CHANDGAME4":"/autoexec/handgame.be",
    "CBALLGAME1":"/autoexec/ballgame.be",
    "CBALLGAME2":"/autoexec/ballgame.be",
    "CBALLGAME3":"/autoexec/ballgame.be",
    "CBALLGAME4":"/autoexec/ballgame.be",
    "CBALLGAME5":"/autoexec/ballgame.be",
    "CBALLGAME6":"/autoexec/ballgame.be",
    "CSAWBOX":"/autoexec/sawbox.be",
    "CCLOWNGAME":"/autoexec/clowngame.be",
    "CLASERGUN":"/autoexec/lasergun.be",
    "CSERVICE3":"/autoexec/bicycle.be",
    "CCAROUSEL":"/autoexec/carousel.be",
}

autoload.extra_files_for_script = {
    "/autoexec/handgame.be":["/lib/LibHandReader.be"],
    "/autoexec/handgame1.be":["/lib/LibHandReader.be"],
}

autoload.game_files = [
    "/autoexec/clawmachine.be",
    "/autoexec/cashregister.be",
    "/autoexec/ceilingled.be",
    "/autoexec/duckgame.be",
    "/autoexec/sign.be",
    "/autoexec/animalwheel.be",
    "/autoexec/cylinder.be",
    "/autoexec/knifegame.be",
    "/autoexec/elephant.be",
    "/autoexec/handgame.be",
    "/autoexec/handgame1.be",
    "/autoexec/sawbox.be",
    "/autoexec/ballgame.be",
    "/autoexec/clowngame.be",
    "/autoexec/lasergun.be",
    "/autoexec/bicycle.be",
    "/autoexec/carousel.be",
]

autoload.lib_files = [
    "/lib/LibHandReader.be",
]

autoload.fetch_url = "https://raw.githubusercontent.com/tomee20000/eexit-circus/refs/heads/main/tasmota"

autoload.topic = def ()
    return tasmota.cmd("Topic")["Topic"]
end

autoload.file_for_topic = def (topic)
    var result = nil
    try
        result = autoload.autoload_files_for_topic[topic]
    except .. as e, m
        result = nil
    end
    return result
end

autoload.extra_files_for = def (script_file)
    var result = []
    try
        result = autoload.extra_files_for_script[script_file]
    except .. as e, m
        result = []
    end
    return result
end

autoload.is_in_items = def (needle, items)
    for item: items
        if item == needle
            return true
        end
    end
    return false
end

autoload.unique_items = def (items)
    var result = []
    for item: items
        if !autoload.is_in_items(item, result)
            result = result + [item]
        end
    end
    return result
end

autoload.files_for_topic = def (topic)
    var script_file = autoload.file_for_topic(topic)
    if script_file == nil
        return nil
    end

    var files = autoload.base_files + [script_file] + autoload.extra_files_for(script_file)
    return autoload.unique_items(files)
end

autoload.managed_files = def ()
    return autoload.unique_items(autoload.game_files + autoload.lib_files)
end

autoload.init = def ()
    if autoload.inited
        return
    end

    autoload.inited = true
    tasmota.add_cmd("UpdateScripts", autoload.update_scripts)
    tasmota.add_cmd("PurgeScripts", autoload.purge_scripts)
    tasmota.add_cmd("Purge", autoload.purge_scripts)

    var topic = autoload.topic()
    var files = autoload.files_for_topic(topic)
    if files == nil
        import string
        print(string.format("No script mapping for topic: %s", topic))
        return
    end

    for f: files
        if autoload.is_in_items(f, autoload.lib_files)
            import string
            var is_loaded = load(f)
            var message
            if !is_loaded
                message = "%s is not present!"
            else
                message = "%s is loaded."
            end
            print(string.format(message, f))
        end
    end
end

autoload.fetch = def (url, filepath)
    import string
    try
        var file_size = tasmota.urlfetch(url, filepath)
        if file_size
            print(string.format("Downloaded %s: %d bytes.", filepath, file_size))
        end
        tasmota.yield()
    except .. as e, m
        print(string.format("Could not fetch %s. Error: %s (%s)", url, e, m))
    end
end

autoload.delete_file = def (filepath)
    import string
    try
        tasmota.cmd("UfsDelete2 " + filepath)
        print(string.format("Deleted if present: %s", filepath))
        tasmota.yield()
    except .. as e, m
        print(string.format("Could not delete %s. Error: %s (%s)", filepath, e, m))
    end
end

autoload.purge_unwanted = def (topic)
    var wanted_files = autoload.files_for_topic(topic)
    if wanted_files == nil
        import string
        print(string.format("Purge stopped. No script mapping for topic: %s", topic))
        return false
    end

    for f: autoload.managed_files()
        if !autoload.is_in_items(f, wanted_files)
            autoload.delete_file(f)
        end
    end
    return true
end

autoload.reload_scripts = def ()
    tasmota.set_timer(500, / -> tasmota.cmd("BrRestart"))
end

autoload.update_scripts = def ()
    import path
    import string

    var topic = autoload.topic()
    var files = autoload.files_for_topic(topic)
    if files == nil
        print(string.format("Update stopped. No script mapping for topic: %s", topic))
        tasmota.resp_cmnd_error()
        return
    end

    for d: autoload.folders
        path.mkdir(d)
    end

    tasmota.resp_cmnd_done()

    try
        autoload.purge_unwanted(topic)

        for f: files
            var url = autoload.fetch_url + f
            log(url)
            autoload.fetch(url, f)
        end

        autoload.reload_scripts()
    except .. as e, m
        print(string.format("UpdateScripts error: %s (%s)", e, m))
        tasmota.resp_cmnd_error()
    end
end

autoload.purge_scripts = def ()
    var topic = autoload.topic()
    if autoload.purge_unwanted(topic)
        tasmota.resp_cmnd_done()
        autoload.reload_scripts()
    else
        tasmota.resp_cmnd_error()
    end
end

return autoload