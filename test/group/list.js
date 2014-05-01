// GET /db/{db}/groups
// Groups / List all groups in the database
//
// Alpha @ 0.1.27
// 
// `200 OK`, 
// [Read-only](/docs/#/concept/read-only.md),
// [Viewer-dependent](/docs/#/concept/viewer-dependent.md),
// [Paginated](/docs/#/concept/paginated.md).
//
// Returns all the groups in the database that can be seen by `{as}`,
// in arbitrary order. Supports `limit` and `offset` pagination. 
//
// ### Response format
//     { "list": [ <group-info>, ... ] }
// - `list` is a list of groups on the requested page, in 
//   [short format](/docs/#/group/group-info.js).

TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    
    return Query.get(["db/",db,"/groups"],auth)
	.assertStatus(200).assertIsJson();

});

// # Examples
// 
// ### Example request
//     GET /db/0SNQc00211H/groups/public?limit=3&offset=16
// 
// ### Example response
//     200 OK
//     Content-Type: application/json 
//     
//     { "list" : [ 
//       { "id" : "0SNQe00311H",
//         "label" : null,
//         "access": [ "list", "view" ],
//         "count": 25 },
//       { "id" : "0SNQg00511H",
//         "label" : "Team members",
//         "access" : [ "view" ]
//         "count": null } ] }

// # Errors
// 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.get("/db/00000000001/groups").assertStatus(404);
});

// 
// ## Returns `401 Unauthorized`
// - ... if the authorization token does not allow acting as `{as}`.

TEST("Returns 401 when token is invalid.", function(Query) {
    var db = Query.mkdb();
    return Query.get(["/db/",db,"/groups"],{id:"1234567890A",token:"1234567890A"})
	.assertStatus(401);
});
  
// # Access restrictions
//
// By definition, anyone can retrieve results from this API. If the viewer
// does not have **view** acces to any group, the returned list will be 
// empty.