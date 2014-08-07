// POST /groups/{id}/remove

TEST("The response has valid return code and content type.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var peon = Query.auth(db,false,"peon@runorg.com");
    return Query.post(["db/",db,"/groups/admin/remove"],[peon.id],auth)
	.assertStatus(202).assertIsJson();    
});

TEST("An empty list is acceptable.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var peon = Query.auth(db,false,"peon@runorg.com");
    return Query.post(["db/",db,"/groups/admin/remove"],[],auth)
	.assertStatus(202);    
});

TEST("Duplicate contacts in list are acceptable.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var peon = Query.auth(db,false,"peon@runorg.com");
    return Query.post(["db/",db,"/groups/admin/remove"],[peon.id,peon.id],auth)
	.assertStatus(202);    
});

TEST("Removed contacts can not be found in the group.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var peon = Query.auth(db,true,"peon@runorg.com");
    return Query.post(["db/",db,"/groups/admin/remove"],[peon.id],auth).then(function() {
	return Query.get(["db/",db,"/groups/admin"],auth).then(function(d,s,r) { 
	    var list = d.list;
	    return $.when(
		Assert.areEqual(1,list.length),
		Assert.areEqual(auth.id, list[0].id)
	    );
	});
    });
});

TEST("Returns 401 when token is not valid.", function(Query) {
    var db = Query.mkdb();
    return Query.post(["db/",db,"/groups/admin/remove"],[],{id:"01234567890",token:"01234567890"})
	.assertStatus(401);
});

TEST("Returns 403 when no 'moderate' access.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db); 
    var id = Query.post(["db/",db,"/groups"],{"audience":{"list":"anyone"}},auth).id();
    var peon = Query.auth(db,false,"peon@runorg.com");
    return Query.post(["db/",db,"/groups/",id,"/remove"],[],peon)
	.assertStatus(403);
});

TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.post(["db/00000000000/groups/admin/remove"],[]).assertStatus(404);
});

TEST("Returns 404 when group does not exist.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db); 
    return Query.post(["db/",db,"/groups/00000000000/remove"],[]).assertStatus(404);
});

TEST("Returns 404 when no 'view' access.", function(Query) {
    var db = Query.mkdb();
    var peon = Query.auth(db,false,"peon@runorg.com");
    return Query.post(["db/",db,"/groups/admin/remove"],[],peon).assertStatus(404);
});

