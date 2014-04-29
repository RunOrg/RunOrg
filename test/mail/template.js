// JSON <template>
// Mail / A template object
// 
// Describes how an e-mail subject, text body or HTML 
// body should be build based on information about the
// sender, the recipient and the mail draft's own properties.
//
// A type of [template](/docs/#/types/template.js): refer to
// that document for general information about templates and template syntax,
// and to this document about specific variables available to e-mail templates.
//
// All e-mail templates (subject, text body and HTML body) support the same
// set of variables.
// 
// # Sender information
//
// The sender is specified as the `from` field during [draft 
// creation](/docs/#/mail/create.js). It is available from the template
// as variable `from` with the following properties: 
//
// - `from.email`: the e-mail address of the sender. This also appears
//   in the e-mail's `From:` header.
// - `from.givenName`: _optional_, the sender's given name, if any. 
// - `from.familyName`: _optional_, the sender's family name, if any.
// - `from.name`: _optional_, the sender's full name, if any.
// - `from.label`: a string describing the sender. This is usually 
//   either `email` or `name`, but may take other more relevant values.
//
// All these variables match their corresponding definition in the
// [person object](/docs/#/person/import.js).
//
// # Recipient information
//
// The available information is the same as for the _sender_ (above), 
// and can be accessed through variable `to`.
//
// ### Example use of 'to'
// 
//     { "script": "$0;to.label;$1",
//       "inline": [ "Dear ", ", ..." ] }
//
// # Custom e-mail data
// 
// This is a custom JSON object provided as the `custom` field during [draft 
// creation](/docs/#/mail/create.js). It is available from the template
// as variable `custom`.
//
// # Tracking links
//
// Variable `self` redirects to the URL provided as the `self` field 
// during [draft creation](/docs/#/mail/create.js). If that field was not
// provided, the variable is not available to the template. This redirection
// includes [authentication](/docs/#/mail/auth.md).
//
// This is known as the **self link**.
//
// ### Example use of 'self'
//
//     { "script": "$0;self",
//       "inline": [ "If you cannot view this e-mail, click here:" ] }
//
// Variable `track` is always available to the template, and contains a 
// tracking URL for that specific e-mail. Visiting the URL returns an empty
// one-pixel GIF image, and will count the e-mail as _opened_ but not
// _clicked_ (all other tracking links count as _clicked_). 
// 
// This is known as the **track link**.
//
// ### Example use of 'track'
//
//     { "script": "$0;track;$1",
//       "inline": [ "<img src='", "'/>" ] }
//
// Variables `urls` and `auth` are two arrays that both correspond to the
// `urls` field provided during [draft creation](/docs/#/mail/create.js).
// The difference is that `auth` includes [authentication](/docs/#/mail/auth.md)
// while `urls` does not.
//
// These are known as the **body links** and **authenticated body links**.
//
// ### Example use of 'url'
//     { "script": "$0;urls[0];$1",
//       "inline": [ "<h1><a href='", "'>Adorable kittens available</a></h1>" ] }
