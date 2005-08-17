<!-- BEGIN quick_reply -->
<script language='JavaScript'>
        function openAllSmiles(){
                smiles = window.open('{U_MORE_SMILIES}', '_phpbbsmilies', 'HEIGHT=300,resizable=yes,scrollbars=yes,WIDTH=250');
                smiles.focus();
                return false;
        }
        
        function quoteSelection() {

                theSelection = false;
                theSelection = document.selection.createRange().text; // Get text selection

                if (theSelection) {
                        // Add tags around selection
                        emoticon( '[quote]\n' + theSelection + '\n[/quote]\n');
                        document.post.message.focus();
                        theSelection = '';
                        return;
                }else{
                        alert('{L_NO_TEXT_SELECTED}');
                }
        }

        function storeCaret(textEl) {
                if (textEl.createTextRange) textEl.caretPos = document.selection.createRange().duplicate();
        }

        function emoticon(text) {
                if (document.post.message.createTextRange && document.post.message.caretPos) {
                        var caretPos = document.post.message.caretPos;
                        caretPos.text = caretPos.text.charAt(caretPos.text.length - 1) == ' ' ? text + ' ' : text;
                        document.post.message.focus();
                } else {
                        document.post.message.value  += text;
                        document.post.message.focus();
                }
        }

        function checkForm() {
                formErrors = false;
                if (document.post.message.value.length < 2) {
                        formErrors = '{L_EMPTY_MESSAGE}';
                }
                if (formErrors) {
                        alert(formErrors);
                        return false;
                } else {
                        if (document.post.quick_quote.checked) {
                                document.post.message.value = document.post.last_msg.value + document.post.message.value;
                        } 
                        document.post.quick_quote.checked = false;
                        return true;
                }
        }
</script>
<form action='{quick_reply.POST_ACTION}' method='post' name='post' onsubmit='return checkForm(this)'>
        <input type="hidden" name="sid" value="{quick_reply.SID}">

	<table width="80%" align="center" style="margin-top: 0.2cm;">
		<tr>
			<td align="right" width="10%">
				<div align="center">
					<!-- BEGIN smilies -->
					<img src="{quick_reply.smilies.URL}" border="0" onmouseover="this.style.cursor='hand';" onclick="emoticon(' {quick_reply.smilies.CODE} ');" alt="{quick_reply.smilies.DESC}" title="{quick_reply.smilies.DESC}" />
					<!-- END smilies -->
					<p>
					<INPUT TYPE=button CLASS=BUTTON NAME="SmilesButt" VALUE="{L_ALL_SMILIES}" ONCLICK="openAllSmiles();">
				</div>
			</td>
			<td width="80%">

        <textarea name="message" rows="10" cols="80" wrap="virtual" tabindex="3" class="post" onselect="storeCaret(this);" onclick="storeCaret(this);" onkeyup="storeCaret(this);" style="width: 100%;"></textarea><br>

        <!-- BEGIN user_logged_in -->
        <input type='hidden' name='attach_sig' {quick_reply.user_logged_in.ATTACH_SIGNATURE}>
        <input type='hidden' name='notify' {quick_reply.user_logged_in.NOTIFY_ON_REPLY}>
        <!-- END user_logged_in -->

        <input type='hidden' name='mode' value='reply'>
        <input type='hidden' name='t' value='{quick_reply.TOPIC_ID}'>
        <!--input type='hidden' name='message' value=''-->


			</td>
		</tr>
	</table>

	<p>
	<div align="center" style="margin-bottom: 0.25cm;">
        <input type='submit' name='preview' class='liteoption' value='{L_PREVIEW}'>&nbsp;
        <input type='submit' name='post' class='mainoption' value='{L_SUBMIT}'>
	</div>

</form>
<!-- END quick_reply -->
