local Skynet = require "skynet"
local Netpack = require "skynet.netpack"
local Json = require "cjson"

local PACK_FMT = '>s2'

local M = {}

function M.pack(proto, param, packHead)
    local data = {
        ["proto"] = proto,
        ["param"] = param,
    }
    local pkg = Json.encode(data)
    if packHead then --tcp need, udp or websocket not
        pkg = string.pack(PACK_FMT, pkg)
    end
    return pkg
end

function M.unpack(msg, sz)
    local s = Netpack.tostring(msg, sz)
    local data = Json.decode(s)
    return data["proto"],data["param"]
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