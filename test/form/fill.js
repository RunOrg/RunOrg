// PUT /db/{db}/forms/{id}/filled/{owner}
// Forms / Fill a form. 
// 
// Alpha @ 0.1.43
//
// `202 Accepted`, 
// [Idempotent](/docs/#/concept/idempotent.md).
//
// Contact [`{as}`](/docs/#/concept/as.md) fills in an instance of 
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

TEST("The response has valid return code and content type.", function(next) {

    var form = { 
	"owner": "contact",
	"audience": {},
	"fields": [ { 
	    "id": "color",
	    "kind": "text",
	    "label": "Favourite color"
	} ]
    };

    var data = { "data": { "color" : "Red" } };

    var db = Query.mkdb();
    var token = Query.auth(db);
    var id = Test.query("POST",["db/",db,"/forms/create"],form,token).result('id');

    var response = Test.query("PUT",["db/",db,"/forms/",id,"/filled/",token.id],data,token).response();

    response.map(function(r) {
	Assert.areEqual(202, r.status).then();
	Assert.isTrue(r.responseJSON, "Response type is JSON").then();
    }).then(next);
    
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

TEST("Correct data is available.", function(next) {

    var form = { 
	"owner": "contact",
	"audience": {},
	"fields": [ { 
	    "id": "color",
	    "kind": "text",
	    "label": "Favourite color"
	} ]
    };

    var data = { "color" : "Red" };

    var db = Query.mkdb();
    var token = Query.auth(db);
    var id = Test.query("POST",["db/",db,"/forms/create"],form,token).result('id');

    Test.query("PUT",["db/",db,"/forms/",id,"/filled/",token.id],{"data":data},token).response().then(function(){

	var result = Test.query("GET",["db/",db,"/forms/",id,"/filled/",token.id],token).result();

	var expected = {
	    "owner" : token.id,
	    "data" : data
	};

	Assert.areEqual(expected, result).then(next);

    });

});


// # Errors
// 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(next) {

    Test.query("PUT",["db/00000000000/forms/00000000001/filled/00000000002"],{"data":{}})
	.error(404).then(next);

});

// - ... if form `{id}` does not exist in database `{db}`

TEST("Returns 404 when form does not exist.", function(next) {

    var db = Query.mkdb();

    Test.query("PUT",["db/",db,"/forms/00000000001/filled/00000000002"],{"data":{}})
	.error(404).then(next);

});


// - ... if contact `{as}` is not allowed to view form `{id}`, to ensure 
// [absence equivalence](/docs/#/concept/absence-equivalence.md). 

TEST("Returns 404 when form not viewable.", function(next) {

    var form = { 
	"owner": "contact",
	"audience": {},
	"fields": [ { 
	    "id": "color",
	    "kind": "text",
	    "label": "Favourite color"
	} ]
    };

    var data = { "data": { "color" : "Red" } };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Test.query("POST",["db/",db,"/forms/create"],form,auth).result("id");

    var peon = Query.auth(db,false,"peon@runorg.com");
    Test.query("PUT",["db/",db,"/forms/",id,"/filled/",peon.id],data,peon)
	.error(404).then(next);
});


// ## Returns `401 Unauthorized` 
// - ... if the provided token does not grant access as the named 
//   contact, or no token was provided

TEST("Returns 401 when token is not valid.", function(next) {

    var example = {
	"owner": "contact",
	"audience": {},
	"fields": []
    };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Test.query("POST",["db/",db,"/forms/create"],example,auth).result("id");

    Test.query("PUT",["db/",db,"/forms/",id,"/filled/",auth.id],{"data":{}},{tok:"0123456789a",id:"0123456789a"})
	.error(401).then(next);    

});


// ## Returns `403 Forbidden`
// - ... if contact `{as}` is can view the form, but not fill the requested 
//   instance. For instance, without **admin** access, a contact may only
//   fill the instance bound to himself (`{owner} == {as}`), and not to 
//   other contacts. Access restrictions are defined for each type of 
//   owner.

TEST("Returns 403 when form instance not viewable.", function(next) {

    var form = { 
	"owner": "contact",
	"audience": { "fill" : "anyone" },
	"fields": [ { 
	    "id": "color",
	    "kind": "text",
	    "label": "Favourite color"
	} ]
    };

    var data = { "data": { "color" : "Red" } };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Test.query("POST",["db/",db,"/forms/create"],form,auth).result("id");

    var peon = Query.auth(db,false,"peon@runorg.com");
    Test.query("PUT",["db/",db,"/forms/",id,"/filled/",auth.id],data,peon)
	    .error(403).then(next);
});

TEST("Allow cross-filling when admin", function(next) {

    var form = { 
	"owner": "contact",
	"audience": { "fill" : "anyone" },
	"fields": [ { 
	    "id": "color",
	    "kind": "text",
	    "label": "Favourite color"
	} ]
    };

    var data = { "data": { "color" : "Red" } };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Test.query("POST",["db/",db,"/forms/create"],form,auth).result("id");

    var peon = Query.auth(db,false,"peon@runorg.com");
    Test.query("PUT",["db/",db,"/forms/",id,"/filled/",peon.id],data,auth)
	.success(202).then(next);
});

// ## Returns `400 Bad Request`
// - ... if a required field was not provided or is `null`, `""`, `[]` or `{}`. 

TEST("Missing required field.", function(next) {

    var form = { 
	"owner": "contact",
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
    var id = Test.query("POST",["db/",db,"/forms/create"],form,auth).result("id");

    var tests = [];
    for (var i = 0; i < data.length; ++i) 
	tests.push(Test.query("PUT",["db/",db,"/forms/",id,"/filled/",auth.id],data[i],auth)
		   .error(400));

    tests.then(next);
});

// - ... if a provided field does not exist in the form. 

TEST("Unknown provided field.", function(next) {

    var form = { 
	"owner": "contact",
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
    var id = Test.query("POST",["db/",db,"/forms/create"],form,auth).result("id");

    var tests = [];
    Test.query("PUT",["db/",db,"/forms/",id,"/filled/",auth.id],data,auth)
	.error(400).then(next);

});

// - ... A provided field was not in the expected data format. 

TEST("Missing required field.", function(next) {

    var form = { 
	"owner": "contact",
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
	    "id": "contact",
	    "kind": "contact",
	    "label": "Contact"
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
        { "contact": "00000000000" },
        { "contact": 123 }
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
        { "contact": auth.id },
	{ "contact": null }
    ]; 

    var id = Test.query("POST",["db/",db,"/forms/create"],form,auth).result("id");

    var tests = [];
    for (var i = 0; i < fail.length; ++i) 
	tests.push(Test.query("PUT",["db/",db,"/forms/",id,"/filled/",auth.id],{"data":fail[i]},auth)
		   .error(400));

    for (var i = 0; i < success.length; ++i) 
	tests.push(Test.query("PUT",["db/",db,"/forms/",id,"/filled/",auth.id],{"data":success[i]},auth)
		   .success(202));

    tests.then(next);
});


// # Access restrictions
//
// Contact must have `fill` [audience](/docs/#/form/audience.md) access to 
// the form, and be able to fill the instance.
