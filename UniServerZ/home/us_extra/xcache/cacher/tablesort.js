var sort_column;
var prev_span = null;
function get_inner_text(el) {
 if((typeof el == 'string')||(typeof el == 'undefined'))
  return el;
 if(el.innerText)
  return el.innerText;
 else {
  var str = "";
  var cs = el.childNodes;
  var l = cs.length;
  for (var i=0;i<l;i++) {
   if (cs[i].nodeType==1) str += get_inner_text(cs[i]);
   else if (cs[i].nodeType==3) str += cs[i].nodeValue;
  }
 }
 return str;
}
function sortfn(a,b) {
 var i = a.cells[sort_column].getAttribute('int');
 if (i != null) {
  return parseInt(i)-parseInt(b.cells[sort_column].getAttribute('int'));
 } else {
  var at = get_inner_text(a.cells[sort_column]);
  var bt = get_inner_text(b.cells[sort_column]);
  aa = at.toLowerCase();
  bb = bt.toLowerCase();
  if (aa==bb) return 0;
  else if (aa<bb) return -1;
  else return 1;
 }
}
function resort(lnk) {
 var span = lnk.childNodes[1];
 if (!span) {
 	 var span = document.createElement("span")
 	 span.className = "sortarrow";
 	 lnk.appendChild(span);
 }
 var table = lnk.parentNode.parentNode.parentNode.parentNode;
 var rows = new Array();
 for (j=1;j<table.rows.length;j++)
  rows[j-1] = table.rows[j];
 sort_column = lnk.parentNode.cellIndex;
 rows.sort(sortfn);
 if (prev_span != null) prev_span.innerHTML = '';
 if (span.getAttribute('sortdir')=='down') {
  span.innerHTML = '&uarr;';
  span.setAttribute('sortdir','up');
  rows.reverse();
 } else {
  span.innerHTML = '&darr;';
  span.setAttribute('sortdir','down');
 }
 for (i=0;i<rows.length;i++)
  table.tBodies[0].appendChild(rows[i]);
 prev_span = span;
}
