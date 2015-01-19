// PUT /db/{db}/forms/{id}/filled/{owner}

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

    return Query.put(["db/",db,"/forms/",id,"/filled/",auth.id],Data,auth)
	.assertStatus(202).assertIsJson();

});

TEST("Correct data is available.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],Form,auth).id();

    return Query.put(["db/",db,"/forms/",id,"/filled/",auth.id],Data,auth).then(function() {

	var result = Query.get(["db/",db,"/forms/",id,"/filled/",auth.id],auth)
	    .then(function(d,s,r) { return d; });

	var expected = {
	    "owner" : auth.id,
	    "data" : Data.data
	};
	
	return Assert.areEqual(expected, result);
	
    });

});

TEST("Returns 404 when database does not exist.", function(Query) {

    return Query.put(["db/00000000000/forms/00000000001/filled/00000000002"],Data)
	.assertStatus(404);

});

TEST("Returns 404 when form does not exist.", function(Query) {

    var db = Query.mkdb();

    return Query.put(["db/",db,"/forms/00000000001/filled/00000000002"],Data)
	.assertStatus(404);

});

TEST("Returns 404 when form not viewable.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],Form,auth).id();

    var peon = Query.auth(db,false,"peon@runorg.com");
    return Query.put(["db/",db,"/forms/",id,"/filled/",peon.id],Data,peon)
	.assertStatus(404);
});

TEST("Returns 401 when token is not valid.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],Form,auth).id();

    return Query.put(["db/",db,"/forms/",id,"/filled/",auth.id],Data,{tok:"0123456789a",id:"0123456789a"})
	.assertStatus(401);    

});

TEST("Returns 403 when form instance not viewable.", function(Query) {

    var form = $.extend({},Form,{"audience":{"fill":"anyone"}});

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],form,auth).id();

    var peon = Query.auth(db,false,"peon@runorg.com");
    return Query.put(["db/",db,"/forms/",id,"/filled/",auth.id],Data,peon)
	    .assertStatus(403);
});

TEST("Allow cross-filling when admin", function(Query) {

    var form = $.extend({},Form,{"audience":{"fill":"anyone"}});

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],form,auth).id();

    var peon = Query.auth(db,false,"peon@runorg.com");
    return Query.put(["db/",db,"/forms/",id,"/filled/",peon.id],Data,auth)
	.assertStatus(202);
});

TEST("Missing required field.", function(Query) {

    var form = { 
	"owner": "person",
	"audience": { "fill" : "anyone" },
	"fields": [ { 
	    "id": "color",
	    "kind": "json",
	    "label": "Favourite color",
	    "required": true
	} ]
    };

    var data = [ 
	{ "data": { "color" : null } },
	{ "data": {} },
	{ "data": { "color" : [] } },
	{ "data": { "color" : {} } },
	{ "data": { "color" : "" } }
    ]; 

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],form,auth).id();

    var tests = [];
    for (var i = 0; i < data.length; ++i) 
	tests.push(Query.put(["db/",db,"/forms/",id,"/filled/",auth.id],data[i],auth)
		   .assertStatus(400));

    return Async.wait(tests);
});

TEST("Unknown provided field.", function(Query) {

    var form = { 
	"owner": "person",
	"audience": { "fill" : "anyone" },
	"fields": [ { 
	    "id": "color",
	    "kind": "json",
	    "label": "Favourite color"
	} ]
    };

    var data = { "data": { "color" : "Red", "unkown": true } };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],form,auth).id();

    return Query.put(["db/",db,"/forms/",id,"/filled/",auth.id],data,auth)
	.assertStatus(400);

});

TEST("Missing required field.", function(Query) {

    var form = { 
	"owner": "person",
	"audience": { "fill" : "anyone" },
	"fields": [ { 
	    "id": "text",
	    "kind": "text",
	    "label": "Text"
	}, { 
	    "id": "single",
	    "kind": "single",
	    "choices": [ "A", "B" ],
	    "label": "Single"
	}, { 
	    "id": "multiple",
	    "kind": "multiple",
	    "choices": [ "A", "B" ],
	    "label": "Multiple"
	}, { 
	    "id": "time",
	    "kind": "time",
	    "label": "Time"
	}, { 
	    "id": "person",
	    "kind": "person",
	    "label": "Person"
	} ]
    };

    var fail = [ 
	{ "text": [] },
        { "single": [1] },
        { "single": "1" },
        { "single": 2 },
        { "multiple": 1 },
        { "multiple": [1,2] },
        { "multiple": {} },
        { "time": 0 },
        { "time": "2014/01/01" },
        { "person": "00000000000" },
        { "person": 123 }
    ]; 

    var db = Query.mkdb();
    var auth = Query.auth(db);

    var success = [ 
	{ "text": "Hello" },
        { "single": 1, },
        { "multiple": [1] },
        { "multiple": [] },
        { "time": "2014-01-01" },
        { "time": "2014-01-01T23:59:59Z" },
        { "person": auth.id },
	{ "person": null }
    ]; 

    var id = Query.post(["db/",db,"/forms"],form,auth).id();

    var tests = [];
    for (var i = 0; i < fail.length; ++i) 
	tests.push(Query.put(["db/",db,"/forms/",id,"/filled/",auth.id],{"data":fail[i]},auth)
		   .assertStatus(400));

    for (var i = 0; i < success.length; ++i) 
	tests.push(Query.put(["db/",db,"/forms/",id,"/filled/",auth.id],{"data":success[i]},auth)
		   .assertStatus(202));

    return Async.wait(tests);
});

