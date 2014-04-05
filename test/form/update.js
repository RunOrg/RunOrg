// PUT /db/{db}/forms/{id}
// Forms / Update a form
//
// Alpha @ 0.1.36
//
// `202 Accepted`, [Delayed](/docs/#/concept/delayed.md), [Idempotent](/docs/#/concept/idempotent.md).
//
// Contact [`{as}`](/docs/#/concept/as.md) updates the properties of a form. Note 
// that once a form has been filled (even if only
// once), the list of fields may not be updated (though other properties can). 
// 
// ### Request format
//     { "label" : <label> | null,
//       "custom": <json>,
//       "owner": "contact",
//       "fields": [ <field>, ... ],
//       "audience": <audience> }
// - `label` is an optional [human-readable name](/docs/#/types/label.js).
// - `custom` is an arbitrary block of JSON that will be stored as-is by 
//   RunOrg and returned as such by the API.
// - `owner` is the nature of the owners associated with each filled instance
//   of the form. In the current version of the API, this is always `"contact"`
//   (each instance is owned by a contact). 
// - `fields` is an ordered list of [fields](/docs/#/form/field.js) to be 
//   filled.
// - `audience` is the [audience](/docs/#/form/audience.js) of the form.
// 
// The API will behave differently when a value is `null` and when it is missing. 
// For instance, `{"label":null}` will set the label to `null` and update nothing
// else, while `{}` will not update the label at all. 
//
// ### Response format
//     { "at" : <clock> }

TEST("The response has valid return code and content type.", function(next) {

    var example = { 
	"owner": "contact",
	"audience": {},
	"fields": []
    };

    var db = Query.mkdb(),
        token = Query.auth(db),
        id = Test.query("POST",["db/",db,"/forms/create"],example,token).result('id'),
        response = Test.query("PUT",["db/",db,"/forms/",id],example,token).response();

    response.map(function(r) {
	Assert.areEqual(202, r.status).then();
	Assert.isTrue(r.responseJSON, "Response type is JSON").then();
    }).then(next);
});


// ### Example request
//     PUT /db/0SNQc00211H/forms/0SNQe0032JZ
//     Content-Type: application/json
// 
//     { "label" : "Personal information", 
//       "audience" : {
//         "admin": {},
//         "fill": { groups: [ "0SNQe0032JZ" ] } } }
//
// ### Example response
//     202 Accepted
//     Content-Type: application/json
// 
//     { "at" : [[2,219]] }
//  
// # Errors
// 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(next) {

    var example = { 
	"owner": "contact",
	"audience": {},
	"fields": []
    };

    Test.query("PUT",["db/00000000000/forms/00000000001"],example)
	.error(404).then(next);
        
});

// - ... if form `{id}` does not exist in database `{db}` 

TEST("Returns 404 when form does not exist.", function(next) {

    var example = { 
	"owner": "contact",
	"audience": {},
	"fields": []
    };

    var db = Query.mkdb();

    Test.query("PUT",["db/",db,"/forms/00000000001"],example)
	.error(404).then(next);
        
});

// - ... if contact `{as}` cannot view form `{id}`, to ensure [absence 
//   equivalence](/docs/#/concept/absence-equivalence.md). 

TEST("Returns 404 when form cannot be viewed.", function(next) {

    var example = { 
	"owner": "contact",
	"audience": {},
	"fields": []
    };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Test.query("POST",["db/",db,"/forms/create"],example,auth).result("id");

    var peon = Query.auth(db,false);
    Test.query("PUT",["db/",db,"/forms/",id],example)
	.error(404).then(next);

});

// ## Returns `409 Conflict`
// - ... if the form has already been filled, and the request attempts
//   to update the form fields.

TEST("Returns 409 when filled.", function(next) {
    next();
});

// ## Returns `403 Forbidden` 
// - ... if contact `{as}` does not have the **admin** access required to 
//   update the form.

TEST("Returns 403 no admin access.", function(next) {

    var example = { 
	"owner": "contact",
	"audience": { "fill": "anyone" },
	"fields": []
    };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Test.query("POST",["db/",db,"/forms/create"],example,auth).result("id");

    var peon = Query.auth(db,false);
    Test.query("PUT",["db/",db,"/forms/",id],example)
	.error(403).then(next);
});

// ## Returns `401 Unauthorized` 
// - ... if the provided token does not match contact `{as}`,
//   or no token was provided

TEST("Returns 401 when token is not valid.", function(next) {

    var example = {
	"owner": "contact",
	"audience": {},
	"fields": []
    };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Test.query("POST",["db/",db,"/forms/create"],example,auth).result("id");

    Test.query("PUT",["db/",db,"/forms/",id],example,{tok:"0123456789a",id:"0123456789a"})
	.error(401).then(next);    

});

// # Access restrictions
//
// Subject to the form's `admin` [audience](/docs/#/concept/audience.md).