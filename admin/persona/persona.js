/* Authenticating with Persona. */

API.onLoginRequired = function() {
    var R = Route.replace();
    R["persona/page"]({ button: function(R) {
	R.$.click(function() {
	    navigator.id.get(function(assertion){
		API.AUTH('/admin/auth/persona', {assertion:assertion}, function(r){
		    Route.dispatch();
		});		
	    },{
		siteName: 'RunOrg Server Administration',
		siteLogo: 'https://' + document.location.host + '/admin/logo.png'
	    });
	});
    }});
    R.show();
};
