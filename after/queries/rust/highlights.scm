;extends

(extern_crate_declaration
  ((crate)
    name: (identifier) @module))

(use_declaration
  argument: (scoped_use_list
    path: (identifier)
    list: (use_list
      (identifier) @module)))

(use_declaration
  argument: (use_list
    (scoped_identifier
      path: (identifier)
      name: (identifier) @module)))

(attribute_item
  (attribute
    (identifier) @preproc))

(inner_attribute_item
  (attribute
    (identifier) @preproc))

(attribute
  (scoped_identifier
    (identifier) @preproc .))
