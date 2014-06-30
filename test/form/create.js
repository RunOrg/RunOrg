var Example = { 
    "owner": "person",
    "audience": {},
    "fields": []
};

TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var response = Query.post(["db/",db,"/forms"],Example,auth);

    return response.assertStatus(202).assertIsJson();

});

TEST("Form with forced id appears.", function(Query) {

    var example = $.extend({ "id": "personal" }, Example);

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],example,auth).id();
    var owner = Query.get(["db/",db,"/forms/",id],auth).then(function(r) { return r.owner; });
    
    return $.when(
	Assert.areEqual(example.id,id),
	Assert.areEqual(example.owner,owner)
    );

});

TEST("Multiple creations create multiple forms.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);

    var id1 = Query.post(["db/",db,"/forms"],Example,auth).id();
    var id2 = Query.post(["db/",db,"/forms"],Example,auth).id();

    return Assert.notEqual(id1, id2);

});

TEST("Returns 404 when database does not exist.", function(Query) {

    return Query.post(["db/00000000000/forms"],Example).assertStatus(404);

});

TEST("Returns 403 when person cannot create a form.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db,false);
    
    return Query.post(["db/",db,"/forms"],Example,auth).assertStatus(403);
    
});

TEST("Returns 400 when custom id is invalid.", function(Query) {   

    var ex1 = $.extend({ "id": "a-b" }, Example);
    var ex2 = $.extend({ "id": "0123456789a"}, Example);

    var db = Query.mkdb();
    var auth = Query.auth(db);

    return $.when(
	Query.post(["db/",db,"/forms"],ex1,auth).assertStatus(400),
	Query.post(["db/",db,"/forms"],ex2,auth).assertStatus(400)
    );
    

});

TEST("Returns 409 when the form exists.", function(Query) {

    var example = $.extend({ "id": "personal" }, Example);

    var db = Query.mkdb();
    var auth = Query.auth(db);
    
    return Query.post(["db/",db,"/forms"],example,auth).then(function() {
	return Query.post(["db/",db,"/forms"],example,auth).assertStatus(409);
    });
});

TEST("Returns 401 when token is not valid.", function(Query) {

    var db = Query.mkdb();
    return Query.post(["db/",db,"/forms"],Example,{token:"0123456789a",id:"0123456789a"})
	.assertStatus(401);

});

