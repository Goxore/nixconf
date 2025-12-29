return {
    "codecompanion.nvim",
    after = function()
        require("codecompanion").setup({
            ignore_warnings = true,
            strategies = {
                chat = {
                    adapter = "openrouter",
                    -- keymaps = {
                    -- 	submit = {
                    -- 		modes = { n = "<CR>" },
                    -- 		description = "Submit",
                    -- 		callback = function(chat)
                    -- 			chat:apply_model(current_model)
                    -- 			chat:submit()
                    -- 		end,
                    -- 	},
                    -- },
                },
                inline = {
                    adapter = "openrouter",
                },
            },
            adapters = {
                http = {
                    openrouter = function()
                        return require("codecompanion.adapters").extend("openai_compatible", {
                            env = {
                                url = "https://openrouter.ai/api",
                                api_key = "OPENROUTER_API_KEY",
                                chat_url = "/v1/chat/completions",
                                -- models_endpoint = "/v1/models",
                            },
                            schema = {
                                model = {
                                    -- default = "google/gemini-2.5-flash:online",
                                    -- default = "openai/gpt-5.2",
                                    default = "openai/gpt-oss-120b",
                                },
                            },
                        })
                    end,
                },
            },
            interactions = {
                chat = {
                    opts = {
                        -- system_prompt = "My new system prompt",
                    },
                },
            },
        })
    end
}
