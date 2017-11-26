local Class = require "lualib.class"
local Net = require "lualib.net"
local Defines = require "chat.defines"
local Debug = require "lualib.debug"

local channel_tbl = {}

local WorldChannel = Class("WorldChannel")

WorldChannel.BC_ADDR = "WORLD_CHAT_BC"

function WorldChannel:init()
    self.m_Players = {}
    self.m_MsgCache = {}
    channel_tbl[Defines.WORLD_CHANNEL] = self
    Debug.fprint("世界频道已开启")
end

function WorldChannel:add_player(uuid, mArgs)
    self.m_Players[uuid] = mArgs
    Net.send_to_player(uuid, "gs2c_world_chat_history", {history_msgs = self.m_MsgCache}, self.BC_ADDR)
    local msg = string.format("玩家%s[%d] 加人世界频道", mArgs.name,uuid)
    self:broadcast(SYS_UUID, msg, {[uuid] = true})
    self:chat(SYS_UUID, uuid, "您已加入世界频道")
    Debug.fprint("[id:%s name:%s] join world channel.", uuid, mArgs.name)
end

function WorldChannel:del_player(uuid)
    if self.m_Players[uuid] then
        local mArgs = self.m_Players[uuid]
        self.m_Players[uuid] = nil
        self:broadcast(SYS_UUID, string.format("玩家%s[%d] 离开世界频道",mArgs.name,uuid))
        Debug.fprint("[id:%s name:%s] leave world channel.", uuid, mArgs.name)
    end
end

function WorldChannel:chat(speaker_uuid, listener_uuid, msg)
    if speaker_uuid ~= SYS_UUID and not self.m_Players[speaker_uuid] then
        Debug.ferror("world chat not exist speaker uuid %s",speaker_uuid)
        return
    end
    if not self.m_Players[listener_uuid] then
        Debug.ferror("world chat not exist listener uuid %s",listener_uuid)
        return
    end
    local data = {}
    data["speaker_uuid"] = speaker_uuid
    data["msg"] = msg
    if speaker_uuid == SYS_UUID then
        data["speaker_name"] = "系统"
    else
        local mArgs = self.m_Players[speaker_uuid]
        data["speaker_name"] = mArgs.name
    end
    data["timestamp"] = GetSecond()
    Net.send_to_player(listener_uuid, "gs2c_usr_world_chat", {msg = data}, self.BC_ADDR)
end

function WorldChannel:broadcast(speaker_uuid, msg, except_uuids_tbl)
    if speaker_uuid ~= SYS_UUID and not self.m_Players[speaker_uuid] then
        Debug.ferror("world broadcast not exist speaker uuid %s",speaker_uuid)
        return
    end
    except_uuids_tbl = except_uuids_tbl or {}
    local data = {}
    data["speaker_uuid"] = speaker_uuid
    data["msg"] = msg
    if speaker_uuid == SYS_UUID then
        data["speaker_name"] = "系统"
    else
        local mArgs = self.m_Players[speaker_uuid]
        data["speaker_name"] = mArgs.name
    end
    data["timestamp"] = GetSecond()
    table.insert(self.m_MsgCache, data)
    if #self.m_MsgCache > 6 then
        table.remove(self.m_MsgCache, 1)
    end
    Net.world_broadcast("gs2c_usr_world_chat", {msg = data}, self.BC_ADDR, except_uuids_tbl)
end

local cls_map = {
    ["world"] = WorldChannel
}

local M = {}

function M.new_channel(stype, ...)
    if cls_map[stype] then
        return cls_map[stype]:new(...)
    end
end

function M.get_channel(chan_id)
    return channel_tbl[chan_id]
end

function M.get_world_channel()
    return channel_tbl[Defines.WORLD_CHANNEL]
end

return M