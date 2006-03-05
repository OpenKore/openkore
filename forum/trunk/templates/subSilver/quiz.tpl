<form style="margin: 1.5em;" method="post" action="{FORM_ACTION}">

<!-- BEGIN intro -->
<div style="background: #ffe8e8; border: 1px solid #ffd0d0; margin: 1em; margin-bottom: 2em; padding: 0.5em;">
	Our forums have etiquettes and rules. So before you can proceed, you must finish this quiz,
	in order to test whether you know enough about the etiquettes and rules.
</div>
<!-- END intro -->

<!-- BEGIN answered -->
<div style="color: blue; font-weight: bold;">
	{answered.NUMBER} questions have been correctly answered.
</div>
<!-- END answered -->

<input type="hidden" name="language" value="{LANGUAGE}">
<input type="hidden" name="questions" value="{QUESTIONS}">

<!-- BEGIN answered_question -->
<input type="hidden" name="question-{answered_question.ITEMINDEX}" value="{answered_question.ANSWERINDEX}">
<!-- END answered_question -->

<dl>
	<!-- BEGIN quizitem -->
	<dt style="font-weight: bold; margin-bottom: 0.5em;">{quizitem.QUESTION}</dt>
	<dd style="margin-bottom: 2em;">
		{quizitem.ANSWERS}
	</dd>
	<!-- END quizitem -->
</dl>

<div style="text-align: center;">
	<input type="submit" value="Submit" name="submit" class="mainoption" style="margin-right: 1em;">
	<input type="reset" value="Reset" class="liteoption">
</div>
</form>
