local Dep = require 'sloth-flake.dep'
local command = require 'sloth-flake.command'
local priv = {
  setup_called = false,
}

local M = {}

function M.get(name)
  return Dep.get(name)
end

function M.init_non_lazy()
  for _, dep in ipairs(M.non_lazy_deps()) do
    dep:init()
  end
end

function M.import_non_lazy()
  for _, dep in ipairs(M.non_lazy_deps()) do
    dep:import()
  end
end

function M.config_non_lazy()
  for _, dep in ipairs(M.non_lazy_deps()) do
    dep:config()
  end
end

function M.dep_names()
  return M.dep_names_by(function() return true end):totable()
end

function M.dep_names_by(fn)
  return M.deps_iter_by(fn):map(function(v) return v:name() end)
end

function M.deps_iter_by(fn)
  return vim.iter(Dep.all()):map(function(k, v) return v end):filter(fn)
end

function M.non_lazy_deps()
  return M.deps_iter_by(function(dep)
    return not dep:is_lazy()
  end):totable()
end

function M.lazy_deps()
  return M.deps_iter_by(function(dep)
    return dep:is_lazy()
  end):totable()
end

function M.setup(config)
  if priv.setup_called then
    return
  end
  priv.setup_called = true

  local post_init = config and config.post_init or function() end

  M.init_non_lazy()
  post_init()
  M.import_non_lazy()
  M.config_non_lazy()

  local lazy_deps = M.lazy_deps()
  for _, dep in ipairs(lazy_deps) do
    dep:shim()
  end

  command.register()
end

return M
