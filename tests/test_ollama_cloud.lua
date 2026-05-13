#!/usr/bin/env lua
-- Quick end-to-end test for Ollama Cloud

-- Setup package path for plugin modules (same logic as inspect.lua)
local function setupPaths()
    local info = debug.getinfo(1, "S")
    local script_path = info.source:match("@?(.*)")
    local script_dir = script_path:match("(.*/)") or "./"
    local plugin_dir = script_dir:gsub("tests/$", ""):gsub("/$", "")
    if plugin_dir == "" then plugin_dir = "." end
    package.path = script_dir .. "lib/?.lua;" ..
                   script_dir .. "?.lua;" ..
                   plugin_dir .. "/?.lua;" ..
                   package.path
    return plugin_dir
end

setupPaths()

require("mock_koreader")

local TestConfig = require("test_config")
local TestHelpers = require("test_helpers")

-- Load API keys
local api_keys = TestConfig.loadApiKeys()

-- Pick the provider to test
local provider = arg[1] or "ollama-cloud"
local model_name = arg[2]  -- optional model override

print("Testing provider: " .. provider)
print("------------------------------")

-- Load handler
local ok, handler = pcall(require, "koassistant_api." .. provider)
if not ok then
    print("Error loading handler: " .. tostring(handler))
    os.exit(1)
end

-- Patch for synchronous execution
TestHelpers.patchHandlerForSync(handler)

-- Build config
local api_key = api_keys[provider] or api_keys["ollama"] or ""
print("API key present: " .. (api_key ~= "" and "yes" or "no"))

local config_opts = {
    temperature = 0.7,
    max_tokens = 64,
}
if model_name then
    config_opts.model = model_name
end

local config = TestConfig.buildFullConfig(provider, api_key, config_opts)

print("Model: " .. (config.model or "(default)"))
print("Base URL: " .. (config.base_url or "(default)"))

-- Create test messages
local messages = {
    { role = "user", content = "Say hello in exactly 5 words." }
}

-- Invoke handler
print("\nSending request...")
local start = os.clock()
local query_ok, result = pcall(handler.query, handler, messages, config)
local elapsed = os.clock() - start

if not query_ok then
    print("Error: handler.query threw an exception")
    print(result)
    os.exit(1)
end

-- Parse result using TestHelpers
local success, text, _, reasoning = TestHelpers.handleQueryResult(true, result, elapsed)

print("\n=== Response ===")
if success then
    print(text)
    print("\nElapsed: " .. string.format("%.2f", elapsed) .. "s")
    if reasoning then
        print("Reasoning: " .. reasoning:sub(1, 120) .. (reasoning:len() > 120 and "..." or ""))
    end
else
    print("ERROR: " .. text)
    os.exit(1)
end
