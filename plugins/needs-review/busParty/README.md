# busParty plugin

busParty is to improves the information openkore has of the others players of the party (that are also using openkore)
because it's using bus system, it cannot dectect players that are using normal ragnarok client.
VERY RECOMMENDED in partys bigger than 2, it is also useful for master and slave party

## How to Install:
1. move the "busParty" folder to the "plugins" folder
2. open *control\sys.txt* and change:
   * enable the [bus](https://openkore.com/wiki/bus): `bus 1` (you can also configure other bus parameters)
   * add the busParty plugin to the [loadPlugins_list](https://openkore.com/wiki/loadPlugins_list): `loadPlugins_list ..., busParty`
3. run OpenKore

## New console command
**busParty** - shows all members of the fake party:
```
------------------------------ busParty Information ------------------------------
#  Name                   Map           Coord     Online  HP
0  ya4ept                 new_1-4       24, 173   Yes     150044/150044 (100%)
1  alisonrag              prontera      66, 317   Yes     10000000/10000000 (100%)
2  sctnightcore           morocc        28, 83    Yes     796286/796286 (100%)
----------------------------------------------------------------------------------
```

## Limitations
* If you close one instance of OpenKore, the character will still be displayed online
