local usr_data_tbl = {}

local M = {}

function M.set_usr_data(uuid, data)
    usr_data_tbl[uuid] = data
end

function M.query_usr_data(uuid)
    return usr_data_tbl[uuid]
end

return M