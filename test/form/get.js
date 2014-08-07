// GET /forms/{id}

var Example = { 
    "owner": "person",
    "audience": {},
    "fields": []
};


TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],Example,auth).id();
    
    return Query.get(["db/",db,"/forms/",id],auth)
	.assertStatus(200).assertIsJson();

});

TEST("Returns correct data in fill level.", function(Query) {

    var example = { 
	"owner": "person",
	"audience": { "fill": "anyone" },
	"label": "Personal information",
	"custom": [1,2,3],
	"fields": [ {
	    "id": "1",
	    "label": "Why did you join our group ?",
	    "kind": "text",
	    "required": true
	} ]
    };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],example,auth).id();

    return Query.get(["db/",db,"/forms/",id]).then(function(d,s,r) {

	var expect = {
	    "id" : id,
	    "owner": "person",
	    "label": "Personal information",
	    "access": ["fill"],
	    "audience": null, // No server support for missing fields yet
	    "custom": [1,2,3],
	    "fields": [ {
		"id": "1",
		"label": "Why did you join our group ?",
		"kind": "text",
		"required": true,
		"custom": null, // No server support for missing fields yet
		"choices": [] // No server support for missing fields yet
	    } ]
	};    
	
	return Assert.areEqual(expect, d);
    });

});

TEST("Returns correct data in admin level.", function(Query) {

    var example = { 
	"owner": "person",
	"audience": { "fill": "anyone" },
	"label": "Personal information",
	"custom": [1,2,3],
	"fields": [ {
	    "id": "1",
	    "label": "Why did you join our group ?",
	    "kind": "text",
	    "required": true
	} ]
    };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],example,auth).id();

    return Query.get(["db/",db,"/forms/",id],auth).then(function(d,s,r) {

	var expect = {
	    "id" : id,
	    "owner": "person",
	    "label": "Personal information",
	    "access": ["admin","fill"],
	    "audience": { "fill": "anyone" },
	    "custom": [1,2,3],
	    "fields": [ {
		"id": "1",
		"label": "Why did you join our group ?",
		"kind": "text",
		"required": true,
		"custom": null, // No server support for missing fields yet
		"choices": [] // No server support for missing fields yet
	    } ]
	};    

	return Assert.areEqual(expect, d);
    });

});

TEST("Returns 404 when database does not exist.", function(Query) {

    return Query.get(["db/00000000000/forms/00000000001"]).assertStatus(404);

});

TEST("Returns 404 when form does not exist.", function(Query) {

    var db = Query.mkdb();

    return Query.get(["db/",db,"/forms/00000000001"]).assertStatus(404);

});

TEST("Returns 404 when form not viewable.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],Example,auth).id();

    var peon = Query.auth(db,false,"peon@runorg.com");
    return Query.get(["db/",db,"/forms/",id],peon).assertStatus(404);

});

TEST("Returns 401 when token is not valid.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],Example,auth).id();

    return Query.get(["db/",db,"/forms/",id],{tok:"0123456789a",id:"0123456789a"})
	.assertStatus(401);

});
