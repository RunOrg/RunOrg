// GET /db/{db}/people/{id}
// People / Fetch basic information for a person 
//
// Alpha @ 0.1.21
//
// `200 OK`, [Read-only](/docs/#/concept/read-only.md).
//

TEST("The response has valid return code and content type.", function(Query) {

    var example = { "email" : "vnicollet@runorg.com" };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/people/import"],[example],auth)
	.then(function(d) { return d.imported[0]; });

    return Query.get(["db/",db,"/people/",id])
	.assertStatus(200).assertIsJson();

});

// Returns a [short representation](/docs/#/person/short.js) of person
// `{id}`.
//
// ### Example request
//     GET /db/0Et4X0016om/people/0Et9j0026rO
//     
// ### Example response
//     200 OK 
//     Content-Type: application/json
//
//     { "id" : "0Et9j0026rO",
//       "label" : "Victor Nicollet",
//       "gender" : "M", 
//       "pic" : "https://www.gravatar.com/avatar/648e25e4372728b2d3e0c0b2b6e26f4e" }

TEST("The example was properly returned.", function(Query) {

    var example = { "email" : "vnicollet@runorg.com",
		    "name" : "Victor Nicollet",
		    "gender" : "M" };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/people/import"],[example],auth)
	.then(function(d) { return d.imported[0]; });

    var created = Query.get(["db/",db,"/people/",id]).then(function(d) { return d; });

    var expected = { "id": id, 
		     "label": "Victor Nicollet",
		     "gender": "M", 
		     "pic" : "https://www.gravatar.com/avatar/5a31b00f649489a9a24d3dc3e8b28060?d=identicon" };

    return Assert.areEqual(expected, created);

});

// 
// # Errors
// 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.get("/db/00000000001/people/00000000002/").assertStatus(404);
});

// - ... if person `{id}` does not exist in database `{db}`

TEST("Returns 404 when person does not exist in database.", function(Query) {
    var db = Query.mkdb();
    return Query.get(["db/",db,"/people/00000000002/"]).assertStatus(404);
});

// 
// # Access restrictions
//
// Anyone can view any person's basic information, if they have their identifier.