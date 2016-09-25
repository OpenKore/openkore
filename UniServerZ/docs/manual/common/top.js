// This works in other browsers
// document.write('<a href=\"\" target=\"_self\" class=\"up_arrow\" title=\"Jump to top of page\"></a>');
// Well! IE requires this
// document.write('<a href=\"#\" target=\"_self\" class=\"up_arrow\" title=\"Jump to top of page\"></a>');
// Shame that! Now # is displayed at end of each url. Solution is to use the following:

var page_name   = "";                       // Reset page name
var name_array = new Array();               // Create array

page_name = location.href.split('/').pop(); // Get document name, may include #
                                            // pop last in first out

if( page_name.indexOf('#')+1 ) {            // Check for # 
 name_array = page_name.split('#');         // Match found. Split at #
 page_name = name_array[0];                 // Get name
}

//document.write(page_name); // Test
document.write('<a href=\"' + page_name + '\" target=\"_self\" class=\"up_arrow\" title=\"Jump to top of page\"></a>');