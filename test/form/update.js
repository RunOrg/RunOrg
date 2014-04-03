// PUT /db/{db}/forms/{id}
// Forms / Update a form
//
// Alpha @ 0.1.36
//
// `202 Accepted`, [Delayed](/docs/#/concept/delayed.md), [Idempotent](/docs/#/concept/idempotent.md).
//
// Updates the properties of a form. Note that once a form has been filled (even if only
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
    Assert.fail();
});

// - ... if form `{id}` does not exist in database `{db}` 

TEST("Returns 404 when database does not exist.", function(next) {
    Assert.fail();
});

// ## Returns `409 Conflict`
// - ... if the form has already been filled, and the request attempts
//   to update the form fields.

TEST("Returns 409 when filled.", function(next) {
    Assert.fail();
});

// ## Returns `401 Unauthorized` 
// - ... if the provided token does not allow updating that form,
//   or no token was provided

TEST("Returns 401 when token is not valid.", function(next) {
    Assert.fail();
});

// # Access restrictions
//
// Subject to the form's `admin` [audience](/docs/#/concept/audience.md).