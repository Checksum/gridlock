-- Gridlock
-- An nginx lua script for managing app maintenance
-- By Srinath Sankar
-- https://github.com/Checksum/gridlock
-- Copyright Srinath Sankar
-- MIT License

local redis = require "resty.redis"
local client = redis:new()
local ok, err = client:connect(ngx.var.REDIS_HOST, ngx.var.REDIS_PORT)

if not ok then
  ngx.log(ngx.ERR, "Error connecting to redis")
  return
end

local res, err = client:get("gridlock.readonly")
if res == "true" then
  -- readonly denotes that the site is in readonly mode
  ngx.ctx.readonly = true
  local method = ngx.req.get_method()

  -- Set header for upstream server
  ngx.req.set_header("X-READONLY", "true")

  -- Allow readonly HTTP methods like GET, HEAD
  if method == "GET" or method == "HEAD" then
    return
  end

  -- Enforce the readonly rule in two ways:
  -- redirect: ignores all write requests and redirects to referer
  -- forbit: throws a 403 error
  -- Note: This is not an ideal UX
  local mode, err = client:get("gridlock.readonly.mode")
  if mode then
    -- If a list of paths is allowed explicitly by
    -- setting "ngx.readonly.allowed", do not block them.
    -- This is to allow URLs like login, logout, etc
    local allow = false
    local allowed, err = client:lrange("gridlock.readonly.allowed", 0, 1)
    if allowed then
      for i, url in ipairs(allowed) do
        if url == ngx.var.uri then
          allow = true
          ngx.log(ngx.INFO, "Allowing " .. method .. ngx.var.uri .. " in readonly mode")
          break
        end
      end
    end

    if not allow then
      if mode == "redirect" then
        local redirect_url, err = client:get("gridlock.readonly.redirect_url")
        if not redirect_url then
          redirect_url = ngx.req.get_headers("referer")
        end
        -- Send out a custom header so that if it was an XMLHttpRequest,
        -- the handler can decide on the appropriate response
        ngx.header["X-READONLY-REDIRECT"] = redirect_url
        ngx.redirect(redirect_url, ngx.HTTP_MOVED_TEMPORARILY)
      elseif mode == "forbid" then
        ngx.exit(ngx.HTTP_FORBIDDEN)
      end
    end
  end
end

-- Instead of closing the connection, pool it
local ok, err = client:set_keepalive(3000, 2)
