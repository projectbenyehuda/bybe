// This is a manifest file that'll be compiled into including all the files listed below.
// Add new JavaScript/Coffee code in separate files in this directory and they'll automatically
// be included in the compiled file accessible from http://example.com/assets/application.js
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//
//= require jquery
//= require rails-ujs
//= require jquery-ui
//= require dragula.min
//= require jquery.slick
//= require jquery.mark.min
//= require jquery.caret
//= require wikidata-sdk.min
//= require activestorage
//= require moment
//= require moment/he.js
//= require tempusdominus-bootstrap-4
//= require ahoy
//= require rails.validations

//= require_tree .

var mobileWidth = 767;

function isMobile() {
  return window.innerWidth < mobileWidth;
}
function startModal(id) {
    $("body").prepend("<div id='PopupMask' style='position:fixed;width:100%;height:100%;z-index:10;background-color:gray;'></div>");
    $("#PopupMask").css('opacity', 0.5);
    $("#"+id).data('saveZindex', $("#"+id).css( "z-index"));
    $("#"+id).data('savePosition', $("#"+id).css( "position"));
    $("#"+id).css( "z-index" , 11 );
    $("#"+id).css( "position" , "fixed" );
    $("#"+id).css( "display" , "block" );
}
function stopModal(id) {
    if ($("#PopupMask") == null) return;
    $("#PopupMask").remove();
    $("#"+id).css( "z-index" , $("#"+id).data('saveZindex') );
    $("#"+id).css( "position" , $("#"+id).data('savePosition') );
    $("#"+id).css( "display" , "none" );
}
