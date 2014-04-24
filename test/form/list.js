// GET /db/{db}/forms
// Forms / List all forms
// 
// Alpha @ 0.1.41
//
// `200 OK`, 
// [Read-only](/docs/#/concept/read-only.md),
// [Paginated](/docs/#/concept/paginated.md).
//
// Returns all the forms that can be seen by person `{as}`, in arbitrary order.
// Supports `limit` and `offset` pagination. 
//
// ### Response format
//     { "list": [ <short-form>, ... ] }
// - `list` is a list of forms on the requested page, in 
//   [short format](/docs/#/format/short.js)

TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    return Query.get(["db/",db,"/forms"]).assertStatus(200).assertIsJson();

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
//         "owner" : "person",
//         "label" : "Why did you join our group ?", 
//         "fields" : 2,
//         "access" : ["fill"] },
//       { "id" : "0SNQg00511H",
//         "label" : null,
//         "owner" : "person", 
//         "fields" : 1,
//         "pic" : ["admin","fill"] }

TEST("Returns data for all forms.", function(Query) {

    var exampleA = {
	"owner": "person",	
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
	"owner": "person",	
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
	"owner": "person",	
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

    return Query.post(["db/",db,"/forms"],exampleA,auth).id().then(function(idA) {
	return Query.post(["db/",db,"/forms"],exampleB,auth).id().then(function(idB) {
	    return Query.post(["db/",db,"/forms"],exampleC,auth).id().then(function(idC) {

		var expected = {
		    "list" : [ {
			"id": idA,
			"owner": "person",
			"access": ["fill"],
			"fields": 2,
			"label": exampleA.label
		    }, { 
			"id": idB,
			"owner": "person",
			"access": ["admin","fill"],
			"fields": 1,
			"label": exampleB.label
		    } ]
		};
		
		return Query.get(["db/",db,"/forms"]).then(function(d,s,r) {
		    return Assert.areEqual(expected, d);
		});
	    });
	});
    });
    
});

// # Errors
// 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.get(["db/00000000000/forms"]).assertStatus(404);
});


// ## Returns `401 Unauthorized` 
// - ... if the provided token does not grant match person `{as}`.

TEST("Returns 401 when token is not valid.", function(Query) {
    var db = Query.mkdb();
    return Query.get(["db/",db,"/forms"],{token:"012345789a",id:"0123456789a"})
	.assertStatus(401);
});
 
// # Access restrictions
//
// Anyone can ask for a list of forms, and will only be shown the forms
// they can see (**fill** access is required). 