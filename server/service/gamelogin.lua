local Skynet = require "skynet"
local Debug = require "lualib.debug"
local Handle = require "login.command"

local function __init__()
    Skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = assert(Handle[cmd], cmd)
        Skynet.retpack(f(...))
    end)
    Skynet.register("GAMELOGIN")
    Debug.print("====service GAMELOGIN start====")
end

Skynet.start(__init__)