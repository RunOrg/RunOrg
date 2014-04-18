// GET /db/{db}/forms
// Forms / List all forms
// 
// Alpha @ 0.1.41
//
// `200 OK`, 
// [Read-only](/docs/#/concept/read-only.md),
// [Paginated](/docs/#/concept/paginated.md).
//
// Returns all the forms that can be seen by contact `{as}`, in arbitrary order.
// Supports `limit` and `offset` pagination. 
//
// ### Response format
//     { "list": [ <short-form>, ... ] }
// - `list` is a list of forms on the requested page, in 
//   [short format](/docs/#/format/short.js)

TEST("The response has valid return code and content type.", function(next) {

    var db = Query.mkdb();
    var response = Test.query("GET",["db/",db,"/forms"]).response();

    response.map(function(r) {
	Assert.areEqual(200, r.status).then();
	Assert.isTrue(r.responseJSON, "Response type is JSON").then();
    }).then(next);

});

// # Examples
// 
// ### Example request
//     GET /db/0SNQc00211H/forms?as=0Sd7003511H&limit=3&offset=213
// 
// ### Example response
//     200 OK
//     Content-Type: application/json 
//     
//     { "list" : [ 
//       { "id" : "0SNQe00311H",
//         "owner" : "contact",
//         "label" : "Why did you join our group ?", 
//         "fields" : 2,
//         "access" : ["fill"] },
//       { "id" : "0SNQg00511H",
//         "label" : null,
//         "owner" : "contact", 
//         "fields" : 1,
//         "pic" : ["admin","fill"] }

TEST("Returns data for all forms.", function(next) {

    var exampleA = {
	"owner": "contact",	
	"audience": { "fill": "anyone" },
	"label": "Join form",
	"custom": [1,2,3],
	"fields": [ {
	    "id": "1",
	    "label": "Why did you join our group ?",
	    "kind": "text",
	    "required": true
	}, {
	    "id": "2",
	    "label": "How often do you log in ?",
	    "kind": "single",
            "choices" : [
		"Every day",
		"Once a week",
		"Once a month",
		"Less than once a month" ],
	    "required": false
	} ]
    };

    var exampleB = {
	"owner": "contact",	
	"audience": { "admin": "anyone" },
	"label": "Personal information",
	"fields": [ {
	    "id": "1",
	    "label": "First pet's name",
	    "kind": "text",
	    "required": false
	} ]
    };

    var exampleC = {
	"owner": "contact",	
	"audience": {},
	"label": "Private information",
	"fields": [ {
	    "id": "1",
	    "label": "Your favourite color",
	    "kind": "text",
	    "required": false
	} ]
    };


    var db = Query.mkdb();
    var auth = Query.auth(db);

    Test.query("POST",["db/",db,"/forms"],exampleA,auth).result("id")(function(idA) {
	Test.query("POST",["db/",db,"/forms"],exampleB,auth).result("id")(function(idB) {
	    Test.query("POST",["db/",db,"/forms"],exampleC,auth).result("id")(function(idC) {

		var expected = {
		    "list" : [ {
			"id": idA,
			"owner": "contact",
			"access": ["fill"],
			"fields": 2,
			"label": exampleA.label
		    }, { 
			"id": idB,
			"owner": "contact",
			"access": ["admin","fill"],
			"fields": 1,
			"label": exampleB.label
		    } ]
		};
		
		var list = Test.query("GET",["db/",db,"/forms"]).result();

		Assert.areEqual(expected, list).then(next);

	    });
	});
    });
    
});

// # Errors
// 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(next) {
    Test.query("GET",["db/00000000000/forms"]).error(404).then(next);
});


// ## Returns `401 Unauthorized` 
// - ... if the provided token does not grant mathch contact `{as}`.

TEST("Returns 401 when token is not valid.", function(next) {
    var db = Query.mkdb();
    Test.query("GET",["db/",db,"/forms"],{token:"012345789a",id:"0123456789a"})
	.error(401).then(next);
});
 
// # Access restrictions
//
// Anyone can ask for a list of forms, and will only be shown the forms
// they can see (**fill** access is required). 