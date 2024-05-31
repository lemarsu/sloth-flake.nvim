local Dep = require 'sloth-flake.dep'

local M = {}

local commands = {
  list = require 'sloth-flake.command.list',
  load = require 'sloth-flake.command.load',
  version = require 'sloth-flake.command.version',
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
