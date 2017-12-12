local Pubutils = require "pubutils"
local Skynet = require "skynet"

-------时间相关--------
function GetCSecond()
    return Skynet.now()
end

function GetMSecond()
    return Skynet.now()*10
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

local M = {}

for k,v in pairs(Pubutils) do
    M[k] = v
end

return M