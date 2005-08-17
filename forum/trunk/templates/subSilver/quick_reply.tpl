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
        <table border='0' cellpadding='10' cellspacing='1' width='100%' class='forumline'>
                <tr>
                        <th class='thHead' colspan='2' height='25'><b>{L_QUICK_REPLY}</b></th>
                </tr>
                <!-- BEGIN user_logged_out -->
                <tr>
                        <td class='row2' align='left'><span class='gen'><b>{L_USERNAME}:</b></span></td>
                        <td class='row2' width='100%'><span class='genmed'><input type='text' class='post' tabindex='1' name='username' size='25' maxlength='25' value='' /></span></td>
                </tr>
                <!-- END user_logged_out -->
                <tr>
                        <td class='row1'>
                        </td>
                        <td class='row1' valign='top'>
                                <textarea name='message' rows='10' cols='80' wrap='virtual' tabindex='3' class='post' onselect='storeCaret(this);' onclick='storeCaret(this);' onkeyup='storeCaret(this);'></textarea><br>
                                <!-- BEGIN smilies -->
                                <img src="{quick_reply.smilies.URL}" border="0" onmouseover="this.style.cursor='hand';" onclick="emoticon(' {quick_reply.smilies.CODE} ');" alt="{quick_reply.smilies.DESC}" title="{quick_reply.smilies.DESC}" />
                                <!-- END smilies -->
                                <INPUT TYPE=button CLASS=BUTTON NAME="SmilesButt" VALUE="{L_ALL_SMILIES}" ONCLICK="openAllSmiles();">
                                <br />
                                <input type='button' name='quoteselected' class='liteoption' value='{L_QUOTE_SELECTED}' onclick='javascript:quoteSelection()'></td>
                </tr>
                <tr>
                        <td class='row2'>
                        </td>
                        <td class='row2' valign='top'><span class='gen'>
                                <b>{L_OPTIONS}</b><br />
                                <input type='checkbox' name='quick_quote'>{L_QUOTE_LAST_MESSAGE}<br>
                                <!-- BEGIN user_logged_in -->
                                <input type='checkbox' name='attach_sig' {quick_reply.user_logged_in.ATTACH_SIGNATURE}>{L_ATTACH_SIGNATURE}<br>
                                <input type='checkbox' name='notify' {quick_reply.user_logged_in.NOTIFY_ON_REPLY}>{L_NOTIFY_ON_REPLY}</td>
                                <!-- END user_logged_in -->
                </tr>
                <tr>
                        <td class='catBottom' align='center' height='28' colspan='2'>
                                <input type='hidden' name='mode' value='reply'>
                                <input type='hidden' name='t' value='{quick_reply.TOPIC_ID}'>
                                <input type='hidden' name='last_msg' value='{quick_reply.LAST_MESSAGE}'>
                                <!--input type='hidden' name='message' value=''-->
                                <input type='submit' name='preview' class='liteoption' value='{L_PREVIEW}'>&nbsp;
                                <input type='submit' name='post' class='mainoption' value='{L_SUBMIT}'>
                        </td>
                </tr>
        </table>
</form>
<!-- END quick_reply -->
