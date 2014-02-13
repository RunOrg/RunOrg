var api = (function(){
    var match = /db\/([a-zA-Z0-9]+)/.exec(document.location.pathname),
        db = match[1];
    return new API('https://' + document.location.host, db);
})(); 
