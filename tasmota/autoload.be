
var autoload_module = module("autoload_module")


autoload_module.folders = [
    "/lib",
    "/autoexec",
]

autoload_module.update_files = [
    "autoexec.be",
    "preinit.be",
    "autoload.be",
    "autoexec/clawmachine.be",
    "autoexec/cashregister.be",
    "autoexec/ceilingled.be",
    "autoexec/duckgame.be",
]

autoload_module.lib_files = [
    "/lib/LibMultiplexer.be",
]


autoload_module.fetch_url = "https://raw.githubusercontent.com/Tomee20000/eexit-circus/refs/heads/main/tasmota/"

autoload_module.init = def ()
    tasmota.add_cmd("UpdateScripts", autoload_module.update_scripts)
    #tasmota.add_cmd("PurgeScripts", autoload_module.purge_scripts)
    
    for f: autoload_module.lib_files
        import string
        var is_loaded = load(f) 
        var message
        if (!is_loaded)
            message = "%s is not present!"
        else
            message = "%s is loaded."
        end
        print (string.format(message, f))
    end
end


autoload_module.fetch = def (url, filepath)
    import string
    try
        var file_size = tasmota.urlfetch(url, filepath)
        if (file_size)
            print (string.format("Downloaded %d bytes.", file_size)) 
        end
        tasmota.yield()
    except .. as variable, message
        print (string.format("Could not fetch %s. Error: %s (%s)", url, variable, message)) 
    end 
end

autoload_module.update_scripts = def ()
    import path
    for d: autoload_module.folders
        path.mkdir(d)
    end
    
    #fetch all berry component
    var all_files = autoload_module.update_files + autoload_module.lib_files
    tasmota.resp_cmnd_done()
    try
        for f: all_files
            var url = autoload_module.fetch_url + f
            log(url)
            autoload_module.fetch(url, f)
        end
    except
        tasmota.resp_cmnd_error()
    end
end

return autoload_module