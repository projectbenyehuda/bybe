// This is a manifest file that'll be compiled into including all the files listed below.
// Add new JavaScript/Coffee code in separate files in this directory and they'll automatically
// be included in the compiled file accessible from http://example.com/assets/application.js
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//
//= require jquery3
//= require jquery-ui/widgets/autocomplete
//= require rails-ujs
//= require jquery-ui
//= require sortable.min
//= require jquery.slick
//= require jquery.caret
//= require wikidata-sdk.min
//= require activestorage
//= require moment
//= require moment/he.js
//= require tempusdominus-bootstrap-4
//= require ahoy
//= require rails.validations
//= require bootstrap-rtl-4.2.1.bundle.min

//= stub jquery.ddslick.min
//= require_tree .

var mobileWidth = 767;

function isMobile() {
  return window.innerWidth < mobileWidth;
}
// Browse lists (/works, /authors, /collections): on narrow screens the
// sort/filter panel is collapsed by CSS so the list starts in the first
// screenful, and #mobile_filter_btn is the single control that reveals it.
// The open state lives on <body> because the panel and the buttons that drive
// it sit in different subtrees (the buttons are in the fixed page header).
function setMobileFiltersOpen(isOpen) {
  $('body').toggleClass('mobile-filters-open', isOpen);
  var btn = $('#mobile_filter_btn');
  btn.attr('aria-expanded', isOpen ? 'true' : 'false')
     .text(isOpen ? btn.data('hide-label') : btn.data('show-label'));
}

function closeMobileFilters() {
  setMobileFiltersOpen(false);
}

// Delegated, so the handlers survive the AJAX re-render of the filter panel.
$(document).on('click', '#mobile_filter_btn', function() {
  setMobileFiltersOpen(!$('body').hasClass('mobile-filters-open'));
});

// #apply_mobile_filters submits the filter form (via its `form` attribute) and
// collapses the panel again, putting the freshly filtered list back on screen.
$(document).on('click', '#apply_mobile_filters', function() {
  if (typeof resetPagination === 'function') {
    resetPagination();
  }
  closeMobileFilters();
  $('html').scrollTop($('#thelist').offset().top);
});

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
