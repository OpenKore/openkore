var speed=50
var currentpos=0,alt=1,curpos1=0,curpos2=-1

function initialize(){
	startit()
}
function scrollwindow(){
	if (document.all &&
		!document.getElementById)
		temp=document.body.scrollTop
	else
		temp=window.pageYOffset
	if (alt==0)
		alt=2
	else
		alt=1
	if (alt==0)
		curpos1=temp
	else
		curpos2=temp
	if (curpos1!=curpos2){
		if (document.all)
			currentpos=document.body.scrollTop+speed
		else
			currentpos=window.pageYOffset+speed
			window.scroll(0,currentpos)
	}
	else{
		currentpos=0
		window.scroll(0,currentpos)
	}
}
function startit(){
setInterval("scrollwindow()",1)
}
window.onload=initialize