local Utils = require("avante.utils")
local Helpers = require("avante.llm_tools.helpers")
local Base = require("avante.llm_tools.base")

---@class AvanteLLMTool
local M = setmetatable({}, Base)

M.name = "ls"

M.description = "List the contents of a directory. The quick tool to use for discovery, before using more targeted tools like semantic search or file reading. Useful to try to understand the file structure before diving deeper into specific files. Can be used to explore the codebase."

---@type AvanteLLMToolParam
M.param = {
  type = "table",
  fields = {
    {
      name = "explanation",
      description = "One sentence explanation as to why this tool is being used, and how it contributes to the goal.",
      type = "string",
    },
    {
      name = "path",
      description = "Path to list contents of, relative to the workspace root.",
      type = "string",
    },
    {
      name = "max_depth",
      description = "Maximum depth of the directory to list contents of.",
      type = "integer",
    },
  },
  usage = {
    explanation = "One sentence explanation as to why this tool is being used, and how it contributes to the goal.",
    path = "Path to list contents of, relative to the workspace root.",
    max_depth = "Maximum depth of the directory to list contents of.",
  },
}

---@type AvanteLLMToolReturn[]
M.returns = {
  {
    name = "entries",
    description = "List of file paths and directory paths in the given directory",
    type = "string[]",
  },
  {
    name = "error",
    description = "Error message if the directory was not listed successfully",
    type = "string",
    optional = true,
  },
}

---@type AvanteLLMToolFunc<{ path: string, max_depth?: integer }>
function M.func(input, opts)
  local on_log = opts.on_log
  local abs_path = Helpers.get_abs_path(input.path)
  if not Helpers.has_permission_to_access(abs_path) then return "", "No permission to access path: " .. abs_path end
  if on_log then on_log("path: " .. abs_path) end
  if on_log then on_log("max depth: " .. tostring(input.max_depth)) end
  local files = Utils.scan_directory({
    directory = abs_path,
    add_dirs = true,
    max_depth = input.max_depth,
  })
  local filepaths = {}
  for _, file in ipairs(files) do
    local uniform_path = Utils.uniform_path(file)
    table.insert(filepaths, uniform_path)
  end
  return vim.json.encode(filepaths), nil
end

return M
