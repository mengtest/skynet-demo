local Skynet = require "skynet"
local Player = require "agent.player"

local M = {}

function M.get_user_agent( pid )
    local iAgentCnt = Skynet.getenv("AGENT_CNT")
    local n = pid % iAgentCnt
    if n == 0 then
        n = iAgentCnt
    end
    n = math.floor(n)
    return "AGENT" .. n
end

function M.new_player(pid, mArgs)
    return Player:new(pid, mArgs)
end

function M.init()
    local iAgentCnt = Skynet.getenv("AGENT_CNT")
    for i=1,iAgentCnt do
        Skynet.newservice("agent", i)
    end
end

return M