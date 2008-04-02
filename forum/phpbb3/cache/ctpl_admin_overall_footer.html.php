</div>
				</div>
			<span class="corners-bottom"><span></span></span>
		</div>
		</div>
	</div>
	
	<!--
		We request you retain the full copyright notice below including the link to www.phpbb.com.
		This not only gives respect to the large amount of time given freely by the developers
		but also helps build interest, traffic and use of phpBB. If you (honestly) cannot retain
		the full copyright we ask you at least leave in place the "Powered by phpBB" line, with
		"phpBB" linked to www.phpbb.com. If you refuse to include even this then support on our
		forums may be affected.
	
		The phpBB Group : 2006
	// -->
	
	<div id="page-footer">
		<?php if ($this->_rootref['S_COPYRIGHT_HTML']) {  ?>
			Powered by phpBB &copy; 2000, 2002, 2005, 2007 <a href="http://www.phpbb.com/">phpBB Group</a>
			<?php if ($this->_rootref['TRANSLATION_INFO']) {  ?><br /><?php echo (isset($this->_rootref['TRANSLATION_INFO'])) ? $this->_rootref['TRANSLATION_INFO'] : ''; } } if ($this->_rootref['DEBUG_OUTPUT']) {  if ($this->_rootref['S_COPYRIGHT_HTML']) {  ?><br /><?php } ?>
			<?php echo (isset($this->_rootref['DEBUG_OUTPUT'])) ? $this->_rootref['DEBUG_OUTPUT'] : ''; ?>
		<?php } ?>
	</div>
</div>

</body>
</html>