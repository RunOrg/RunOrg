// GET /db/{db}/forms/{id}/stats
// Forms / Get the fill statistics of a form.
// 
// Alpha @ 0.1.45
//
// `200 OK`, 
// [Read-only](/docs/#/concept/read-only.md).
//
// Computes and returns global and per-field statistics for form `{id}`. 
// 
// ### Response format
//     { "count" : <int>,
//       "fields" : { <field> : <stats>, .. } }
// - `count` is the number of filled instances of this form. 
// - `fields` is a dictionary containing, for each field of the form, 
//   some statistics about that field. 
//
// Field statistics, listed below, depend on the [kind of field](/docs/#/form/field.js). 
//
// ### Field stats format
//     { "filled": <int>,
//       "missing": <int>,
//       "first": <time> | null,
//       "last": <time> | null,
//       "items": [ <int>, ... ],
//       "contacts": <int>,
//       "top100": [ [ <id>, <int> ], ... ] }
// - `filled` is the number of times this field has been filled. Computed for
//   every kind of field.
// - `missing` is the number of times this field has been left empty (meaning
//   it contains a value that would have been rejected if the field had been
//   marked as required). `filled + missing` always equals the number of form
//   instances. Computed for every kind of field.
// - `first` is the earliest date that appears in a `"time"` kind of field.
//   Is `null` when the field has not been filled. 
// - `last` is the last date that appears in a `"time"` kind of field.
//   Is `null` when the field has not been filled.
// - `items` is used for `"single"` and `"multi"` fields. It is an array
//   with as many elements as there are choices in the field, each cell 
//   containing the number of times that choice was picked. 
// - `contacts` is used for `"person"` fields, and contains the number of 
//   different contacts that were picked. 
// - `top10` is used for `"person"` fields, and contains the top 10 contacts
//   by number of occurrences, along with those numbers. 


var Form = { 
    "owner": "person",
    "audience": {},
    "fields": []
};


TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var token = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],Form,token).id();

    return Query.get(["db/",db,"/forms/",id,"/stats"],token)
	.assertStatus(200).assertIsJson();

});

// # Examples
// 
// ### Example request
//     GET /db/0SNQc00211H/forms/0SNQe0032JZ/stats?as=0SNxd0002JZ
// 
// ### Example response
//     200 OK
//     Content-Type: application/json 
//
//     { "count": 225,
//       "fields": {
//         "color": { "filled": 122, "missing": 103 },
//         "birth": { 
//           "filled": 225, 
//           "missing": 0, 
//           "first": "1932-12-03", 
//           "last": "2013-10-08" },
//         "rating": {
//           "filled": 211,
//           "missing": 14,
//           "items": [ 34, 102, 54, 21 ] },
//         "recommender": {
//           "filled": 86,
//           "missing": 139,
//           "contacts": 31,
//           "top10": [
//             [ "0SNQe0002JZ", 28 ],
//             [ "0SDfX0053oS", 11 ],
//             [ "0PWz901218w", 7 ],
//             [ "07nKl003anm", 4 ],
//             [ "0SAmp0005JZ", 4 ],
//             [ "08DKl004aSm", 4 ],
//             [ "03Amp000xNU", 3 ],
//             [ "07nKl003anm", 3 ],
//             [ "0LAmp0091PZ", 3 ],
//             [ "0CnDl013anT", 3 ] ] }

