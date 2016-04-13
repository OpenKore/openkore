//OpenBrowserWindow----
function openBrWindow(theURL,winName,features) {
 window.open(theURL,winName,features);
}
//SetPointer-----
function setPointer(theRow){
 if ( typeof(theRow.style) == 'undefined' ) {
  return false;
 }
 if ( typeof(document.getElementsByTagName) != 'undefined' ) {
  var theCells = theRow.getElementsByTagName('td');
 } else if ( typeof(theRow.cells) != 'undefined' ) {
  var theCells = theRow.cells;
 } else {
  return false;
 }
 var rowCellsCnt  = theCells.length;
 for (var c = 0; c < rowCellsCnt; c++) {
  if ( theCells[c].className == "hotDeal" ) {
   theCells[c].style.backgroundColor = '#CC6666';
  } else if ( theRow.className == "isstillinitem" ) {
   theCells[c].style.backgroundColor = '#CCCC66';
  } else {
   theCells[c].style.backgroundColor = 'EEEEEE';
  }
 }
 return true;
}
//UnsetPointer-----
function unsetPointer(theRow){
 if ( typeof(document.getElementsByTagName) != 'undefined' ) {
  var theCells = theRow.getElementsByTagName('td');
 } else if ( typeof(theRow.cells) != 'undefined' ) {
  var theCells = theRow.cells;
 } else {
  return false;
 }
 var rowCellsCnt  = theCells.length;
 for (var c = 0; c < rowCellsCnt; c++) {
  if ( theCells[c].className == "hotDeal" ) {
   theCells[c].style.backgroundColor = '';
  } else if ( theRow.className == "isstillinitem" ) {
   theCells[c].style.backgroundColor = '';
  } else {
   theCells[c].style.backgroundColor = '';
  }
 }
 return true;
}