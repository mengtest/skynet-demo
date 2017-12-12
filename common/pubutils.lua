local ostime = os.time 
local mathrand = math.random


-------时间相关--------
function GetSecond()
    return ostime()
end

function GetDate()
    return os.date("%Y/%m/%d %H:%M:%S", ostime())
end

function RandomList(lst)
    if #lst == 0 then
        return nil
    end
    return lst[mathrand(1,#lst)]
end

local M = {}

function M.table_str(mt, max_floor, cur_floor)
    cur_floor = cur_floor or 1
    max_floor = max_floor or 5
    if max_floor and cur_floor > max_floor then
        return tostring(mt)
    end
    local str
    if cur_floor == 1 then
        str = string.format("%s{\n",string.rep("--",max_floor))
    else
        str = "{\n"
    end
    for k,v in pairs(mt) do
        if type(v) == 'table' then
            v = M.table_str(v, max_floor, cur_floor+1)
        else
            if type(v) == 'string' then
                v = "'" .. v .. "'"
            end
            v = tostring(v) .. "\n"
        end
        str = str .. string.format("%s[%s] = %s",string.rep("--",cur_floor),k,v)
    end
    str = str .. string.format("%s}\n",string.rep("--",cur_floor-1))
    return str
end

function M.table_len(mt)
    local len = 0
    for k,v in pairs(mt) do
        len = len + 1
    end
    return len
end

local function split(str, sep)
    local s, e = str:find(sep)
    if s then
        return str:sub(0, s - 1), str:sub(e + 1)
    end
    return str
end

function M.split_all(str, sep, n)
    local res = {}
    local i = 0
    while true do
        local lhs, rhs = split(str, sep)
        table.insert(res, lhs)
        if not rhs then
            break
        end
        i = i + 1
        if n and i >= n then
            table.insert(res, rhs)
            break
        end
        str = rhs
    end
    return res
end

local function sync_long_args(opts, src, lparam)
    local search
    for _,ar in ipairs(lparam) do
        if ar:sub(-1,-1) == "=" then
            if src:sub(1,#ar-1) == ar:sub(1,-2) then
                search = ar:sub(1,-2)
                break
            end
        else
            if src:sub(1,#ar) == ar then
                table.insert(opts, {"--"..ar,""})
                return
            end
        end
    end
    if search then
        local head = #search + 1
        local tail = #src
        while head <= tail do
            if src:sub(head,head) ~= " " then
                break
            end
            head = head + 1
        end
        while tail > head do
            if src:sub(tail,tail) ~= " " then
                break
            end
            tail = tail - 1
        end
        table.insert(opts, {"--"..search, src:sub(head,tail)})
    end
end

local function sync_short_args(opts, src, sparam)
    local c = src:sub(1,1)
    local idx = sparam:find(c)
    if not idx then
        return
    end
    if sparam:sub(idx+1,idx+1) == ":" then
        local head = 2
        local tail = #src
        while head <= tail do
            if src:sub(head,head) ~= " " then
                break
            end
            head = head + 1
        end
        while tail > head do
            if src:sub(tail,tail) ~= " " then
                break
            end
            tail = tail - 1
        end
        table.insert(opts, {"-"..c, src:sub(head,tail)})
    else
        table.insert(opts, {"-"..c,""})
    end
end

function M.getopt(src, sparam, lparam, mode)
    local idx = src:find("%-")
    if not idx then
        return {}
    end
    local opts = {}
    while idx <= #src do
        local head
        if src:sub(idx+1,idx+1) == "-" then
            head = idx + 2
        else
            head = idx + 1
        end
        local nxt = src:sub(head):find("%-")
        local tail
        if nxt then
            tail = head - 1 + nxt - 1
        else
            tail = #src
        end
        if head == idx + 2 then
            sync_long_args(opts, src:sub(head, tail), lparam)
        else
            sync_short_args(opts, src:sub(head, tail), sparam)
        end
        idx = tail + 1
    end
    if mode == "map" then
        local mt = {}
        for _,v in pairs(opts) do
            mt[v[1]] = v[2]
        end
        return mt
    else
        return opts
    end
end

local first_names = {
    "李", "王", "张", "刘", "陈", "杨", "赵", "黄", "周", "吴",
    "司徒","西门","欧阳","司马"
}
local last_names = {
    "秀娟", "英华", "慧", "巧", "美娜", "静", "淑惠", "翠珠",
    "辰逸","浩宇","瑾瑜","瑾瑜","天佑","大刀","小帅","伟","帅","进","振东"
}
function M.random_name()
    return RandomList(first_names) .. RandomList(last_names)
end

return M