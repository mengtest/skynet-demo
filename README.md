## Skynet-demo

* What is skynet? https://github.com/cloudwu/skynet
* Skynet 官方资料:<br>
        https://github.com/cloudwu/skynet/wiki<br>
        https://blog.codingnow.com/eo/skynet<br>
        https://github.com/cloudwu/skynet/issues<br>
* Skynet 部分三方资料:<br>
        http://blog.csdn.net/linshuhe1/article/category/6860208<br>
        http://www.cnblogs.com/Jackie-Snow/category/964885.html<br>
        http://forthxu.com/blog/skynet.html<br>
## 编译连接

```
sh init.sh
```

## 环境搭建

```
服务端:
    sh rungs.sh
客户端:
    sh runcs.sh -u pid(默认1) #多终端启动，终端输入quit or Ctrl-C退出登录，输入其他字符串为世界频道消息，支持重登
```

## 服务端工作流程分析
server为工程目录,init.sh中建立了其软连接到skynet目录下,server/config为启动配置文件,文件中所有配置将做为进程内的环境变量被记录,可通过skynet.getenv获取,进程启动目录为skynet/, 
config文件中luaservice，lua_path，lua_cpath，preload等都是以其做参照的相对路径,
start(或main)对应的是skynet进程启动的用户定义的初始化服务,
这里是server/service/init.lua，该服务由[默认的bootstrap服务](https://github.com/cloudwu/skynet/blob/master/service/bootstrap.lua#L46)启动.
下面分析init.lua
```lua
#service/init.lua
local Skynet = require "skynet"
local BcApi = require "broadcast.api"
local AgentApi = require "agent.api"

local function __init__()
    print("===========game_init begin=========",GetDate())
    BcApi.init()

    AgentApi.init()

    Skynet.newservice("database")

    local gate = Skynet.newservice("gamegate")
    local login_port = tonumber(Skynet.getenv("login_port"))
    Skynet.send(gate, "lua", "open", {port = login_port})

    Skynet.newservice("gamelogin")

    Skynet.newservice("chat")

    print("===========game_init end=========")
    Skynet.exit()
end

Skynet.start(__init__)
```
Skynet.start先将skynet.dispatch_message注册为服务收到消息的回调函数，再通过定时器回射的方式执行__init__函数.

```lua
#broadcast/api.lua
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
```
BcApi.init 启动了一个世界频道广播服务和一个通用广播服，当玩家登录成功后，会把其pid与socket在逻辑层对应fd的映射关系通过register_fd注册到所有广播服务,
下线的时候通过unregister_fd从所有广播服务删除其映射关系.这样做的目的是无论在哪个服务想要给客户端发消息，只需将玩家的pid和消息内容发往指定的广播服，该广播服务会自动将消息发送给玩家，[lualib/net.lua](https://github.com/xingshuo/skynet-demo/blob/master/server/lualib/net.lua#L27)
里封装了4个接口用来处理给玩家发包的功能. demo支持了json和sproto两种CS通信协议的解决方案,可以通过[common/pubdefines.lua](https://github.com/xingshuo/skynet-demo/blob/master/common/pubdefines.lua)文件配置,该过程也被封装在lualib/net.lua的[pack和unpack函数](https://github.com/xingshuo/skynet-demo/blob/master/server/lualib/net.lua#L9)中,[common/protocol文件](https://github.com/xingshuo/skynet-demo/blob/master/common/protocol)是协议的内容说明.
下面看下broadcast服务启动文件
```lua
#service/broadcast.lua
local Skynet = require "skynet"
local Debug = require "lualib.debug"
local Handle = require "broadcast.command"
local service_name = ...

local function __init__()
    Skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = assert(Handle[cmd], cmd)
        Skynet.retpack(f(...))
    end)
    Skynet.register(service_name)
    Debug.fprint("====service %s start====",service_name)
end

Skynet.start(__init__)
```
Skynet.dispatch("lua", ...)这一行注册了"lua"类型消息的回调函数,实际上是在[这里](https://github.com/cloudwu/skynet/blob/master/lualib/skynet.lua#L496)被调用,
local f = assert(Handle[cmd], cmd) 设置回调函数根据broadcast/command.lua返回的table做为接收cmd的处理方案,例如register_fd函数中发送"lua"类型的"register_fd"命令给所有广播服，广播服在收到该消息后后执行到[这里](https://github.com/xingshuo/skynet-demo/blob/master/server/broadcast/command.lua#L6)
Skynet.retpack(f(...))这一行把执行函数的返回值打包，再根据发送服务请求消息中的session值是否为0(发送服务调用skynet.send还是skynet.call),来决定是否把打包的返回值回应给发送服务
Skynet.register(service_name) 这一行把服务启动时接收到的参数service_name 这里应该就是"WORLD_CHAT_BC"或者"PUB_BC"作为服务的字符串标识注册到C层,所以skynet.send和skynet.call的目标服务地址参数,
既可以填目标服务调用skynet.self()返回的整形handle，也可以填Skynet.register注册的字符串.

```lua
#agent/api.lua
local Skynet = require "skynet"
local Player = require "agent.player"

local M = {}

function M.get_user_agent( pid )
    local iAgentCnt = Skynet.getenv("AGENT_CNT")
    local n = pid % iAgentCnt
    if n == 0 then
        n = iAgentCnt
    end
    n = math.floor(n)
    return "AGENT" .. n
end

function M.new_player(pid, mArgs)
    return Player:new(pid, mArgs)
end

function M.init()
    local iAgentCnt = Skynet.getenv("AGENT_CNT")
    for i=1,iAgentCnt do
        Skynet.newservice("agent", i)
    end
end

return M
```
AgentApi.init 启动了AGENT_CNT(config文件配置参数)个agent服务,作为玩家对象的生存服务,根据get_user_agent可以看出pid与agent的映射关系.
大部分情况下,登录的所有玩家会被相对均匀的分配到启动了的AGENT_CNT个agent服务中.

Skynet.newservice("database") 启动了一个简陋的数据库服务，它只是简单的把玩家的信息存储在内存中，实际应用可通过该服务与mysql,mongodb等数据库建立连接

local gate = Skynet.newservice("gamegate") 启动了网关服务gamegate,它的实现参考了[这里](https://github.com/cloudwu/skynet/wiki/GateServer)

local login_port = tonumber(Skynet.getenv("login_port"))<br>
Skynet.send(gate, "lua", "open", {port = login_port})<br>
这两行实现了网关服务对本地config文件中配置的login_port端口的监听,下面具体分析下gamegate的实现
```lua
#service/gamegate.lua
local Skynet = require "skynet"
local Netpack = require "skynet.netpack"
local Socketdriver = require "skynet.socketdriver"
local Utils = require "lualib.utils"
local Debug = require "lualib.debug"
local Connection = require "login/connection"
local socket    -- listen socket
local queue     -- message queue
local CMD = setmetatable({}, { __gc = function() Netpack.clear(queue) end })

function CMD.open(source, conf)
    local address = conf.address or "0.0.0.0"
    local port = assert(conf.port)
    Skynet.error(string.format("====Listen on %s:%d start====", address, port))
    socket = Socketdriver.listen(address, port)
    Socketdriver.start(socket)
    Skynet.error(string.format("====Listen on %s:%d %d end====", address, port,socket))
end

function CMD.close()
    assert(socket)
    Socketdriver.close(socket)
end

 #Omitted some code here...

local MSG = {}

local function dispatch_msg(fd, msg, sz)
    local conn = Connection.get_conn(fd)
    if not conn then
        return
    end
    if conn.m_Agent then
        Skynet.send(conn.m_Agent, "lua", "unpack", conn.m_Pid, msg, sz)
    else
        Skynet.send("GAMELOGIN", "lua", "unpack", fd, msg, sz)
    end
end

MSG.data = dispatch_msg

local function dispatch_queue()
    local fd, msg, sz = Netpack.pop(queue)
    if fd then
        Skynet.fork(dispatch_queue)
        dispatch_msg(fd, msg, sz)

        for fd, msg, sz in Netpack.pop, queue do
            dispatch_msg(fd, msg, sz)
        end
    end
end

MSG.more = dispatch_queue

function MSG.open(fd, msg)
    Socketdriver.start(fd)
    Socketdriver.nodelay(fd)
    Connection.new_conn(fd)
end

function MSG.close(fd)
    Connection.del_conn(fd)
end

function MSG.error(fd, msg)
    Connection.del_conn(fd)
end

Skynet.register_protocol {
    name = "socket",
    id = Skynet.PTYPE_SOCKET,   -- PTYPE_SOCKET = 6
    unpack = function ( msg, sz )
        return Netpack.filter( queue, msg, sz)
    end,
    dispatch = function (_, _, q, type, ...)
        queue = q
        if type then
            MSG[type](...)
        end
    end
}

Skynet.start(function()
    AddTimer(5*60*100, function () Connection.check_conns() end, "CheckConnections")
    Skynet.dispatch("lua", function (_, address, cmd, ...)
        local f = CMD[cmd]
        if f then
            Skynet.ret(Skynet.pack(f(address, ...)))
        end
    end)
    Skynet.register("GAMEGATE")
    Debug.print("====service GAMEGATE start====")
end)
```
首先看下CMD.open函数:socket = Socketdriver.listen(address, port) 将完成创建TCP socket -> bind -> listen的流程,并将包装过的逻辑层fd返回.Socketdriver.start(socket) 将对应的系统fd注册到epoll或kqueue中.<br>
服务在初始化的时候调用Skynet.register_protocol 注册了"socket"类型消息的unpack和dispatch方法,网络线程读取到某系统fd的网络流后会将其以"socket"类型的消息发给fd对应的注册服务.
服务收到"socket"消息后，通过unpack方法调用Netpack.filter进行网络流的解析
当有客户端connect login_port,网络线程完成accept后,会将新建socket包装过的逻辑层fd返回,这里会将消息传递给MSG.open函数做处理,这里同样会把新创建的fd注册到epoll或kqueue中,同时调用Connection.new_conn(fd)创建一个连接对象.
accept的fd接收到网络流会以消息传递给MSG.data(收到的流长度正好为2字节包头指定长度)和MSG.more(收到的流长度大于2字节包头指定长度),最后都会将完整包交给dispatch_msg函数处理.
同理,accept的fd断开连接时,会被MSG.close处理,产生错误时,会被MSG.error处理.
```lua
#login/command.lua
local Skynet = require "skynet"
local Utils = require "lualib.utils"
local Net = require "lualib.net"
local AgentApi = require "agent.api"

local M = {}

function M.unpack(fd, msg, sz)
    local proto,param = Net.unpack(msg, sz)
    if proto == "c2gs_login" then
        local pid = param.pid
        local name
        local is_new_role = false
        local mdb = Skynet.call("DB", "lua", "query_usr_data", pid)
        if mdb then
            name = mdb.name
        else
            name = Utils.random_name()
            is_new_role = true
            Skynet.send("DB", "lua", "set_usr_data", pid, {name = name, create_time = GetSecond()})
        end
        local agent = AgentApi.get_user_agent(pid)
        local mArgs = {pid = pid, agent = agent, name = name, fd = fd, is_new_role = is_new_role}
        Skynet.send("GAMEGATE", "lua", "loginsuc", fd, mArgs)
    end
end

return M
```
Skynet.newservice("gamelogin") 启动了登录中心服务,它的主要作用是sdk验证(这里没有这部分),去数据库加载玩家数据(实际应用中可能是去数据中心拉取账号下角色信息),<br>
并根据玩家pid分配一个agent服,然后发送"loginsuc"的命令给网关服务,下面看下loginsuc的处理
```lua
#service/gamegate.lua
function CMD.loginsuc(source, fd, mArgs)
    local conn = Connection.get_conn(fd)
    if not conn then
        Debug.print("login error:no conn",fd,Utils.table_str(mArgs))
        return
    end
    if conn.m_Agent then
        Debug.print("login error:re login",fd,Utils.table_str(mArgs))
        return
    end
    local oldcon = Connection.get_pid_conn(mArgs.pid)
    if oldcon then --已经登录的直接踢下线
        Connection.del_conn(oldcon.m_fd)
    end
    conn:loginsuc(mArgs.agent, mArgs.pid)
    Skynet.send(conn.m_Agent, "lua", "start", mArgs.pid, mArgs)
    Debug.print("login suc",fd,Utils.table_str(mArgs))
end
```
这里会获取CS connect时,Connection.new_conn建立的连接对象,并把pid和Agent的信息通过conn:loginsuc(mArgs.agent, mArgs.pid)记录到连接对象中,到此,玩家的登录验证就完成了.<br>
Skynet.send(conn.m_Agent, "lua", "start", mArgs.pid, mArgs) 将正式登录的消息发往对应agent服,根据玩家数据mArgs创建玩家对象,并向聊天服务注册自己的信息<br>
再看下dispatch_msg接口的实现
```lua
local function dispatch_msg(fd, msg, sz)
    local conn = Connection.get_conn(fd)
    if not conn then
        return
    end
    if conn.m_Agent then
        Skynet.send(conn.m_Agent, "lua", "unpack", conn.m_Pid, msg, sz)
    else
        Skynet.send("GAMELOGIN", "lua", "unpack", fd, msg, sz)
    end
end
```
易知网关收到包后,如果该连接已完成登录验证,则直接将消息发往其对应的agent服务,否则发送消息到登录中心去走上述验证流程<br>
Skynet.newservice("chat") 启动了聊天服务,服务启动时会创建世界频道,管理聊天相关逻辑.<br>
最后调用Skynet.exit()注销自己.至此init服务的全部内容便分析完了.<br>
下面是完整流程图:<br>
![flowchart](https://github.com/xingshuo/skynet-demo/blob/master/flowchart.png)