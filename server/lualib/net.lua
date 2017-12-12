local Skynet = require "skynet"
local Netpack = require "skynet.netpack"
local Sprotohandler = require "lualib.sprotohandler"
local Json = require "cjson"

local PACK_FMT = '>s2'

local M = {}

function M.pack(proto, param, packHead)
    local pkg
    if IsSprotoCompression() then
        pkg = Sprotohandler.encode(proto, param)
    elseif IsJsonCompression() then
        local data = {
            ["proto"] = proto,
            ["param"] = param,
        }
        pkg = Json.encode(data)
    end
    assert(pkg)
    if packHead then --tcp need, udp or websocket not
        pkg = string.pack(PACK_FMT, pkg)
    end
    return pkg
end

function M.unpack(msg, sz)
    if IsSprotoCompression() then
        local proto,param = Sprotohandler.decode(msg, sz)
        return proto,param
    elseif IsJsonCompression() then
        local s = Netpack.tostring(msg, sz)
        local data = Json.decode(s)
        return data["proto"],data["param"]
    end
    assert(false)
end

function M.send_to_player(uuid, proto, param, bc_addr)
    bc_addr = bc_addr or "PUB_BC"
    local pkg = M.pack(proto, param, true)
    Skynet.send(bc_addr, "lua", "send_to_player", uuid, pkg)
end

function M.send_to_list(uuid_list, proto, param, bc_addr)
    bc_addr = bc_addr or "PUB_BC"
    local pkg = M.pack(proto, param, true)
    for _,uuid in ipairs(uuid_list) do
        Skynet.send(bc_addr, "lua", "send_to_player", uuid, pkg)
    end
end

function M.send_to_tbl(uuid_tbl, proto, param, bc_addr)
    bc_addr = bc_addr or "PUB_BC"
    local pkg = M.pack(proto, param, true)
    for uuid in pairs(uuid_tbl) do
        Skynet.send(bc_addr, "lua", "send_to_player", uuid, pkg)
    end
end

function M.world_broadcast(proto, param, bc_addr, except_uuids_tbl)
    bc_addr = bc_addr or "PUB_BC"
    except_uuids_tbl = except_uuids_tbl or {}
    local pkg = M.pack(proto, param, true)
    Skynet.send(bc_addr, "lua", "world_broadcast", pkg, except_uuids_tbl)
end

return M