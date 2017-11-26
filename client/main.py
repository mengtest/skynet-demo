#!/usr/bin/python
# -*- coding: utf-8 -*-
import socket
import os
import struct
import sys
reload(sys)
sys.setdefaultencoding('utf-8')
import threading
import thread
import time
import json
import getopt

def date_str(timestamp=None):
    if not timestamp:
        timestamp = time.time()
    return time.strftime('[%Y-%m-%d %H:%M:%S]',time.localtime(timestamp))

def sync_chat_msg(chat_msg, listener_id):
    timestamp = chat_msg['timestamp']
    if chat_msg['speaker_uuid'] == 0:
        print '%s[系统消息]: %s'%(date_str(timestamp), chat_msg['msg'])
    else:
        if chat_msg['speaker_uuid'] == listener_id:
            print '%s[你]: %s'%(date_str(timestamp), chat_msg['msg'])
        else:
            print '%s[%s]: %s'%(date_str(timestamp), chat_msg['speaker_name'], chat_msg['msg'])

class Client(object):
    def __init__(self, pid, gs_addr):
        self.m_Addr = gs_addr
        self.m_ID = pid
        self.m_Buf = ""
        self.m_Name = ""

    def name(self):
        return u"%s"%(self.m_Name)

    def start(self, noblocking=False):
        self.m_SockFd = socket.socket(socket.AF_INET,socket.SOCK_STREAM)
        try:
            self.m_SockFd.connect(self.m_Addr)
            if noblocking:
                self.m_SockFd.setblocking(0)
            print "connect:%s succeed!"% (self.m_Addr,)
        except socket.error, e:
            print "connect:%s error:%s"%(self.m_Addr,e)
            return False

        self.send('c2gs_login', {'pid':self.m_ID})

        t = threading.Thread(target = self.read_stdin)
        t.daemon = True
        t.start()
        return True

    def read_stdin(self):
        while True:
            try:
                line = sys.stdin.readline()
            except:
                break
            if not line:
                break
            if line == "quit\n":
                self.send('c2gs_quit', {})
            else:
                self.send('c2gs_usr_world_chat', {'msg':line})

    def send(self, proto, param):
        pkg = self.pack(proto, param)
        self.m_SockFd.sendall(pkg)

    def _read(self):
        if len(self.m_Buf) < 2:
            return None
 
        plen, = struct.unpack('!H', self.m_Buf[:2])
        if len(self.m_Buf) < plen + 2:
            return None

        data = self.m_Buf[2:plen+2]
        self.m_Buf = self.m_Buf[plen+2:]
        return data

    def recv(self):
        while True:
            try:
                buf = self.m_SockFd.recv(4*1024)
                if not buf:
                    print "sock close"
                    return
                self.m_Buf = self.m_Buf + buf
            except socket.error, e:
                print "sock error: %s"%e
                return
            while True:
                data = self._read()
                if not data:
                    break
                proto,param = self.unpack(data)
                self.dispatch(proto, param)

    def pack(self, proto, param, packHead=True):
        data = {
            'proto':proto,
            'param':param
        }
        pkg = json.dumps(data)
        if packHead:
            pkg = struct.pack("!H", len(pkg)) + pkg
        return pkg

    def unpack(self, msg):
        data = json.loads(msg)
        return data['proto'],data['param']

    def dispatch(self, proto, param):
        if proto == 'gs2c_loginsuc':
            self.m_Name = param['name']
            print "%s[%d] 登录成功"%(self.name(),self.m_ID)
            
        elif proto == 'gs2c_usr_world_chat':
            chat_msg = param["msg"]
            sync_chat_msg(chat_msg, self.m_ID)

        elif proto == 'gs2c_world_chat_history':
            history_msgs = param["history_msgs"]
            print "----世界频道聊天记录开始----"
            for chat_msg in history_msgs:
                sync_chat_msg(chat_msg, self.m_ID)
            print "----世界频道聊天记录结束----"

def init():
    pid,host,port = 1,'127.0.0.1',6100
    opts, args = getopt.getopt(sys.argv[1:], "u:h:p:")
    for op in opts:
        if op[0] == '-u':
            pid = int(op[1])
        elif op[0] == "-p":
            port = int(op[1])
        elif op[0] == "-h":
            host = op[1]

    cs = Client(pid, (host,port))
    if not cs.start():
        return
    print "chat start"
    cs.recv()
    print "chat end"

if __name__ == "__main__":
    init()