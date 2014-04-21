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

TODO("The response has valid return code and content type.", function(next) {
    Assert.fail();
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

TODO("Deleted group disappears.", function(next) {
    Assert.fail();
});

// # Errors
// 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TODO("Returns 404 when database does not exist.", function(next) {
    Assert.fail();
});

// - ... if group `{id}` does not exist in database `{db}`

TODO("Returns 404 when group does not exist.", function(next) {
    Assert.fail();
});

// ## Returns `401 Unauthorized` 
// - ... if the provided token does not grant access to all contacts,
//   or no token was provided

TODO("Returns 401 when token is not valid.", function(next) {
    Assert.fail();
});

// ## Returns `403 Forbidden` 
// - ... when attempting to delete group [`admin`](/docs/#/group/admin.md).

TODO("Returns 403 when deleting admin group.", function(next) {
    Assert.fail();
});
 
// # Access restrictions
//
// Currently, anyone can delete a group with a token for the corresponding database. 
// This is subject to change in future versions.
