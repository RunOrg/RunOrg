var example = { "label" : "Board members" };

TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    
    return Query.post(["db/",db,"/groups"],example,auth)
	.assertStatus(202).assertIsJson();

});

TEST("Group with forced id appears.", function(Query) {

    var id = "board";
    var example = { "id" : id, "label" : "Board members" };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    
    return Query.post(["db/",db,"/groups"],example,auth).then(function() {
	var get = Query.get(["db/",db,"/groups/",id,"/info"],auth).then(function(d) { return d; });
	var expected = {
	    "id":id,
	    "label":"Board members",
	    "access":["view","list","admin","moderate"],
	    "count":0,
	    "audience": {}
	};
	return Assert.areEqual(expected, get);
    });

});

TEST("New group with forced id created after deletion.", function(Query) {

    var id = "board";
    var example = { "id" : id, "label" : "Broad members" };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    
    return Query.post(["db/",db,"/groups"],example,auth).then(function() {

	return Query.del(["db/",db,"/groups/",id],auth).then(function(){

	    example.label = "Board members";

	    return Query.post(["db/",db,"/groups"],example,auth).then(function(){
		var get = Query.get(["db/",db,"/groups/",id,"/info"],auth).then(function(d) { return d; });
		var expected = {
		    "id":id,
		    "label":"Board members",
		    "access":["view","list","admin","moderate"],
		    "count":0,
		    "audience": {}
		};
		return Assert.areEqual(expected, get);
	    });
	});
    });
});

TEST("Multiple creations create multiple groups.", function(Query) {

    var example = { "label" : "Sample group" };

    var db = Query.mkdb();
    var auth = Query.auth(db);

    var id1 = Query.post(["db/",db,"/groups"],example,auth).id();
    var id2 = Query.post(["db/",db,"/groups"],example,auth).id();

    var get1 = Query.get(["db/",db,"/groups/",id1,"/info"],auth).then(function(d) { return d; });
    var get2 = Query.get(["db/",db,"/groups/",id2,"/info"],auth).then(function(d) { return d; });

    var expected1 = {
	"id":id1,
	"label":"Sample group",
	"access":["view","list","admin","moderate"],
	"count":0,
	"audience": {}
    };

    var expected2 = {
	"id":id2,
	"label":"Sample group",
	"access":["view","list","admin","moderate"],
	"count":0,
	"audience": {}
    };
    
    return $.when(
	Assert.notEqual(id1, id2),
	Assert.areEqual(expected1, get1),
	Assert.areEqual(expected2, get2)
    );
	    
});

TEST("Returns 400 when custom id is invalid.", function(Query) {

    var ex1 = { "id": "a-b", "label" : "Invalid character" };
    var ex2 = { "id": "0123456789a", "label" : "Too long" };

    var db = Query.mkdb();
    var auth = Query.auth(db);

    return $.when(
	Query.post(["db/",db,"/groups"],ex1,auth).assertStatus(400),
	Query.post(["db/",db,"/groups"],ex2,auth).assertStatus(400)
    );
    
});

TEST("Returns 401 when token is not valid.", function(Query) {
    var db = Query.mkdb();
    return Query.post(["db/",db,"/groups"],example,{tok:"0123456789a",id:"0123456789a"})
	.assertStatus(401);
});

TEST("Returns 403 creating groups is not allowed.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db, false); 
    return Query.post(["db/",db,"/groups"],example,auth).assertStatus(403);
});
 
TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.post(["db/01234567890/groups"],example).assertStatus(404);
});

TEST("Returns 409 when the group exists.", function(Query) {

    var id = "board";
    var example = { "id" : id, "label" : "Board members" };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    
    return Query.post(["db/",db,"/groups"],example,auth).then(function() {
	return Query.post(["db/",db,"/groups"],example,auth).assertStatus(409);
    });
});

TEST("Returns 409 when re-creating the admin group.", function(Query) {

    var id = "admin";
    var example = { "id" : id, "label" : "Board members" };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    
    return Query.post(["db/",db,"/groups"],example,auth).assertStatus(409);

});

