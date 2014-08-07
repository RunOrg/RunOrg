// POST /people/auth/persona

TODO("Returns 404 when database does not exist.", function(next) {
    Test.query("POST","/db/00000000001/people/auth/persona",{assertion:'x'}).error(404).then(next);
});

TODO("Returns 400 when assertion is invalid.", function(next) {
    var db = Query.mkdb();    
    Test.query("GET",["/db/",db,"/people/auth/persona"],{assertion:'x'}).error(400).then(next);
});
