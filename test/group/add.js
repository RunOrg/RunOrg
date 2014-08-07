// POST /groups/{id}/add

TEST("The response has valid return code and content type.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var peon = Query.auth(db,false,"peon@runorg.com");
    return Query.post(["db/",db,"/groups/admin/add"],[peon.id],auth)
	.assertStatus(202).assertIsJson();    
});

TEST("An empty list is acceptable.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.post(["db/",db,"/groups/admin/add"],[],auth)
	.assertStatus(202);    
});

TEST("Duplicate contacts in list are acceptable.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var peon = Query.auth(db,false,"peon@runorg.com");
    return Query.post(["db/",db,"/groups/admin/add"],[peon.id,peon.id],auth)
	.assertStatus(202);    
});

TEST("Contacts already in group are ignored.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.post(["db/",db,"/groups/admin/add"],[auth.id],auth)
	.assertStatus(202);    
});

TEST("Added contacts can be found in the group.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var peon = Query.auth(db,false,"test+2@runorg.com");
    return Query.post(["db/",db,"/groups/admin/add"],[peon.id,peon.id],auth).then(function() {

	var list = Query.get(["db/",db,"/groups/admin"],auth).then(function(d) { return d.list; });
	var expected = [{
	    "id" : auth.id,
	    "label" : "test@…",
	    "gender" : null,
	    "pic" : "https://www.gravatar.com/avatar/1ed54d253636f5b33eff32c2d5573f70?d=identicon"
	}, {
	    "id" : peon.id,
	    "label" : "test+2@…",
	    "gender" : null,
	    "pic" : "https://www.gravatar.com/avatar/fcf1ec969e2da183f88f5a6dca0c1d65?d=identicon"
	}];
	
	return Assert.areEqual(expected,list);
    });
});

TEST("Returns 401 when token is not valid.", function(Query) {
    var db = Query.mkdb();
    return Query.post(["db/",db,"/groups/admin/add"],[],{id:"01234567890",token:"01234567890"})
	.assertStatus(401);
});

TEST("Returns 403 when no 'moderate' access.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db); 
    var id = Query.post(["db/",db,"/groups"],{"audience":{"list":"anyone"}},auth).id();
    var peon = Query.auth(db,false,"peon@runorg.com");
    return Query.post(["db/",db,"/groups/",id,"/add"],[],peon)
	.assertStatus(403);
});

TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.post(["db/00000000000/groups/admin/add"],[]).assertStatus(404);
});

TEST("Returns 404 when group does not exist.", function(Query) {
    var db = Query.mkdb();
    return Query.post(["db/",db,"/groups/00000000000/add"],[]).assertStatus(404);
});

TEST("Returns 404 when no 'view' access.", function(Query) {
    var db = Query.mkdb();
    var peon = Query.auth(db,false,"peon@runorg.com");
    return Query.post(["db/",db,"/groups/admin/add"],[],peon).assertStatus(404);
});

TEST("Returns 404 when person does not exist.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.post(["db/",db,"/groups/admin/add"],["00000000000"],auth).assertStatus(404);
});
