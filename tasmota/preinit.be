import string

try
    import autoload
    if autoload != nil
        autoload.init()
    end
except .. as e, m
    log(string.format("Autoload preinit failed: %s (%s)", e, m))
end