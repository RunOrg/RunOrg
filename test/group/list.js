// GET /db/{db}/groups
// Groups / List all groups in the database
//
// Beta @ 0.9.0
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

TEST("Initially empty.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);

    return Query.get(["/db/",db,"/groups"],auth).then(function(d,s,r) {
	return Assert.areEqual([],d.list);
    });

});

TEST("Need view access to see elements.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);

    var id1 = Query.post(["/db/",db,"/groups"],{}, auth).id();
    var id2 = Query.post(["/db/",db,"/groups"],{"audience":{"view":"anyone"}},auth).id();

    var peon = Query.auth(db,false,"peon@runorg.com");

    return $.when(id1,id2).then(function() {
	return Query.get(["/db/",db,"/groups"],peon).then(function(d,s,r) {

	    var expected = [
		{ "id" : id2,
		  "label" : null,
		  "access" : [ "view" ],
		  "count" : null }
	    ];

	    return Assert.areEqual(expected,d.list);

	});
    });

});

// # Errors
// 
// ## Returns `401 Unauthorized`
// - ... if the authorization token does not allow acting as `{as}`.

TEST("Returns 401 when token is invalid.", function(Query) {
    var db = Query.mkdb();
    return Query.get(["/db/",db,"/groups"],{id:"1234567890A",token:"1234567890A"})
	.assertStatus(401);
});

// 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.get("/db/00000000001/groups").assertStatus(404);
});
  
// # Access restrictions
//
// By definition, anyone can retrieve results from this API. If the viewer
// does not have **view** acces to any group, the returned list will be 
// empty.