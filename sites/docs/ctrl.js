/* Simple controller. */

/* Root page */
Route.add(/^\/docs(\/(#\/?)?)?$/, function(R) {

    R.layout({});
    R.show();

});

