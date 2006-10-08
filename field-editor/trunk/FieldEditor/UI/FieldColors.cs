using System;
using Gdk;

namespace FieldEditor {

/**
 * A convenience class for managing the colors and GCs used to
 * render a field.
 */
public class FieldColors {
	/**
	 * An array which maps a BlockType to a Color.
	 *
	 * @invariant
	 *   colors.Length == number of items in BlockType
	 */
	private Color[] colors;

	/**
	 * An array which maps a BlockType to a Color. Unlike
	 * the _colors_ array, this is for colors that are to be used
	 * for selected blocks.
	 *
	 * @invariant
	 *   selection_colors.Length == number of items in BlockType
	 */
	private Color[] selection_colors;

	/**
	 * The color used to draw the selection's border.
	 *
	 * @invariant
	 *   selectionBorderColor != null
	 */
	private Color selectionBorderColor;


	public Color SelectionBorderColor {
		get { return selectionBorderColor; }
	}

	public Color GetColor(BlockType type) {
		return colors[(int) type];
	}

	public Color GetSelectionColor(BlockType type) {
		return selection_colors[(int) type];
	}

	public FieldColors() {
		int len = Enum.GetValues(((Enum) BlockType.Walkable).GetType()).Length;

		colors = new Color[len];
		selection_colors = new Color[len];

		SetColor(BlockType.Walkable,                    0xFF, 0xFF, 0xFF);
		SetColor(BlockType.NonWalkable,                 0, 0, 0);
		SetColor(BlockType.NonWalkableNonSnipableWater, 0x66, 0x66, 0xFF);
		SetColor(BlockType.WalkableWater,               0, 0, 0xFF);
		SetColor(BlockType.NonWalkableSnipableWater,    0xAA, 0xAA, 0xFF);
		SetColor(BlockType.SnipableCliff,               0, 0xBB, 0);
		SetColor(BlockType.NonSnipableCliff,            0, 0x88, 0);
		SetColor(BlockType.Unknown,                     0xFF, 0, 0);

		selectionBorderColor = new Color(0x90, 0x47, 0xBF);

		for (int i = 0; i < len; i++) {
			// Blend color with 50% 90 47 BF (purple)
			Color color = colors[i];
			color.Red   = (ushort) Math.Min(0xFFFF, ((int) color.Red   + 0x90 * 256) / 2);
			color.Green = (ushort) Math.Min(0xFFFF, ((int) color.Green + 0x47 * 256) / 2);
			color.Blue  = (ushort) Math.Min(0xFFFF, ((int) color.Blue  + 0xBF * 256) / 2);
			selection_colors[i] = color;
		}
	}

	private void SetColor(BlockType type, byte red, byte green, byte blue) {
		Color c = new Color(red, green, blue);
		colors[(int) type] = c;
	}
}

} // namespace FieldEditor