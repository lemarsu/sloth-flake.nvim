local deps = require 'sloth-flake.deps'
local priv = {
  is = {
    init = {},
    import = {},
    config = {},
    shim = {},
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
  local function fn(name)
    local dep = M.get(name)
    if dep == nil then
      -- TODO Handle missing deps
      return
    end
    if priv.is[type][name] then
      return
    end
    priv.is[type][name] = true
    if dep[type] ~= nil then
      for _, child in ipairs(dep.dependencies) do
        fn(child)
      end
      dep[type]()
    end
  end
  return fn
end

M.init = load_fn('init')
M.config = load_fn('config')

function M.import(name)
  if M.is_imported(name) then
    return
  end
  local plugin = M.get(name)
  if plugin == nil then
    -- TODO Handle missing deps
    return
  end
  priv.is.import[name] = true
  if plugin.lazy then
    for _, dep in ipairs(plugin.dependencies) do
      M.import(dep)
    end
    vim.cmd("packadd " .. name)
  end
end

function M.is_imported(name)
  return priv.is.import[name] or false
end

function M.is_loaded(name)
  return priv.is.config[name] or false
end

function M.load(name)
  unshim_plugin(name)
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

function M.lazy_deps()
  return M.deps_iter_by(function(dep)
    return dep.lazy
  end):totable()
end

function lazy_load_cmd(dep, cmd)
  return function(param)
    M.load(dep.name)
    local bang = param.bang and '!' or ''
    vim.cmd(cmd .. bang .. ' ' .. param.args)
  end
end

function lazy_load_ft(dep)
  return function(param)
    M.load(dep.name)
    print(param.match)
    vim.api.nvim_exec_autocmds('FileType', {
      pattern = param.match,
    })
  end
end

function augroup_name(dep)
  return "Sloth-plugin-" .. dep.name
end

function shim_plugin(dep)
  if priv.is.shim[dep.name] then
    return
  end
  priv.is.shim[dep.name] = true

  if dep.cmd then
    for _, cmd in ipairs(dep.cmd) do
      vim.api.nvim_create_user_command(cmd, lazy_load_cmd(dep, cmd), {
        desc = "Sloth-flake placeholder for plugin " .. dep.name,
        nargs = '*',
        bang = true,
      })
    end
  end

  if dep.ft then
    local group_id = vim.api.nvim_create_augroup(augroup_name(dep), {
      clear = true,
    })
    vim.api.nvim_create_autocmd('FileType', {
      group = group_id,
      pattern = dep.ft,
      callback = lazy_load_ft(dep)
    })
  end
end

function unshim_plugin(name)
  local dep = M.get(name)
  if not priv.is.shim[name] then
    return
  end
  priv.is.shim[name] = nil

  if dep.cmd then
    for _, cmd in ipairs(dep.cmd) do
      vim.api.nvim_del_user_command(cmd)
    end
  end

  if dep.ft then
    vim.api.nvim_del_augroup_by_name(augroup_name(dep))
  end
end

function M.setup(config)
  local post_init = config and config.post_init or function() end

  M.init_non_lazy()
  post_init()
  M.import_non_lazy()
  M.config_non_lazy()

  local lazy_deps = M.lazy_deps()
  for _, dep in ipairs(lazy_deps) do
    shim_plugin(dep)
  end
end

return M
