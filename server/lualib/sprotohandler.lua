local SprotoLoader = require 'sprotoloader'

local M = {}

local proxy = setmetatable({},{
    __index = function (t, key)
        assert(rawget(t,key) == nil, "repeat sproto key")
        local sp = SprotoLoader.load(SPROTO_INDEX)
        local sp_recv = sp:host(BASE_PACKAGE)
        local sp_send = sp_recv:attach(sp)
        t["send"] = sp_send
        t["recv"] = sp_recv
        t["cobj"] = sp
        assert(rawget(t,key), "unkonw sproto key")
        return t[key]
    end
})

function M.init(sproto_path)
    local fpath = sproto_path .. "/" .. 'sproto.spb'
    local fp = assert(io.open(fpath, "rb"), "Can't open sproto file")
    local bin = fp:read "*a"
    fp:close()
    SprotoLoader.save(bin, SPROTO_INDEX)
end

function M.encode(proto, param)
    local now = GetSecond()
    local ud = {timestamp = now}
    local pkg = proxy.send(proto, param, nil, ud)
    return pkg
end

function M.decode(msg, sz)
    local msg_type, proto, param = proxy.recv:dispatch(msg, sz)
    return proto,param
end

return M