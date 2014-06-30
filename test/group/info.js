TEST("The response has valid return code and content type.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.get(["db/",db,"/groups/admin/info"],auth)
	.assertStatus(200).assertIsJson();    
});

TEST("Returns correct count.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.get(["db/",db,"/groups/admin/info"],auth).then(function(d,s,r) {
	return Assert.areEqual(1, d.count);
    });
});

TEST("Returns correct group label.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/groups"],{"label":"My Group"},auth).id();
    return Query.get(["db/",db,"/groups/",id,"/info"],auth).then(function(d,s,r) {
	return Assert.areEqual("My Group", d.label);
    });
});

TEST("Returns correct access and audience.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/groups"],{"audience":{"admin":"anyone"}},auth).id();
    return Query.get(["db/",db,"/groups/",id,"/info"],auth).then(function(d,s,r) {
	return Assert.areEqual({
	    "id": id,
	    "label": null,
	    "access": [ "view", "list", "admin", "moderate" ],
	    "count": 0,
	    "audience": { "admin": "anyone" }
	}, d);
    });
});

TEST("Do not include 'count' or 'audience' without list access.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);    
    var id = Query.post(["db/",db,"/groups"],{"audience":{"view":"anyone"}},auth).id();
    return Query.get(["db/",db,"/groups/",id,"/info"]).then(function(d,s,r) {
	return Assert.areEqual({
	    "id" :      id,
	    "label":    null,
	    "access":   [ "view" ],
	    "count":    null, /* no server side support for missing fields */
	    "audience": null  /* no server side support for missing fields */
	}, d);
    });
});

TEST("Do not include 'audience' without admin access.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/groups"],{"audience":{"moderate":"anyone"}},auth).id();
    return Query.get(["db/",db,"/groups/",id,"/info"]).then(function(d,s,r) {
	return Assert.areEqual({
	    "id" :      id,
	    "label":    null,
	    "access":   [ "view", "list", "moderate" ],
	    "count":    0,
	    "audience": null  /* no server side support for missing fields */
	}, d);
    });
});

TEST("Returns 401 when token is not valid.", function(Query) {
    var db = Query.mkdb();
    return Query.get(["db/",db,"/groups/admin/info"],{id:"01234567890",token:"01234567890"})
	.assertStatus(401);
});
 
TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.get(["db/00000000000/groups/admin/info"]).assertStatus(404);
});

TEST("Returns 404 when group does not exist.", function(Query) {
    var db = Query.mkdb();
    return Query.get(["db/",db,"/groups/00000000000/info"]).assertStatus(404);
});

TEST("Returns 404 when no 'view' access.", function(Query) {
    var db = Query.mkdb();
    var peon = Query.auth(db,false,"peon@runorg.com");
    return Query.get(["db/",db,"/groups/admin/info"],peon).assertStatus(404);
});
