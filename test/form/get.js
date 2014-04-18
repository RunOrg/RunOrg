// GET /db/{db}/forms/{id}
// Forms / Get the meta-data of a form.
// 
// Alpha @ 0.1.37
//
// `200 OK`, 
// [Read-only](/docs/#/concept/read-only.md),
// [Viewer-dependent](/docs/#/concept/viewer-dependent.md).
//
// Contact [`{as}`](/docs/#/concept/as.md) retrieves returns the meta-data that 
// they can see about a form.
// Different fields have a different access level, and will be missing unless the
// contact has that access level. 
//
// ### Response format
//     { "id"       : <id>,
//       "owner"    : <owner>,
//       "label"    : <label> | null,
//       "fields"   : [ <field>, ... ],       
//       "custom"   : <json>,
//       "access"   : [ <access>, ... ],
//       "audience" : <form-audience>, }
// - `id` is the identifier of the form.
// - `owner` is the nature of the owners associated with each filled instance
//   of the form. In the current version of the API, this is always `"contact"`
//   (each instance is owned by a contact). 
// - `label` is an optional [human-readable name](/docs/#/types/label.js).
// - `fields` is an ordered list of [fields](/docs/#/form/field.js) to be 
//   filled.
// - `custom` is an arbitrary block of JSON provided by the creator of the
//   form, and returned as-is by the API. 
// - `access` is the list of access levels the contact `{as}` has over the
//   form. See [audience and access](/docs/#/concept/audience.md) for more 
//   information.
// - `audience` (**admin**-only) is the [audience](/docs/#/form/audience.js) of the form.

TEST("The response has valid return code and content type.", function(next) {

    var example = { 
	"owner": "contact",
	"audience": {},
	"fields": []
    };

    var db = Query.mkdb(),
        token = Query.auth(db),
        id = Test.query("POST",["db/",db,"/forms"],example,token).result('id'),
        response = Test.query("GET",["db/",db,"/forms/",id],token).response();

    response.map(function(r) {
	Assert.areEqual(200, r.status).then();
	Assert.isTrue(r.responseJSON, "Response type is JSON").then();
    }).then(next);

});

// # Examples
// 
// ### Example request
//     GET /db/0SNQc00211H/forms/0SNQe0032JZ?as=0SNxd0002JZ
// 
// ### Example response
//     200 OK
//     Content-Type: application/json 
//     { "id" : "0SNQe0032JZ",
//       "label" : "Personal information", 
//       "owner" : "contact",
//       "custom" : null,
//       "fields" : [ {
//         "id" : "1",
//         "label" : "Why did you join our group ?",
//         "kind" : "text",
//         "required" : true
//       }, {
//         "id" : "2", 
//         "label" : "How often do you log in ?",
//         "kind" : "single",
//         "choices" : [
//           "Every day",
//           "Once a week",
//           "Once a month",
//           "Less than once a month" ],
//         "required" : false
//       } ],
//       "access" : [ "admin", "fill" ],
//       "audience" : {
//         "admin": {},
//         "fill": { groups: [ "0SNQe0032JZ" ] } } }

TEST("Returns correct data in fill level.", function(next) {

    var example = { 
	"owner": "contact",
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
    var token = Query.auth(db);
    var id = Test.query("POST",["db/",db,"/forms"],example,token).result('id');

    var form = Test.query("GET",["db/",db,"/forms/",id]).result();

    var expect = {
	"id" : id,
	"owner": "contact",
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

    Assert.areEqual(expect, form).then(next);

});

TEST("Returns correct data in admin level.", function(next) {

    var example = { 
	"owner": "contact",
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
    var token = Query.auth(db);
    var id = Test.query("POST",["db/",db,"/forms"],example,token).result('id');

    var form = Test.query("GET",["db/",db,"/forms/",id],token).result();

    var expect = {
	"id" : id,
	"owner": "contact",
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

    Assert.areEqual(expect, form).then(next);

});

// # Errors
// 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(next) {

    Test.query("GET",["db/00000000000/forms/00000000001"])
	.error(404).then(next);

});

// - ... if form `{id}` does not exist in database `{db}`

TEST("Returns 404 when form does not exist.", function(next) {

    var db = Query.mkdb();

    Test.query("GET",["db/",db,"/forms/00000000001"])
	.error(404).then(next);

});

// - ... if contact `{as}` does not have at least **fill** 
//   access to view form `{id}`, to ensure [absence 
//   equivalence](/docs/#/concept/absence-equivalence.md). 

TEST("Returns 404 when form not viewable.", function(next) {

    var example = { 
	"owner": "contact",
	"audience": {},
	"fields": []
    };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Test.query("POST",["db/",db,"/forms"],example,auth).result("id");

    var peon = Query.auth(db,false,"peon@runorg.com");
    Test.query("GET",["db/",db,"/forms/",id],peon)
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
    var id = Test.query("POST",["db/",db,"/forms"],example,auth).result("id");

    Test.query("GET",["db/",db,"/forms/",id],{tok:"0123456789a",id:"0123456789a"})
	.error(401).then(next);    

});


 // # Access restrictions
//
// Subject to the form's `fill` [audience](/docs/#/form/audience.md). 
