package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

-- Mock io.popen
local original_popen = io.popen
io.popen = function(cmd)
    if cmd:match("list%-channels") then
        return {
            lines = function()
                local channels = {"mock_files", "mock_text", "mock_git"}
                local i = 0
                return function()
                    i = i + 1
                    return channels[i]
                end
            end,
            close = function() end
        }
    end
    return original_popen(cmd)
end

-- Mock vim global first
_G.vim = {
    fn = {
        fnameescape = function(x) return x end,
        tempname = function() return "/tmp/mock_temp" end,
        executable = function() return 1 end, -- Assume tv is installed
        filereadable = function() return 1 end,
        isdirectory = function() return 0 end,
        shellescape = function(x) return "'" .. x .. "'" end,
    },
    api = {
        nvim_win_set_cursor = function(win, pos)
            -- Verify pos are numbers
            if type(pos[1]) ~= "number" or type(pos[2]) ~= "number" then
                error("nvim_win_set_cursor: expected numbers, got " .. tostring(pos[1]) .. ", " .. tostring(pos[2]))
            end
            print("nvim_win_set_cursor called with " .. pos[1] .. ", " .. pos[2])
        end,
        nvim_err_writeln = function(msg) print("Error: " .. msg) end,
        nvim_create_buf = function() return 1 end,
        nvim_open_win = function() return 1 end,
        nvim_list_uis = function() return {{width=100, height=50}} end,
        nvim_win_is_valid = function() return true end,
        nvim_win_close = function() end,
    },
    cmd = function(cmd) print("vim.cmd: " .. cmd) end,
    split = function(s, sep, plain)
        local parts = {}
        local pattern = string.format("([^%s]+)", sep)
        for part in string.gmatch(s, pattern) do
            table.insert(parts, part)
        end
        return parts
    end,
    tbl_deep_extend = function(_, t1, t2)
        local t = {}
        for k,v in pairs(t1) do t[k] = v end
        for k,v in pairs(t2) do t[k] = v end
        return t
    end,
    o = { shell = "/bin/sh" },
    keymap = { set = function() end },
}

-- Load the module to test
local television = require("television")

print("Loaded television module")

-- Test 1: Text channel parsing (standard)
print("\nTest 1: Standard text parsing (file.txt:10:5)")
television.default_handler("file.txt:10:5", "enter", "text")

-- Test 2: Text channel parsing (path with colons)
print("\nTest 2: Path with colons (/path/to/file:name.txt:20:10)")
-- Expected: file=/path/to/file:name.txt, line=20, col=10
-- Should pass now
local status, err = pcall(function()
    television.default_handler("/path/to/file:name.txt:20:10", "enter", "text")
end)
if not status then
    print("FAILED: " .. err)
else
    print("SUCCESS")
end

-- Test 3: Windows path
print("\nTest 3: Windows path (C:\\path\\to\\file.txt:30:15)")
-- Expected: C:\path\to\file.txt, line=30, col=15
-- Should pass now
status, err = pcall(function()
    television.default_handler("C:\\path\\to\\file.txt:30:15", "enter", "text")
end)
if not status then
    print("FAILED: " .. err)
else
    print("SUCCESS")
end

-- Test 4: Missing column (file.txt:40)
print("\nTest 4: Missing column (file.txt:40)")
television.default_handler("file.txt:40", "enter", "text")

-- Test 5: Invalid number
print("\nTest 5: Invalid number (file.txt:invalid:5)")
-- Should NOT crash, but just skip setting cursor (or handle gracefully)
status, err = pcall(function()
    television.default_handler("file.txt:invalid:5", "enter", "text")
end)
if not status then
    print("FAILED (Crashed): " .. err)
else
    print("SUCCESS (Did not crash)")
end

-- Test 6: List channels (verify cache and mock)
print("\nTest 6: List channels")
local channels = television.list_channels()
print("Channels found: " .. table.concat(channels, ", "))
if #channels == 3 and channels[1] == "mock_files" then
    print("SUCCESS: Channels mocked correctly")
else
    print("FAILED: Channels not as expected")
end

-- Test 7: Cache invalidation
print("\nTest 7: Cache invalidation")
television.setup({})
-- Mock different output if needed, but here we just check if it calls popen again?
-- Or just check if cache is cleared.
if television.channels_cache == nil then
    print("SUCCESS: Cache cleared after setup")
else
    print("FAILED: Cache not cleared")
end
