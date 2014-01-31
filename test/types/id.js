// JSON <id>
// Types / A short unique identifier
//
// RunOrg generates unique identifiers, which are guaranteed to be unique within a given 
// database. They are 11 characters long, and a given identifier will be sorted 
// (lexicographically) after any identifiers generated earlier, though this does not
// always imply the corresponding objects have been created in that order.
// 
// Other processes, notably [custom identifiers](/docs/#/types/custom-id.js), support
// the creation of identifiers between 1 and 10 characters long. A typical example
// is the `admin` group. 
//
// An unique identifier satisfies the regular expression `[a-zA-Z0-9]{1,11}`. 
//
// ### Example value
//     "0Et9j0026rO"