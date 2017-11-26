local Class = require "lualib.class"
local Env = require "agent.env"
local BCApi = require "broadcast.api"
local Debug = require "lualib.debug"
local Skynet = require "skynet"
local Net = require "lualib.net"

local Player = Class("Player")

function Player:__tostring()
    return string.format("[id:%s name:%s fd:%s]",self.m_ID,self.m_Name,self.m_FD)
end

function Player:init(id, mArgs)
    self.m_ID = id
    self.m_Name = mArgs.name
    self.m_FD = mArgs.fd
    if mArgs.is_new_role then
        self:on_new_role()
    end
end

function Player:on_new_role()
    Debug.fprint("====create new player %s==",self)
end

function Player:login()
    Env.set_player(self.m_ID, self)
    BCApi.register_fd(self.m_ID, self.m_FD)
    Skynet.send("CHAT", "lua", "login", self.m_ID, {name = self.m_Name,})
    Net.send_to_player(self.m_ID, "gs2c_loginsuc", {name = self.m_Name,})
    Debug.fprint("====player %s==login==",self)
end

function Player:quit()
    Env.del_player(self.m_ID)
    BCApi.unregister_fd(self.m_ID)
    Skynet.call("CHAT", "lua", "quit", self.m_ID)
    Debug.fprint("====player %s==quit===",self)
end

return Player