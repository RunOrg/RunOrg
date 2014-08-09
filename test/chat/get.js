// GET /chat/{id}

TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{},auth).id();
    return Query.get(["db/",db,"/chat/",id],auth)
	.assertStatus(200).assertIsJson();
});

TEST("Returns correct data as admin.", function(Query) {

    var created = {
	subject: "Hello, world!",
	custom: { a: true },
	audience: { admin: "anyone" }
    };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],created,auth).id();
    return Query.get(["db/",db,"/chat/",id],auth).then(function(value) {

	var expected = $.extend({
	    id: id,
	    count: 0,
	    access: [ "view","read","admin","moderate","write" ]	   
	}, created);
	
	delete value.info.last;
	
	return Assert.areEqual(expected, value.info);

    });

});

TEST("Returns correct data as moderator.", function(Query) {

    var created = {
	subject: "Hello, world!",
	custom: { a: true },
	audience: { moderate: "anyone" }
    };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],created,auth).id();
    return Query.get(["db/",db,"/chat/",id]).then(function(value) {

	var expected = $.extend({
	    id: id,
	    count: 0,
	    access: [ "view","read","moderate","write" ]	   
	}, created);

	expected.audience = null; // Not available to non-admins
	
	delete value.info.last;
	
	return Assert.areEqual(expected, value.info);

    });

});


TEST("Returns correct data as viewer.", function(Query) {

    var created = {
	subject: "Hello, world!",
	custom: { a: true },
	audience: { view: "anyone" }
    };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],created,auth).id();
    return Query.get(["db/",db,"/chat/",id]).then(function(value) {

	var expected = $.extend({
	    id: id,
	    count: null, // Not available to non-readers
	    access: [ "view" ]	   
	}, created);

	expected.audience = null; // Not available to non-admins
	
	delete value.info.last;
	
	return Assert.areEqual(expected, value.info);

    });

});

TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.get(["db/00000000000/chat/00000000001"]).assertStatus(404);
});

TEST("Returns 404 when chatroom does not exist.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.get(["db/",db,"/chat/00000000000"],auth).assertStatus(404);
});

TEST("Returns 404 when no 'view' access.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{ audience: {} },auth).id();
    return Query.get(["db/",db,"/chat/",id]).assertStatus(404);
});


