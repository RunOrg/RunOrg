// JSON <short-form>
// Forms / A short representation of a form
// 
// Returned by most API methods that involve multiple forms. It is intended to 
// provide data relevant for displaying the form within a list.
// 
// Typical examples [listing all forms](/docs/#/forms/list.js).
//
// ### `ShortContact` JSON format
//     { id : <id>, 
//       label : <label> | null, 
//       fields : <int>,
//       owner : <owner>,
//       access : [ <access>, ... ] }
// 
// - `id` is the [unique identifier](/docs/#/types/id.js) for this 
//   form.
// - `label` is a [human-readable name](/docs/#/types/label.js). Not all forms
//   have one, because it is not a mandatory property when creating a forms.
// - `fields` is the number of fields in the form.
// - `owner` is the owner of filled form instances, currently only `"contact"` 
//   is supported.
// - `access` lists the [access levels](/docs/#/form/audience.js) of the viewer
//   over this form.  

TEST("The form's data is returned.", function(next) {

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

    var db = Query.mkdb();
    var auth = Query.auth(db);

    Test.query("POST",["db/",db,"/forms"],example,auth).result("id")(function(id) {

	var form = Test.query("GET",["db/",db,"/forms"],auth).result("list",0);
	
	var expected = {
	    "id": id,
	    "label": example.label,
	    "owner": example.owner,
	    "fields": 2,
	    "access": ["admin","fill"]
	};
	
	Assert.areEqual(expected,form).then(next);

    });

});

//
// ### Example value
//     { "id" : "0Et9j0026rO",
//       "label" : "Personal information",
//       "owner" : "contact",
//       "fields" : 4,
//       "access" : ["fill"] }
//
// To get more information about a specific form, use the [get single form](/docs/#/form/get.js)
// endpoint.