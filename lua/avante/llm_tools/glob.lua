local Helpers = require("avante.llm_tools.helpers")
local Base = require("avante.llm_tools.base")

---@class AvanteLLMTool
local M = setmetatable({}, Base)

M.name = "glob"

M.description = [[### Instructions:
Fast file pattern matching tool that works with any codebase size.
Supports glob patterns like "**/*.js" or "src/**/*.ts".

**Note on planning**: When doing an open ended search that may require multiple rounds of globbing and grepping, use planning tools (todo related tools) instead.

**Batch processing capability**: This tool has the capability to be called multiple times in a single response. It is always better to speculatively perform multiple searches as a batch that are potentially useful.

Search for files in the workspace by glob pattern. This only returns the paths of matching files. Use this tool when you know the exact filename pattern of the files you're searching for. Glob patterns match from the root of the workspace folder. 

### Examples:
- **/*.{js,ts} to match all js/ts files in the workspace.
- src/** to match all files under the top-level src folder.
- **/foo/**/*.js to match all js files under any foo folder in the workspace.
]]

---@type AvanteLLMToolParam
M.param = {
  type = "table",
  fields = {
    {
      name = "pattern",
      description = "Glob pattern to search for",
      type = "string",
    },
    {
      name = "path",
      description = "Relative path to the project directory, as cwd",
      type = "string",
    },
    {
      name = "explanation",
      description = "One sentence explanation as to why this tool is being used, and how it contributes to the goal.",
      type = "string",
    },
  },
  usage = {
    pattern = "Glob pattern to search for",
    path = "Relative path to the project directory, as cwd",
    explanation = "One sentence explanation as to why this tool is being used, and how it contributes to the goal.",
  },
}

---@type AvanteLLMToolReturn[]
M.returns = {
  {
    name = "matches",
    description = "List of matched files",
    type = "string",
  },
  {
    name = "err",
    description = "Error message",
    type = "string",
    optional = true,
  },
}

---@type AvanteLLMToolFunc<{ path: string, pattern: string }>
function M.func(input, opts)
  local on_log = opts.on_log
  local on_complete = opts.on_complete
  local abs_path = Helpers.get_abs_path(input.path)
  if not Helpers.has_permission_to_access(abs_path) then return "", "No permission to access path: " .. abs_path end
  if on_log then on_log("path: " .. abs_path) end
  if on_log then on_log("pattern: " .. input.pattern) end
  local files = vim.fn.glob(abs_path .. "/" .. input.pattern, true, true)
  local truncated_files = {}
  local is_truncated = false
  local size = 0
  for _, file in ipairs(files) do
    size = size + #file
    if size > 1024 * 10 then
      is_truncated = true
      break
    end
    table.insert(truncated_files, file)
  end
  local result = vim.json.encode({
    matches = truncated_files,
    is_truncated = is_truncated,
  })
  if not on_complete then return result, nil end
  on_complete(result, nil)
end

return M
