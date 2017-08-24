# teleToDest plugin

When active and config file is corretly set openkore will try to get to a certain coordinate in a map by teleporting,
it works just like 'route_teleport' setting in config.

## Console Commands

None.

## Configuration Options

### Syntax

teleToDestOn [1|0] #Activates the plugin or not
teleToDestMap [prontera|gef_fild10|pay_dun02|etc] #map in which the plugin will work
teleToDestXY [250 140 | 99 120 | 50 300 | etc] #x and y coordinates the plugin will try to get to
teleToDestDistance [20 | 100 | 50 | etc] #Minimun distance at which the plugin will consider 'destination reached'
teleToDestMethod [steps|radius] #Method that will be used to determine minimun distance, radius is geometric distance to the target location, steps is the distance in steps to get to the target location


#### Notes

* Radius method for distance is faster and less CPU intensive than steps method.
* If for some reason openkore cannot teleport the plugin will be deactivated and teleToDestOn will be set to 0
* When destination is reached teleToDestOn will be set to 0

## Examples

Will try to get to 'x: 150 y: 170' of geffen by at least distance 50 (in least steps):
```
teleToDestOn 1
teleToDestMap geffen
teleToDestXY 150 170
teleToDestDistance 50
teleToDestMethod steps
```