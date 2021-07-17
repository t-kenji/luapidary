---
--  A tiny URI parser.
--
--  @module     lupidary.uri
--  @author     t-kenji <protect.2501@gmail.com>
--  @license    MIT
--  @copyright  2021 t-kenji

local _M = {}
_M.__index = _M

local match = string.match

local uri_cls = {}

function uri_cls:schema()
    return self.schema_
end

function uri_cls:host()
    return self.host_
end

function uri_cls:path()
    return self.path_
end

function uri_cls:query()
    return self.query_
end

function _M.parse(uri)
    local s = tostring(uri or '')
    local o = {}

    local schema, host, path, query = match(s, '^([%w][%w%.%+%-]*)%://([^/]*)([^?]+)?*([^#]*)')
    o.schema_ = schema or ''
    o.host_ = host or ''
    o.path_ = path or ''
    o.query_ = query or ''

    setmetatable(o, {
        __index = uri_cls,
        __tostring = function (self)
            return self.schema_ .. '://' .. self.host_ .. self.path_ .. '?' .. self.query_
        end,
    })
    return o
end

return _M
