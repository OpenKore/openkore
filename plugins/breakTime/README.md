# breakTime plugin

Automatically disconnect and reconnect at certain times of the day. This
feature is useful to automatically logout during server maintenance periods.

## Console Commands

None.

## Configuration Options

### Syntax

```
autoBreakTime [{all|mon|tue|wed|thu|fri|sat|sun}] {
  startTime 
  stopTime [<time>]
}
```

### Attribute Definitions

`autoBreakTime [{all|mon|tue|wed|thu|fri|sat|sun}]`
* This option specifies the days of the week when Kore automatically disconnect.

`startTime <time>`
* This option specifies the time (in 24-hour format) when Kore will automatically disconnect.

`stopTime [<time>]`
* This option specifies the time (in 24-hour format) when Kore will automatically reconnect.


#### Notes

* All times are your computer's local time, not UTC/GMT, not the server's local time.
* startTime and stopTime can straddle either side of midnight (00:00).
* Can only be used to break for less than 24 hours; define two or more breaktimes for time periods longer than 24 hours.
* AM/PM Format is not supported, you must use 24 Hr clock! For example: Midnight is 00:00. Noon is 12:00. 9:30 PM is 21:30.
* If you tell Kore to log in later than the stopTime (with `relog 86400`, for instance), this plugin will not change the login time.
* If you tell Kore to log in earlier than the stopTime (with `relog 30`, for instance), this plugin will change the login time to the stopTime.
* If you successfully force a login between startTime and stopTime, this plugin will automatically log out within a few seconds.

## Examples

Automatically disconnect at 9:29 P.M. on Sunday and resume botting at 1:08 A.M. on Monday:
```
autoBreakTime Sun {
  startTime 21:29
  stopTime 01:08
}
```
