// POST /chat/{id}/posts

TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{audience:{}},auth).id();
    return Query.post(["db/",db,"/chat/",id,"/posts"],{ body: "Hello" },auth)
	.assertStatus(202).assertIsJson();

});

TEST("The post count increases.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{audience:{}},auth).id();
    return Query.post(["db/",db,"/chat/",id,"/posts"],{ body: "Hello" },auth).then(function() {
	return Query.get(["db/",db,"/chat/",id],auth).then(function(data) {
	    return Assert.areEqual(1, data.info.count);
	});
    });

});


TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.post(["db/00000000000/chat/00000000001/posts"],{}).assertStatus(404);
});

TEST("Returns 404 when chat does not exist.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.post(["db/",db,"/chat/00000000001/posts"],{ body: "Hello" },auth).assertStatus(404);
});

TEST("Returns 403 when not allowed to post.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{ audience: { view: "anyone" } },auth).id();
    var peon = Query.auth(db, false, "test+peon@runorg.com");
    return Query.post(["db/",db,"/chat/",id,"/posts"],{ body: "Hello" },peon).assertStatus(403);    
});

TEST("Returns 404 when not allowed to view.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{ audience: {} },auth).id();
    var peon = Query.auth(db, false, "test+peon@runorg.com");
    return Query.post(["db/",db,"/chat/",id,"/posts"],{ body: "Hello" },peon).assertStatus(404);    
});

