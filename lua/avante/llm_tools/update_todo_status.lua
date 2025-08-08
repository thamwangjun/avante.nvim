local Base = require("avante.llm_tools.base")
local Utils = require("avante.utils")

---@class AvanteLLMTool
local M = setmetatable({}, Base)

M.name = "update_todo_status"

M.description = [[Updates the completion status of a specific todo item during the coding task lifecycle. This tool enables real-time tracking of progress as work advances through different phases. Use this tool to maintain accurate project state, communicate progress to users, and manage workflow transitions. Essential for providing visibility into task completion and identifying bottlenecks or dependencies that may require attention.]]

---@type AvanteLLMToolParam
M.param = {
  type = "table",
  fields = {
    {
      name = "id",
      description = [[The unique identifier of the TODO item to update. Must exactly match the ID used when the item was created with add_todos. Use the same naming convention, Case-sensitive and must be an exact string match.]],
      type = "string",
    },
    {
      name = "status",
      description = [[The new status to assign to the TODO item. Choose based on current work state: 'todo' for pending tasks not yet started, 'doing' for actively in-progress work, 'done' for completed tasks that meet acceptance criteria, 'cancelled' for tasks that are no longer needed or have been superseded by alternative approaches. Status transitions should follow logical progression: todo → doing → done, or todo/doing → cancelled.]],
      type = "string",
      choices = { "todo", "doing", "done", "cancelled" },
    },
  },
}

---@type AvanteLLMToolReturn[]
M.returns = {
  {
    name = "success",
    description = "Whether the TODO was updated successfully",
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

---@type AvanteLLMToolFunc<{ id: string, status: string }>
function M.func(input, opts)
  local on_complete = opts.on_complete
  local sidebar = require("avante").get()
  if not sidebar then return false, "Avante sidebar not found" end
  local todos = sidebar.chat_history.todos
  if not todos or #todos == 0 then return false, "No todos found" end
  if type(todos) ~= "table" then
    Utils.error("Invalid todos type: " .. type(todos) .. ". Content: " .. vim.inspect(todos))
    return false, "Invalid todos format"
  end
  for _, todo in ipairs(todos) do
    if tostring(todo.id) == tostring(input.id) then
      todo.status = input.status
      break
    end
  end
  sidebar:update_todos(todos)
  if on_complete then
    on_complete(true, nil)
    return nil, nil
  end
  return true, nil
end

return M
