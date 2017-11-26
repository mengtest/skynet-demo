local Skynet = require "skynet"
local BcApi = require "broadcast.api"
local AgentApi = require "agent.api"

local function __init__()
    print("===========game_init begin=========",GetDate())
    BcApi.init()
    
    AgentApi.init()
    
    Skynet.newservice("database")

    local gate = Skynet.newservice("gamegate")
    local login_port = tonumber(Skynet.getenv("login_port"))
    Skynet.send(gate, "lua", "open", {port = login_port})

    Skynet.newservice("gamelogin")

    Skynet.newservice("chat")

    print("===========game_init end=========")
    Skynet.exit()
end

Skynet.start(__init__)