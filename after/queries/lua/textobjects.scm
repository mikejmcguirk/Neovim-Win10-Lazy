;extends

(string
  .
  ("\""
    "\"") .) @string.outer @string.inner

(string
  .
  ("'"
    "'") .) @string.outer @string.inner

(string
  content: (string_content) @string.inner) @string.outer
