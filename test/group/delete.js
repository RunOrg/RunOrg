// DELETE /db/{db}/groups/{id}
// Groups / Delete a group
// 
// Alpha @ 0.1.23
//
// `202 Accepted`, 
// [Delayed](/docs/#/concept/delayed.md).
// [Idempotent](/docs/#/concept/idempotent.md).
//
// Deletes a group forever. The contacts remain in the database, but their 
// membership (to the deleted group) is forgotten.
//
// ### Response format
//     { "at": <clock> }
// 

TEST("The response has valid return code and content type.", function(next) {
});

// # Examples
// 
// ### Example request
//     DELETE /db/0SNQc00211H/groups/0SNQe0032JZ
// 
// ### Example response
//     202 Accepted
//     Content-Type: application/json 
//     
//     { "at": [[1, 334]] }

TEST("Deleted group disappears.", function(next) {
});

// # Errors
// 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(next) {
});

// - ... if group `{id}` does not exist in database `{db}`

TEST("Returns 404 when group does not exist.", function(next) {
});

// ## Returns `401 Unauthorized` 
// - ... if the provided token does not grant access to all contacts,
//   or no token was provided

TEST("Returns 401 when token is not valid.", function(next) {
});

// ## Returns `403 Forbidden` 
// - ... when attempting to delete group [`admin`](/docs/#/group/admin.md).

TEST("Returns 403 when deleting admin group.", function(next) {
});
 
// # Access restrictions
//
// Currently, anyone can delete a group with a token for the corresponding database. 
// This is subject to change in future versions.
