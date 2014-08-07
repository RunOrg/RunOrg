// POST /people/import

TEST("The response has valid return code and content type.", function(Query) {

    var example = { "email" : "vnicollet@runorg.com" };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.post(["db/",db,"/people/import"],[example],auth)
	.assertStatus(202).assertIsJson();

});

TEST("Single import works.", function(Query) {

    var example = { "email" : "vnicollet@runorg.com",
		    "name" : "Victor Nicollet",
		    "gender" : "M" };

    var db = Query.mkdb();
    var auth = Query.auth(db);

    var id = Query.post(["db/",db,"/people/import"],[example],auth)
	.then(function(d) { return d.imported[0]; });
    
    var created = Query.get(["db/",db,"/people/",id],auth)
	.then(function(d) { return d; });

    var expected = { 
	"id": id, 
	"label": "Victor Nicollet",
	"gender": "M", 
	"pic" : "https://www.gravatar.com/avatar/5a31b00f649489a9a24d3dc3e8b28060?d=identicon" 
    };
    
    return Assert.areEqual(expected, created);

});

TEST("Returns 401 when token is not valid.", function(Query) {
    var db = Query.mkdb();
    return Query.post(["db/",db,"/people/import"],[],{id:"0123456789a",token:"01234567890"})
	.assertStatus(401);
});

TEST("Returns 403 when not allowed to import contacts.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db,false);
    return Query.post(["/db/",db,"/people/import"],[],auth).assertStatus(403);
});

TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.post("/db/00000000001/people/import",[]).assertStatus(404);
});

