// GET /db/{db}/people/{id}
// People / Fetch basic information for a person 

TEST("The response has valid return code and content type.", function(Query) {

    var example = { "email" : "vnicollet@runorg.com" };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/people/import"],[example],auth)
	.then(function(d) { return d.imported[0]; });

    return Query.get(["db/",db,"/people/",id])
	.assertStatus(200).assertIsJson();

});

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

TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.get("/db/00000000001/people/00000000002/").assertStatus(404);
});

TEST("Returns 404 when person does not exist in database.", function(Query) {
    var db = Query.mkdb();
    return Query.get(["db/",db,"/people/00000000002/"]).assertStatus(404);
});

