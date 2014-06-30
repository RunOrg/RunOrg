TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/groups"],{},auth).id();
    return Query.get(["db/",db,"/groups/",id],auth)
	.assertStatus(200).assertIsJson();

});

TEST("Returns correct number of contacts in count.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var other = Query.auth(db,true,"test+2@runorg.com");
    
    return $.when(auth,other).then(function() {
	var count = Query.get(["db/",db,"/groups/admin?limit=1"],auth).then(function(d) { return d.count; });
	return Assert.areEqual(2,count);
    });
    
});

TEST("Returns data for all contacts.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);

    return auth.id.then(function() {

	var other = Query.auth(db,true,"test+2@runorg.com");
    
	return other.id.then(function() {

	    var list = Query.get(["db/",db,"/groups/admin"],auth).then(function(d) { return d.list; });
	    var expected = [{
		"id" : auth.id,
		"label" : "test@…",
		"gender" : null,
		"pic" : "https://www.gravatar.com/avatar/1ed54d253636f5b33eff32c2d5573f70?d=identicon"
	    }, {
		"id" : other.id,
		"label" : "test+2@…",
		"gender" : null,
		"pic" : "https://www.gravatar.com/avatar/fcf1ec969e2da183f88f5a6dca0c1d65?d=identicon"
	    }];
	    
	    return Assert.areEqual(expected,list);

	});
    });

});

TEST("Returns 401 when token is not valid.", function(Query) {
    var db = Query.mkdb();
    return Query.get(["db/",db,"/groups/admin"],{id:"01234567890",token:"01234567890"})
	.assertStatus(401);
});

TEST("Returns 403 when no 'list' access.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/groups"],{"audience":{"view":"anyone"}},auth).id();	
    var peon = Query.auth(db, false, "peon@runorg.com");
    return Query.get(["db/",db,"/groups/",id])
	.assertStatus(403);
});

TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.get(["db/00000000000/groups/admin"]).assertStatus(404);
});

TEST("Returns 404 when group does not exist.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.get(["db/",db,"/groups/00000000000"],auth).assertStatus(404);
});

TEST("Returns 404 when no 'view' access.", function(Query) {
    var db = Query.mkdb();
    // Create admin to auto-create admin group
    return Query.auth(db).id.then(function() {
	var peon = Query.auth(db,false,"peon@runorg.com");
	return Query.get(["db/",db,"/groups/admin"],peon).assertStatus(404);
    });
});

