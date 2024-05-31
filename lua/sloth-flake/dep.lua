local raw_deps = require 'sloth-flake.dependencies'

local M = {}

function M.new(values)
  return setmetatable({
    priv = {
      init = false,
      import = false,
      config = false,
      shim = false,
    },
    values = values,
  }, {
    __index = M,
  })
end

function M:name()
  return self.values.name
end

function M:dependencies()
  local ret = {}
  for _, name in ipairs(self.values.dependencies) do
    local dep = M.get(name)
    if dep ~= nil then
      ret[#ret + 1] = dep
    end
  end
  return ret
end

function M:cmd()
  return self.values.cmd
end

function M:ft()
  return self.values.ft
end

function M:is_lazy()
  return self.values.lazy or false
end

function M:is_imported()
  return self.priv.import
end

function M:is_loaded()
  -- last step is config, so a plugin is loaded if its config has run
  return self.priv.config
end

function load_fn(type)
  local function fn(self)
    if self.priv[type] then
      return
    end
    self.priv[type] = true

    for _, dep in ipairs(self:dependencies()) do
      fn(dep)
    end

    if self.values[type] ~= nil then
      self.values[type]()
    end
  end
  return fn
end

M.init = load_fn('init')
M.config = load_fn('config')

function M:import()
  if self:is_imported() then
    return
  end
  self.priv.import = true

  for _, dep in ipairs(self:dependencies()) do
    dep:import()
  end

  if self:is_lazy() then
    vim.cmd("packadd " .. self:name())
  end
end

function M:load()
  self:unshim()
  self:init()
  self:import()
  self:config()
end

function M:augroup_name()
  return "Sloth-plugin-" .. self:name()
end

function M:lazy_load_cmd(cmd)
  return function(param)
    self:load()
    local bang = param.bang and '!' or ''
    vim.cmd(cmd .. bang .. ' ' .. param.args)
  end
end

function M:lazy_load_ft()
  return function(param)
    self:load()
    vim.api.nvim_exec_autocmds('FileType', {
      pattern = param.match,
    })
  end
end

function M:shim()
  if self.priv.shim then
    return
  end
  self.priv.shim = true

  if self:cmd() then
    for _, cmd in ipairs(self:cmd()) do
      vim.api.nvim_create_user_command(cmd, self:lazy_load_cmd(cmd), {
        desc = "Sloth-flake placeholder for plugin " .. self:name(),
        nargs = '*',
        bang = true,
      })
    end
  end

  if self:ft() then
    local group_id = vim.api.nvim_create_augroup(self:augroup_name(), {
      clear = true,
    })
    vim.api.nvim_create_autocmd('FileType', {
      group = group_id,
      pattern = self:ft(),
      callback = self:lazy_load_ft()
    })
  end
end

function M:unshim()
  if not self.priv.shim then
    return
  end
  self.priv.shim = nil

  if self:cmd() then
    for _, cmd in ipairs(self:cmd()) do
      vim.api.nvim_del_user_command(cmd)
    end
  end

  if self:ft() then
    vim.api.nvim_del_augroup_by_name(self:augroup_name())
  end
end

local deps = {}
for k, v in pairs(raw_deps) do
  deps[k] = M.new(v)
end

function M.get(name)
  return deps[name]
end

function M.all()
  return deps
end

return M