TEST("Returns correct stats.", function(Query) {

    var example = { 
	"owner": "person",
	"audience": {},
	"fields": [ {
	    "id": "text",
	    "label": "Why did you join our group ?",
	    "kind": "text"
	}, {
	    "id": "rich",
	    "label": "Tell us more about yourself.",
	    "kind": "rich"
	}, {
	    "id": "time",
	    "label": "When did you start using RunOrg ?",
	    "kind": "time"
	}, {
	    "id": "json",
	    "label": "The places you have gone.",
	    "kind": "json"
	}, {
	    "id": "single",
	    "label": "How often do you log in ?",
	    "kind": "single",
            "choices": [ "Daily", "Once a week", "Once a month", "Once a year" ]
	}, {
	    "id": "multiple",
	    "label": "Do you own...",
	    "kind": "multiple",
	    "choices": [ "Laptop", "Desktop computer", "Tablet", "Smartphone" ]
	}, {
	    "id": "person",
	    "label": "Who told you about RunOrg ?",
	    "kind": "person"
	} ]
    };

    var db = Query.mkdb();
    var token = Query.auth(db);
    var peon1 = Query.auth(db, false, "peon@runorg.com");
    var peon2 = Query.auth(db, false, "peon2@runorg.com");

    var data1 = { "data": {
	"text": "I am passionate about pasta.",
	/* "rich" missing */
	"time": null,
	"json": {},
	"single": 1,
	"multiple": [0,2],
	"person": token.id
    }}; 

    var data2 = { "data": {
	"text": "",
	"rich": null,
	"time": "2014-04-07",
	"json": { "lat": ["N",36,3.212408],
		  "lon": ["W",112,6.269531] },
	"single": 0,
	"multiple": [0,1],
	"person": token.id
    }}; 

    var data3 = { "data": {
	/* "text" missing */
	"rich": "I don't know what to say.",
	"time": "2014-04-09T13:37:00Z",
	"json": [],
	"single": null,
	"multiple": [],
	"person": peon1.id
    }}; 
    
    var id = Query.post(["db/",db,"/forms"],example,token).id();

    return Query.put(["db/",db,"/forms/",id,"/filled/",token.id],data1,token).then(function(){
	return Query.put(["db/",db,"/forms/",id,"/filled/",peon1.id],data2,token).then(function(){

	    var stats = Query.get(["db/",db,"/forms/",id,"/stats"],token)
		.then(function(d,s,r) { return d; });

	    var expected = {
		"count": 2,
		"fields": {
		    "text": { "filled": 1, "missing": 1 },
		    "rich": { "filled": 0, "missing": 2 },
		    "json": { "filled": 1, "missing": 1 },
		    "time": { "filled": 1, "missing": 1, "first": "2014-04-07", "last": "2014-04-07" },
		    "single": { "filled": 2, "missing": 0, "items": [ 1, 1, 0, 0 ] },
		    "multiple": { "filled": 2, "missing": 0, "items": [ 2, 1, 1, 0 ] },
		    "person": { "filled": 2, "missing": 0, "contacts": 1, "top10": [[ token.id, 2 ]] }
		}
	    };
	  
	    return Assert.areEqual(expected, stats).then(function(){

		return Query.put(["db/",db,"/forms/",id,"/filled/",peon2.id],data3,token).then(function(){

		    var stats = Query.get(["db/",db,"/forms/",id,"/stats"],token)
			.then(function(d,s,r) { return d; });

		    var expected = {
			"count": 3,
			"fields": {
			    "text": { "filled": 1, "missing": 2 },
			    "rich": { "filled": 1, "missing": 2 },
			    "json": { "filled": 1, "missing": 2 },
			    "time": { "filled": 2, "missing": 1, 
				      "first": "2014-04-07", "last": "2014-04-09T13:37:00Z" },
			    "single": { "filled": 2, "missing": 1, "items": [ 1, 1, 0, 0 ] },
			    "multiple": { "filled": 2, "missing": 1, "items": [ 2, 1, 1, 0 ] },
			    "person": { "filled": 3, "missing": 0, "contacts": 2, 
					 "top10": [[ token.id, 2 ],[ peon1.id, 1 ]] }
			}
		    };
		    
		    return Assert.areEqual(expected, stats);
		    
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

    return Query.get(["db/00000000000/forms/00000000001/stats"])
	.assertStatus(404);

});

// - ... if form `{id}` does not exist in database `{db}`

TEST("Returns 404 when form does not exist.", function(Query) {

    var db = Query.mkdb();

    return Query.get(["db/",db,"/forms/00000000001/stats"])
	.assertStatus(404);

});

// - ... if person `{as}` does not have at least **fill** 
//   access to view form `{id}`, to ensure [absence 
//   equivalence](/docs/#/concept/absence-equivalence.md). 

TEST("Returns 404 when form not viewable.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],Form,auth).id();

    var peon = Query.auth(db,false,"peon@runorg.com");
    return Query.get(["db/",db,"/forms/",id,"/stats"],peon)
	.assertStatus(404);

});

// ## Returns `403 Forbidden`
// - ... if person `{as}` does not have **admin** access to
//   form `{id}`.

TEST("Returns 403 when not form admin.", function(Query) {

    var form = $.extend({},Form,{"audience":{"fill":"anyone"}});

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],form,auth).id();

    var peon = Query.auth(db,false,"peon@runorg.com");
    return Query.get(["db/",db,"/forms/",id,"/stats"],peon)
	.assertStatus(403);

});

// ## Returns `401 Unauthorized` 
// - ... if the provided token does not grant access as the named 
//   person, or no token was provided

TEST("Returns 401 when token is not valid.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],Form,auth).id();

    return Query.get(["db/",db,"/forms/",id,"/stats"],{tok:"0123456789a",id:"0123456789a"})
	.assertStatus(401);    

});

// # Access restrictions
//
// Subject to the form's **admin** [audience](/docs/#/form/audience.md). 
