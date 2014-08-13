// GET /chat/posts

TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.get(["db/",db,"/chat/posts"],auth)
	.assertStatus(200).assertIsJson();

});

TEST("Initially empty.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.get(["db/",db,"/chat/posts"],auth).then(function(data) {
	return Assert.areEqual({ list: [] }, data);
    });

});

TEST("With single post.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{audience:{}},auth).id();
    return Query.post(["db/",db,"/chat/",id,"/posts"],{ body: "Hi" },auth).id().then(function(pid) {
	var first = Query.get(["db/",db,"/chat/posts"],auth).then(function(data) {
	    delete data.list[0].time;
	    return Assert.areEqual({ list : [{ id : id, post : pid }] }, data);
	});
	var after = Query.get(["db/",db,"/chat/posts?since=",id,",",pid],auth).then(function(data) {
	    return Assert.areEqual({ list: [] }, data);
	});
	return $.when(first,after);
    });

});

TEST("With two posts, same chat.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{audience:{}},auth).id();
    var url = ["db/",db,"/chat/",id,"/posts"];
    return Query.post(url,{ body: "Hi" },auth).id().then(function(pid1) {
	return Async.sleep(1000).then(function() {
	    return Query.post(url,{ body: "<strong>Hello</strong>" },auth).id().then(function(pid2) {
		var both = Query.get(["db/",db,"/chat/posts"],auth).then(function(data) {
		    delete data.list[0].time;
		    delete data.list[1].time;
		    return Assert.areEqual({ list : [
			{ id : id, post : pid1 },
			{ id : id, post : pid2 }
		    ] }, data);
		});
		var first =  Query.get(["db/",db,"/chat/posts?limit=1"],auth).then(function(data) {
		    delete data.list[0].time;
		    return Assert.areEqual({ list : [ { id : id, post : pid1 } ] }, data);
		});
		var second = Query.get(["db/",db,"/chat/posts?since=",id,",",pid1],auth).then(function(data) {
		    delete data.list[0].time;
		    return Assert.areEqual({ list : [ { id : id, post : pid2 } ] }, data);
		});
		return $.when(both,first,second);
	    });
	});
    });

});


TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.get(["db/00000000000/chat/posts"]).assertStatus(404);
});

TEST("Returns 403 when not admin.", function(Query) {
    var db = Query.mkdb();
    var peon = Query.auth(db, false, "test+peon@runorg.com");
    return Query.get(["db/",db,"/chat/posts"],peon).assertStatus(403);    
});

TEST("Returns 400 when invalid 'since'.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.get(["db/",db,"/chat/posts?since="],auth).assertStatus(400);    
});


