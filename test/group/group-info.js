// TYPE <groups/info>

TEST("The groups's identifier is returned.", function(Query) {

    var example = {};

    var db = Query.mkdb();
    var auth = Query.auth(db);

    var id = Query.post(["db/",db,"/groups"],example,auth).id();
    var id2 = Query.get(["db/",db,"/groups/",id,"/info"],auth).id();

    return Assert.areEqual(id,id2);

});

TEST("The group's label is returned if available.", function(Query) {

    var example = { "label" : "Associates" };

    var db = Query.mkdb();
    var auth = Query.auth(db);

    var id = Query.post(["db/",db,"/groups"],example,auth).id();
    var label = Query.get(["db/",db,"/groups/",id,"/info"],auth).then(function(d) { return d.label; });

    return Assert.areEqual(example.label,label);

});

TEST("The group's access levels are returned.", function(Query) {

    var example = { "audience" : { "moderate" : "anyone" } };

    var db = Query.mkdb();
    var auth = Query.auth(db);

    var id = Query.post(["db/",db,"/groups"],example,auth).id();
    var access = Query.get(["db/",db,"/groups/",id,"/info"]).then(function(d) { return d.access; });

    return Assert.areEqual([ "view", "list", "moderate" ], access);

});

TEST("The group's member count is returned.", function(Query) {

    var example = { "label" : "Associates" };

    var db = Query.mkdb();
    var auth = Query.auth(db);

    var id = Query.post(["db/",db,"/groups"],example,auth).id();
    
    return Query.post(["db/",db,"/groups/",id,"/add"],[auth.id],auth).then(function(){	
	return Query.get(["db/",db,"/groups/",id,"/info"],auth).then(function(d,s,r) {	    
	    return Assert.areEqual(1, d.count);	    
	});
    });

});

TEST("The group's member count requires 'list' access.", function(Query) {

    var example = { "label" : "Associates", "audience" : { "view" : "anyone" } };

    var db = Query.mkdb();
    var auth = Query.auth(db);

    var id = Query.post(["db/",db,"/groups"],example,auth).id();
    
    return Query.post(["db/",db,"/groups/",id,"/add"],[auth.id],auth).then(function(){	
	return Query.get(["db/",db,"/groups/",id,"/info"]).then(function(d,s,r) {	    
	    return Assert.areEqual(null, d.count);	    
	});
    });

});
