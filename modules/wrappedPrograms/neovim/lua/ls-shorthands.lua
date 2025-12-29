local ls = require "luasnip"
local M = {}

M.s = ls.snippet;
M.sn = ls.snippet_node;
M.isn = ls.indent_snippet_node;
M.t = ls.text_node;
M.i = ls.insert_node;
M.f = ls.function_node;
M.c = ls.choice_node;
M.d = ls.dynamic_node;
M.r = ls.restore_node;
M.events = require("luasnip.util.events");
M.ai = require("luasnip.nodes.absolute_indexer");
M.fmt = require("luasnip.extras.fmt").fmt;
M.lambda = require("luasnip.extras").l;
M.rep = require("luasnip.extras").rep;
M.p = require("luasnip.extras").partial;
M.m = require("luasnip.extras").match;
M.n = require("luasnip.extras").nonempty;
M.dl = require("luasnip.extras").dynamic_lambda;
M.fmta = require("luasnip.extras.fmt").fmta;
M.types = require("luasnip.util.types");
M.conds = require("luasnip.extras.expand_conditions");

return M
