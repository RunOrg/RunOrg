TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    
    return Query.get(["db/",db,"/groups"],auth)
	.assertStatus(200).assertIsJson();
});

TEST("Initially empty.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);

    return Query.get(["/db/",db,"/groups"],auth).then(function(d,s,r) {
	return Assert.areEqual([],d.list);
    });

});

TEST("Need view access to see elements.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);

    var id1 = Query.post(["/db/",db,"/groups"],{}, auth).id();
    var id2 = Query.post(["/db/",db,"/groups"],{"audience":{"view":"anyone"}},auth).id();

    var peon = Query.auth(db,false,"peon@runorg.com");

    return $.when(id1,id2).then(function() {
	return Query.get(["/db/",db,"/groups"],peon).then(function(d,s,r) {

	    var expected = [
		{ "id" : id2,
		  "label" : null,
		  "access" : [ "view" ],
		  "count" : null }
	    ];

	    return Assert.areEqual(expected,d.list);

	});
    });

});

TEST("Returns 401 when token is invalid.", function(Query) {
    var db = Query.mkdb();
    return Query.get(["/db/",db,"/groups"],{id:"1234567890A",token:"1234567890A"})
	.assertStatus(401);
});

TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.get("/db/00000000001/groups").assertStatus(404);
});
  
