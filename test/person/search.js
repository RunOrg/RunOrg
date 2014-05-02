// GET /db/{db}/people/search
// People / Search for people by name
//
// Beta @ 0.9.0
// 
// `200 OK`, 
// [Read-only](/docs/#/concept/read-only.md).
//
// Returns a set of people from the database that match the search query. 
// 
// ### Response format
//     { "list": [ <short>, ... ] }
// - `list` is a list of people matching the query, in order of 
//   decreasing relevance. 

TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.get(["db/",db,"/people?q="],auth)
	.assertStatus(200).assertIsJson();

});

//
// The search query is provided as GET parameter `q`.
//
// # Examples
//
// ### Example request
//     GET /db/0SNQc00211H/people?limit=3&q=vic
//
// ### Example response
//     200 OK
//     Content-Type: application/json
// 
//     { "list" : [ 
//       { "id" : "0SNQg00511H",
//         "label" : "Victor Nicollet",
//         "gender" : "M",
//         "pic" : "https://www.gravatar.com/avatar/5a31b00f649489a9a24d3dc3e8b28060" } ] }

TEST("Returns data for matching people.", function(Query) {

    var example = [ { "email": "test@runorg.com" },
		    { "email" : "vnicollet@runorg.com",
		      "name" : "Victor Nicollet",
		      "gender" : "M" } ];

    var db   = Query.mkdb();
    var auth = Query.auth(db);
    return Query.post(["db/",db,"/people/import"],example,auth).then(function(d,s,r) {

	var ids = d.imported;	    
	var list = Query.get(["db/",db,"/people/search?q=vic"],auth)
	    .then(function(d) { return d.list; });

	var expected = [ 
	    { "id" : ids[1], 
	      "label" : "Victor Nicollet",
	      "gender" : "M", 
	      "pic" : "https://www.gravatar.com/avatar/5a31b00f649489a9a24d3dc3e8b28060?d=identicon" } ];
	
	return Assert.areEqual(expected, list);

    });
});

//
// # Errors
//
// ## Returns `401 Unauthorized` 
// - ... if the provided token does not allow acting as `{as}`

TEST("Returns 401 when token is not valid.", function(Query) {
    var db = Query.mkdb();
    return Query.get(["db/",db,"/people/search?q="],{id:"01234567890",token:"01234567890"})
	.assertStatus(401);
});
 
// ## Returns `403 Forbidden` 
// - ... if `{as}` is not a database administrator

TEST("Returns 403 when not an admin.", function(Query) {
    var db = Query.mkdb();
    var peon = Query.auth(db, false);
    return Query.get(["db/",db,"/people/search?q="],peon).assertStatus(403);
});

// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.get("/db/00000000001/people/search?q=").assertStatus(404);
});

// # Access restrictions
//
// Only [database administrators](/docs/#/group/admin.md) may search for
// people by name.