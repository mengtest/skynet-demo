package.path = package.path .. ";../server/lualib/?.lua" .. ";../skynet/lualib/?.lua;" .. "../common/?.lua"
package.cpath = package.cpath .. ";../build/clib/?.so" .. ";../skynet/luaclib/?.so" .. ";../skynet/cservice/?.so"
local Pubdefines = require "pubdefines"
local Client = require "client"
local Utils = require "pubutils"
local Lclient = require "lclient"

local fprint = function ( ... )
    print(string.format(...))
end

local function sync_chat_msg(chat_msg, listener_id)
    local timestamp = chat_msg['timestamp']
    if chat_msg['speaker_uuid'] == 0 then
        fprint("%s[系统消息]: %s",GetDate(),chat_msg['msg'])
    else
        if chat_msg['speaker_uuid'] == listener_id then
            fprint("%s[你]: %s", GetDate(), chat_msg['msg'])
        else
            fprint("%s[%s]: %s", GetDate(), chat_msg['speaker_name'], chat_msg['msg'])
        end
    end
end

local net_handler = function (self, proto, param)
    if proto == "gs2c_loginsuc" then
        self:setname(param["name"])
        fprint("%s[%d] 登录成功",self:getname(),self.m_ID)

    elseif proto == "gs2c_usr_world_chat" then
        sync_chat_msg(param["msg"], self.m_ID)
    
    elseif proto == "gs2c_world_chat_history" then
        fprint "----世界频道聊天记录开始----"
        for _,msg in pairs(param["history_msgs"]) do
            sync_chat_msg(msg, self.m_ID)
        end
        fprint "----世界频道聊天记录结束----"
    end
end

local uid,host,port = 1,'127.0.0.1',6100

local args = table.concat({...},"")

local opts = Utils.getopt(args, "h:p:u:", {}, "map")
if tonumber(opts["-u"]) then
    uid = tonumber(opts["-u"])
end
if tonumber(opts["-h"]) then
    host = tonumber(opts["-h"])
end
if tonumber(opts["-p"]) then
    port = tonumber(opts["-p"])
end

local oclient = Client:new({id = uid, addr = {host,port}, net_handler = net_handler})
oclient:start()

while true do
    local r,err = oclient:recv(0.1)
    if r then
        print(err)
        break
    end
    local str = Lclient.readstdin()
    if str then
        if str == "quit" then
            oclient:send('c2gs_quit', {})
        elseif str == "exit" then
            oclient:close()
        else
            oclient:send('c2gs_usr_world_chat', {msg = str})
        end
    end
end