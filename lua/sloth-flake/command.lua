local Dep = require 'sloth-flake.dep'

local M = {}

local function vim_error(...)
  vim.api.nvim_err_writeln(string.format(...))
end

local commands = {
  list = function(args)
    local filter = args[1] or "all"
    local deps = vim.iter(Dep.all()):map(function (_, dep)
      return dep:name()
    end)
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
      local dep = Dep.get(plugin)
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

function M.register()
  vim.api.nvim_create_user_command('Sloth', sloth_cmd, {
    nargs = '*',
  })
end

return M
