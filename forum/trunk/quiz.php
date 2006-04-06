<?php
define('IN_PHPBB', true);
$phpbb_root_path = './';

include($phpbb_root_path . 'extension.inc');
include($phpbb_root_path . 'common.'.$phpEx);
include($phpbb_root_path . 'includes/quiz.'.$phpEx);
require_once($phpbb_root_path . 'includes/openkore.'.$phpEx);

$userdata = session_pagestart($user_ip, PAGE_QUIZ);
init_userprefs($userdata);


/**
 * Thrown when the language ID passed to the quiz model
 * is invalid.
 */
class QuizIllegalLanguageException extends Exception {
	public function __construct($message = null, $code = 0) {
		parent::__construct($message, $code);
	}
}

/**
 * A model for a quiz page.
 * This model holds:
 * - A list of quiz items that the user must answer.
 * - A list of items that the user has correctly answered.
 */
class QuizModel {
	const NUM_ITEMS = 7;

	/** @invariant $source instanceof QuizSource */
	private $source;
	/** @invariant !is_null($excludedItems) */
	private $excludedItems;
	/**
	 * An associative array, whose keys are the indices of the selected items.
	 * @invariant
	 *     !is_null($selection)
	 *     for all $k in $selection: $k
	 */
	private $selection;
	/**
	 * An associative array, whose keys are the indices of the quiz items
	 * that have been correctly answered.
	 * @invariant
	 *     !is_null($correctAnswered)
	 *     for all $k in $correctAnswered: $k
	 */
	private $correctAnswered;
	/** @invariant $language != "" */
	private $language;

	/**
	 * Construct a new QuizModel object.
	 *
	 * @param language  A language ID, used to determine which source quiz file to use.
	 * @ensure
	 *     count(this->getCorrectAnswered()) == 0
	 *     count(this->getSelection())       == 0
	 *     count(this->getExcludedItems())   == 0
	 *     this->getLanguage() == $language
	 * @throws QuizSourceParseException, QuizIllegalLanguageException
	 */
	public function __construct($language) {
		$this->source = new QuizSource($this->getFileForLanguage($language));
		$this->excludedItems   = array();
		$this->selection       = array();
		$this->correctAnswered = array();
		$this->language        = $language;
	}

	/**
	 * Get the XML file for the given language ID.
	 *
	 * @param language  A language ID.
	 * @return  A language filename.
	 * @ensure  result != ""
	 * @throws QuizIllegalLanguageException
	 */
	private function getFileForLanguage($language) {
		global $phpbb_root_path;
		if (is_null($language) || $language == "") {
			return $phpbb_root_path . "quiz/en.xml";
		} else if ($language == "pt") {
			return $phpbb_root_path . "quiz/pt.xml";
		} else if ($language == "id") {
			return $phpbb_root_path . "quiz/id.xml";
		} else if ($language == "tl") {
			return $phpbb_root_path . "quiz/tl.xml";
		} else {
			throw new QuizIllegalLanguageException();
		}
	}

	/**
	 * Return the current language ID.
	 *
	 * @ensure result != ""
	 */
	public function getLanguage() {
		return $this->language;
	}

	/**
	 * Select at most $num non-excluded random quiz items
	 * from the quiz item source. Items that are excluded
	 * from the selection are not selected.
	 *
	 * @require 0 <= $num <= getSource()->getCount()
	 */
	public function selectRandomItems($num) {
		$source = $this->source;
		$available = $source->getCount() - count(array_values($this->excludedItems));

		while ($available > 0 && count($this->selection) < $num) {
			do {
				$index = mt_rand(0, $source->getCount() - 1);
			} while (isset($this->selection[$index]) || $this->isExcluded($index));
			$this->selection[$index] = true;
			$available--;
		}
	}

	/**
	 * Select a quiz item.
	 *
	 * @param index  The index of the quiz item in the quiz item source.
	 * @require 0 <= $index < this->getSource()->getCount()
	 * @return False if the specified item is excluded from selection,
	 *         true otherwise.
	 */
	public function selectItem($index) {
		if ($this->isExcluded($index)) {
			return false;
		} else {
			$this->selection[$index] = true;
			return true;
		}
	}

