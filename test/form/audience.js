// JSON <form-audience>
// Forms / Form audience and access levels
//
// ### Example audience
//     "audience" : {
//       "admin": {},
//       "fill": "anyone"
//     }
//
// Forms support the following [access levels](/docs/#/concept/audience.md): 
//
// # Administrating the form
//
// The **admin** access allows any operations that can be performed on 
// the form. 
//
// It includes **fill** access. 
//
// # Filling the form 
//
// The **fill** access allows:
//
// - Reading a form's meta-data (but not all fields)
// - Filling the form. Which instances can be filled depends on the
//   ownership of those instances. For `"contact"` ownership, for example,
//   a contact may only fill his own instance. 
// - Viewing any filled form instance they can re-fill. 
//
