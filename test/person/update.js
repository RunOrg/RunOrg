// PUT /people/{id}

TEST("The response has valid return code and content type.", function(Query) {

    var example = { "email" : "vnicollet@runorg.com" };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/people/import"],[example],auth)
	.then(function(d) { return d.imported[0]; });

    return Query.put(["db/",db,"/people/",id],example,auth)
	.assertStatus(202).assertIsJson();

});

TEST("The example was properly returned.", function(Query) {

    var example = { "email" : "vnicollet@runorg.com",
		    "name" : "Victor Nicollet",
		    "gender" : "M" };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/people/import"],[{ "email": "invalid@example.com" }],auth)
	.then(function(d) { return d.imported[0]; });

    return Query.put(["db/",db,"/people/",id],example,auth).then(function() {
    
	var created = Query.get(["db/",db,"/people/",id]).then(function(d) { return d; });
	
	var expected = { 
	    "id": id, 
	    "label": "Victor Nicollet",
	    "gender": "M", 
	    "pic" : "https://www.gravatar.com/avatar/5a31b00f649489a9a24d3dc3e8b28060?d=identicon" };
	
	return Assert.areEqual(expected, created);

    });

});

TEST("Overwriting the name with 'null'.", function(Query) {

    var example = { "email" : "vnicollet@runorg.com",
		    "name" : "V. Nicollet",
		    "gender" : "M" };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/people/import"],[example],auth)
	.then(function(d) { return d.imported[0]; });

    var updated = {
	"name": null,
	"givenName" : "Victor",
	"familyName" : "Nicollet",
	"gender" : null
    };
    
    return Query.put(["db/",db,"/people/",id],updated,auth).then(function() {
    
	var created = Query.get(["db/",db,"/people/",id]).then(function(d) { return d; });
	
	var expected = { 
	    "id": id, 
	    "label": "Victor Nicollet",
	    "gender": null, 
	    "pic" : "https://www.gravatar.com/avatar/5a31b00f649489a9a24d3dc3e8b28060?d=identicon" };
	
	return Assert.areEqual(expected, created);

    });

});

TEST("Not overwriting when missing.", function(Query) {

    var example = { "email" : "vnicollet@runorg.com",
		    "name" : "V. Nicollet",
		    "gender" : "M" };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/people/import"],[example],auth)
	.then(function(d) { return d.imported[0]; });

    var updated = {
	"givenName" : "Victor",
	"familyName" : "Nicollet",
	"gender" : null
    };
    
    return Query.put(["db/",db,"/people/",id],updated,auth).then(function() {
    
	var created = Query.get(["db/",db,"/people/",id]).then(function(d) { return d; });
	
	var expected = { 
	    "id": id, 
	    "label": "V. Nicollet",
	    "gender": null, 
	    "pic" : "https://www.gravatar.com/avatar/5a31b00f649489a9a24d3dc3e8b28060?d=identicon" };
	
	return Assert.areEqual(expected, created);

    });

});

TEST("Can edit self.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db,false,"peon@runorg.com");
    return Query.put(["db/",db,"/people/",auth.id],{},auth).assertStatus(202);
});

TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.put("/db/00000000001/people/00000000002",{}).assertStatus(404);
});

TEST("Returns 404 when person does not exist in database.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.put(["db/",db,"/people/00000000002"],{},auth).assertStatus(404);
});

TEST("Returns 403 when not administrator.", function(Query) {
    var db = Query.mkdb();
    var test = Query.auth(db);
    var auth = Query.auth(db,false,"peon@runorg.com");
    return Query.put(["db/",db,"/people/",test.id],{},auth).assertStatus(403);
});

