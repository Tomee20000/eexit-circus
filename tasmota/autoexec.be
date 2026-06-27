import autoload
import string

var topic = autoload.topic()
var file = autoload.file_for_topic(topic)

if file == nil
    log(string.format("No script mapping for topic: %s", topic))
else
    log(string.format("Loading: %s", file))
    load(file)
end