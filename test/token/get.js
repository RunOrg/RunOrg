// GET /db/{db}/tokens/{token}
// Tokens / Get the description of a token
//
// Beta @ 0.9.3
//
// `200 OK`, 
// [Read-only](/docs/#/concept/read-only.md).
//
// Describes who owns `{token}`, and whether the token is currently active.
// 
// ### Response format
//     { "token": <token>,
//       "self" : <person> }
// - `token` is the exact same token that was provided as input. 
// - `self` is the [short profile](/docs/person/short.js) for the person who owns
//   the tokens. 
//
// The identifier of the returned person can be used for the [`?as`](/docs/#/concept/as.md)
// parameter of requests authenticated with this token.
//
// ### Example request
//     GET /db/0vJlA00726W/tokens/9dF3M1wEma4
//
// ### Example response
//     200 OK
//     Content-Type: application/json
//
//     { "token": "7Rq03AsR92W",
//       "self": { 
//         "id" : "0Et9j0026rO",
//         "label" : "Victor Nicollet",
//         "gender" : "M", 
//         "pic" : "https://www.gravatar.com/avatar/648e25e4372728b2d3e0c0b2b6e26f4e" } }

TEST("Returns correct data.", function(Query) {

    var example = { "email" : "vnicollet@runorg.com",
		    "name" : "Victor Nicollet",
		    "gender" : "M" };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/people/import"],[example],auth)
	.then(function(d,s,r) { return d.imported[0]; });

    return id.then(function() {

	var auth = Query.auth(db,null,"vnicollet@runorg.com");
	var r = Query.get(["db/",db,"/tokens/",auth.token]).then(function(d,s,r) { return d; });

	var expected = {
	    "token": auth.token,
	    "self": { 
		"id": auth.id, 
		"label": "Victor Nicollet",
		"gender": "M", 
		"pic" : "https://www.gravatar.com/avatar/5a31b00f649489a9a24d3dc3e8b28060?d=identicon" 
	    }
	};
	
	return Assert.areEqual(expected, r);

    });

    return Query.get(["/db/",db,"/tokens/00000000002"]).assertStatus(404);
});

// # Errors
//
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.get("/db/00000000001/tokens/00000000002").assertStatus(404);
});

// - ... if token `{token}` does not exist or is not active anymore in database `{db}`

TEST("Returns 404 when token does not exist.", function(Query) {
    var db = Query.mkdb();
    return Query.get(["/db/",db,"/tokens/00000000002"]).assertStatus(404);
});

// # Access restrictions
//
// The owner of a valid token may perform this query on their own token.
