var Example = { 
    "owner": "person",
    "audience": {},
    "fields": []
};

TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var token = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],Example,token).id();
    
    return Query.put(["db/",db,"/forms/",id],Example,token)
	.assertStatus(202).assertIsJson();

});


TEST("Returns 404 when database does not exist.", function(Query) {

    return Query.put(["db/00000000000/forms/00000000001"],Example)
	.assertStatus(404);
        
});

TEST("Returns 404 when form does not exist.", function(Query) {

    var db = Query.mkdb();

    return Query.put(["db/",db,"/forms/00000000001"],Example)
	.assertStatus(404);
        
});

TEST("Returns 404 when form cannot be viewed.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],Example,auth).id();

    var peon = Query.auth(db,false,"peon@runorg.com");
    return Query.put(["db/",db,"/forms/",id],Example,peon)
	.assertStatus(404);

});

TODO("Returns 409 when filled.");

TEST("Returns 403 if no admin access.", function(Query) {

    var example = $.extend({}, Example, { "audience": { "fill": "anyone" } });

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],example,auth).id();

    var peon = Query.auth(db,false,"peon@runorg.com");
    return Query.put(["db/",db,"/forms/",id],example,peon)
	.assertStatus(403);

});

TEST("Returns 401 when token is not valid.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],Example,auth).id();

    return Query.put(["db/",db,"/forms/",id],Example,{tok:"0123456789a",id:"0123456789a"})
	.assertStatus(401);

});
