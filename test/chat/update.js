// PUT /chat/{id}

TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{ audience: {} },auth).id();
    return Query.put(["db/",db,"/chat/",id],{},auth)
	.assertStatus(202).assertIsJson();
});

TEST("Updates all data.", function(Query) {

    var created = {
	subject: "Hello, world!",
	custom: { a: true },
	audience: { admin: "anyone" }
    };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],created,auth).id();
   
    var updated = {
	subject: null,
	custom: { b: false },
	track: false,
	audience: { moderate: "anyone" }
    };
 
    return Query.put(["db/",db,"/chat/",id],updated,auth).then(function() {
	return Query.get(["db/",db,"/chat/",id],auth).then(function(value) {
	    
	    var expected = $.extend({
		id: id,
		count: 0,
		access: [ "view","read","admin","moderate","write" ]	   
	    }, updated);
	    
	    delete value.info.last;
	    
	    return Assert.areEqual(expected, value.info);
	    
	});
    });

});

TEST("Partial data update.", function(Query) {

    var created = {
	subject: "Hello, world!",
	custom: { a: true },
	audience: { admin: "anyone" }
    };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],created,auth).id();
   
    var updated = {};
 
    return Query.put(["db/",db,"/chat/",id],updated,auth).then(function() {
	return Query.get(["db/",db,"/chat/",id],auth).then(function(value) {
	    
	    var expected = $.extend({
		id: id,
		count: 0,
		track: false,
		access: [ "view","read","admin","moderate","write" ]	   
	    }, created);
	    
	    delete value.info.last;
	    
	    return Assert.areEqual(expected, value.info);
	    
	});
    });

});

TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.put(["db/00000000000/chat/00000000001"],{}).assertStatus(404);
});

TEST("Returns 404 when chatroom does not exist.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.put(["db/",db,"/chat/00000000000"],{},auth).assertStatus(404);
});

TEST("Returns 404 when no 'view' access.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{ audience: {} },auth).id();
    return Query.put(["db/",db,"/chat/",id],{}).assertStatus(404);
});

TEST("Returns 403 when no 'admin' access.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{ audience: { moderate: "anyone"} },auth).id();
    return Query.put(["db/",db,"/chat/",id],{}).assertStatus(403);
});


