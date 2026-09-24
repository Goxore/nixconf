return {
    "codecompanion.nvim",
    after = function()
        require("codecompanion").setup({
            ignore_warnings = true,
            adapters = {
                http = {
                    openrouter = function()
                        return require("codecompanion.adapters").extend("openai_compatible", {
                            env = {
                                url = "https://openrouter.ai/api",
                                api_key = "OPENROUTER_API_KEY",
                                chat_url = "/v1/chat/completions",
                            },
                            schema = {
                                model = {
                                    default = "openai/gpt-oss-120b",
                                },
                            },
                        })
                    end,
                },
            },
            interactions = {
                inline = {
                    adapter = "openrouter",
                },
                chat = {
                    adapter = "openrouter",
                    opts = {
                    },
                },
            },
        })
    end
}
