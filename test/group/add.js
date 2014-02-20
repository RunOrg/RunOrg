// POST /db/{db}/groups/{id}/add
// Groups / Add contacts to a group
// 
// Alpha @ 0.1.23
//
// `202 Accepted`,
// [Delayed](/docs/#/concept/delayed.md),
// [Idempotent](/docs/#/concept/idempotent.md).
//
// Adds the provided contacts to the specified group. Contacts already
// in the group are silently ignored. 
// 
// ### Request format
//     [ <id>, ... ]
//
// The contacts are passed as an array of identifiers. 

TEST("The response has valid return code and content type.", function(next) {
    Assert.fail();
});

TEST("An empty list is acceptable.", function(next) {
    Assert.fail();
});

TEST("Duplicate contacts in list are acceptable.", function(next) {
    Assert.fail();
});

TEST("Contacts already in group are ignored.", function(next) {
    Assert.fail();
});

TEST("Added contacts can be found in the group.", function(next) {
    Assert.fail();
});

// # Examples
// 
// ### Example request
//     POST /db/0SNQc00211H/groups/0SNQe0032JZ/add
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
    Assert.fail();
});

// - ... if group `{id}` does not exist in database `{db}`

TEST("Returns 404 when group does not exist.", function(next) {
    Assert.fail();
});

// - ... if one of the added contacts does not exist in database `{db}`

TEST("Returns 404 when contact does not exist.", function(next) {
    Assert.fail();
});

// ## Returns `401 Unauthorized` 
// - ... if the provided token does not grant adding to the group,
//   or no token was provided

TEST("Returns 401 when token is not valid.", function(next) {
    Assert.fail();
});
 
// # Access restrictions
//
// Currently, anyone can add contacts to a group with a token for the corresponding database. 
// This is subject to change in future versions.

