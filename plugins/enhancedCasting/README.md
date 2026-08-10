# enhancedCasting

`enhancedCasting` selects an attack skill or ammunition from the target's
property in `monsters_table.txt`. It uses OpenKore's current
`attackSkillSlot` AI instead of maintaining a separate attack queue.

## Elemental skills

Add the following keys to every participating `attackSkillSlot`:

```text
attackSkillSlot Fire Bolt {
    target_elementalBest 1
    elementalElement Fire
    elementalPriority 10
    elementalLevelMode linear
}
```

- `target_elementalBest 1` enables selection for the block.
- `elementalElement` is the skill's attack property.
- `elementalPriority` breaks ties after the property modifier. A larger value
  wins. This is useful for preferring Jupitel Thunder against Neutral targets.
- `elementalLevelMode linear` learns conservative damage per skill level from
  successful casts and chooses the lowest sufficient level. Omit it for skills
  whose hit count is not linear.

The plugin considers only learned skills whose normal self, monster, and
inventory conditions currently pass. Elemental multiplier always outranks the
tie-break priority.

## Ammunition

Declare available ammunition in priority order:

```text
elementalAmmo Fire Arrow {
    element Fire
    priority 10
}
```

When combat starts, the plugin selects the available ammunition with the best
property modifier and equips it. Missing ammunition is ignored.

## Diagnostics

Use `ecinfo <monster index>` to print the target's level, HP, property,
race, size, and selected skill.

Dynamic property changes and the Frozen/Petrified states override the default
property from `monsters_table.txt`.
