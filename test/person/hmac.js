// POST /people/auth/hmac

TEST("Correctly authenticates user.", function(Query) {

    var example = { "email" : "vnicollet@runorg.com",
		    "name" : "Victor Nicollet",
		    "gender" : "M" };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/people/import"],[example],auth)
	.then(function(d,s,r) { return d.imported[0]; });

    var key = "74e6f7298a9c2d168935f58c001bad88";
    var kid = Query.post(["db/",db,"/keys"],{"hash":"SHA-1","key":key,"encoding":"hex"},auth).id();

    return id.then(function(id) {
	
	var date = "2020-12-31T23:59:59Z";
        var assertion = "auth:" + id + ":until:" + date;
	    
	var sha1 = new jsSHA(assertion,"TEXT");
        var hmac = sha1.getHMAC(key,"HEX","SHA-1","HEX");
	
	var r = Query.post(["db/",db,"/people/auth/hmac"],{"id":id,"expires":date,"proof":hmac,"key":kid})
	    .then(function(d,s,r) { return d.self; });

	var expected = { 
	    "id": id, 
	    "label": "Victor Nicollet",
	    "gender": "M", 
	    "pic" : "https://www.gravatar.com/avatar/5a31b00f649489a9a24d3dc3e8b28060?d=identicon" 
	};
	
	return Assert.areEqual(expected, r);

    });

});

TEST("Returns 404 when database does not exist.", function(Query) {
    var hmac = {"id":"","expires":"1970-01-01","key":"","proof":""};
    return Query.post("/db/00000000001/people/auth/hmac", hmac)
	.assertStatus(404);
});
