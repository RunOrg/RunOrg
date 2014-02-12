/* Authenticating with Persona. */

api.onLoginRequired = function() {
    var R = Route.replace(), self = this;
    R["persona/page"]({ button: function(R) {
	R.$[0].onclick = function() {
	    navigator.id.get(function(assertion){
		self.AUTH('/admin/auth/persona', {assertion:assertion}, function(r){
		    Route.dispatch();
		});		
	    },{
		siteName: i18n.title,
		siteLogo: 'https://' + document.location.host + '/admin/logo.png'
	    });
	};
    }});
    R.show();
};
