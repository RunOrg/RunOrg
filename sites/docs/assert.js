var Assert = (function(){

    function equal(a,b) {
	if (typeof a != typeof b) return false;
	if (typeof a == "object" && Array.isArray(a)) {
	    if (a.length != b.length) return false;
	    for (var i = 0; i < a.length; ++i)
		if (!equal(a[i],b[i])) return false;
	    return true;
	}
	if (typeof a == "object") {
	    for (var k in b) 
		if (b.hasOwnProperty(k) && !a.hasOwnProperty(k)) return false;
	    for (k in a) {
		if (a.hasOwnProperty(k) && !b.hasOwnProperty(k)) return false;
		if (!equal(a[k],b[k])) return false;
	    }
	    return true;
	}
	return a === b;
    }

    return {

	fail: function() { Test.fail("Assert.fail()"); },

	areEqual: function(a,b) {

	    return Async.lift([a,b]).map(function(p){
		var a = p[0], b = p[1]; 
		if (equal(a,b)) return Async.lift(true);
		else Test.fail("Not equal: "+JSON.stringify(a)+" and "+JSON.stringify(b));
	    });

	},

	notEqual: function(a,b) {

	    return Async.lift([a,b]).map(function(p){
		var a = p[0], b = p[1]; 
		if (!equal(a,b)) return Async.lift(true);
		else Test.fail("Both equal to: "+JSON.stringify(a));
	    });

	},

	isTrue: function(a, reason) {

	    return Async.lift(a).map(function(a){
		if (a) return Async.lift(true);
		else Test.fail("False: " + reason);
	    });

	},

    };

})();