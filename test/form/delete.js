// DELETE /forms/{id}

function Example(audience) {
    return { 
	"owner": "person",
	"audience": audience || {},
	"fields": []
    }
}


TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    
    var id = Query.post(["db/",db,"/forms"],Example(),auth).id();

    return Query.del(["db/",db,"/forms/",id],auth)
	.assertStatus(202).assertIsJson();

});

TEST("Deleted form disappears.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    
    var id = Query.post(["db/",db,"/forms"],Example(),auth).id();

    return Query.del(["db/",db,"/forms/",id],auth).then(function() {
	return Query.get(["db/",db,"/forms/",id],auth).assertStatus(404);
    });

});

TEST("Deleted form disappears from list.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    
    var id = Query.post(["db/",db,"/forms"],Example(),auth).id();

    return Query.del(["db/",db,"/forms/",id],auth).then(function() {
	return Query.get(["db/",db,"/forms/"],auth).then(function(list) {
	    return Assert.areEqual({"list":[]}, list);
	});
    });

});

TEST("Returns 401 when token is not valid.", function(Query) {
    var db = Query.mkdb();
    return Query.del(["db/",db,"/forms/00000000000"],{id:"01234567890",token:"01234567890"})
	.assertStatus(401);
});

TEST("Returns 403 when deleting form without admin access.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],Example({"fill":"anyone"}),auth).id();
    var peon = Query.auth(db,false,"peon@runorg.com")
    return Query.del(["db/",db,"/forms/",id],peon).assertStatus(403);
});

TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.del(["db/00000000000/forms/00000000000"])
	.assertStatus(404);
});

TEST("Returns 404 when form does not exist.", function(Query) {
    var db = Query.mkdb();
    return Query.del(["db/",db,"/forms/00000000000"])
	.assertStatus(404);
});
