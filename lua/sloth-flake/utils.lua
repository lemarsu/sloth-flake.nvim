local M = {}

function M.info(...)
  print(string.format(...))
end

function M.error(...)
  vim.api.nvim_err_writeln(string.format(...))
end

return M
