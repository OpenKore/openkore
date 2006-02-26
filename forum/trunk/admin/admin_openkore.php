<?php
/* Special configuration options for the Openkore forum. */
define('IN_PHPBB', 1);

if(!empty($setmodules)) {
	$file = basename(__FILE__);
	$module['General']['OpenKore'] = "$file";
	return;
}

$phpbb_root_path = './../';
require($phpbb_root_path . 'extension.inc');
require('./pagestart.' . $phpEx);
require_once($phpbb_root_path . 'includes/openkore.' . $phpEx);


class View {
	private $options;
	private $template;
	private $submitted;

	public function __construct(OOptions $options, Template $template) {
		$this->options = $options;
		$this->template = $template;
	}

	public function display() {
		global $phpEx;
		$template = $this->template;
		$options  = $this->options;

		$template->set_filenames(array(
			'body' => 'admin/admin_openkore.tpl'
		));

		$template->assign_vars(array(
			'V_IMPORTANT_ANNOUNCEMENT' => $options->get('important_announcement'),
			'S_OPENKORE_ACTION'        => append_sid("admin_openkore.$phpEx")
		));

		$template->pparse('body');
	}

	/**
	 * Indicate that the user pressed the Submit button.
	 */
	public function setSubmitted() {
		if (!$this->submitted) {
			$this->template->assign_block_vars('submitted', array());
			$this->submitted = true;
		}
	}
}

class Controller {
	private $options;
	private $view;

	public function __construct(OOptions $options) {
		$this->options = $options;
	}

	public function start() {
		global $template;
		$this->view = new View($this->options, $template);

		if (isset($_POST['submit'])) {
			$this->options->set('important_announcement', $_POST['important_announcement']);
			$this->view->setSubmitted();
		}
	}

	public function getView() {
		return $this->view;
	}
}

$controller = new Controller(OOptions::getInstance());
$controller->start();
$view = $controller->getView();
$view->display();

include('./page_footer_admin.'.$phpEx);
?>