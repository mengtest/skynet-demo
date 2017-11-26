local Skynet = require "skynet"

local ostime = os.time 
local mathrand = math.random 

-------时间相关--------
function GetSecond()
    return ostime()
end

function GetCSecond()
    return Skynet.now()
end

function GetMSecond()
    return Skynet.now()*10
end

function GetDate()
    return os.date("%Y/%m/%d %H:%M:%S", ostime())
end

-------定时器相关--------
-- ti: 执行间隔，单位百分之一秒(10ms)
-- count：0表示无限次数, >0 有限次
-- handle : 自定义(int,string等常量key)或系统分配
local timer_no = 0
local timer_list = {}
local timer_default_hdl = 0
function AddTimer(ti, func, handle, count)
    assert(ti >= 0)
    count = count or 0
    count = (count>0) and count or true
    if handle == nil then
        handle = timer_default_hdl
        timer_default_hdl = timer_default_hdl + 1
    end
    local tno = timer_no
    timer_no = timer_no + 1
    timer_list[handle] = {tno, count}
    local f
    f = function ()
        if not timer_list[handle] then
            return
        end
        if timer_list[handle][1] ~= tno then
            return
        end
        if timer_list[handle][2] == true then
            Skynet.timeout(ti, f)
        else
            timer_list[handle][2] = timer_list[handle][2] - 1
            if timer_list[handle][2] > 0 then
                Skynet.timeout(ti, f)
            else
                timer_list[handle] = nil
            end
        end
        func()
    end
    Skynet.timeout(ti, f)
    return handle
end

function RemoveTimer(handle)
    timer_list[handle] = nil
end

function RemoveAllTimers()
    timer_list = {}
end

function FindTimer(handle)
    return timer_list[handle]
end

-------其他相关--------
local UniqIDList = {}
function NewServiceUniqID(sType)
    if not UniqIDList[sType] then
        UniqIDList[sType] = 0
    end
    UniqIDList[sType] = UniqIDList[sType] + 1
    return UniqIDList[sType]
end

function SkynetCall(service, cmd, ...)
    return Skynet.call(service, "lua", cmd, ...)
end

function SkynetSend(service, cmd, ...)
    Skynet.send(service, "lua", cmd, ...)
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