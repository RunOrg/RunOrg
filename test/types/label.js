// JSON <label>
// Types / A short human-readable label or text
// 
// A label is a short UTF-8 string, no longer than 80 code points, and not empty.
// 
// The label is always trimmed and cleaned up by the RunOrg server. Initial and 
// final whitespace (understood as javascript's regex character `\s`) are dropped, 
// all whitespace characters are turned into either normal or non-breaking spaces 
// (depending on their nature) and multiple consecutive whitespace characters are 
// turned into only one (a normal space, or a non-breaking space if only 
// non-breaking spaces are found). 
//
// Length tests occur after trimming and cleanup.
//
// Note that in JavaScript, `string.length` returns the size in an UTF16 encoding, 
// which is always greater than the number of code points. It is therefore acceptable
// to use `label.trim().replace('\s+',' ').length < 80` as a test on the maximum 
// length of the string.
//
// # Errors
// 
// - `Empty label` occurs when the trimmed and cleaned label has length zero.
// - `Label is X code points long, only 80 allowed.` occurs when the trimmed and 
//   cleaned label is longer than 80 code points.
