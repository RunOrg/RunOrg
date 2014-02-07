// GET /db/{db}/groups/{id}/info
// Groups / Read group information
// 
// Alpha @ 0.1.23
//
// `200 OK`,
// [Read-only](/docs/#/concept/read-only.md).
//
// Returns all available information about a group (except, of course, the full
// list of its members). 
// 
// ### Response format
//     { "id": <id>,
//       "label": <label> | null,
//       "count": <int> }
// - `id` is the group [identifier](/docs/#/types/id.js) (that was passed in the URL).
// - `label` is an optional [human-readable name](/docs/#/types/label.js) for the group.
// - `count` is the number of contacts in the group.

TEST("The response has valid return code and content type.", function(next) {
});

// # Examples
// 
// ### Example request
//     GET /db/0SNQc00211H/groups/0SNQe0032JZ/info
// 
// ### Example response
//     200 OK
//     Content-Type: application/json 
//     
//     { "id": "0SNQe0032JZ",
//       "label": "Team members",
//       "count" : 215 }

TEST("Returns correct number of contacts in count.", function(next) {
});

TEST("Returns correct group label.", function(next) {
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
// - ... if the provided token does not grant access to group information,
//   or no token was provided

TEST("Returns 401 when token is not valid.", function(next) {
});
 
// # Access restrictions
//
// Currently, anyone can read about a group with a token for the corresponding database. 
// This is subject to change in future versions.
