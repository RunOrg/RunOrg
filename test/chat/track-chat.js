// POST /chat/{id}/track

TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{ audience: {} },auth).id();
    return Query.post(["db/",db,"/chat/",id,"/track"],true,auth)
	.assertStatus(202).assertIsJson();
});

TEST("View 'track' only as self.", function(Query) {

    var created = { audience: { admin: "anyone" } };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],created,auth).id();
    return Query.post(["db/",db,"/chat/",id,"/track"],true,auth).then(function() {
	var asSelf = Query.get(["db/",db,"/chat/",id],auth).then(function(value) {	    
	    return Assert.areEqual(true, value.info.track);	    
	});
	var auth2 = Query.auth(db,true,"test+2@runorg.com");
	var asOther = Query.get(["db/",db,"/chat/",id],auth2).then(function(value) {	    
	    return Assert.areEqual(false, value.info.track);	    
	}); 
	return $.when(asSelf,asOther);
    });

});

TEST("Remove 'track' only as self.", function(Query) {

    var created = { audience: { admin: "anyone" } };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var auth2 = Query.auth(db,true,"test+2@runorg.com");
    var id = Query.post(["db/",db,"/chat"],created,auth).id();
    return $.when(
	Query.post(["db/",db,"/chat/",id,"/track"],true,auth),
	Query.post(["db/",db,"/chat/",id,"/track"],true,auth2)
    ).then(function() {
	return Query.post(["db/",db,"/chat/",id,"/track"],false,auth).then(function() {
	    var asSelf = Query.get(["db/",db,"/chat/",id],auth).then(function(value) {	    
		return Assert.areEqual(false, value.info.track);	    
	    });
	    var asOther = Query.get(["db/",db,"/chat/",id],auth2).then(function(value) {	    
		return Assert.areEqual(true, value.info.track);	    
	    }); 
	    return $.when(asSelf,asOther);
	});
    });

});

TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.post(["db/00000000000/chat/00000000001/track"],true).assertStatus(404);
});

TEST("Returns 404 when chatroom does not exist.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.post(["db/",db,"/chat/00000000000/track"],true,auth).assertStatus(404);
});

TEST("Returns 404 when no 'view' access.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{ audience: {} },auth).id();
    var peon = Query.auth(db,false,"test+peon@runorg.com");
    return Query.post(["db/",db,"/chat/",id,"/track"],true,peon).assertStatus(404);
});

TEST("Returns 403 when no 'read' access.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{ audience: {view:"anyone"} },auth).id();
    var peon = Query.auth(db,false,"test+peon@runorg.com");
    return Query.post(["db/",db,"/chat/",id,"/track"],true,peon).assertStatus(403);
});

