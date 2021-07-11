---
--  SCGI module.
--
--  @module     lupidary.scgi
--  @author     t-kenji <protect.2501@gmail.com>
--  @license    MIT
--  @copyright  2021 t-kenji

local _M = {_VERSION = '0.1.0'}
_M.__index = _M

local gmatch = string.gmatch
local insert, unpack = table.insert, table.unpack

local mt = {}
mt.__index = mt

function mt:receive(...)
    return self.so_:receive(...)
end

function mt:send(...)
    return self.so_:send(...)
end

function mt:run(application)
    local function read_len()
        local str = ''
        while true do
            local c, err = self:receive(1)
            if err ~= nil and err ~= 'timeout' then
                error(err)
            end

            if c == nil or c == ':' then
                break
            end

            if c ~= nil then
                str = str .. c
            end
        end
        return tonumber(str)
    end

    local len = read_len()
    if not len then
        error('netstring size not found in SCGI request')
    end

    local str = self:receive(len)
    local headers = {}
    for k, v in gmatch(str, '(%Z+)%z(%Z*)%z') do
        if headers[k] then
            error('duplicate SCGI header encountered ' .. k)
        end

        insert(headers, k)
        headers[k] = v
    end

    -- skip ','
    self:receive(1)

    local environ = {}
    for k, v in pairs(headers) do
        if type(k) ~= 'number' then
            environ[k] = v
        end
    end
    environ['scgi.input'] = self.so_
    environ['scgi.errors'] = io.stderr

    local headers_set = {}
    local headers_sent = {}

    local function write(data)
        if #headers_set == 0 then
            error('write() before start_response()')
        elseif #headers_sent == 0 then
            headers_sent = headers_set
            local status, response_headers = unpack(headers_set)
            self:send('Status: ' .. status .. '\r\n')
            for k, v in pairs(response_headers) do
                if type(v) == 'string' then
                    self:send(k .. ': ' .. v .. '\r\n')
                elseif type(v) == 'table' then
                    for i = 1, #v do
                        self:send(k .. ': ' .. v[i] .. '\r\n')
                    end
                end
            end
            self:send('\r\n')
        end

        if type(data) == 'string' then
            self:send(data .. '\r\n')
        elseif type(data) == 'table' then
            for _, v in ipairs(data) do
                self:send(v .. '\r\n')
            end
        elseif type(data) == 'function' then
            for v in data  do
                self:send(v .. '\r\n')
            end
        end
    end

    local function start_response(status, response_headers)
        if #headers_set > 0 then
            error('headers already set')
        end

        headers_set = {status, response_headers}

        return write
    end

    local ok, err = pcall(function ()
        write(application(environ, start_response))
    end)
    if not ok then
        error(err)
    end
end

function _M.wrap(so)
    local o = {
        so_ = so,
    }

    setmetatable(o, {__index = mt})
    return o
end

return _M
