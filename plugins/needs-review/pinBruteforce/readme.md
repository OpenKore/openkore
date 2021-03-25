## PinBruteforce plugin assignment

If you have forgotten your account PIN, this plugin will help you recover it. The plugin uses a brute-force method, each time adding +1 to the previous pin-code value.

### Instructions:
1. In the file **config.txt** in the `loginPinCode` parameter set the initial value of the pin-code. This plugin assumes that the pin code consists of any 4 digits.
```
loginPinCode 0000
```
2. In the **sys.txt** file, enable the use of this plugin (see [manual] (https://openkore.com/wiki/loadPlugins))
3. Start the OpenKore
4. The bot will automatically start substituting the pin code. The last value is saved in the config, so the bot can be turned off at any time. When you restart it, the bot will continue guessing the password from the previous value.
5. When the pin code is found, the OpenKore will write a message:
```
[pinBruteforce] PIN code is correct: ****
```
