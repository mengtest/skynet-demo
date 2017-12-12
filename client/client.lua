local Lsocket = require "lsocket"
local Class = require "class"
local Json = require "cjson"
local Sprotohandler = require "sprotohandler"
local Lclient = require "lclient"

Sprotohandler.init("../build")

local Client = Class("ClientObj")

function Client:init(mArgs)
    self.m_ID = mArgs.id
    self.m_Addr = mArgs.addr
    self.m_NetHandler = mArgs.net_handler
    self.m_Buffer = ""
end

function Client:start()
    local fd,err = Lsocket.connect(self.m_Addr[1], self.m_Addr[2])
    if fd == nil then
        error(err)
    end
    Lsocket.select(nil, {fd})
    local ok, err = fd:status()
    if not ok then
        error(err)
    end
    self.m_oFd = fd
    self:send('c2gs_login', {pid = self.m_ID})
    local info = fd:info("socket")
    print(info.family.." "..info.addr..":"..info.port.. " -> " .. self.m_Addr[1] .. ":" .. self.m_Addr[2] .." Connect succeed!")
end

function Client:close()
    self.m_oFd:close()
    self.m_oFd = nil
    self.m_Buffer = ""
end

function Client:__tostring()
    return string.format("Agent[id:%s fd:%s name:%s]",self.m_ID,self.m_oFd:info()["fd"],self.m_Name)
end

function Client:setname( name )
    self.m_Name = name
end

function Client:getname()
    return self.m_Name
end

function Client:_read()
    if #self.m_Buffer < 2 then
        return nil
    end
    local head = self.m_Buffer:sub(1,2)
    local len = head:byte(1,1)*256 + head:byte(2,2)
    if #self.m_Buffer < len+2 then
        return nil
    end
    local r = self.m_Buffer:sub(3,len+2)
    self.m_Buffer = self.m_Buffer:sub(len+3)
    return r
end

function Client:recv(ti)
    while true do
        local fd = self.m_oFd
        if fd == nil then
            return true,"closed"
        end
        local rd = Lsocket.select({fd}, ti)
        if not rd or next(rd) == nil then
            return nil
        end
        local p,err = fd:recv()
        if p == false then --no data available
            return nil
        end
        if p == nil then
            if err then --socket err
                return true,err
            else --closed
                return true,"server close"
            end
        end
        self.m_Buffer = self.m_Buffer .. p
        while true do
            local data = self:_read()
            if not data then
                break
            end
            self:_dispatch(data)
        end
    end
end

function Client:_dispatch(data)
    local proto,param = self:unpack(data, #data)
    self.m_NetHandler(self, proto, param)
end

function Client:pack(proto, param, packHead)
    local pkg
    if IsJsonCompression() then
        local data = {
            ["proto"] = proto,
            ["param"] = param,
        }
        pkg = Json.encode(data)
    else
        pkg = Sprotohandler.encode(proto, param)
    end
    if packHead then
        pkg = string.pack('>s2', pkg)
    end
    return pkg
end

function Client:unpack(msg, sz)
    if IsJsonCompression() then
        local data = Json.decode(msg)
        return data["proto"],data["param"]
    else --sproto
        local proto,param = Sprotohandler.decode(msg, sz)
        return proto,param
    end
end

function Client:send(proto, param)
    local s = self:pack(proto, param, true)
    local rcnt,len = 0,#s
    while rcnt < len do
        local r,err = self.m_oFd:send(s)
        if not r then
            if err then
                error("[send error]: "..err)
            else
                error("[send error]: EAGAIN")
            end
        end
        rcnt = rcnt + r
        s = s:sub(r+1)
    end
end

return Client