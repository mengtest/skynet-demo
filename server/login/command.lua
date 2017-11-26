local Skynet = require "skynet"
local Utils = require "lualib.utils"
local Net = require "lualib.net"
local AgentApi = require "agent.api"

local M = {}

function M.unpack(fd, msg, sz)
    local proto,param = Net.unpack(msg, sz)
    if proto == "c2gs_login" then
        local pid = param.pid
        local name
        local is_new_role = false
        local mdb = Skynet.call("DB", "lua", "query_usr_data", pid)
        if mdb then
            name = mdb.name
        else
            name = Utils.random_name()
            is_new_role = true
            Skynet.send("DB", "lua", "set_usr_data", pid, {name = name, create_time = GetSecond()})
        end
        local agent = AgentApi.get_user_agent(pid)
        local mArgs = {pid = pid, agent = agent, name = name, fd = fd, is_new_role = is_new_role}
        Skynet.send("GAMEGATE", "lua", "loginsuc", fd, mArgs)
    end
end

return M