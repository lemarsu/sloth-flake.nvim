local Dep = require 'sloth-flake.dep'
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

local function vim_error(...)
  vim.api.nvim_err_writeln(string.format(...))
end

local commands = {
  list = function(args)
    local filter = args[1] or "all"
    local deps = vim.iter(M.dep_names())
    if filter == "all" then
      -- Nothing to do
    elseif filter == "loaded" then
      deps = deps:filter(function (dep)
        return Dep.get(dep):is_loaded()
      end)
    elseif filter == "notloaded" then
      deps = deps:filter(function (dep)
        return not Dep.get(dep):is_loaded()
      end)
    else
      vim_error([[No Sloth list filter "%s".]], cmd)
      vim_error("Filters are: all, loaded, notloaded")
      return
    end
    deps = deps:totable()
    table.sort(deps)
    for _, dep in ipairs(deps) do
      print(string.format("- %s", dep))
    end
  end,

  load = function(plugins)
    if #plugins == 0 then
      vim_error("You should at least give a plugin to load!")
      return
    end
    for _, plugin in ipairs(plugins) do
      local dep = M.get(plugin)
      if dep ~= nil then
        dep:load()
      end
    end
  end,

  version = function()
    local version = require('sloth-flake.version')
    print(string.format('Sloth v%s', version()))
  end,
}

function sloth_cmd(param)
  local args = param.fargs
  local cmd = args[1] or "list";
  table.remove(args, 1)
  local fn = commands[cmd]
  if fn then
    fn(args)
  else
    vim.api.nvim_err_writeln(string.format([[No Sloth subcommand "%s"]], cmd))
  end
end

function register_command()
  vim.api.nvim_create_user_command('Sloth', sloth_cmd, {
    nargs = '*',
  })
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

  register_command()
end

return M
