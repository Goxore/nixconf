[
  (Literal_String)
  (Comment)
]  @leaf

(Comment) @allow_blank_line_before @append_hardline

(Statement) @allow_blank_line_before @append_hardline

(Statement) @allow_blank_line_before

(
  (NodeBody__start) @append_begin_scope @append_indent_start
  (NodeBody__end) @append_end_scope @prepend_indent_end @prepend_empty_softline

  (#scope_id! "tuple")
)

; (NodeItem) @prepend_empty_softline
(
  (NodeBody
    items: (NodeBody_items_vec_contents
      (NodeItem) @prepend_empty_softline 
      (NodeItem) @prepend_empty_softline 
      (NodeItem) @prepend_empty_softline 
      (NodeItem) @prepend_empty_softline
      (NodeItem) @prepend_empty_softline
      (_)*))
)

(NodeItem_Child) @prepend_hardline

((Node
(NodeBody
(NodeBody_items_vec_contents
(NodeItem
(NodeItem_Child))
)))) @prepend_hardline 

(AwaitStatement__await_kw) @prepend_hardline

(NodeDefinition__def)  @prepend_hardline
