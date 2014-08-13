// POST /chat/{id}/posts/{post}/unread

function url(db,id,pid) {
    return ["db/",db,"/chat/",id,"/posts/",pid,"/unread"];
}

TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{ audience: {} },auth).id();
    var pid = Query.post(["db/",db,"/chat/",id,"/posts"],{body:"X"},auth).id();
    return Query.get(url(db,id,pid),auth)
	.assertStatus(200).assertIsJson();
});

TEST("View unreaders if chat is tracked.", function(Query) {

    var created = { audience: { admin: "anyone" } };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var auth2 = Query.auth(db,true,"test+2@runorg.com");
    var id = Query.post(["db/",db,"/chat"],created,auth).id();

    return $.when(
	Query.post(["db/",db,"/chat/",id,"/track"],true,auth).id(),
	Query.post(["db/",db,"/chat/",id,"/track"],true,auth2).id()
    ).then(function() {
	var pid = Query.post(["db/",db,"/chat/",id,"/posts"],{body:"X"},auth).id();
	return Query.get(url(db,id,pid),auth).then(function(data) {
	    return Assert.areEqual([auth.id,auth2.id],data.list);
	});
    });

});

TEST("View unreaders if parent post is tracked.", function(Query) {

    var created = { audience: { admin: "anyone" } };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var auth2 = Query.auth(db,true,"test+2@runorg.com");
    var id = Query.post(["db/",db,"/chat"],created,auth).id();
    var parent = Query.post(["db/",db,"/chat/",id,"/posts"],{body:"X"},auth).id();
    return $.when(
	Query.post(["db/",db,"/chat/",id,"/posts/",parent,"/track"],true,auth).id(),
	Query.post(["db/",db,"/chat/",id,"/posts/",parent,"/track"],true,auth2).id()
    ).then(function() {
	var pid = Query.post(["db/",db,"/chat/",id,"/posts"],{body:"X",reply:parent},auth).id();
	return Query.get(url(db,id,pid),auth).then(function(data) {
	    return Assert.areEqual([auth.id,auth2.id],data.list);
	});
    });

});

TEST("Unreaders disappear if access is lost.", function(Query) {

    var created = { audience: { admin: "anyone" } };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var auth2 = Query.auth(db,false,"test+2@runorg.com");
    var id = Query.post(["db/",db,"/chat"],created,auth).id();

    return $.when(
	Query.post(["db/",db,"/chat/",id,"/track"],true,auth),
	Query.post(["db/",db,"/chat/",id,"/track"],true,auth2)
    ).then(function() {
	var pid = Query.post(["db/",db,"/chat/",id,"/posts"],{body:"X"},auth).id();
	return Query.put(["db/",db,"/chat/",id],{ audience: {} },auth).then(function() {
	    return Query.get(url(db,id,pid),auth).then(function(data) {
		return Assert.areEqual([auth.id],data.list);
	    });
	});
    });

});

TEST("Unreaders disappear if marked as read.", function(Query) {

    var created = { audience: { admin: "anyone" } };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var auth2 = Query.auth(db,false,"test+2@runorg.com");
    var id = Query.post(["db/",db,"/chat"],created,auth).id();

    return $.when(
	Query.post(["db/",db,"/chat/",id,"/track"],true,auth),
	Query.post(["db/",db,"/chat/",id,"/track"],true,auth2)
    ).then(function() {
	var pid = Query.post(["db/",db,"/chat/",id,"/posts"],{body:"X"},auth).id();
	return Query.post(["db/",db,"/chat/",id,"/read"],[pid],auth2).then(function() {
	    return Query.get(url(db,id,pid),auth).then(function(data) {
		return Assert.areEqual([auth.id],data.list);
	    });
	});
    });

});

TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.get(url("00000000000","00000000001","00000000002")).assertStatus(404);
});

TEST("Returns 404 when chatroom does not exist.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.get(url(db,"00000000000","00000000001"),auth).assertStatus(404);
});

TEST("Returns 403 when not an administrator.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{ audience: {} },auth).id();
    var pid = Query.post(["db/",db,"/chat/",id,"/posts"],{body:"X"},auth).id();
    var peon = Query.auth(db,false,"test+peon@runorg.com");
    return Query.get(url(db,id,pid),peon).assertStatus(403);
});

TEST("Returns 404 when no post does not exist.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{ audience: {} },auth).id();
    return Query.get(url(db,id,'00000000000'),auth).assertStatus(404);
});

