// GET /db/{db}/forms/{id}/filled/{owner}

var Form = { 
    "owner": "person",
    "audience": {},
    "fields": [ { 
	"id": "color",
	"kind": "text",
	"label": "Favourite color"
    } ]
};

var Data = { "data": { "color" : "Red" } };

TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],Form,auth).id();

    return Query.put(["db/",db,"/forms/",id,"/filled/",auth.id],Data,auth).then(function() {
	return Query.get(["db/",db,"/forms/",id,"/filled/",auth.id],auth)
	    .assertStatus(200).assertIsJson();
    });
});

TEST("Returns correct data.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],Form,auth).id();

    return Query.put(["db/",db,"/forms/",id,"/filled/",auth.id],Data,auth).then(function() {
	return Query.get(["db/",db,"/forms/",id,"/filled/",auth.id],auth).then(function(d,s,r) {

	    var expected = {
		"owner" : auth.id,
		"data" : Data.data
	    };

	    return Assert.areEqual(expected, d);

	});
    });

});

TEST("Returns 404 when database does not exist.", function(Query) {

    return Query.get(["db/00000000000/forms/00000000001/filled/00000000002"])
	.assertStatus(404);

});

TEST("Returns 404 when form does not exist.", function(Query) {

    var db = Query.mkdb();

    return Query.get(["db/",db,"/forms/00000000001/filled/00000000002"])
	.assertStatus(404);

});

TEST("Returns 404 when form is not filled.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],Form,auth).id();

    return Query.get(["db/",db,"/forms/",id,"/filled/",auth.id],auth)
	.assertStatus(404);

});

TEST("Returns 404 when form not viewable.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],Form,auth).id();

    return Query.put(["db/",db,"/forms/",id,"/filled/",auth.id],Data,auth).then(function() {
    
	var peon = Query.auth(db,false,"peon@runorg.com");
	return Query.get(["db/",db,"/forms/",id,"/filled/",auth.id],peon)
	    .assertStatus(404);

    });
});

TEST("Returns 401 when auth is not valid.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],Form,auth).id();

    return Query.get(["db/",db,"/forms/",id,"/filled/",auth.id],{tok:"0123456789a",id:"0123456789a"})
	.assertStatus(401);    

});

TEST("Returns 403 when form instance not viewable.", function(Query) {

    var form = $.extend({},Form,{"audience":{"fill":"anyone"}})

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],form,auth).id();

    return Query.put(["db/",db,"/forms/",id,"/filled/",auth.id],Data,auth).then(function(){
    
	var peon = Query.auth(db,false,"peon@runorg.com");
	return Query.get(["db/",db,"/forms/",id,"/filled/",auth.id],peon)
	    .assertStatus(403);

    });
});

