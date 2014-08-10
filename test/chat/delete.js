// DELETE /chat/{id}

TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{ audience: {} },auth).id();
    return Query.del(["db/",db,"/chat/",id],auth)
	.assertStatus(202).assertIsJson();

});

TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.del(["db/00000000000/chat/00000000001"]).assertStatus(404);
});

TEST("Returns 404 when chat does not exist.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.del(["db/",db,"/chat/00000000001"],auth).assertStatus(404);
});

TEST("Returns 403 when not allowed to delete.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{ audience: { moderate: "anyone" } }, auth).id();
    return Query.del(["db/",db,"/chat/",id]).assertStatus(403);
});

TEST("Returns 404 when chat not visible.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{ audience: {}}, auth).id();
    return Query.del(["db/",db,"/chat/",id]).assertStatus(404);
});

TEST("Returns 404 when chat deleted twice.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{ audience: {}}, auth).id();			
    return Query.del(["db/",db,"/chat/",id],auth).then(function() {
	return Query.del(["db/",db,"/chat/",id],auth).assertStatus(404);
    });
});

TEST("Chatroom not visible after deletion.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{ audience: {}}, auth).id();			
    return Query.del(["db/",db,"/chat/",id],auth).then(function() {
	return $.when(
	    Query.get(["db/",db,"/chat/",id,"/posts"],auth).assertStatus(404),
	    Query.get(["db/",db,"/chat/",id],auth).assertStatus(404)
	);
    });
});
