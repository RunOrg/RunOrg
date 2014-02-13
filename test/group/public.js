// GET /db/{db}/groups/public
// Groups / List all public groups in the database
//
// Alpha @ 0.1.27
// 
// `200 OK`, 
// [Read-only](/docs/#/concept/read-only.md),
// [Paginated](/docs/#/concept/paginated.md).
//
// Returns all the groups in the database that can be seen without
// authentication, in arbitrary order.
// Supports `limit` and `offset` pagination. 
//
// ### Response format
//     { "list": [ <groupinfo>, ... ],
//       "count": <int> }
// - `list` is a list of groups on the requested page, in 
//   [short format](/docs/#/group/group-info.js)
// - `count` is the total number of public groups in the database.

TEST("The response has valid return code and content type.", function(next) {

    var db = Query.mkdb(),
        token = Query.auth(db),
        response = Test.query("GET",["db/",db,"/groups/public"],{},token).response();

    response.map(function(r) {
	Assert.areEqual(200, r.status).then();
	Assert.isTrue(r.responseJSON, "Response type is JSON").then();
    }).then(next);

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
//         "count": 25 },
//       { "id" : "0SNQg00511H",
//         "label" : "Team members",
//         "count": 8 } ],
//       "count" : 18 }

TEST("Returns correct number of groups in count.", function(next) {
});

TEST("Returns data for all public groups.", function(next) {
});

TEST("Do not return non-public groups.", function(next) {
});

// # Errors
// 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(next) {
    Test.query("GET","/db/00000000001/groups/public").error(404).then(next);
});
 
// # Access restrictions
//
// By definition, anyone can retrieve results from this API. If there are no public
// groups, an empty list will be returned.