// GET /db/{db}/groups/{id}
// Groups / List all group members
// 
// Alpha @ 0.1.23
//
// `200 OK`, 
// [Read-only](/docs/#/concept/read-only.md),
// [Paginated](/docs/#/concept/paginated.md).
//
// Returns all the contacts in the specified group, in arbitrary order.
// Supports `limit` and `offset` pagination. 
//
// ### Response format
//     { "list": [ <shortcontact>, ... ],
//       "count": <int> }
// - `list` is a list of contacts on the requested page, in 
//   [short format](/docs/#/contact/short-contact.js)
// - `count` is the total number of contacts in the group.

TEST("The response has valid return code and content type.", function(next) {
});

// # Examples
// 
// ### Example request
//     GET /db/0SNQc00211H/groups/0SNQe0032JZ?limit=3&offset=213
// 
// ### Example response
//     200 OK
//     Content-Type: application/json 
//     
//     { "list" : [ 
//       { "id" : "0SNQe00311H",
//         "name" : "test@runorg.com",
//         "gender" : null,
//         "pic" : "https://www.gravatar.com/avatar/1ed54d253636f5b33eff32c2d5573f70" },
//       { "id" : "0SNQg00511H",
//         "name" : "vnicollet@runorg.com",
//         "gender" : null,
//         "pic" : "https://www.gravatar.com/avatar/5a31b00f649489a9a24d3dc3e8b28060"} ],
//       "count" : 215 }

TEST("Returns correct number of contacts in count.", function(next) {
});

TEST("Returns data for all contacts.", function(next) {
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
 
// # Access restrictions
//
// Currently, anyone can list all members of a group with a token for the corresponding database. 
// This is subject to change in future versions.
