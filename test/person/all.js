// GET /db/{db}/people
// People / List all people in the database
//
// Beta @ 0.9.0
// 
// `200 OK`, 
// [Read-only](/docs/#/concept/read-only.md),
// [Paginated](/docs/#/concept/paginated.md).
//
// Returns all the people in the database, in arbitrary order.
// Supports `limit` and `offset` pagination. 
//
// ### Response format
//     { "list": [ <person>, ... ],
//       "count": <int> }
// - `list` is a list of people on the requested page, in 
//   [short format](/docs/#/person/short.js)
// - `count` is the total number of people in the database.

TEST("The response has valid return code and content type.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.get(["db/",db,"/people"],auth)
	.assertStatus(200).assertIsJson();
});

// # Examples
// 
// ### Example request
//     GET /db/0SNQc00211H/people?limit=3&offset=213
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

TEST("Returns correct number of people in count.", function(Query) {

    var example = { "email" : "vnicollet@runorg.com",
		    "fullname" : "Victor Nicollet",
		    "gender" : "M" };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    
    return Query.post(["db/",db,"/people/import"],[example],auth).then(function() {

	var count = Query.get(["db/",db,"/people?limit=0"],auth)
	    .then(function(d) { return d.count; });

	return Assert.areEqual(2, count);

    });       

});

TEST("Returns data for all people.", function(Query) {

    var example = [ { "email": "test@runorg.com" },
		    { "email" : "vnicollet@runorg.com",
		      "name" : "Victor Nicollet",
		      "gender" : "M" } ];

    var db = Query.mkdb();
    var auth = Query.auth(db);

    return Query.post(["db/",db,"/people/import"],example,auth).then(function(d,s,r) {

	var ids  = d.imported;	    
	var list = Query.get(["db/",db,"/people"],auth).then(function(d) { return d.list; });

	var expected = [ 
	    { "id" : ids[0],
	      "label" : "test@…",
	      "gender" : null,
	      "pic" : "https://www.gravatar.com/avatar/1ed54d253636f5b33eff32c2d5573f70?d=identicon" },		
	    { "id" : ids[1], 
	      "label" : "Victor Nicollet",
	      "gender" : "M", 
	      "pic" : "https://www.gravatar.com/avatar/5a31b00f649489a9a24d3dc3e8b28060?d=identicon" } ];
	
	return Assert.areEqual(expected, list);

    });

});

// # Errors
//
// ## Returns `401 Unauthorized` 
// - ... if the provided token does allow acting as `{as}`.

TEST("Returns 401 when token is not valid.", function(Query) {
    var db = Query.mkdb();
    return Query.get(["db/",db,"/people"],{id:"01234567890",token:"01234567890"})
	.assertStatus(401);
});

// ## Returns `403 Forbidden` 
// - ... if `{as}` is not a database administrator

TEST("Returns 403 when not an admin.", function(Query) {
    var db = Query.mkdb();
    var peon = Query.auth(db, false);
    return Query.get(["db/",db,"/people"],peon).assertStatus(403);
});
  
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.get("/db/00000000001/people/00000000002/").assertStatus(404);
});

// # Access restrictions
//
// Only [database administrators](/docs/#/group/admin.md) may list all people
// in the database. 
//
// Note that [viewing individuals](/docs/#/contact/get.js) is open to anyone.
