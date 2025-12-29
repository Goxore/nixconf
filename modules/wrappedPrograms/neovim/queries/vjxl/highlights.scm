(source_file) @punctuation

(Comment) @comment

(NodeRef) @keyword

(
    (Expression_Call 0: (Expression (Expression_Identifier) @function))
    (#set! "priority" 128)
)

(Identifier_name) @variable

(
  (Identifier_name) @variable.parameter
  (#has-ancestor? @variable.parameter Params)
)

; (
;   (Identifier_name) @function
;   (#has-ancestor? @function Expression_Call)
; )

(Node name: (Identifier name: (Identifier_name) @type)) 

(Literal_Integer) @number

(Literal_Bool) @boolean

(AwaitStatement__await_kw) @keyword

(Assign__kw) @keyword

(Assign__kw) @keyword

(NodeDefinition__def) @keyword

(PropDefinition__prop) @keyword

(ReturnStatement__return_kw) @keyword

(Literal_MultilineString_0) @string

(Prop
  name: (Identifier
    name: (Identifier_name) @variable.parameter))

(Literal_String_0) @string


(PropDefinition
  ; _prop: (PropDefinition__prop)
  data_type: (Identifier
    name: (Identifier_name)  @type)
  name: (Identifier
    name: (Identifier_name))
)

(Expression_Call 0: (Expression (Expression_Identifier) @function))