	/**
	 * Check whether the correct answer is given for the specified quiz item.
	 * If not, the specified quiz item will be selected, unless it is
	 * excluded from selection.
	 *
	 * @param itemIndex    The index of the quiz item.
	 * @param answerIndex  The index of the answer.
	 * @return Whether the question was correctly answered.
	 * @require
	 *     0 <= $itemIndex < this->getSource()->getCount()
	 *     $answerIndex >= 0
	 * @ensure
	 *     if result: this->getCorrectAnswered()[$itemIndex]
	 */
	public function answer($itemIndex, $answerIndex) {
		$item = $this->source->getItem($itemIndex);
		if ($item->getCorrectAnswer() != $answerIndex) {
			$this->selectItem($itemIndex);
			return false;
		} else {
			$this->correctAnswered[$itemIndex] = true;
			return true;
		}
	}

	/**
	 * Return an array of indices for the quiz items which have been
	 * correct answered (with $this->answer())
	 *
	 * @ensure !is_null(result)
	 */
	public function getCorrectAnswered() {
		return array_keys($this->correctAnswered);
	}

	/**
	 * Return an array containing the indices of the selected items.
	 *
	 * @ensure for all $k in result: 0 <= $k < this->getSource->getCount()
	 */
	public function getSelection() {
		return array_keys($this->selection);
	}

	private function isExcluded($index) {
		return $index < count(array_values($this->excludedItems))
		    && $this->excludedItems[$index];
	}

	/**
	 * Exclude a specific quiz item from being selected.
	 *
	 * @param index The index (in the quiz source) of the quiz
	 *              item you want to exclude.
	 * @require 0 <= $index < this->getSource()->getCount()
	 */
	public function excludeItem($index) {
		$this->excludedItems[$index] = true;
	}

	/**
	 * Returns an array of indices of the excluded quiz items.
	 *
	 * @return !is_null(result)
	 */
	public function getExcludedItems() {
		return array_keys($this->excludedItems);
	}

	/**
	 * Return the used quiz source object.
	 *
	 * @ensure result instanceof QuizSource
	 */
	public function getSource() {
		return $this->source;
	}

	/**
	 * Mark the user's account as having finished the quiz.
	 */
	public function saveUserSetting() {
		global $userdata;
		global $db;

		$sql = sprintf("UPDATE %s SET user_done_quiz = 1 WHERE user_id = %d",
			       USERS_TABLE,
			       $userdata['user_id']
		);
		$result = $db->sql_query($sql);
		if (!$result) {
			$error = $db->sql_error();
			printf("A database error occured: %s (code %d)",
			       htmlspecialchars($error['message']),
			       $error['code']
			);
			exit;
		}
	}

	/**
	 * Checks whether the user has answered all questions in the quiz.
	 *
	 * @ensure result == (count(this->getSelection()) == 0)
	 */
	public function done() {
		return count($this->getSelection()) == 0;
	}
}

class QuizView {
	/** @invariant $model instanceof QuizModel */
	private $model;
	/** @invariant $template instanceof Template */
	private $template;
	private $isIntro;

	/**
	 * Construct a QuizView object.
	 *
	 * @param model     The model to use.
	 * @param template  The template engine to use.
	 * @param isIntro   Whether this is the first page in the quiz. (iow,
	 *                  whether the user has pressed Submit before)
	 */
	public function __construct(QuizModel $model, Template $template, $isIntro) {
		$this->model    = $model;
		$this->template = $template;
		$this->items    = array();
		$this->isIntro  = $isIntro;
		$this->init();
	}

	private function init() {
		global $phpEx;
		$template = $this->template;

		$template->set_filenames(array(
			'quiz' => 'quiz.tpl')
		);

		$queryParams = OUtils::removeKeys(remove_sid($_SERVER['QUERY_STRING']),
						  array('language'));
		if ($this->isIntro) {
			$source = $this->model->getSource();
			$template->assign_block_vars('intro', array(
				'INTRO_TEXT' => $source->getIntroText(),
				'RULES_LINK_TEXT' => $source->getRulesLinkText(),
				'QUERY_PARAMS' => $queryParams
			));
		}

		$url = "quiz." . $phpEx . "?" . remove_sid($_SERVER['QUERY_STRING']);
		$template->assign_vars(array(
			'FORM_ACTION' => append_sid($url),
			'LANGUAGE' => htmlspecialchars($this->model->getLanguage()),
		));
	}

