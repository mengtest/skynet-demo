local Debug = require "lualib.debug"
local Class = require "lualib.class"
local Skynet = require "skynet"
local Socketdriver = require "skynet.socketdriver"

local conlist = {}

local Connection = Class("Connection")

function Connection:init(fd)
    self.m_fd = fd
    self.m_StartTime = GetSecond()
end

function Connection:loginsuc(agent, pid)
    self.m_Agent = agent
    self.m_Pid = pid
end

local M = {}

function M.new_conn(fd)
    conlist[fd] = Connection:new(fd)
    Debug.fprint("new connction %s",fd)
end

function M.del_conn(fd)
    local conn = conlist[fd]
    if conn then
        Debug.fprint("del connction %s",fd)
        if conn.m_Agent then
            Skynet.send(conn.m_Agent, "lua", "kick", conn.m_Pid)
        end
        conlist[fd] = nil
        Socketdriver.close(fd)
    end
end

function M.get_conn(fd)
    return conlist[fd]
end

function M.get_pid_conn(pid)
    for fd,conn in pairs(conlist) do
        if conn.m_Pid == pid then
            return conn
        end
    end
end

function M.check_conns()
    local now = GetSecond()
    for fd,conn in pairs(conlist) do
        if not conn.m_Agent and now - conn.m_StartTime > 5*60 then
            del_conn(fd)
        end
    end
end

return M