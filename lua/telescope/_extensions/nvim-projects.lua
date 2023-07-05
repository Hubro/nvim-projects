local telescope = require("telescope")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local conf = require("telescope.config").values

local projects = require("nvim-projects")

-- Shows the available projects using Telescope
local function projects_telescope(opts)
  local project_dirs = vim.fn.keys(projects.gather_projects())
  table.sort(project_dirs)

  pickers
    .new(opts, {
      prompt_title = "Projects",

      finder = finders.new_table({
        results = project_dirs,
        entry_maker = function(entry)
          return {
            value = entry,
            display = entry,
            ordinal = entry,
            preview_command = function(preview_entry, bufnr)
              vim.api.nvim_buf_set_lines(
                bufnr,
                0,
                -1,
                false,
                "I am the preview for " .. preview_entry
              )
            end,
          }
        end,
      }),

      attach_mappings = function()
        actions.select_default:replace(function(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)

          projects.jump_to(selection.value)
        end)

        return true
      end,

      sorter = conf.generic_sorter(opts),
    })
    :find()
end

return telescope.register_extension({
  exports = {
    ["nvim-projects"] = projects_telescope,
  },
})
