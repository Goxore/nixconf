(Literal_Bool) @fold

(AwaitStatement__await_kw) @fold

(SpawnStatement__spawn_kw) @fold
(AddStatement__kw) @fold
(ImportStatement__import_kw) @fold
(Statement_WaitUntilStatement) @fold

(Assign__kw) @fold

(Assign__kw) @fold

(NodeDefinition__def) @fold

(PropDefinition__prop) @fold

(EmbeddedScript) @fold

(Statement) @fold

(
  (SourceFile_statements_vec_element) @fold.start
  .
  (SourceFile_statements_vec_element)+ @fold.end
) @fold

