local Skynet = require "skynet"
local Netpack = require "skynet.netpack"
local Socketdriver = require "skynet.socketdriver"
local Utils = require "lualib.utils"
local Debug = require "lualib.debug"
local Connection = require "login/connection"
local socket    -- listen socket
local queue     -- message queue
local CMD = setmetatable({}, { __gc = function() Netpack.clear(queue) end })

function CMD.open(source, conf)
    local address = conf.address or "0.0.0.0"
    local port = assert(conf.port)
    Skynet.error(string.format("====Listen on %s:%d start====", address, port))
    socket = Socketdriver.listen(address, port)
    Socketdriver.start(socket)
    Skynet.error(string.format("====Listen on %s:%d %d end====", address, port,socket))
end

function CMD.close()
    assert(socket)
    Socketdriver.close(socket)
end

function CMD.loginsuc(source, fd, mArgs)
    local conn = Connection.get_conn(fd)
    if not conn then
        Debug.print("login error:no conn",fd,Utils.table_str(mArgs))
        return
    end
    if conn.m_Agent then
        Debug.print("login error:re login",fd,Utils.table_str(mArgs))
        return
    end
    local oldcon = Connection.get_pid_conn(mArgs.pid)
    if oldcon then
        Connection.del_conn(oldcon.m_fd)
    end
    conn:loginsuc(mArgs.agent, mArgs.pid)
    Skynet.send(conn.m_Agent, "lua", "start", mArgs.pid, mArgs)
    Debug.print("login suc",fd,Utils.table_str(mArgs))
end

function CMD.quit(source, fd)
    Connection.del_conn(fd)
end

local MSG = {}

local function dispatch_msg(fd, msg, sz)
    local conn = Connection.get_conn(fd)
    if not conn then
        return
    end
    if conn.m_Agent then
        Skynet.send(conn.m_Agent, "lua", "unpack", conn.m_Pid, msg, sz)
    else
        Skynet.send("GAMELOGIN", "lua", "unpack", fd, msg, sz)
    end
end

MSG.data = dispatch_msg

local function dispatch_queue()
    local fd, msg, sz = Netpack.pop(queue)
    if fd then
        Skynet.fork(dispatch_queue)
        dispatch_msg(fd, msg, sz)

        for fd, msg, sz in Netpack.pop, queue do
            dispatch_msg(fd, msg, sz)
        end
    end
end

MSG.more = dispatch_queue

function MSG.open(fd, msg)
    Socketdriver.start(fd)
    Socketdriver.nodelay(fd)
    Connection.new_conn(fd)
end

function MSG.close(fd)
    Connection.del_conn(fd)
end

function MSG.error(fd, msg)
    Connection.del_conn(fd)
end

Skynet.register_protocol {
    name = "socket",
    id = Skynet.PTYPE_SOCKET,   -- PTYPE_SOCKET = 6
    unpack = function ( msg, sz )
        return Netpack.filter( queue, msg, sz)
    end,
    dispatch = function (_, _, q, type, ...)
        queue = q
        if type then
            MSG[type](...)
        end
    end
}

Skynet.start(function()
    AddTimer(5*60*100, function () Connection.check_conns() end, "CheckConnections")
    Skynet.dispatch("lua", function (_, address, cmd, ...)
        local f = CMD[cmd]
        if f then
            Skynet.ret(Skynet.pack(f(address, ...)))
        end
    end)
    Skynet.register("GAMEGATE")
    Debug.print("====service GAMEGATE start====")
end)