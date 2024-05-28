local deps = require 'sloth-flake.deps'
local priv = {
  is_loaded = {}
}

local M = {}

function M.get(name)
  return deps[name]
end

function M.init_all()
  for k, v in pairs(deps) do
    M.init(k)
  end
end

function M.config_all()
  for k, v in pairs(deps) do
    M.config(k)
  end
end

function M.init(name)
  local dep = M.get(name)
  if name == nil then
    -- TODO Report error ?
  elseif dep.init ~= nil then
    dep.init()
  end
end

function M.load(name)
  if name == nil then
    -- TODO Report error ?
  elseif M.is_loaded(name) then
    -- TODO Nothing todo
  else
    -- TODO Laod dynamic plugin
    priv.is_loaded[name] = true
  end
end

function M.config(name)
  local dep = M.get(name)
  if name == nil then
    -- TODO Report error ?
  elseif dep.config ~= nil then
    dep.config()
  end
end

function M.get_dep_names()
  local ret = {}
  for k, v in pairs(deps) do
    ret[#ret + 1] = v.name
  end
  return ret
end

function M.load_all()
  for k, _v in pairs(deps) do
    M.load(k)
  end
end

function M.is_loaded(name)
  return priv.is_loaded[name] or false
end

function M.setup(config)
  local post_init = config.post_init or function() end

  M.init_all()
  post_init()
  M.load_all()
  M.config_all()
end

return M
