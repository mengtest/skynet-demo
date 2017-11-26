local Object = require "chat.object"

local M = {}

function M.login(uuid, mArgs)
    local chan_obj = Object.get_world_channel()
    chan_obj:add_player(uuid, mArgs)
end

function M.quit(uuid)
    local chan_obj = Object.get_world_channel()
    chan_obj:del_player(uuid)
end

function M.usr_world_chat(uuid, msg)
    local chan_obj = Object.get_world_channel()
    chan_obj:broadcast(uuid, msg)
end

return M