---
--  Query module.
--
--  @module     lupidary.query
--  @author     t-kenji <protect.2501@gmail.com>
--  @license    MIT
--  @copyright  2021 t-kenji

local _M = {_VERSION = '0.1.0'}
_M.__index = _M

local gsub, gmatch, format, byte, char = string.gsub, string.gmatch, string.format, string.byte, string.char

function _M.quote(str)
    str = gsub(str, '\n', '\r\n')
    str = gsub(str, '([^%w])', function (c)
        return format('%%%02X', byte(c))
    end)
    str = gsub(str, ' ', '+')
    return str
end

function _M.unquote(str)
    str = gsub(str, '+', ' ')
    str = gsub(str, '%%(%x%x)', function (h) return char(tonumber(h, 16)) end)
    str = gsub(str, '\r\n', '\n')
    return str
end

function _M.parse_qs(qs)
    local t = {}
    for k, v in gmatch(qs, '([^&=]+)=([^&=]*)&?') do
        t[_M.unquote(k)] = _M.unquote(v)
    end
    return t
end

return _M
