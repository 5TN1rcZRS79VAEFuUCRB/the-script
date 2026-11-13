--!nonstrict
-- the-script's to-do button: "today · week" from `todo json` every 30 s, or a focus session's
-- countdown from $XDG_RUNTIME_DIR/todo-focus. Click: the list (todo-pick).

local HOME = noctalia.getenv("HOME") or ""
local RUN = noctalia.getenv("XDG_RUNTIME_DIR") or "/tmp"
local text, tip = "…", "To-do"
local lastLoad = -1e9
local focusEnd, focusName = 0, ""

local UNIT = { m = 60, h = 3600, d = 86400, w = 604800 }

local function secs(left)
  local s = 0
  for n, u in string.gmatch(left or "", "(%d+)%s*([mhdw])") do
    s += tonumber(n) * (UNIT[u] or 0)
  end
  return s
end

local function load()
  noctalia.runAsync({ HOME .. "/.local/bin/todo", "json" }, function(res)
    if res.exitCode ~= 0 then
      text, tip = "?", "To-do couldn't load"
      return
    end
    local m = noctalia.json.decode(res.stdout)
    if type(m) ~= "table" then
      text, tip = "?", "To-do couldn't load"
      return
    end
    local now = os.time()
    local t = os.date("*t", now)
    local midnight = os.time({ year = t.year, month = t.month, day = t.day, hour = 23, min = 59, sec = 59 })
    local today, week = 0, 0
    for _, task in ipairs(m.tasks or {}) do
      local s = task.late and 0 or secs(task.left)
      if task.late or now + s <= midnight then today += 1 end
      if task.late or s < 7 * 86400 then week += 1 end
    end
    text = `{today} · {week}`
    local first = (m.tasks or {})[1]
    tip = `{today} due today, {week} in the next 7 days\n`
      .. (first and `Next: {first.title} ({first.left})` or "All caught up")
      .. `\n{m.pts or 0} points, {m.streak or 0}-day streak`
  end, 20000)
end

local function readFocus()
  focusEnd = 0
  local line = noctalia.readFile(RUN .. "/todo-focus")
  if line then
    local e, _, name = string.match(line, "^(%d+)%s+(%S+)%s*(.-)%s*$")
    focusEnd, focusName = tonumber(e) or 0, name or ""
  end
end

function update()
  noctalia.setUpdateInterval(1000)
  if noctalia.nowMs() - lastLoad >= 30000 then
    lastLoad = noctalia.nowMs()
    load()
  end
  readFocus()
  local left = focusEnd - os.time()
  barWidget.setGlyph(left > 0 and "clock" or "checklist")
  if left > 0 then
    barWidget.setText(string.format("%d:%02d", left // 60, left % 60))
    barWidget.setTooltip(focusName ~= "" and focusName or "Focus session")
  else
    barWidget.setText(text)
    barWidget.setTooltip(tip)
  end
end

function onClick()
  noctalia.runAsync(HOME .. "/.local/bin/todo-pick")
  lastLoad = -1e9
end

function onIpc(event)
  if event == "refresh" then lastLoad = -1e9 end
end
