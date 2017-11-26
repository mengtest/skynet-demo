local Skynet = require "skynet"
local Debug = require "lualib.debug"
local Handle = require "agent.command"

local iNo = ...
iNo = math.floor(tonumber(iNo))

local function __init__()
    Skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = assert(Handle[cmd], cmd)
        Skynet.retpack(f(...))
    end)
    Skynet.register("AGENT" .. iNo)
    Debug.fprint("====service %s start====","AGENT" .. iNo)
end

Skynet.start(__init__)