// POST /db/{db}/groups/{id}/remove
// Groups / Remove contacts from a group
// 
// Alpha @ 0.1.23
//
// `202 Accepted`,
// [Delayed](/docs/#/concept/delayed.md),
// [Idempotent](/docs/#/concept/idempotent.md).
//
// Removes the provided contacts from the specified group. Contacts not 
// in the group are silently ignored. 
// 
// ### Request format
//     [ <id>, ... ]
//
// The contacts are passed as an array of identifiers. 

TEST("The response has valid return code and content type.", function(next) {
});

TEST("An empty list is acceptable.", function(next) {
});

TEST("Duplicate contacts in list are acceptable.", function(next) {
});

TEST("Contacts not in group are ignored.", function(next) {
});

TEST("Removed contacts can not be found in the group.", function(next) {
});

// # Examples
// 
// ### Example request
//     POST /db/0SNQc00211H/groups/0SNQe0032JZ/remove
//     Content-Type: application/json
//
//     [ "0SNQe00311H", "0SNQg00511H" ]
//
// ### Example response
//     202 Accepted
//     Content-Type: application/json
//
//     { "at": [[1,113]] }
//
// # Errors
// 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(next) {
});

// - ... if group `{id}` does not exist in database `{db}`

TEST("Returns 404 when group does not exist.", function(next) {
});

// - ... if one of the removed contacts does not exist in database `{db}`

TEST("Returns 404 when contact does not exist.", function(next) {
});

// ## Returns `401 Unauthorized` 
// - ... if the provided token does not grant removing from the group,
//   or no token was provided

TEST("Returns 401 when token is not valid.", function(next) {
});
 
// # Access restrictions
//
// Currently, anyone can remove contacts from a group with a token for the corresponding database. 
// This is subject to change in future versions.

