// JSON <short-form>
// Forms / A short representation of a form
// 
// Returned by most API methods that involve multiple forms. It is intended to 
// provide data relevant for displaying the form within a list.
// 
// Typical examples [listing all forms](/docs/#/forms/list.js).
//
// ### `ShortPerson` JSON format
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
// - `owner` is the owner of filled form instances, currently only `"person"` 
//   is supported.
// - `access` lists the [access levels](/docs/#/form/audience.js) of the viewer
//   over this form.  

TEST("The form's data is returned.", function(Query) {

    var example = {
	"owner": "person",	
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

    return Query.post(["db/",db,"/forms"],example,auth).id().then(function(id) {

	var form = Query.get(["db/",db,"/forms"],auth).then(function(d,s,r) {
	    return d.list[0];
	});

	var expected = {
	    "id": id,
	    "label": example.label,
	    "owner": example.owner,
	    "fields": 2,
	    "access": ["admin","fill"]
	};
	
	return Assert.areEqual(expected,form);

    });

});

//
// ### Example value
//     { "id" : "0Et9j0026rO",
//       "label" : "Personal information",
//       "owner" : "person",
//       "fields" : 4,
//       "access" : ["fill"] }
//
// To get more information about a specific form, use the [get single form](/docs/#/form/get.js)
// endpoint.