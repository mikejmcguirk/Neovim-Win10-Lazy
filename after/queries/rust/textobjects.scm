; extends

(macro_definition) @preproc.outer

(macro_definition
  (macro_rule) @preproc.inner)

(attribute_item) @preproc.outer

(attribute_item
  (attribute
    arguments: (token_tree
      "," @preproc.outer @preproc.outer
      .
      (identifier) @preproc.inner @preproc.outer
      .
      (string_literal) @preproc.inner @preproc.outer)))

(attribute_item
  (attribute
    arguments: (token_tree
      .
      (identifier) @preproc.inner @preproc.outer
      .
      (string_literal) @preproc.inner @preproc.outer
      .
      ","? @preproc.outer)))

(attribute_item
  (attribute
    .
    (identifier) @preproc.inner
    .
    value: (string_literal) @preproc.inner .))

(attribute_item
  (attribute
    arguments: (token_tree
      .
      (identifier) @preproc.inner .)))

(attribute_item
  (attribute
    .
    (identifier) @preproc.inner .))

(inner_attribute_item) @preproc.outer

(inner_attribute_item
  (attribute
    arguments: (token_tree
      "," @preproc.outer @preproc.outer
      .
      (identifier) @preproc.inner @preproc.outer
      .
      (string_literal) @preproc.inner @preproc.outer)))

(inner_attribute_item
  (attribute
    arguments: (token_tree
      .
      (identifier) @preproc.inner @preproc.outer
      .
      (string_literal) @preproc.inner @preproc.outer
      .
      ","? @preproc.outer)))
