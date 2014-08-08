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
	    access: [ "admin", "view" ]	   
	}, created);
	
	delete value.last;
	
	return Assert.areEqual(expected, value);

    });

});

TODO("Returns correct subject.", function(next) {
    Assert.fail();
});


TODO("Returns 404 when database does not exist.", function(next) {
    Assert.fail();
});


TODO("Returns 404 when chatroom does not exist.", function(next) {
    Assert.fail();
});

TODO("Returns 401 when token is not valid.", function(next) {
    Assert.fail();
});
 


