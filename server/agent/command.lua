local Skynet = require "skynet"
local Socketdriver = require "skynet.socketdriver"
local Api = require "agent.api"
local Env = require "agent.env"
local Net = require "lualib.net"
local Debug = require "lualib.debug"

local M = {}

function M.start(uuid, mArgs)
    local pobj = Api.new_player(uuid, mArgs)
    pobj:login()
end

function M.kick(uuid)
    local pobj = Env.get_player(uuid)
    if pobj then
        pobj:quit()
    end
end

function M.unpack(uuid, msg, sz)
    local pobj = Env.get_player(uuid)
    local proto,param = Net.unpack(msg, sz)
    if not pobj then
        Debug.ferror("err cs unpack %s", proto)
        return
    end
    if proto == "c2gs_usr_world_chat" then
        Skynet.send("CHAT", "lua", "usr_world_chat", uuid, param.msg)
    elseif proto == "c2gs_quit" then
        Skynet.send("GAMEGATE", "lua", "quit", pobj.m_FD)
    end
end

return M