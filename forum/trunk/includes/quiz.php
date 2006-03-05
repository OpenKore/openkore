<?php
if (!defined('IN_PHPBB')) {
	die("????");
}

/**
 * A quiz item, containing information about the question
 * and its answers.
 */
class QuizItem {
	private $question;
	private $answers;
	private $correct;

	/**
	 * Construct a new QuizItem object.
	 * @internal
	 * @ensure
	 *     getCorrectAnswer() == -1
	 *     is_null(getQuestion())
	 *     count(getAnswers()) == 0
	 */
	public function __construct() {
		$this->answers = array();
		$this->correct = -1;
	}

	/**
	 * Return the question.
	 */
	public function getQuestion() {
		return $this->question;
	}

	/**
	 * Returns an array of possible answers.
	 */
	public function getAnswers() {
		return $this->answers;
	}

	/**
	 * Returns the index of the correct answer.
	 *
	 * @ensure 0 <= result < count(getAnswers())
	 */
	public function getCorrectAnswer() {
		return $this->correct;
	}

	/**
	 * Set the question.
	 *
	 * @internal
	 */
	public function setQuestion($question) {
		$this->question = $question;
	}

	/**
	 * Add a possible answer.
	 *
	 * @internal
	 */
	public function addAnswer($answer) {
		$this->answers[] = $answer;
	}

	/**
	 * Set the index of the correct answer.
	 *
	 * @internal
	 */
	public function setCorrectAnswer($index) {
		$this->correct = $index;
	}
}

/**
 * Thrown when the quiz source could not parse its data file.
 */
class QuizSourceParseException extends Exception {
	public function __construct($message = null, $code = 0) {
		parent::__construct($message, $code);
	}
}

/**
 * A data access object for quiz items.
 */
class QuizSource {
	/**
	 * The array containing quiz items.
	 *
	 * @invariant for all $k in $items: $k instanceof QuizItem
	 */
	private $items;

	// Temporary variables for parser.
	private $currentItem;
	private $tagstack;
	private $answerNumber;
	private $currentCharData;

	/**
	 * Construct a new QuizSource object and load the quiz items
	 * from the specified file.
	 *
	 * @param filename The XML file containing the quiz items.
	 * @require $filename != "" && file_exists($filename)
	 * @throws  QuizSourceParseException
	 */
	public function __construct($filename) {
		$this->items = array();
		$this->tagstack = array();
		$this->parse($filename);
	}

	/**
	 * Get a quiz item.
	 *
	 * @param index  The index of requested quiz item.
	 * @return  A QuizItem object.
	 * @require 0 <= $index < getCount()
	 * @ensure  result instanceof QuizItem
	 */
	public function getItem($index) {
		return $this->items[$index];
	}

	/**
	 * Get the number of quiz items.
	 *
	 * @ensure result >= 0
	 */
	public function getCount() {
		return count($this->items);
	}

	/**
	 * Parse a quiz items XML file.
	 *
	 * @param filename The XML file containing the quiz items.
	 * @require $filename != "" && file_exists($filename)
	 * @throws  QuizSourceParseException
	 */
	private function parse($filename) {
		$parser = xml_parser_create();
		xml_set_element_handler($parser,
			array($this, 'handleStartElement'),
			array($this, 'handleEndElement'));
		xml_set_character_data_handler($parser, array($this, 'handleCharData'));

		$f = fopen($filename, "r");
		if (!$f) {
			throw new QuizSourceParseException("Cannot open $filename for reading");
		}

		while ($data = fread($f, 1024 * 32)) {
			if (!xml_parse($parser, $data, feof($f))) {
				$error = sprintf("XML error: %s at line %d",
					xml_error_string(xml_get_error_code($parser)),
					xml_get_current_line_number($parser));
				throw new QuizSourceParseException($error,
					xml_get_error_code($parser));
			}
		}
		fclose($f);
		xml_parser_free($parser);
	}

	private function handleStartElement($parser, $name, $attribs) {
		array_unshift($this->tagstack, $name);
		if ($name == "ITEM") {
			$this->currentItem = new QuizItem();
			$this->answerNumber = 0;

		} else if ($name == "ANSWER") {
			if (isset($attribs['CORRECT']) && $attribs['CORRECT'] == "yes") {
				$this->currentItem->setCorrectAnswer($this->answerNumber);
			}
			$this->answerNumber++;
		}

		if ($name == "ANSWER" || $name == "QUESTION") {
			$this->currentCharData = '';
		}
	}

	private function handleEndElement($parser, $name) {
		array_shift($this->tagstack);
		if ($name == "ITEM") {
			if (is_null($this->currentItem->getQuestion())) {
				$error = sprintf("No question defined (XML line %d)",
					xml_get_current_line_number($parser));
				throw new QuizSourceParseException($error);

			} else if ($this->currentItem->getCorrectAnswer() == -1) {
				$error = sprintf("No correct answer defined (XML line %d)",
					xml_get_current_line_number($parser));
				throw new QuizSourceParseException($error);
			}
			$this->items[] = $this->currentItem;

		} else if ($name == "QUESTION") {
			$this->currentItem->setQuestion($this->currentCharData);

		} else if ($name == "ANSWER") {
			$this->currentItem->addAnswer($this->currentCharData);
		}
	}

	private function handleCharData($parser, $data) {
		$this->currentCharData .= $data;
	}
}
?>