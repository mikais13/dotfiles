-- Gruvbox, plus a picker to flip variant/contrast live.
-- Open with :Themery (or <leader>th). Selection persists to the Themery
-- block in lua/config/lazy.lua.
return {
	{
		"ellisonleao/gruvbox.nvim",
		lazy = false,
		priority = 1000,
		opts = { contrast = "hard" }, -- "Gruvbox Dark Hard"
	},
	{
		"sainnhe/gruvbox-material",
		lazy = false,
		priority = 1000,
		init = function()
			vim.g.gruvbox_material_background = "hard"
			vim.g.gruvbox_material_better_performance = 1
		end,
	},
	{
		"zaldih/themery.nvim",
		lazy = false,
		keys = {
			{ "<leader>th", "<cmd>Themery<cr>", desc = "Pick colorscheme" },
		},
		config = function()
			require("themery").setup({
				livePreview = true,
				themes = {
					"gruvbox",
					"gruvbox-material",
					"retrobox", -- builtin, gruvbox-ish
					"habamax", -- builtin
				},
			})
		end,
	},
}
