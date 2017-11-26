local player_tbl = {}

local M = {}

function M.set_player(pid, pobj)
    player_tbl[pid] = pobj
end

function M.get_player(pid)
    return player_tbl[pid]
end

function M.del_player(pid)
    player_tbl[pid] = nil
end

return M