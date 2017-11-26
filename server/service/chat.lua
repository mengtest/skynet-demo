local Skynet = require "skynet"
local Debug = require "lualib.debug"
local Handle = require "chat.command"
local ChatObj = require "chat.object"

local function __init__()
    Skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = assert(Handle[cmd], cmd)
        Skynet.retpack(f(...))
    end)
    ChatObj.new_channel("world")
    Skynet.register("CHAT")
    Debug.print("====service CHAT start====")
end

Skynet.start(__init__)