local Base = require("avante.llm_tools.base")

---@class AvanteLLMTool
local M = setmetatable({}, Base)

M.name = "add_todos"

M.description = [[Adds a list of actionable todo items for coding tasks. This tool accepts an array of todo items that collectively represent a complete implementation plan for the user's coding request. Each item should be a discrete, executable step that moves the project toward completion. Use this tool after thoroughly analyzing the user's requirements to create a logical sequence of development tasks that include setup, implementation, testing, and validation steps.]]

---@type AvanteLLMToolParam
M.param = {
  type = "table",
  fields = {
    {
      name = "todos",
      description = [[Adds a list of actionable todo items for coding tasks. This tool accepts an array of todo items that collectively represent a complete implementation plan for the user's coding request. Each item should be a discrete, executable step that moves the project toward completion. Use this tool after thoroughly analyzing the user's requirements to create a logical sequence of development tasks that include setup, implementation, testing, and validation steps.]],
      type = "array",
      items = {
        name = "items",
        type = "object",
        description = "A single todo item representing one actionable step in the coding task completion process",
        fields = {
          {
            name = "id",
            description = [[Unique identifier for the TODO item. Use a descriptive, naming convention that reflects the task category and sequence. This ID should be meaningful for tracking progress and identifying dependencies between related tasks.",]],
            type = "string",
          },
          {
            name = "content",
            description = [[Clear, specific description of the task to be completed. Write in imperative form using action verbs. Include sufficient detail for implementation without being overly verbose. Specify file names, function names, or configuration details where relevant.]],
            type = "string",
          },
          {
            name = "status",
            description = [[Current completion status of the TODO item. Use 'todo' for all newly created items unless specifically updating existing tasks. Other statuses are for tracking progress: 'doing' for active work, 'done' for completed tasks, 'cancelled' for abandoned items.]],
            type = "string",
            choices = { "todo", "doing", "done", "cancelled" },
          },
          {
            name = "priority",
            description = [[Task priority level based on criticality and dependencies. Use 'high' for blocking tasks, foundational setup, or critical functionality that other tasks depend on. Use 'medium' for core feature implementation and important functionality. Use 'low' for polish, optimization, documentation, or nice-to-have features that don't block other work.]],
            type = "string",
            choices = { "low", "medium", "high" },
          },
        },
      },
    },
  },
}

---@type AvanteLLMToolReturn[]
M.returns = {
  {
    name = "success",
    description = "Whether the TODOs were added successfully",
    type = "boolean",
  },
  {
    name = "error",
    description = "Error message if the TODOs could not be updated",
    type = "string",
    optional = true,
  },
}

M.on_render = function() return {} end

---@type AvanteLLMToolFunc<{ todos: avante.TODO[] }>
function M.func(input, opts)
  local on_complete = opts.on_complete
  local sidebar = require("avante").get()
  if not sidebar then return false, "Avante sidebar not found" end
  local todos = input.todos

  -- Parse JSON string if needed
  if type(todos) == "string" then
    local ok, parsed_todos = pcall(vim.json.decode, todos)
    if not ok then
      return false, "Failed to parse todos JSON: " .. tostring(todos)
    end
    todos = parsed_todos
  end

  if not todos or #todos == 0 then return false, "No todos provided" end
  sidebar:update_todos(todos)
  if on_complete then
    on_complete(true, nil)
    return nil, nil
  end
  return true, nil
end

return M
