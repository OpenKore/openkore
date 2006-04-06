<form style="margin: 1.5em;" method="post" action="{FORM_ACTION}">

<!-- BEGIN intro -->
<div style="background: #ffe8e8; border: 1px solid #ffd0d0; margin: 1em; margin-bottom: 2em; padding: 0.5em;">
	<p style="margin: 0px; margin-bottom: 0.9em; padding: 0px;">
		{intro.INTRO_TEXT}
		<a href="http://www.openkore.com/wiki/index.php/International_forum_rules" target="_blank">{intro.RULES_LINK_TEXT}</a>
	</p>
	<ul class="openkore_linklist">
		<li><a href="quiz.php?{intro.QUERY_PARAMS}">English</a></li>
		<li><a href="quiz.php?language=pt&{intro.QUERY_PARAMS}">Portuguese</a></li>
		<li><a href="quiz.php?language=id&{intro.QUERY_PARAMS}">Bahasa Indonesia</a></li>
		<li><a href="quiz.php?language=tl&{intro.QUERY_PARAMS}">Philipinnes (Tagalog)</a></li>
		<li><a href="quiz.php?language=de&{intro.QUERY_PARAMS}">Deutsch</a></li>
	</ul>
</div>
<!-- END intro -->

<!-- BEGIN answered -->
<div>
	<span style="color: blue; font-weight: bold;">
	{answered.NUMBER}
	</span>
	<a href="http://www.openkore.com/wiki/index.php/International_forum_rules" target="_blank">{answered.RULES_LINK_TEXT}</a>
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
