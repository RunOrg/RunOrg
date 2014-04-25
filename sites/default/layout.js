// Fill in the default components of a layout

Renderer.fill("layout",function(data) {
    return $.extend({
	menu: [
	    { url: "#", label: i18n.chat.title },
	    { url: "#/people", label: i18n.people.title },
	    { url: "#/groups", label: i18n.groups.title }
	],
	self: api.self, 
	login: function(R) { 
	    R.esc(i18n.login); 
	    R.show();
	    R.$.click(function() { api.onLoginRequired(); });
	},
	logout: function(R) {
	    R.esc(i18n.logout);
	    R.show();
	    R.$.click(function() {
		api.self = null;
		api.token = null;
		Route.dispatch();
	    });
	},
	body: function(R) { R.show() }
    }, data);
});