	/**
	 * Save the model's state into HTML form elements.
	 */
	private function saveState() {
		$template = $this->template;
		$model = $this->model;
		$indices = $model->getSelection();

		$allItems = array();
		foreach ($indices as $itemIndex) {
			$allItems[] = $itemIndex;
		}

		foreach ($model->getCorrectAnswered() as $itemIndex) {
			$allItems[] = $itemIndex;
		}
		$template->assign_vars(array(
			'QUESTIONS' => htmlspecialchars(implode(',', $allItems))
		));

		foreach ($model->getCorrectAnswered() as $itemIndex) {
			$template->assign_block_vars('answered_question', array(
				'ITEMINDEX'   => $itemIndex,
				'ANSWERINDEX' => $model->getSource()->getItem($itemIndex)->getCorrectAnswer()
			));
		}
	}

	/**
	 * Display the model.
	 */
	public function display() {
		$template = $this->template;
		$model = $this->model;
		$indices = $model->getSelection();

		$this->saveState();

		if (!$this->isIntro) {
			$correct = count($model->getCorrectAnswered());
			$source = $model->getSource();
			$this->template->assign_block_vars('answered', array(
				'NUMBER' => sprintf($source->getCorrectAnswerText(), $correct),
				'RULES_LINK_TEXT' => $source->getRulesLinkText()
			));
		}

		foreach ($indices as $index) {
			$item = $model->getSource()->getItem($index);

			$answers = '';
			$answerIndex = 0;
			foreach ($item->getAnswers() as $answer) {
				$answers .= sprintf(
					'<input type="radio" id="checkbox-%d-%d" name="question-%d" value="%d">' .
					'<label for="checkbox-%d-%d">%s</label><br>%s',
					$index,	$answerIndex,
					$index,
					$answerIndex,
					$index, $answerIndex,
					htmlspecialchars($answer),
					"\n");
				$answerIndex++;
			}

			$template->assign_block_vars('quizitem', array(
				'QUESTION' => htmlspecialchars($item->getQuestion()),
				'ANSWERS'  => $answers
			));
		}

		$template->pparse('quiz');
	}
}

class Controller {
	private $view;
	private $model;

	/**
	 * Start the controller.
	 */
	public function start() {
		global $template;

		if ($this->dataSubmitted()) {
			$this->validateInput();
		}
		try {
		$model = new QuizModel($this->getLanguage());
		} catch (QuizSourceParseException $e) {
			message_die(GENERAL_ERROR, "An internal error occured while parsing the quiz file: " .
				    $e->getMessage() . "<br>\n" .
				    "Please contact an administrator.");
		} catch (QuizIllegalLanguageException $e) {
			message_die(GENERAL_ERROR, "Illegal language specified: " .
				    htmlspecialchars($this->getLanguage()));
		}
		$this->model = $model;

		if ($this->dataSubmitted()) {
			$this->validateInput2();
			$this->selectItems(explode(',', $_POST['questions']));
		} else {
			$model->selectRandomItems(QuizModel::NUM_ITEMS);
		}

		if ($model->done()) {
			$this->validateRedirectionInput();
			$model->saveUserSetting();
			$this->completed();

		} else {
			$this->view = new QuizView($model, $template, !$this->dataSubmitted());
		}
	}

	/**
	 * Checks whether the user pressed the submit button.
	 */
	private function dataSubmitted() {
		return isset($_POST['submit']);
	}

	/**
	 * @require dataSubmitted()
	 * @ensure
	 *     isset($_POST['language'])
	 *     isset($_POST['questions'])
	 *     count(explode(',', $_POST['questions'])) == QuizModel::NUM_ITEMS
	 */
	private function validateInput() {
		if (!isset($_POST['language'])) {
			die("No language set.");
		} else if (!isset($_POST['questions'])) {
			die("No questions set.");
		}

		$num = count(explode(',', $_POST['questions']));
		if ($num != QuizModel::NUM_ITEMS) {
			die("Number of questions is invalid.");
		}
	}

