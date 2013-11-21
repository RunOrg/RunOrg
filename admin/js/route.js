/* The route system overrides page navigation. 
 *
 * It is enabled once a token is provided.
 *
 * Call "/path/to/foo".route(function) to define a route.
 */

RegExp.prototype.route = function(f) {
    var re = this, t;
    routes.push(function(p) {
	if (t = re.test(p)) {
	    $('body').html('<div/>').trigger('route');
	    f(new R($('body').children()), p.match(re).slice(1));
	}
	return t;
    });
};

String.prototype.route = function(f) {
    new RegExp('^' + this.replace(/\*/g,'([^/]*)') + '$').route(f)
};

window.routes = [];

function onLogin(token){

    window.token = token;

    // Define new routes from regular expressions or strings.
   
    // Dispatches to the specified path or, if no path is specified,
    // the current URL

    window.route = function(p) {
	p = (typeof p == 'string') ? p : document.location.pathname
	for (var i = 0; i < routes.length; ++i)
	    if (routes[i](p)) return;
    };

    // Go to the specified path. Sets the browser's URL to that value,
    // the runs a dispatch.
  
    window.go = function(p) {
	history.pushState(null, null, p)
	route(p)
    };

    if ('pushState' in history) {
	window.onpopstate = route;
             
	$('body').on('click', 'a', function() {
	    if (document.location.host != this.host) return true;
	    event.stopPropagation();
	    go(this.pathname);
	    return false
	});
    }

    route();
}

