local deps = require 'sloth-flake.deps'
local priv = {
  is = {
    init = {},
    import = {},
    config = {},
  },
}

local M = {}

function M.get(name)
  return deps[name]
end

function M.init_non_lazy()
  for _, dep in ipairs(M.non_lazy_deps()) do
    M.init(dep.name)
  end
end

function M.import_non_lazy()
  for _, dep in ipairs(M.non_lazy_deps()) do
    M.import(dep.name)
  end
end

function M.config_non_lazy()
  for _, dep in ipairs(M.non_lazy_deps()) do
    M.config(dep.name)
  end
end

function load_fn(type)
  return function(name)
    local dep = M.get(name)
    if priv.is[type][name] then
      return
    end
    priv.is[type][name] = true
    if dep[type] ~= nil then
      dep[type]()
    end
  end
end

M.init = load_fn('init')
M.config = load_fn('config')

function M.import(name)
  if M.is_imported(name) then
    return
  end
  local plugin = M.get(name)
  priv.is.import[name] = true
  if plugin.lazy then
    vim.cmd("packadd " .. name)
  end
end

function M.is_imported(name)
  return priv.is.import[name] or false
end

function M.load(name)
  M.init(name)
  M.import(name)
  M.config(name)
end

function M.dep_names()
  return M.dep_names_by(function() return true end):totable()
end

function M.dep_names_by(fn)
  return M.deps_iter_by(fn):map(function(v) return v.name end)
end

function M.deps_iter_by(fn)
  return vim.iter(deps):map(function(k, v) return v end):filter(fn)
end

function M.non_lazy_deps()
  return M.deps_iter_by(function(dep)
    return not dep.lazy
  end):totable()
end

function M.setup(config)
  local post_init = config and config.post_init or function() end

  M.init_non_lazy()
  post_init()
  M.import_non_lazy()
  M.config_non_lazy()
end

return M
