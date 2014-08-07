// GET /people/search

TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.get(["db/",db,"/people/search?q="],auth)
	.assertStatus(200).assertIsJson();

});

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

TEST("Returns 401 when token is not valid.", function(Query) {
    var db = Query.mkdb();
    return Query.get(["db/",db,"/people/search?q="],{id:"01234567890",token:"01234567890"})
	.assertStatus(401);
});
 
TEST("Returns 403 when not an admin.", function(Query) {
    var db = Query.mkdb();
    var peon = Query.auth(db, false);
    return Query.get(["db/",db,"/people/search?q="],peon).assertStatus(403);
});

TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.get("/db/00000000001/people/search?q=").assertStatus(404);
});