	/**
	 * @require dataSubmitted() && !is_null($this->model)
	 * @ensure
	 *     for all $k in explode(',', $_POST['questions']):
	 *         $k is a number
	 *         0 <= $index < $this->model->getSource()->getCount()
	 */
	private function validateInput2() {
		foreach (explode(',', $_POST['questions']) as $index) {
			if (!is_numeric($index) || $index < 0 || $index >= $this->model->getSource()->getCount()) {
				die("$index is an invalid question index.");
			}
		}
	}

	/**
	 * Get the current language ID.
	 *
	 * @require !$this->dataSubmitted() || isset($_POST['language'])
	 * @return A language ID, or null.
	 */
	private function getLanguage() {
		if ($this->dataSubmitted()) {
			return $_POST['language'];
		} else if (isset($_GET['language'])) {
			return $_GET['language'];
		} else {
			return null;
		}
	}

	/**
	 * Select the quiz items which haven't been answered, or are
	 * incorrectly answered. Correctly answered items are saved
	 * by the model.
	 *
	 * @param itemIndices  An array of indices for all quiz items.
	 * @require
	 *     $this->dataSubmitted()
	 *     !is_null($this->model)
	 *     !is_null($this->view)
	 *     for all $k in $itemIndices:
	 *         $k is a number
	 *         0 <= $index < $this->model->getSource()->getCount()
	 */
	private function selectItems($itemIndices) {
		$correctAnswered = 0;
		foreach ($itemIndices as $itemIndex) {
			$itemIsAnswered = isset($_POST["question-$itemIndex"]);
			if ($itemIsAnswered) {
				$answerIndex = $_POST["question-$itemIndex"];
				$this->model->answer($itemIndex, $answerIndex);
			} else {
				$this->model->selectItem($itemIndex);
			}
		}
	}

	private function validateRedirectionInput() {
		if (!isset($_GET['from'])) {
			die("No 'from' ID set.");
		} else if ($_GET['from'] != "posting") {
			die("Invalid 'from' ID.");
		}

		if ($_GET['from'] == "posting") {
			if (!isset($_GET['mode'])) {
				die("No posting mode set.");
			} else if ($_GET['mode'] != "newtopic" && $_GET['mode'] != "reply"
				&& $_GET['mode'] != "quote"    && $_GET['mode'] != "editpost"
				&& $_GET['mode'] != "delete") {
				die("Invalid posting mode.");
			} else if ($_GET['mode'] == "newtopic" && !isset($_GET['f'])) {
				die("No forum ID set.");
			} else if ($_GET['mode'] == "reply" && !isset($_GET['t'])) {
				die("No topic ID set.");
			} else if ($_GET['mode'] == "quote" && !isset($_GET['p'])) {
				die("No post ID set.");
			} else if ($_GET['mode'] == "editpost" && !isset($_GET['p'])) {
				die("No post ID set.");
			} else if ($_GET['mode'] == "delete" && !isset($_GET['p'])) {
				die("No post ID set.");
			}
		}
	}

	/**
	 * Called when the quiz has been completed.
	 */
	private function completed() {
		global $phpEx;

		if ($_GET['from'] == "posting") {
			$url = "posting." . $phpEx . "?mode=" . $_GET['mode'] . "&";
			if ($_GET['mode'] == "newtopic") {
				$url .= "f=" . urlencode($_GET['f']);
			} else if ($_GET['mode'] == "reply") {
				$url .= "t=" . urlencode($_GET['t']);
			} else {
				$url .= "p=" . urlencode($_GET['p']);
			}
			header("Location: " . append_sid($url));
		}
	}

	public function getView() {
		return $this->view;
	}
}

$controller = new Controller();
$controller->start();

$view = $controller->getView();
if ($view) {
	$page_title = 'Quiz';
	require_once($phpbb_root_path . 'includes/page_header.'.$phpEx);
	$view->display();
	require_once($phpbb_root_path . 'includes/page_tail.'.$phpEx);
}
?>