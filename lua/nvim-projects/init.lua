local scan_dir = require("plenary.scandir").scan_dir

local M = {
  init_filename = nil,
  project_dirs = {},
  exclude = {},
  after_jump = nil,
  before_jump = nil,
}

local function is_dir(path)
  return vim.fn.isdirectory(path) == 1
end

function M.setup(input_opts)
  local opts = vim.deepcopy(input_opts)

  M.init_filename = nil
  M.project_dirs = {}

  if opts.init_filename then
    M.init_filename = opts.init_filename
    opts.init_filename = nil
  end

  if type(opts.project_dirs) ~= "table" then
    error("Option project_dirs is required and must be a table")
  end

  for _, path in ipairs(opts.project_dirs) do
    local normalized_path = vim.fs.normalize(path)

    if is_dir(normalized_path) then
      table.insert(M.project_dirs, path)
    else
      -- vim.notify(
      --   "Directory " .. normalized_path .. " does not exist",
      --   vim.log.levels.WARN,
      --   {
      --     title = "nvim-projects: Setup warning",
      --   }
      -- )
    end
  end

  opts.project_dirs = nil

  if opts.exclude ~= nil then
    M.exclude = opts.exclude
  end
  opts.exclude = nil

  for _, hook in ipairs({ "before_jump", "after_jump" }) do
    if opts[hook] then
      if type(opts[hook]) == "string" then
        local command = opts[hook]

        M[hook] = function(_)
          vim.cmd(command)
        end
      elseif type(opts[hook]) == "function" then
        M[hook] = opts[hook]
      else
        vim.notify(
          "Unexpected type of " .. hook .. " option: " .. type(opts[hook]),
          vim.log.levels.WARN,
          {
            title = "nvim-projects",
          }
        )
      end

      opts[hook] = nil
    end
  end

  M.define_commands()

  -- There should be no keys left in the opts at this point
  if next(opts) ~= nil then
    vim.notify("Unknown options: " .. vim.inspect(opts), vim.log.levels.WARN, {
      title = "nvim-projects: Setup warning",
    })
  end
end

function M.jump_to(project)
  local projects = M.gather_projects()

  if projects[project] == nil then
    vim.notify("Unknown project: " .. project, vim.log.levels.ERROR, {
      title = "nvim-projects",
    })
    return
  elseif type(projects[project]) == "table" then
    -- This could be handled more gracefully by automatically giving the
    -- project a unique name based on the parent directory, but I don't
    -- currently have a use case for it
    vim.notify(
      'Found multiple paths for project "'
      .. project
      .. '":\n- '
      .. table.concat(projects[project], "\n- "),
      vim.log.levels.ERROR,
      {
        title = "nvim-projects",
      }
    )
  else
    local project_path = projects[project]

    local buffers = vim.api.nvim_list_bufs()

    -- Check for unsaved buffers before cleaning up
    for _, buf in ipairs(buffers) do
      if vim.api.nvim_buf_get_option(buf, "modified") then
        vim.notify("Error: One or more unsaved buffers", vim.log.levels.ERROR, {
          title = "nvim-projects",
        })
        return
      end
    end

    if M.before_jump ~= nil then
      M.before_jump()
    end

    for _, buf in ipairs(buffers) do
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end

    vim.fn.chdir(project_path)

    vim.notify("Jumped to: " .. project_path, vim.log.levels.INFO, {
      title = "nvim-projects",
    })

    if M.init_filename ~= nil then
      -- Check if file M.init_filename exists in project_path
      if vim.fn.filereadable(M.init_filename) == 1 then
        vim.cmd("source " .. M.init_filename)

        vim.notify("Sourced " .. M.init_filename, vim.log.levels.INFO, {
          title = "nvim-projects",
        })
      end
    end

    if M.after_jump then
      M.after_jump(project_path)
    end
  end
end

-- Returns all project directories as a mapping from project name to full path
--
-- If the right-hand side of the mapping is a table rather than a string, it
-- means that the project exists in multiple project directories. This should
-- result in a warning if the user tries to jump to it.
--
function M.gather_projects()
  local projects = {}

  local function add_project(name, path)
    if is_dir(path) then
      if projects[name] == nil then
        projects[name] = path
      else
        if type(projects[name]) ~= "table" then
          projects[name] = { projects[name] }
        end

        table.insert(projects[name], path)
      end
    end
  end

  for _, project_dir in ipairs(M.project_dirs) do
    local abs_project_dir = vim.fs.normalize(project_dir)
    scan_dir(abs_project_dir, {
      only_dirs = true,
      depth = 5,
      hidden = true,
      search_pattern = function(entry)
        return entry:sub(-5) == "/.git"
      end,
      ---@param entry string
      on_insert = function(entry)
        local path = entry:sub(1, -6) -- Strip the ".git/" part
        local relative_path = path:sub(#abs_project_dir + 2, -1)

        -- Simple substring search of excluded terms
        if M.exclude then
          for _, pattern in ipairs(M.exclude) do
            if path:find(pattern, 1, true) then
              return
            end
          end
        end

        add_project(project_dir .. "/" .. relative_path, path)
      end,
    })
  end

  return projects
end

function M.define_commands()
  vim.api.nvim_create_user_command("Project", function(opts)
    M.jump_to(opts.args)
  end, {
    nargs = 1,
    complete = function(_, _, _)
      return vim.fn.keys(M.gather_projects())
    end,
  })
end

return M
