local Skynet = require "skynet"

local broadcast_list = {}

--世界频道广播服
table.insert(broadcast_list, "WORLD_CHAT_BC")

--通用广播服
table.insert(broadcast_list, "PUB_BC")

local M = {}

function M.init()
    for _,service in ipairs(broadcast_list) do
        Skynet.newservice("broadcast", service)
    end
end

function M.register_fd(uuid, fd)
    for _,service in ipairs(broadcast_list) do
        Skynet.send(service, "lua", "register_fd", uuid, fd)
    end
end

function M.unregister_fd(uuid)
    for _,service in ipairs(broadcast_list) do
        Skynet.send(service, "lua", "unregister_fd", uuid)
    end
end

return M