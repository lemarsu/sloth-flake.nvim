local M = {}

function M.error(...)
  vim.api.nvim_err_writeln(string.format(...))
end

return M
