<?php $this->_tpl_include('overall_header.html'); ?>


<form action="<?php echo (isset($this->_rootref['S_PROFILE_ACTION'])) ? $this->_rootref['S_PROFILE_ACTION'] : ''; ?>" method="post" id="resend">

<div class="panel">
	<div class="inner"><span class="corners-top"><span></span></span>

	<div class="content">
		<h2><?php echo ((isset($this->_rootref['L_UCP_RESEND'])) ? $this->_rootref['L_UCP_RESEND'] : ((isset($user->lang['UCP_RESEND'])) ? $user->lang['UCP_RESEND'] : '{ UCP_RESEND }')); ?></h2>

		<fieldset>
		<dl>
			<dt><label for="username"><?php echo ((isset($this->_rootref['L_USERNAME'])) ? $this->_rootref['L_USERNAME'] : ((isset($user->lang['USERNAME'])) ? $user->lang['USERNAME'] : '{ USERNAME }')); ?>:</label></dt>
			<dd><input class="inputbox narrow" type="text" name="username" id="username" size="25" /></dd>
		</dl>
		<dl>
			<dt><label for="email"><?php echo ((isset($this->_rootref['L_EMAIL_ADDRESS'])) ? $this->_rootref['L_EMAIL_ADDRESS'] : ((isset($user->lang['EMAIL_ADDRESS'])) ? $user->lang['EMAIL_ADDRESS'] : '{ EMAIL_ADDRESS }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_EMAIL_REMIND'])) ? $this->_rootref['L_EMAIL_REMIND'] : ((isset($user->lang['EMAIL_REMIND'])) ? $user->lang['EMAIL_REMIND'] : '{ EMAIL_REMIND }')); ?></span></dt>
			<dd><input class="inputbox narrow" type="text" name="email" id="email" size="25" maxlength="100" /></dd>
		</dl>
		<dl>
			<dt>&nbsp;</dt>
			<dd><?php echo (isset($this->_rootref['S_HIDDEN_FIELDS'])) ? $this->_rootref['S_HIDDEN_FIELDS'] : ''; echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?><input type="submit" name="submit" id="submit" class="button1" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" tabindex="2" />&nbsp; <input type="reset" value="<?php echo ((isset($this->_rootref['L_RESET'])) ? $this->_rootref['L_RESET'] : ((isset($user->lang['RESET'])) ? $user->lang['RESET'] : '{ RESET }')); ?>" name="reset" class="button2" /></dd>
		</dl>
		</fieldset>
	</div>

	<span class="corners-bottom"><span></span></span></div>
</div>
</form>

<?php $this->_tpl_include('overall_footer.html'); ?>