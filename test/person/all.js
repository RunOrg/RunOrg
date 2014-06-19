// GET /db/{db}/people
// People / List all people in the database

TEST("The response has valid return code and content type.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.get(["db/",db,"/people"],auth)
	.assertStatus(200).assertIsJson();
});

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

TEST("Returns 401 when token is not valid.", function(Query) {
    var db = Query.mkdb();
    return Query.get(["db/",db,"/people"],{id:"01234567890",token:"01234567890"})
	.assertStatus(401);
});

TEST("Returns 403 when not an admin.", function(Query) {
    var db = Query.mkdb();
    var peon = Query.auth(db, false);
    return Query.get(["db/",db,"/people"],peon).assertStatus(403);
});
  
TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.get("/db/00000000001/people/00000000002/").assertStatus(404);
});
