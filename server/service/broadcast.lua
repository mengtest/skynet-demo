local Skynet = require "skynet"
local Debug = require "lualib.debug"
local Handle = require "broadcast.command"
local service_name = ...

local function __init__()
    Skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = assert(Handle[cmd], cmd)
        Skynet.retpack(f(...))
    end)
    Skynet.register(service_name)
    Debug.fprint("====service %s start====",service_name)
end

Skynet.start(__init__)