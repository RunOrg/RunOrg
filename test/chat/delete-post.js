// DELETE /chat/{id}/posts/{post}

TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{ audience: {} },auth).id();
    var pid = Query.post(["db/",db,"/chat/",id,"/posts"],{ body: "" }, auth).id();
    return Query.del(["db/",db,"/chat/",id,"/posts/",pid],auth)
	.assertStatus(202).assertIsJson();

});

TEST("Delete as (non-moderator) author.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{ audience: { write: "anyone" } },auth).id();
    var peon = Query.auth(db,false,"test+peon@runorg.com");
    var pid = Query.post(["db/",db,"/chat/",id,"/posts"],{ body: "" }, peon).id();
    return Query.del(["db/",db,"/chat/",id,"/posts/",pid],peon)
	.assertStatus(202).assertIsJson();

});

TEST("Delete as moderator.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{ audience: { moderate: "anyone" } },auth).id();
    var pid = Query.post(["db/",db,"/chat/",id,"/posts"],{ body: "" }, auth).id();
    return Query.del(["db/",db,"/chat/",id,"/posts/",pid])
	.assertStatus(202).assertIsJson();

});


TEST("With single post.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{audience:{}},auth).id();
    var pid = Query.post(["db/",db,"/chat/",id,"/posts"],{ body: "Hi" },auth).id();
    return Query.del(["db/",db,"/chat/",id,"/posts/",pid],auth).then(function() {
	return Query.get(["db/",db,"/chat/",id,"/posts"],auth).then(function(data) {
	    return Assert.areEqual({ posts: [], people: [], count: 0 }, data);
	});
    });

});

TEST("With nested posts.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var auth2 = Query.auth(db,true,"test+2@runorg.com");
    var id = Query.post(["db/",db,"/chat"],{audience:{}},auth).id();
    var url = ["db/",db,"/chat/",id,"/posts"];

    var pid1 = Query.post(url,{ body: "Hi" },auth).id();

    var pid2 = pid1.then(function() {
	return Async.sleep(1000).then(function() { 
	    return Query.post(url,{ body: "<strong>Hello</strong>" },auth2).id();
	});
    });

    var pid3 = pid2.then(function() {
	return Query.post(url,{ body: "Child", reply: pid1 },auth2).id();
    });
    
    return $.when(pid1,pid2,pid3).then(function() {	
	return Query.del(url.concat("/",pid1),auth);
    }).then(function() {
	return Query.get(["db/",db,"/chat/",id],auth).then(function(data) {
	    return Assert.areEqual(1, data.info.count);
	});
    });

});

TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.del(["db/00000000000/chat/00000000001/posts/00000000002"]).assertStatus(404);
});

TEST("Returns 404 when chatroom does not exist.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.del(["db/",db,"/chat/00000000000/posts/00000000002"],auth).assertStatus(404);
});

TEST("Returns 403 when no 'read' access.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{ audience: { view: "anyone" } },auth).id();
    var pid = Query.post(["db/",db,"/chat/",id,"/posts"],{ body: "" }, auth).id();
    return Query.del(["db/",db,"/chat/",id,"/posts/",pid]).assertStatus(403);
});

TEST("Returns 404 when no 'view' access.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{ audience: {} },auth).id();
    var pid = Query.post(["db/",db,"/chat/",id,"/posts"],{ body: "" }, auth).id();
    return Query.del(["db/",db,"/chat/",id,"/posts/",pid]).assertStatus(404);
});

TEST("Returns 404 when post does not exist.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{ audience: {} },auth).id();
    return Query.del(["db/",db,"/chat/",id,"/posts/00000000002"],auth).assertStatus(404);
});

TEST("Returns 403 when not post owner or moderator.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{ audience: { write: "anyone" } },auth).id();
    var pid = Query.post(["db/",db,"/chat/",id,"/posts"],{ body: "" }, auth).id();
    return Query.del(["db/",db,"/chat/",id,"/posts/",pid]).assertStatus(403);
});


