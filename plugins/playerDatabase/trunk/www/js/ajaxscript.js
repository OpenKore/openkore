    
	var http_request = false;
	var divTarget;
	 
	function search() {
		var charName = document.getElementById("charName").value;
		var guildName = document.getElementById("guildName").value;
		var lvl = document.getElementById("lvl");
		var lvl = lvl.options[lvl.selectedIndex].value;
		var flagCla = document.getElementById("flagCla");
		var flagCla = flagCla.options[flagCla.selectedIndex].value;
		var job = document.getElementById("job");
		var job = job.options[job.selectedIndex].value;
		var sex = document.getElementById("sex");
		var sex = sex.options[sex.selectedIndex].value;
		var limit = document.getElementById("limit");
		var limit = limit.options[limit.selectedIndex].value;
		var baby = document.getElementById("baby").checked;
		var url = "searchplayer.php?charName=" + charName + "&lvl=" + lvl + "&job=" + job + "&flagCla=" + flagCla + "guildName=" + guildName + "&page=" + "&limit=" + limit + "&baby=" + baby;
		divTarget = 'content';
		makeRequest(url, divTarget);
	}
	
	function show_eq(charId) {
		var url = "searchplayer.php?charId=" + charId + "&eq=1";
		divTarget = charId;
		makeRequest(url, divTarget);
	}
	
	function goToPage(params, totalPages) {
		var total = parseInt(totalPages);
		var page = parseInt(document.getElementById("goPage").value);
		var msgmPg = document.getElementById("msgmPg");
		
		if(page <= total && page > 0) {		
			var url = "searchplayer.php?" + params + "&page=" + page;
			divTarget = 'content';
			makeRequest(url,divTarget);
		} else {
			msgmPg.innerHTML="Pagina Invalida";
		}

		
	}
	
	function clean(divTarget) {
		div = document.getElementById(divTarget);
		div.innerHTML = '';
	}
	

    function makeRequest(url, divTarget) {
        http_request = false;
        if (window.XMLHttpRequest) { 
            http_request = new XMLHttpRequest();
            if (http_request.overrideMimeType) {
                http_request.overrideMimeType('text/xml');

            }
        } else if (window.ActiveXObject) { 
            try {
                http_request = new ActiveXObject("Msxml2.XMLHTTP");
            } catch (e) {
                try {
                    http_request = new ActiveXObject("Microsoft.XMLHTTP");
                } catch (e) {}
            }
        }

        if (!http_request) {
            alert('Giving up :( Cannot create an XMLHTTP instance');
            return false;
        }
		
		for(var i = 0; i < url.length; i++){
		  if(url.charAt(i) == " "){
			url= url.replace(url.charAt(i), "+");
		  }
		}
		
        http_request.onreadystatechange = alertContents;
        http_request.open('GET', url, true);
        http_request.send(null);

    }

    function alertContents() {
        if (http_request.readyState == 4) {
            if (http_request.status == 200) {
				clean(divTarget);
				document.getElementById(divTarget).innerHTML = http_request.responseText;
			} else {
                alert('Houve um problema com a requisição');
            }
        }
	}

    
