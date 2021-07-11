---
--  Lupidary - Lua Network Application Gateway.
--
--  @module     lupidary
--  @author     t-kenji <protect.2501@gmail.com>
--  @license    MIT
--  @copyright  2021 t-kenji

local _M = {_VERSION = '0.1.0'}
_M.__index = _M

local socket = require('socket')
local uri = require('lupidary.uri')
local util = require('lupidary.util')

local match = string.match
local protect, try = socket.protect, socket.try
local flatten, indexof = util.flatten, util.indexof

local function resource_parse(s)
    local o = {}

    local u = uri.parse(s)
    local proto, attr = match(u:schema(), '^([^%+]+)%+*([%w]*)$')

    o.uri_ = u
    o.proto = proto
    o.is_listener = attr == 'listen'
    o.path = u:path()
    o.is_unix = #u:host() == 0
    return o
end

local function socket_open(res)
    if res.is_unix then
        local sock = require('socket.unix')[res.proto]()
        if res.is_listener then
            os.remove(res.path)
            assert(sock:bind(res.path))
            assert(sock:listen())
            assert(sock:settimeout(0))
        else
            local connect = protect(function ()
                try(sock:connect(res.path))
            end)
            connect()
        end
        return sock
    else
        error('socket is not supported')
    end
end

local socks = {}
local servers = setmetatable({}, {__mode = 'k'})
local retries = setmetatable({}, {__mode = 'k'})
local readers = setmetatable({}, {__mode = 'k'})
local writers = setmetatable({}, {__mode = 'k'})

local so_cls = {}

function so_cls:receive(pattern)
    if type(pattern) == 'number' and pattern <= 0 then
        return nil, 'timeout'
    end
    table.insert(readers, self.sock_)
    local pos = #readers
    coroutine.yield()
    table.remove(readers, pos)
    return self.sock_:receive(pattern)
end

function so_cls:send(message)
    self.sock_:send(message)
end

function so_cls:close()
    pcall(self.callbacks_.onclose, self)
    pcall(function ()
        self.sock_:close()
    end)

    if self.res_.is_client or self.res_.is_listener then
        socks[self.sock_] = nil
    else
        table.insert(retries, self.sock_)
    end
end

function _M.bind(uri, is_listener)
    local so = {
        res_ = resource_parse(uri),
        callbacks_ = {},
    }
    if is_listener then
        so.res_.is_listener = is_listener
    end

    function so:onopen(callback)
        self.callbacks_.onopen = callback
        return self
    end
    function so:onclose(callback)
        self.callbacks_.onclose = callback
        return self
    end
    function so:onerror(callback)
        self.callbacks_.onerror = callback
        return self
    end

    setmetatable(so, {__index = so_cls})
    table.insert(socks, so)
    return so
end

function _M.run()
    for _, so in ipairs(socks) do
        if so.res_.is_listener then
            so.sock_ = socket_open(so.res_)
            so.co_ = coroutine.create(function ()
                while true do
                    local c = assert(so.sock_:accept())
                    assert(c:settimeout(0))

                    local co = setmetatable({
                        res_ = {is_client = true},
                        sock_ = c,
                        callbacks_ = {
                            onopen = so.callbacks_.onopen,
                            onclose = so.callbacks_.onclose,
                            onerror = so.callbacks_.onerror,
                        }
                    }, {__index = so_cls})
                    co.co_ = coroutine.create(function ()
                        co.callbacks_.onopen(co)
                        co:close()
                    end)
                    socks[c] = co
                    local ok, err = coroutine.resume(co.co_)
                    if not ok then
                        pcall(co.callbacks_.onerror, co, err)
                        co:close()
                    end

                    coroutine.yield()
                end
            end)
            socks[so.sock_] = so
            table.insert(servers, so.sock_)
        else
            function so:connect()
                self.sock_ = socket_open(self.res_)
                self.co_ = coroutine.create(function ()
                    self.callbacks_.onopen(self)
                    self:close()
                end)
                if self.sock_:getsockname() then
                    local ok, err = coroutine.resume(self.co_)
                    if not ok then
                        pcall(self.callbacks_.onerror, self, err)
                        self:close()
                    end
                else
                    table.insert(retries, self.sock_)
                end
            end
            so:connect()
            socks[so.sock_] = so
        end
    end

    local sel = socket.select
    while true do
        local r, w, err = sel(flatten(servers, readers), writers, 1)
        if not err then
            for _, s in ipairs(flatten(r, w)) do
                local so = socks[s]
                local ok, err = coroutine.resume(so.co_)
                if not ok then
                    pcall(so.callbacks_.onerror, so, err)

                    for _, set in pairs{readers, writers} do
                        local i = indexof(set, so)
                        if i then
                            print('remove ' .. so .. ' at ' .. set .. '[' .. i .. ']')
                            table.remove(set, i)
                        end
                    end

                    so:close()
                end
            end
        else
            for i, s in ipairs(retries) do
                local so = socks[s]
                socks[s] = nil
                retries[i] = nil

                so:connect()
                socks[so.sock_] = so
            end
        end
    end
end

_M.scgi = require('lupidary.scgi')
_M.query = require('lupidary.query')

return _M
