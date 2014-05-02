// PUT /db/{db}/forms/{id}/filled/{owner}
// Forms / Fill a form. 
// 
// Beta @ 0.9.0
//
// `202 Accepted`, 
// [Idempotent](/docs/#/concept/idempotent.md).
//
// Person [`{as}`](/docs/#/concept/as.md) fills in an instance of 
// form `{id}` bound to entity `{owner}`. 
//
// ### Request format
//     { "data" : { <key> : <value> }
//
// - `data` contains a dictionary mapping field names to arbitrary JSON values.
//   Expected contents depend on the configuration of individual form fields. 
//
// ### Response type
//     { "at" : <clock> }
//
// - `at` is a vector clock representing the point in time where the changes 
//   performed will be effective. 
// 

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

// # Examples
// 
// ### Example request
//     PUT /db/0SNQc00211H/forms/0SNQe0032JZ/filled/0SNxd0002JZ?as=0SNxd0002JZ
//     Content-Type: application/json
//    
//     { "data" : { 
//         "color": "Red",
//         "birth": "1985-04-19" } }
// 
// ### Example response
//     202 Accepted
//     Content-Type: application/json
// 
//     { "at" : [[5,218]] }

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


// # Errors
// 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(Query) {

    return Query.put(["db/00000000000/forms/00000000001/filled/00000000002"],Data)
	.assertStatus(404);

});

// - ... if form `{id}` does not exist in database `{db}`

TEST("Returns 404 when form does not exist.", function(Query) {

    var db = Query.mkdb();

    return Query.put(["db/",db,"/forms/00000000001/filled/00000000002"],Data)
	.assertStatus(404);

});


// - ... if person `{as}` is not allowed to view form `{id}`, to ensure 
// [absence equivalence](/docs/#/concept/absence-equivalence.md). 

TEST("Returns 404 when form not viewable.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],Form,auth).id();

    var peon = Query.auth(db,false,"peon@runorg.com");
    return Query.put(["db/",db,"/forms/",id,"/filled/",peon.id],Data,peon)
	.assertStatus(404);
});


// ## Returns `401 Unauthorized` 
// - ... if the provided token does not grant access as the named 
//   person, or no token was provided

TEST("Returns 401 when token is not valid.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],Form,auth).id();

    return Query.put(["db/",db,"/forms/",id,"/filled/",auth.id],Data,{tok:"0123456789a",id:"0123456789a"})
	.assertStatus(401);    

});


// ## Returns `403 Forbidden`
// - ... if person `{as}` is can view the form, but not fill the requested 
//   instance. For instance, without **admin** access, a person may only
//   fill the instance bound to himself (`{owner} == {as}`), and not to 
//   other persons. Access restrictions are defined for each type of 
//   owner.

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

// ## Returns `400 Bad Request`
// - ... if a required field was not provided or is `null`, `""`, `[]` or `{}`. 

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

// - ... if a provided field does not exist in the form. 

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

// - ... A provided field was not in the expected data format. 

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

// # Access restrictions
//
// Person must have `fill` [audience](/docs/#/form/audience.md) access to 
// the form, and be able to fill the instance.
