-- Ollama Cloud handler
-- Thin wrapper around the standard Ollama handler that points to ollama.com's API.
-- Uses the same protocol (/api/chat), just a different endpoint + model naming.

local OllamaHandler = require("koassistant_api.ollama")
local ResponseParser = require("koassistant_api.response_parser")

-- Create a new instance to avoid mutating the shared Ollama handler
local OllamaCloudHandler = {}
for k, v in pairs(OllamaHandler) do
    OllamaCloudHandler[k] = v
end
-- Clone the metatable so method calls (:) still find 'self'
setmetatable(OllamaCloudHandler, getmetatable(OllamaHandler))

-- Key: our lookups in Defaults, response parsing, etc. will use this provider id
OllamaCloudHandler.provider_id = "ollama-cloud"

function OllamaCloudHandler:query(message_history, config)
    local result = OllamaHandler.query(self, message_history, config)

    -- Wrap _response_parser to use the shared "ollama" response format
    -- (RESPONSE_TRANSFORMERS does not have a separate entry for ollama-cloud)
    if type(result) == "table" and result._response_parser then
        result._response_parser = function(response)
            local success, content, reasoning = ResponseParser:parseResponse(response, "ollama")
            if not success then
                return false, content  -- content is the error message on failure
            end
            return true, content, reasoning
        end
    end

    return result
end

return OllamaCloudHandler
