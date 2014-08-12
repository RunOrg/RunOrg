// GET /chat

TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.get(["db/",db,"/chat"],auth)
	.assertStatus(200).assertIsJson();
});

TEST("Is empty by default.", function(Query) {

    var db = Query.mkdb();
    return Query.get(["db/",db,"/chat"]).then(function(value) {	
	return Assert.areEqual({ list: [] }, value);
    });

});

TEST("Returns correct data as admin.", function(Query) {

    var created = {
	subject: "Hello, world!",
	custom: { a: true },
	audience: { admin: "anyone" }
    };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.post(["db/",db,"/chat"],created,auth).id().then(function(id) {
	return Query.get(["db/",db,"/chat"],auth).then(function(value) {
	    
	    var expected = $.extend({
		id: id,
		count: 0,
		track: false,
		access: [ "view","read","admin","moderate","write" ]	   
	    }, created);
	    
	    delete value.list[0].last;
	    
	    return Assert.areEqual({ list: [expected]}, value);
	    
	});
    });

});

TEST("Returns correct data as reader.", function(Query) {

    var created = {
	subject: "Hello, world!",
	custom: { a: true },
	audience: { read: "anyone" }
    };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.post(["db/",db,"/chat"],created,auth).id().then(function(id) {
	return Query.get(["db/",db,"/chat"]).then(function(value) {
	    
	    var expected = $.extend({
		id: id,
		count: 0,
		track: false,
		access: [ "view","read" ]	   
	    }, created);
	    
	    expected.audience = null;
	    delete value.list[0].last;
	    
	    return Assert.areEqual({ list: [expected]}, value);
	    
	});
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
    return Query.post(["db/",db,"/chat"],created,auth).id().then(function(id) {
	return Query.get(["db/",db,"/chat"]).then(function(value) {
	    
	    var expected = $.extend({
		id: id,
		count: null,
		track: false,
		access: [ "view" ]	   
	    }, created);
	    
	    expected.audience = null;
	    delete value.list[0].last;
	    
	    return Assert.areEqual({ list: [expected]}, value);
	    
	});
    });

});

TEST("Returns correct data when no access.", function(Query) {

    var created = {
	subject: "Hello, world!",
	custom: { a: true },
	audience: {}
    };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.post(["db/",db,"/chat"],created,auth).then(function() {
	return Query.get(["db/",db,"/chat"]).then(function(value) {	    
 	    return Assert.areEqual({ list: []}, value);	    
	});
    });

});

TEST("Returns data in correct order.", function(Query) {

    var created1 = {
	subject: "Hello, world!",
	custom: { a: true },
	audience: {}
    };

    var created2 = {
	subject: "Later!",
	custom: { b: false },
	audience: {}
    };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.post(["db/",db,"/chat"],created1,auth).id().then(function(id1) {
	return Query.post(["db/",db,"/chat"],created2,auth).id().then(function(id2) {
	    return $.when(
		Query.get(["db/",db,"/chat"],auth).then(function(value) {	    
 		    return $.when(
			Assert.areEqual(id1, value.list[0].id),
			Assert.areEqual(id2, value.list[1].id)
		    );	    
		}),
		Query.get(["db/",db,"/chat?limit=1"],auth).then(function(value) {	    
 		    return $.when(
			Assert.areEqual(id1, value.list[0].id),
			Assert.areEqual(1, value.list.length)
		    );	    
		}),
		Query.get(["db/",db,"/chat?offset=1"],auth).then(function(value) {	    
 		    return $.when(
			Assert.areEqual(id2, value.list[0].id),
			Assert.areEqual(1, value.list.length)
		    );	    
		})
	    );
	});
    });
});

