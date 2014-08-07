// DELETE /groups/{id}

TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    
    var id = Query.post(["db/",db,"/groups"],{},auth).id();

    return Query.del(["db/",db,"/groups/",id],auth)
	.assertStatus(202).assertIsJson();

});

TEST("Deleted group disappears.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    
    var id = Query.post(["db/",db,"/groups"],{},auth).id();

    return Query.del(["db/",db,"/groups/",id],auth).then(function() {
	return Query.get(["db/",db,"/groups/",id,"/info"],auth).assertStatus(404);
    });

});

TEST("Returns 401 when token is not valid.", function(Query) {
    var db = Query.mkdb();
    return Query.del(["db/",db,"/groups/00000000000"],{id:"01234567890",token:"01234567890"})
	.assertStatus(401);
});

TEST("Returns 403 when deleting group without admin access.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/groups"],{"audience":{"moderate":"anyone"}},auth).id();
    var peon = Query.auth(db,false,"peon@runorg.com")
    return Query.del(["db/",db,"/groups/",id],peon).assertStatus(403);
});

TEST("Returns 403 when deleting admin group.", function(Query) {
    var db = Query.mkdb();
    return Query.del(["db/",db,"/groups/admin"]).assertStatus(403);
});

TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.del(["db/00000000000/groups/00000000000"])
	.assertStatus(404);
});

TEST("Returns 404 when group does not exist.", function(Query) {
    var db = Query.mkdb();
    return Query.del(["db/",db,"/groups/00000000000"])
	.assertStatus(404);
});