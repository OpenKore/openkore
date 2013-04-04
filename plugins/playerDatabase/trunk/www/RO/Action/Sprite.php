<?php

namespace RO\Action;

/**
 * Armazena os dados para o desenho do sprite
 */
class Sprite {
	protected $x        = 0;
	protected $y        = 0;
	protected $index    = 0;
	protected $mirror   = 0;
	protected $color    = 0xFFFFFFFF;
	protected $scaleX   = 1.0;
	protected $scaleY   = 1.0;
	protected $rotation = 0;
	protected $type     = 0;
	protected $width    = 0;
	protected $height   = 0;

	/**
	 * 
	 */
	public function __construct() {

	}

	/**
	 * Seta a posição no eixo X
	 * @param $value nova posição
	 */
	public function setX($value) {
		$this->x = $value;
	}

	/**
	 * Retorna a posição no eixo X
	 * @return int
	 */
	public function getX() {
		return $this->x;
	}

	/**
	 * Seta a posição no eixo Y
	 * @param $value nova posição
	 */
	public function setY($value) {
		$this->y = $value;
	}
	
	/**
	 * Retorna a posição no eixo Y
	 * @return int
	 */
	public function getY() {
		return $this->y;
	}

	/**
	 * Define se a imagem será espelhada horizontalmente
	 * @param $value bool
	 */
	public function setMirror($value) {
		$this->mirror = $value;
	}

	/**
	 * Informa se a imagem deve ser espelhada.
	 */
	public function getMirror() {
		return $this->mirror;
	}

	/**
	 * 
	 */
	public function setColor($value) {
		$this->color = $value;
	}

	public function getColor() {
		return $this->color;
	}

	/**
	 * Seta o indice do Sprite
	 */
	public function setIndex($value) {
		$this->index = $value;
	}

	/**
	 * Retorna o indice do sprite
	 */
	public function getIndex() {
		return $this->index;
	}

	/**
	 * Seta a escala no eixo X
	 */
	public function setScaleX($value) {
		$this->scaleX = $value;
	}

	/**
	 * Retorna a escala no eixo Y
	 */
	public function getScaleX() {
		return $this->scaleX;
	}

	/**
	 * Seta a escala no eixo Y
	 */
	public function setScaleY($value) {
		$this->scaleY = $value;
	}

	/**
	 * Retorna a escala no eixo Y
	 */
	public function getScaleY() {
		return $this->scaleY;
	}

	/**
	 * Seta o angulo de rotação da imagem
	 */
	public function setRotation($value) {
		$this->rotation = $value;
	}

	/**
	 * Retorna o angulo de rotação da imagem
	 */
	public function getRotation() {
		return $this->rotation;
	}

	public function setType($value) {
		$this->type = $value;
	}

	public function getType() {
		return $this->type;
	}

	/**
	 * Seta a largura da imagem
	 */
	public function setWidth($value) {
		$this->width = $value;
	}

	/**
	 * Retorna a largura da imagem
	 */
	public function getWidth() {
		return $this->width;
	}

	/**
	 * Seta a altura da imagem
	 */
	public function setHeight($value) {
		$this->height = $value;
	}

	/**
	 * Retorna a altura da imagem
	 */
	public function getHeight() {
		return $this->height;
	}
}