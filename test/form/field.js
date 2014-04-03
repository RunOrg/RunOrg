// JSON <field>
// Forms / A field in a form
// 
// RunOrg handles [forms](/docs/#/form.md) as collections of fields. An individual
// field carries meta-data that tells the client how it should be displayed, and 
// tells the server how it should be validated (when a form is filled) and 
// summarized (for generating form-level statistics).
// 
// ### Format of a field
//     { "id" : <id>,
//       "label" : <string>,
//       "kind" : <kind>,
//       "choices" : [ <choice>, ... ],
//       "custom" : <json>,
//       "required" : true | false }
// - `id` is an alphanumeric identifier, between 1 and 11 characters long. Two fields 
//   in the same form should have different identifiers. 
// - `label` is a human-readable label, to be displayed along with the field by
//   the client application.
// - `kind` describes the kind of field (text, date, single choice, etc). Read more on
//   individual field kinds below. 
// - `choices` is an _optional_ list of choices (treated as empty if missing). Only 
//   used by the `"single"` and `"multiple"` kinds of fields.
// - `custom` is an _optional_, arbitrary chunk of JSON that is stored by RunOrg and 
//   returned as-is by the API. The client applications may use this to configure the 
//   display and behavior of the form. 
// - `required` is an _optional_ flag that marks a field as mandatory. The meaning of
//   this requirement depends on the field kind. If omitted, treated as `false`. 
//
// Some kinds of fields (namely, the multiple-choice and single-choice fields) will use
// a list of possible choices. These choices are numbered on their position (starting 
// with zero). 
//
// A choice may be either a string representing a [human-readable label](/docs/#/types/label.js), 
// or an arbitrary blob of JSON that will be stored and returned as-is by the API. 
//
// # Text fields
//
//     "kind" : "text", 
// 
// A standard text field, designed to contain unformatted text. Usually rendered as
// a `<input type="text"/>` or `<textarea></textarea>` in HTML. 
//
// ### Example value
//     "Hello, world!"
//
// Acceptable values are JSON strings and `null`. When marked as `required`, acceptable 
// values are non-empty JSON strings.
//  
// # Rich text fields
//
//     "kind" : "rich",
// 
// A rich text field, designed to contain HTML-formatted text (more specifically, a
// RunOrg-specific [subset of HTML](/docs/#/types/rich.js)). Usually rendered as a 
// WYSIWYG textarea.
//
// ### Example value
//     "<h1>This is a title</h1><p>This is a <strong>bold</strong> paragraph</p>" 
//
// Acceptable values are JSON strings (containing appropriately-formated rich text)
// and `null`. When marked as `required`, acceptable values are non-empty JSON
// strings. 
// 
// # Date/time fields
//
//    "kind" : "time",
//
// A date or date-time field. Usually rendered as a `<input type="date">` or 
// `<input type="datetime">` in HTML5.    
//
// ### Example value
//     "2014-04-19T18:42:53Z"
//
// Acceptable values are [dates](/docs/#/types/date.js) : JSON strings containing 
// an ISO-8601 formatted date (`yyyy-mm-dd`) or date-time (`yyyy-mm-ddThh:ii:ssZ`), 
// or `null`. When marked as `required`, only dates are acceptable values.  
//
// # Single choice field
//
//    "kind" : "single",
//    "choices" : [...],
// 
// A single-choice question. Uses the list of `choices` to determine what the 
// possible choices are. Usually rendered as a list of `<input type="radio"/>` 
// or a `<select></select>` field. 
// 
// ### Example value
//     2
// 
// Acceptable values are integers between `0` and `n-1` (with `n` being the 
// number of possible choices), representing the picked choice. `null` is 
// also a possible value, unless the field is marked as `required`.
//
// # Multiple choice field
//
//    "kind" : "multiple",
//    "choices" : [...], 
// 
// A multiple choice question. Uses the list of `choices` to determine what the 
// possible choices are. Usually rendered as a list of `<input type="checkbox"/>` 
// fields.
//
// ### Example value
//     [2,4]
//  
// Acceptable values are lists of integers between `0` and `n-1` (with `n` being
// the number of possible choices), representing all the picked choices. There is
// no restriction on how many times a given choice can appear, though when returned
// by the API, each choice will appear no more than once. `null` is also a possible
// value. 
//
// When marked as `required`, the field will accept neither `null` nor `[]`. 
//
// # Arbitrary JSON fields
//
//    "kind" : "json",
// 
// A custom field, for your convenience. Stores arbitrary JSON data and returns it
// as-is. No server-side processing will occur (including statistics). 
// 
// ### Example value
//     { "PayerID" : 185530,
//       "BeneficiaryID" : 185530,
//       "Amount" : 2000,
//       "PayerWalletID" : 0,
//       "BeneficiaryWalletID" : 196902 }
//
// Any JSON value is acceptable. When the field is marked as `required`, however,
// the following values are not acceptable: `null`, `""`, `[]` and `{}`. 
//
// # Contact fields
// 
//    "kind" : "contact",
//
// A field that references a contact in the current database, through its ID. 
// Usually displayed as an auto-completion component that uses the 
// [contact search API](/docs/#/contact/search.js) to find contact identifiers. 
//
// ### Example value
//     "0SNQg00511H"
//
// Acceptable values are contact identifiers that match a contact in the 
// current database. If the field is not marked as `required`, then `null` 
// is also an acceptable value. 
//
// # More field types
// 
// Currently, there are plans for new field types to be implemented. More
// will become available in time. 

