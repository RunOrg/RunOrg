/* Routes dispatch URL changes to controllers. */

var Route = {

    routes: [],

    // Adds a new route, presented as a string with wildcards. Each wildcard
    // matches a segment that becomes an argument to the controller.
    // The first controller argument is always the renderer object.
    add: function(re,f,o) {
	o = o || window;
	this.routes.push(function(path){

	    var m = re.exec(path);
	    if (m === null) return false;	    

	    Route.R.cancel();

	    m.shift();
	    m.unshift(Route.R = new R($('body')));
	    
	    f.apply(o, m);

	    return true;
	});
    },

    // The current renderer, to be cancelled when the route changes
    R: { cancel: function() {} },

    // Dispatch the provided path. Cancels the previous controller
    dispatch: function(path) {
	path = path || document.location.pathname;
	for (var i = 0; i < this.routes.length; ++i) 
	    if (this.routes[i](path))
		return;
    },

    getBase : function(loc) { 
	return loc.protocol + '//' + loc.host + (loc.port ? ':' + loc.port : '') 
    },

    // Set this value to false if you do not wish for the initial page load
    // to occur
    init: true
};

// The current base (protocol, domain, port)
Route.here = Route.getBase(document.location);

// Define the "go" function and (if history is supported) bind internal
// links to pushState
var go;

if ('history' in this) { 

    go = function(path) {
	history.pushState(path);
	Route.dispatch(path);
    }

    $(function() { 
	$('body').on('click', 'a', function(e) {
	    if (Route.here == Route.getBase(this)) go(this.pathname);
	    return false;
	});
    });
}

else {

    go = function(path) {
	document.location = Route.here + path;
    }

}

// Dispatch the initial route
$(function() {
    if (Route.init) Route.dispatch()
});
