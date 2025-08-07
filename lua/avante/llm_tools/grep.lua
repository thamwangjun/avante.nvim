local Path = require("plenary.path")
local Utils = require("avante.utils")
local Helpers = require("avante.llm_tools.helpers")
local Base = require("avante.llm_tools.base")

---@class AvanteLLMTool
local M = setmetatable({}, Base)

M.name = "grep_search"

M.description = [[### Instructions:
This is best for finding exact text matches or regex patterns.
This is preferred over semantic search when we know the exact symbol/function name/etc. to search in some set of directories/file types.
Use this tool to run fast, exact regex searches over text files using the `ripgrep` engine.
To avoid overwhelming output, the results are capped at 50 matches.
Use the include or exclude patterns to filter the search scope by file type or specific paths.
- Always escape special regex characters: ( ) [ ] { } + * ? ^ $ | . \
- Use `\` to escape any of these characters when they appear in your search string.
- Do NOT perform fuzzy or semantic matches.
- Return only a valid regex pattern string.
### Examples:
| Literal               | Regex Pattern            |
|-----------------------|--------------------------|
| function(             | function\(               |
| value[index]          | value\[index\]           |
| file.txt              | file\.txt                |
| user|admin            | user\|admin              |
| path\to\file          | path\\to\\file           |
| hello world           | hello world              |
| foo\(bar\)            | foo\\(bar\\)             |]]

---@type AvanteLLMToolParam
M.param = {
  type = "table",
  fields = {
    {
      name = "path",
      description = "Relative path to the project directory for the search",
      type = "string",
    },
    {
      name = "query",
      description = "The regex pattern to search for",
      type = "string",
    },
    {
      name = "case_sensitive",
      description = "Whether the search should be case sensitive",
      type = "boolean",
      default = false,
      optional = true,
    },
    {
      name = "include_pattern",
      description = "Glob pattern for files to include (e.g. '*.ts' for TypeScript files)",
      type = "string",
      optional = true,
    },
    {
      name = "exclude_pattern",
      description = "Glob pattern for files to exclude (e.g. '*.ts' for TypeScript files)",
      type = "string",
      optional = true,
    },
    {
      name = "explanation",
      description = "One sentence explanation as to why this tool is being used, and how it contributes to the goal.",
      type = "string",
    },
  },
  usage = {
    path = "Relative path to the project directory for the search",
    query = "The regex pattern to search for",
    case_sensitive = "Whether the search should be case sensitive",
    include_pattern = "Glob pattern for files to include (e.g. '*.ts' for TypeScript files)",
    exclude_pattern = "Glob pattern for files to exclude (e.g. '*.ts' for TypeScript files)",
    explanation = "One sentence explanation as to why this tool is being used, and how it contributes to the goal.",
  },
}

---@type AvanteLLMToolReturn[]
M.returns = {
  {
    name = "files",
    description = "List of files that match the keyword",
    type = "string",
  },
  {
    name = "error",
    description = "Error message if the directory was not searched successfully",
    type = "string",
    optional = true,
  },
}

---@type AvanteLLMToolFunc<{ path: string, query: string, case_sensitive?: boolean, include_pattern?: string, exclude_pattern?: string }>
function M.func(input, opts)
  local on_log = opts.on_log

  local abs_path = Helpers.get_abs_path(input.path)
  if not Helpers.has_permission_to_access(abs_path) then return "", "No permission to access path: " .. abs_path end
  if not Path:new(abs_path):exists() then return "", "No such file or directory: " .. abs_path end

  ---check if any search cmd is available
  local search_cmd = vim.fn.exepath("grep")
  if search_cmd == "" then search_cmd = vim.fn.exepath("ag") end
  if search_cmd == "" then search_cmd = vim.fn.exepath("ack") end
  if search_cmd == "" then search_cmd = vim.fn.exepath("rg") end
  if search_cmd == "" then return "", "No search command found" end

  ---execute the search command
  local cmd = ""
  if search_cmd:find("rg") then
    cmd = string.format("%s --files-with-matches --hidden", search_cmd)
    if input.case_sensitive then
      cmd = string.format("%s --case-sensitive", cmd)
    else
      cmd = string.format("%s --ignore-case", cmd)
    end
    if input.include_pattern then cmd = string.format("%s --glob '%s'", cmd, input.include_pattern) end
    if input.exclude_pattern then cmd = string.format("%s --glob '!%s'", cmd, input.exclude_pattern) end
    cmd = string.format("%s '%s' %s", cmd, input.query, abs_path)
  elseif search_cmd:find("ag") then
    cmd = string.format("%s --nocolor --nogroup --hidden", search_cmd)
    if input.case_sensitive then cmd = string.format("%s --case-sensitive", cmd) end
    if input.include_pattern then cmd = string.format("%s --ignore '!%s'", cmd, input.include_pattern) end
    if input.exclude_pattern then cmd = string.format("%s --ignore '%s'", cmd, input.exclude_pattern) end
    cmd = string.format("%s '%s' %s", cmd, input.query, abs_path)
  elseif search_cmd:find("ack") then
    cmd = string.format("%s --nocolor --nogroup --hidden", search_cmd)
    if input.case_sensitive then cmd = string.format("%s --smart-case", cmd) end
    if input.exclude_pattern then cmd = string.format("%s --ignore-dir '%s'", cmd, input.exclude_pattern) end
    cmd = string.format("%s '%s' %s", cmd, input.query, abs_path)
  elseif search_cmd:find("grep") then
    cmd = string.format("cd %s && git ls-files -co --exclude-standard | xargs %s -rH", abs_path, search_cmd, abs_path)
    if not input.case_sensitive then cmd = string.format("%s -i", cmd) end
    if input.include_pattern then cmd = string.format("%s --include '%s'", cmd, input.include_pattern) end
    if input.exclude_pattern then cmd = string.format("%s --exclude '%s'", cmd, input.exclude_pattern) end
    cmd = string.format("%s '%s'", cmd, input.query)
  end

  Utils.debug("cmd", cmd)
  if on_log then on_log("Running command: " .. cmd) end
  local result = vim.fn.system(cmd)

  local filepaths = vim.split(result, "\n")

  return vim.json.encode(filepaths), nil
end

return M
